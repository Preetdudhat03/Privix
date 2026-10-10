package com.privix.privix

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Base64
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.AppOpsManager
import android.os.Process
import com.privix.privix.services.LockPreferences
import com.privix.privix.services.AppLockAccessibilityService
import com.privix.privix.services.AppLockForegroundService
import com.privix.privix.services.CurtainManager
import java.io.ByteArrayOutputStream
import java.security.MessageDigest

/**
 * Main entry point. Registers the platform channel that bridges Flutter ↔ Kotlin.
 * 
 * All platform channel methods are defined here. Flutter calls these methods
 * to interact with native Android APIs that have no Flutter equivalent.
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "com.privix.applock/channel"
    }

    private lateinit var lockPrefs: LockPreferences

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        lockPrefs = LockPreferences(this)

        // Automatically start ForegroundService if in Usage Access mode
        if (lockPrefs.getEngineMode() == LockPreferences.ENGINE_USAGE_STATS && isUsageStatsPermissionGranted()) {
            AppLockForegroundService.start(this)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {

                "getInstalledApps" -> {
                    try {
                        val apps = getInstalledUserApps()
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("GET_APPS_ERROR", e.message, null)
                    }
                }

                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        try {
                            val icon = getAppIcon(packageName)
                            result.success(icon)
                        } catch (e: Exception) {
                            result.error("ICON_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "packageName is required", null)
                    }
                }

                // ─── Locked Apps Management ──────────────────────────
                "saveLockedApps" -> {
                    val apps = call.argument<List<String>>("apps")
                    if (apps != null) {
                        lockPrefs.setLockedApps(apps.toSet())
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "apps list is required", null)
                    }
                }

                "getLockedApps" -> {
                    result.success(lockPrefs.getLockedApps().toList())
                }

                // ─── PIN Management ──────────────────────────────────
                "savePinHash" -> {
                    val pin = call.argument<String>("pin")
                    if (pin != null) {
                        val hash = hashPin(pin)
                        lockPrefs.setPinHash(hash, pin.length)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "pin is required", null)
                    }
                }

                "verifyPin" -> {
                    val pin = call.argument<String>("pin")
                    if (pin != null) {
                        val inputHash = hashPin(pin)
                        val storedHash = lockPrefs.getPinHash()
                        result.success(inputHash == storedHash)
                    } else {
                        result.error("INVALID_ARGS", "pin is required", null)
                    }
                }

                "isPinSet" -> {
                    result.success(lockPrefs.isPinSet())
                }

                // ─── Biometric ───────────────────────────────────────
                "setBiometricEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    lockPrefs.setBiometricEnabled(enabled)
                    result.success(true)
                }

                "isBiometricEnabled" -> {
                    result.success(lockPrefs.isBiometricEnabled())
                }

                // ─── Relock Timeout ──────────────────────────────────
                "setRelockTimeout" -> {
                    val timeout = call.argument<Number>("timeout")?.toLong()
                    if (timeout != null) {
                        lockPrefs.setRelockTimeout(timeout)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "timeout is required", null)
                    }
                }

                "getRelockTimeout" -> {
                    result.success(lockPrefs.getRelockTimeout())
                }

                // ─── Permission Checks ───────────────────────────────
                "checkAccessibilityPermission" -> {
                    result.success(isAccessibilityServiceEnabled())
                }

                "checkUsageStatsPermission" -> {
                    result.success(isUsageStatsPermissionGranted())
                }

                "checkOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }

                "checkBatteryOptimization" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }

                // ─── Open Settings ───────────────────────────────────
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }

                "openUsageStatsSettings" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }

                "openOverlaySettings" -> {
                    val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }

                "openBatteryOptimizationSettings" -> {
                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }

                // ─── Detection Engine & Service Control ───────────────
                "getEngineMode" -> {
                    result.success(lockPrefs.getEngineMode())
                }

                "setEngineMode" -> {
                    val mode = call.argument<String>("mode") ?: LockPreferences.ENGINE_USAGE_STATS
                    lockPrefs.setEngineMode(mode)
                    if (mode == LockPreferences.ENGINE_USAGE_STATS) {
                        if (isUsageStatsPermissionGranted()) {
                            AppLockForegroundService.start(this)
                        }
                    } else {
                        AppLockForegroundService.stop(this)
                    }
                    result.success(true)
                }

                "pauseProtection" -> {
                    val minutes = call.argument<Int>("minutes") ?: 15
                    lockPrefs.pauseForMinutes(minutes)
                    result.success(true)
                }

                "resumeProtection" -> {
                    lockPrefs.resumeProtection()
                    result.success(true)
                }

                "isProtectionPaused" -> {
                    result.success(lockPrefs.isPaused())
                }

                "getPausedRemainingSeconds" -> {
                    result.success(lockPrefs.getPausedRemainingSeconds())
                }

                // ─── Service Status ──────────────────────────────────
                "isServiceRunning" -> {
                    val mode = lockPrefs.getEngineMode()
                    val running = if (mode == LockPreferences.ENGINE_USAGE_STATS) {
                        AppLockForegroundService.isRunning
                    } else {
                        AppLockAccessibilityService.isRunning
                    }
                    result.success(running)
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Get all user-installed (non-system) apps with name and package only.
     * Icons are fetched lazily via getAppIcon to improve loading speed.
     */
    private fun getInstalledUserApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val apps = mutableListOf<Map<String, Any?>>()

        val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledApplications(0)
        }

        for (appInfo in packages) {
            // Skip system apps
            if (appInfo.flags and ApplicationInfo.FLAG_SYSTEM != 0 &&
                appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP == 0) {
                continue
            }

            // Skip our own app
            if (appInfo.packageName == packageName) continue

            try {
                val appName = pm.getApplicationLabel(appInfo).toString()
                apps.add(mapOf(
                    "packageName" to appInfo.packageName,
                    "appName" to appName
                ))
            } catch (e: Exception) {
                // Skip apps we can't read
            }
        }

        // Sort alphabetically
        return apps.sortedBy { (it["appName"] as? String)?.lowercase() }
    }

    /**
     * Fetch a specific app icon, resize it for performance, and return as ByteArray.
     */
    private fun getAppIcon(targetPackage: String): ByteArray? {
        val pm = packageManager
        return try {
            val appInfo = pm.getApplicationInfo(targetPackage, 0)
            val icon = pm.getApplicationIcon(appInfo)
            drawableToByteArray(icon)
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Resize icon to 100x100 and convert to ByteArray with optimized compression.
     */
    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val targetSize = 100
        val bitmap = when (drawable) {
            is BitmapDrawable -> {
                if (drawable.bitmap.width <= targetSize && drawable.bitmap.height <= targetSize) {
                    drawable.bitmap
                } else {
                    Bitmap.createScaledBitmap(drawable.bitmap, targetSize, targetSize, true)
                }
            }
            else -> {
                val bmp = Bitmap.createBitmap(targetSize, targetSize, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                bmp
            }
        }

        val stream = ByteArrayOutputStream()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            bitmap.compress(Bitmap.CompressFormat.WEBP_LOSSY, 85, stream)
        } else {
            bitmap.compress(Bitmap.CompressFormat.PNG, 85, stream)
        }
        return stream.toByteArray()
    }


    /**
     * Check if our AccessibilityService is currently enabled.
     */
    private fun isAccessibilityServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_GENERIC
        )
        val myService = ComponentName(this, AppLockAccessibilityService::class.java)
        return enabledServices.any {
            it.resolveInfo.serviceInfo.let { si ->
                ComponentName(si.packageName, si.name) == myService
            }
        }
    }

    private fun isUsageStatsPermissionGranted(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hashPin(pin: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hashBytes = digest.digest(pin.toByteArray())
        return hashBytes.joinToString("") { "%02x".format(it) }
    }
}

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
import android.view.WindowManager
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.AppOpsManager
import android.os.Process
import android.service.quicksettings.TileService
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import com.privix.privix.services.LockPreferences
import com.privix.privix.services.AppLockForegroundService
import com.privix.privix.services.CurtainManager
import com.privix.privix.services.PrivixTileService
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

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

    private fun requestTileUpdate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                TileService.requestListeningState(
                    this,
                    ComponentName(this, PrivixTileService::class.java)
                )
            } catch (_: Exception) {}
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Security Hardening: Block screenshots, screen recording, and Recent task snapshot
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        lockPrefs = LockPreferences(this)

        // Force Quick Settings Tile to refresh its icon and state
        requestTileUpdate()

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

                // ─── App Self-Lock Authentication ─────────────────────
                "authenticateUser" -> {
                    val executor = ContextCompat.getMainExecutor(this)
                    val biometricPrompt = BiometricPrompt(this, executor,
                        object : BiometricPrompt.AuthenticationCallback() {
                            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                                super.onAuthenticationError(errorCode, errString)
                                result.success(false)
                            }
                            override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                                super.onAuthenticationSucceeded(authResult)
                                result.success(true)
                            }
                            override fun onAuthenticationFailed() {
                                super.onAuthenticationFailed()
                            }
                        })

                    val promptInfoBuilder = BiometricPrompt.PromptInfo.Builder()
                        .setTitle("Privix Security")
                        .setSubtitle("Unlock to access Privix dashboard")

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        promptInfoBuilder.setAllowedAuthenticators(
                            androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG or
                            androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        promptInfoBuilder.setDeviceCredentialAllowed(true)
                    }

                    try {
                        biometricPrompt.authenticate(promptInfoBuilder.build())
                    } catch (e: Exception) {
                        result.error("AUTH_ERROR", e.message, null)
                    }
                }

                // ─── Locked Apps Management ──────────────────────────
                "saveLockedApps" -> {
                    val apps = call.argument<List<String>>("apps")
                    if (apps != null) {
                        val set = apps.toSet()
                        lockPrefs.setLockedApps(set)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "apps list is required", null)
                    }
                }

                "getLockedApps" -> {
                    result.success(lockPrefs.getLockedApps().toList())
                }

                // ─── PIN Management (Salted PBKDF2) ───────────────────
                "savePinHash" -> {
                    val pin = call.argument<String>("pin")
                    if (pin != null) {
                        val hash = hashPinPbkdf2(pin)
                        lockPrefs.setPinHash(hash, pin.length)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "pin is required", null)
                    }
                }

                "verifyPin" -> {
                    val pin = call.argument<String>("pin")
                    if (pin != null) {
                        val storedHash = lockPrefs.getPinHash()
                        if (storedHash == null) {
                            result.success(false)
                        } else {
                            val inputPbkdf2 = hashPinPbkdf2(pin)
                            val isPbkdf2Valid = MessageDigest.isEqual(inputPbkdf2.toByteArray(), storedHash.toByteArray())
                            if (isPbkdf2Valid) {
                                result.success(true)
                            } else {
                                // Backward compatibility check for legacy SHA-256
                                val legacyHash = hashPinLegacy(pin)
                                val isLegacyValid = MessageDigest.isEqual(legacyHash.toByteArray(), storedHash.toByteArray())
                                if (isLegacyValid) {
                                    // Seamlessly upgrade legacy hash to PBKDF2
                                    lockPrefs.setPinHash(inputPbkdf2, pin.length)
                                    result.success(true)
                                } else {
                                    result.success(false)
                                }
                            }
                        }
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
                    result.success(false)
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
                    result.success(false)
                }

                "openUsageStatsSettings" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }

                "openOverlaySettings" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        val fallback = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(fallback)
                        result.success(true)
                    }
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
                    // Safe guard: Always enforce Usage Access Mode (Gov & Bank Safe)
                    lockPrefs.setEngineMode(LockPreferences.ENGINE_USAGE_STATS)
                    if (isUsageStatsPermissionGranted()) {
                        AppLockForegroundService.start(this)
                    }
                    result.success(true)
                }

                "pauseProtection" -> {
                    val minutes = call.argument<Int>("minutes") ?: 15
                    lockPrefs.pauseForMinutes(minutes)
                    requestTileUpdate()
                    result.success(true)
                }

                "resumeProtection" -> {
                    lockPrefs.resumeProtection()
                    requestTileUpdate()
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
                    result.success(AppLockForegroundService.isRunning)
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Get all user-installed apps and launchable apps (Gallery, Camera, Settings, etc.)
     * with name and package only. Icons are fetched lazily via getAppIcon to improve loading speed.
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

        // Query all packages that have a launcher activity (apps with an icon in home screen/app drawer)
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val launcherPackages = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.queryIntentActivities(launcherIntent, PackageManager.ResolveInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentActivities(launcherIntent, 0)
            }.map { it.activityInfo.packageName }.toSet()
        } catch (_: Exception) {
            emptySet()
        }

        // Whitelist critical system packages that users MUST be able to lock
        // to prevent unauthorized uninstallation, data clearing, or permission revocation
        val protectableSystemPackages = setOf(
            "com.android.settings",
            "com.android.vending",
            "com.google.android.packageinstaller",
            "com.android.packageinstaller"
        )

        for (appInfo in packages) {
            // Skip our own app
            if (appInfo.packageName == packageName) continue

            // Skip disabled apps
            if (!appInfo.enabled) continue

            val isUserApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM == 0) ||
                            (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP != 0)
            val hasLauncher = launcherPackages.contains(appInfo.packageName)
            val isProtectableSystem = protectableSystemPackages.contains(appInfo.packageName)

            // Keep user apps, any app with a launcher icon (Samsung Gallery, Photos, Camera, etc.),
            // and critical system control apps
            if (!isUserApp && !hasLauncher && !isProtectableSystem) {
                continue
            }

            try {
                val appName = pm.getApplicationLabel(appInfo).toString()
                if (appName.isNotBlank()) {
                    apps.add(mapOf(
                        "packageName" to appInfo.packageName,
                        "appName" to appName
                    ))
                }
            } catch (e: Exception) {
                // Skip apps we can't read
            }
        }

        // Deduplicate by packageName and sort alphabetically
        return apps.distinctBy { it["packageName"] as? String }
            .sortedBy { (it["appName"] as? String)?.lowercase() }
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

    private fun getOrCreatePinSalt(): ByteArray {
        val saltKey = "pin_pbkdf2_salt"
        val existing = lockPrefs.getPrefs().getString(saltKey, null)
        if (existing != null) {
            return Base64.decode(existing, Base64.NO_WRAP)
        }
        val salt = ByteArray(16)
        SecureRandom().nextBytes(salt)
        val encoded = Base64.encodeToString(salt, Base64.NO_WRAP)
        lockPrefs.getPrefs().edit().putString(saltKey, encoded).apply()
        return salt
    }

    private fun hashPinPbkdf2(pin: String): String {
        val salt = getOrCreatePinSalt()
        val spec = PBEKeySpec(pin.toCharArray(), salt, 10000, 256)
        val factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val hash = factory.generateSecret(spec).encoded
        return hash.joinToString("") { "%02x".format(it) }
    }

    private fun hashPinLegacy(pin: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hashBytes = digest.digest(pin.toByteArray())
        return hashBytes.joinToString("") { "%02x".format(it) }
    }

    override fun onResume() {
        super.onResume()
        if (Settings.canDrawOverlays(this)) {
            CurtainManager.init(applicationContext)
        }
    }
}

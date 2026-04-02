package com.privix.privix.services

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.privix.privix.AuthActivity
import com.privix.privix.services.UnlockManager
import com.privix.privix.services.CurtainManager

/**
 * Core detection engine for the app lock.
 * 
 * WHY AccessibilityService: Android restricts foreground app detection since Android 5.0+.
 * UsageStatsManager requires polling and has latency. AccessibilityService gets real-time
 * TYPE_WINDOW_STATE_CHANGED events the instant a new window appears — this is the only
 * reliable non-root method for instant lock screen triggering.
 * 
 * HOW IT WORKS:
 * 1. Android fires onAccessibilityEvent when any window state changes
 * 2. We extract the package name from the event
 * 3. Compare against our locked apps list
 * 4. If locked → check if recently unlocked (relock timer) 
 * 5. If needs locking → start OverlayService to show lock screen
 */
class AppLockAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "PrivixAccessibility"
        
        // Debounce interval to prevent overlay flickering on rapid app switches
        private const val DEBOUNCE_MS = 200L // Reduced for snappier feel

        // System packages that should never be locked
        private val SYSTEM_PACKAGES = setOf(
            "com.android.systemui",
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.android.settings",
            "com.android.packageinstaller",
            "android",
            "com.privix.privix"
        )
        
        @Volatile
        var isRunning = false
            private set
            
        var lastForegroundPackage: String? = null
        private var lockedAppsCache: Set<String> = emptySet()
    }

    private lateinit var lockPrefs: LockPreferences
    private var lastTriggeredPackage: String? = null
    private var lastTriggerTime: Long = 0
    
    // Track if we are returning from a system window (like notifications)
    private var returningFromSystemWindow = false

    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                Log.d(TAG, "Screen off: clearing all unlocks")
                lockPrefs.clearUnlockedApps()
                UnlockManager.clear()
                lastForegroundPackage = null
                returningFromSystemWindow = false
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        lockPrefs = LockPreferences(this)
        isRunning = true
        CurtainManager.init(this) // Pre-warm the overlay
        
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        registerReceiver(screenOffReceiver, filter)
        
        Log.d(TAG, "AppLockAccessibilityService created & pre-warmed")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isRunning = true
        CurtainManager.init(this)
        Log.d(TAG, "AppLockAccessibilityService connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        val eventType = event.eventType
        
        // 1. Filter: we only care about window and content changes
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && 
            eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) return

        val eventPackage = event.packageName?.toString()
        val topPackage = getTopPackageName()
        
        // A. Resolve actual active package
        var packageName = eventPackage
        if (packageName == null || !lockedAppsCache.contains(packageName)) {
            packageName = topPackage ?: eventPackage ?: return
        }

        // B. SYNC locked apps cache promptly
        if (lockedAppsCache.isEmpty() || packageName == "com.privix.privix") {
            lockedAppsCache = lockPrefs.getLockedApps()
        }

        val previousPackage = lastForegroundPackage

        // C. SERVICE PACKAGE HANDLING (Launcher, Settings, etc.)
        if (isServicePackage(packageName)) {
            // --- EXIT DETECTION ---
            // If we are moving FROM a locked app TO a service screen, revoke unlock.
            if (previousPackage != null && !isServicePackage(previousPackage)) {
                if (lockedAppsCache.contains(previousPackage)) {
                    Log.d(TAG, "User exited $previousPackage to $packageName. Revoking session.")
                    UnlockManager.forgetApp(previousPackage)
                    lockPrefs.removeAppUnlocked(previousPackage)
                    // We DO NOT set lastForegroundPackage = null here anymore. 
                    // We keep it so we can detect backgrounding events of the SAME app.
                }
            }
            
            if (packageName != "com.privix.privix") {
                returningFromSystemWindow = true
                // settling on a system window now, can clear the tracker
                lastForegroundPackage = packageName 
            }
            return
        }

        // Ignore our own activity logic
        if (packageName == "com.privix.privix") return

        // D. TRANSITION DIRECTION CHECK (Entry vs Exit)
        // If the top window is the Launcher, but we see a locked app event:
        if (topPackage != null && isServicePackage(topPackage)) {
            if (packageName == previousPackage) {
                // This is almost certainly an EXIT (app is backgrounding). Skip lock.
                return
            }
        }

        // E. NAVIGATION CHECKS
        // 1. Same-app transition skip (unless session was revoked)
        if (packageName == previousPackage && !returningFromSystemWindow) {
            return
        }

        // 2. Returning from notifications panel etc.
        if (returningFromSystemWindow && packageName == previousPackage) {
            returningFromSystemWindow = false
            return
        }
        
        returningFromSystemWindow = false

        // E. LOCK REQUIREMENT CHECKS
        // 1. Check if the current app needs locking
        val isLocked = lockedAppsCache.contains(packageName) || lockPrefs.isAppLocked(packageName)
        if (!isLocked) return

        // 2. Check if it's already unlocked in this session
        if (UnlockManager.isAppSessionUnlocked(packageName) || lockPrefs.isAppCurrentlyUnlocked(packageName)) {
            lastForegroundPackage = packageName
            return
        }

        // F. PREDICTIVE & DIRECTIONAL FILTERING
        // To prevent "Lock on Leave", only trigger predictive locks (when Launcher is on top) 
        // if this is an actual Window State Change (a launch).
        if (topPackage != null && isServicePackage(topPackage)) {
            if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                // Ignore background redraws or content changes for exiting apps.
                return
            }
        }

        // G. DEBOUNCE & TRIGGER
        val now = System.currentTimeMillis()
        if (packageName == lastTriggeredPackage && (now - lastTriggerTime) < DEBOUNCE_MS) {
            return
        }

        lastForegroundPackage = packageName
        lastTriggeredPackage = packageName
        lastTriggerTime = now

        Log.d(TAG, "TRIGGERING LOCK for: $packageName")

        // 1. Show curtain instantly (PREDICTIVE ZERO-FLICKER)
        CurtainManager.show(this)
        
        // 2. Launch Auth Activity
        showAuthScreen(packageName)
    }

    private fun isServicePackage(pkg: String?): Boolean {
        if (pkg == null) return false
        // Include launcher, settings, and our own app for immediate skipping
        return pkg == "com.android.systemui" || 
               pkg == "android" || 
               pkg == "com.privix.privix" ||
               pkg == "com.android.settings" ||
               pkg == "com.android.packageinstaller" ||
               pkg.contains("launcher", ignoreCase = true)
    }

    /**
     * Inspects the window hierarchy to find the topmost application package.
     * This is much faster and more reliable than waiting for a WindowState event.
     */
    private fun getTopPackageName(): String? {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
            val windowList = windows
            if (!windowList.isNullOrEmpty()) {
                // Iterate backwards to find the top-most application window
                for (i in windowList.size - 1 downTo 0) {
                    val window = windowList[i]
                    if (window.type == android.view.accessibility.AccessibilityWindowInfo.TYPE_APPLICATION) {
                        return window.root?.packageName?.toString()
                    }
                }
            }
        }
        // Fallback to the active window root
        return rootInActiveWindow?.packageName?.toString()
    }

    private fun showAuthScreen(packageName: String) {
        val intent = Intent(this, AuthActivity::class.java).apply {
            putExtra("packageName", packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_NO_ANIMATION or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
        }
        startActivity(intent)
    }

    override fun onInterrupt() {
        Log.d(TAG, "AppLockAccessibilityService interrupted")
    }

    override fun onDestroy() {
        isRunning = false
        try {
            unregisterReceiver(screenOffReceiver)
        } catch (e: Exception) {
            // Already unregistered
        }
        Log.d(TAG, "AppLockAccessibilityService destroyed")
        super.onDestroy()
    }
}

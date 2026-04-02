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
        
        // 1. Rapid filter: we only care about window and content changes
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && 
            eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) return

        // 2. High-Speed Detection (Zero Delay)
        // Check the direct event first — this is the fastest path.
        val eventPackage = event.packageName?.toString()
        if (eventPackage != null && isServicePackage(eventPackage)) return // Ignore system components early
        
        // Use the event package if it's already in our cache for immediate locking
        var packageName = eventPackage
        if (packageName == null || !lockedAppsCache.contains(packageName)) {
            // Only traverse the full hierarchy if the event doesn't tell us enough.
            // This is "Predicted Detection".
            packageName = getTopPackageName() ?: eventPackage ?: return
        }

        // Sync locked apps cache promptly if it's stale
        if (lockedAppsCache.isEmpty() || packageName == "com.privix.privix") {
            lockedAppsCache = lockPrefs.getLockedApps()
        }

        // 4. Handle System/Transient windows (Notifications, Dialogs, etc.)
        if (isServicePackage(eventPackage) || isServicePackage(packageName)) {
            returningFromSystemWindow = true
            return
        }

        // Ignore our own app
        if (packageName == "com.privix.privix") return

        val previousPackage = lastForegroundPackage
        
        // 2. Optimization: If returning from notification panel/system window to the SAME app, 
        // ignore the event to prevent re-locking the app already in use.
        if (returningFromSystemWindow && packageName == previousPackage) {
            returningFromSystemWindow = false
            return
        }

        // Reset system window flag
        returningFromSystemWindow = false

        // 3. Same-app navigation skip
        if (packageName == previousPackage) return
        
        // ONLY update the foreground package AFTER passing the same-app check.
        // This prevents transient window state events (like those from background launchers)
        // from clobbering our tracking of the user's active session.
        lastForegroundPackage = packageName
        
        // 4. Launcher skip
        if (packageName.contains("launcher", ignoreCase = true) || 
            packageName == "com.android.launcher" || 
            packageName == "com.android.launcher3" || 
            packageName == "com.google.android.apps.nexuslauncher") {
            return
        }

        // 5. System utility skip
        if (packageName == "com.android.settings" || packageName == "com.android.packageinstaller") {
            return
        }

        // 6. Fast Lock-Check (Critical Path)
        if (!lockedAppsCache.contains(packageName)) {
            if (!lockPrefs.isAppLocked(packageName)) return
            lockedAppsCache = lockPrefs.getLockedApps()
        }

        // 7. Check Unlock States
        if (UnlockManager.isAppSessionUnlocked(packageName) || lockPrefs.isAppCurrentlyUnlocked(packageName)) {
            return
        }

        // 8. Debounce rapid events
        val now = System.currentTimeMillis()
        if (packageName == lastTriggeredPackage && (now - lastTriggerTime) < DEBOUNCE_MS) {
            return
        }

        lastTriggeredPackage = packageName
        lastTriggerTime = now

        // 11. ACTION: Show Curtain immediately (Kotlin native window)
        CurtainManager.show(this)
        
        // 12. Show Authentication (Flutter Activity)
        showAuthScreen(packageName)
    }

    private fun isServicePackage(pkg: String?): Boolean {
        if (pkg == null) return false
        return pkg == "com.android.systemui" || pkg == "android" || pkg == "com.privix.privix"
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

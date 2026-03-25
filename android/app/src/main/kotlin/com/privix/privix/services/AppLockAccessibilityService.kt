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
        private const val DEBOUNCE_MS = 300L

        // System packages that should never be locked
        private val SYSTEM_PACKAGES = setOf(
            "com.android.systemui",
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.android.settings",
            "com.android.packageinstaller",
            "com.privix.privix" // Never lock ourselves
        )

        // Static flag to track if service is running
        @Volatile
        var isRunning = false
            private set
            
        // Tracks the app the user is actively exploring across the OS
        var lastForegroundPackage: String? = null
        
        // Cache for locked packages to avoid SharedPreferences reads during transition
        private var lockedAppsCache: Set<String> = emptySet()
    }

    private lateinit var lockPrefs: LockPreferences
    private var lastTriggeredPackage: String? = null
    private var lastTriggerTime: Long = 0

    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                Log.d(TAG, "Screen off: clearing all unlocks")
                lockPrefs.clearUnlockedApps()
                UnlockManager.clear()
                lastForegroundPackage = null // Also reset tracker
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        lockPrefs = LockPreferences(this)
        isRunning = true
        
        // Pre-initialize and pre-add the curtain view for zero latency
        CurtainManager.init(this)
        
        // Register for screen off events to force re-lock
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        registerReceiver(screenOffReceiver, filter)
        
        Log.d(TAG, "AppLockAccessibilityService created and Curtain initialized")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isRunning = true
        CurtainManager.init(this)
        Log.d(TAG, "AppLockAccessibilityService connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return

        // 1. Broad Trigger Filter
        val eventType = event.eventType
        val isTransition = eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                           eventType == AccessibilityEvent.TYPE_VIEW_FOCUSED ||
                           eventType == AccessibilityEvent.TYPE_VIEW_CLICKED ||
                           eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED ||
                           (eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED && 
                            (event.contentChangeTypes and AccessibilityEvent.CONTENT_CHANGE_TYPE_PANE_APPEARED != 0))

        if (!isTransition) return

        // 2. Cache Sync
        if (lockedAppsCache.isEmpty()) {
            lockedAppsCache = lockPrefs.getLockedApps()
        }

        val previousPackage = lastForegroundPackage

        // 3. INTERNAL NAVIGATION GUARD & SYSTEM EVENT FILTER
        // We only skip if it's the same package AND it's NOT a major window change.
        // This allows catching "Re-entry" from Home/Recents which usually triggers a state change.
        if (packageName == previousPackage && eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return
        }
        
        // Skip updating tracker for system events (this prevents re-locking on page change)
        val isSystem = packageName == "android" || packageName == "com.android.systemui" || packageName.contains("launcher", ignoreCase = true) || SYSTEM_PACKAGES.contains(packageName)
        
        // 4. LOCKED APP DETECTED?
        if (lockedAppsCache.contains(packageName)) {
            // Check session unlock state from memory
            if (UnlockManager.isAppSessionUnlocked(packageName) || lockPrefs.isAppCurrentlyUnlocked(packageName)) {
                CurtainManager.cancelHide()
                CurtainManager.hide()
                lastForegroundPackage = packageName
                return
            }

            // SNAPPING CURTAIN
            CurtainManager.show(this)
            lastForegroundPackage = packageName

            // Launch Auth
            val now = System.currentTimeMillis()
            if (packageName == lastTriggeredPackage && (now - lastTriggerTime) < DEBOUNCE_MS) return
            
            lastTriggerTime = now
            lastTriggeredPackage = packageName
            Log.d(TAG, "Securing app: $packageName")
            showAuthScreen(packageName)
        } else {
            // Not a locked app
            if (isSystem) {
                // If we went to home/launcher, hide with delay to bridge re-entry
                if (packageName.contains("launcher", ignoreCase = true) || packageName == "com.android.systemui") {
                   if (previousPackage != null && lockedAppsCache.contains(previousPackage)) {
                       CurtainManager.hideWithDelay(500) // Longer delay for Samsung
                   } else {
                       CurtainManager.hide()
                   }
                   // We DON'T update lastForegroundPackage to 'system' yet, 
                   // so a quick re-entry still sees the previous package.
                }
            } else {
                // It's a real, different, non-locked app. Hide immediately.
                lastForegroundPackage = packageName
                CurtainManager.hide()
            }
        }
    }

    private fun showAuthScreen(packageName: String) {
        val intent = Intent(this, AuthActivity::class.java).apply {
            putExtra("packageName", packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION or Intent.FLAG_ACTIVITY_CLEAR_TOP
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

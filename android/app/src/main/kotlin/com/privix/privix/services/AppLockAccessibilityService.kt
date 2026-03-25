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
        
        // Register for screen off events to force re-lock
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        registerReceiver(screenOffReceiver, filter)
        
        Log.d(TAG, "AppLockAccessibilityService created")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isRunning = true
        Log.d(TAG, "AppLockAccessibilityService connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        // Refresh cache periodically or on transition to ensure accuracy
        if (lockedAppsCache.isEmpty()) {
            lockedAppsCache = lockPrefs.getLockedApps()
        }

        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        // 1. Completely ignore internal Privix events and transient SystemUI/Android events.
        if (packageName == "com.privix.privix" || 
            packageName == "com.android.systemui" || 
            packageName == "android") {
            
            // Sync cache when the user interacts with Privix (since they might have changed settings)
            if (packageName == "com.privix.privix") {
                lockedAppsCache = lockPrefs.getLockedApps()
            }
            return
        }

        val previousPackage = lastForegroundPackage
        lastForegroundPackage = packageName

        // 1. If currently navigating within the same app, do nothing.
        if (packageName == previousPackage) return

        // 2. Identify if this is a launcher or a system package that NEVER triggers a lock
        val isNonLockable = packageName.contains("launcher", ignoreCase = true) || 
                           SYSTEM_PACKAGES.contains(packageName)

        if (isNonLockable) return

        // 3. SHOW CURTAIN IMMEDIATELY BEFORE ANY DISK READS
        // This eliminates the "flash" of the app because we overlay the screen 
        // while we determine if it actually needs a PIN.
        CurtainManager.show(this)

        // 4. Quick-check memory cache 
        if (!lockedAppsCache.contains(packageName)) {
            // Safety: if not in cache, do a slow disk check
            if (!lockPrefs.isAppLocked(packageName)) {
                CurtainManager.hide() // Mistake, app wasn't locked
                return
            }
            lockedAppsCache = lockPrefs.getLockedApps()
        }

        // 5. Check if currently unlocked within relock timeout
        if (UnlockManager.isAppSessionUnlocked(packageName) || lockPrefs.isAppCurrentlyUnlocked(packageName)) {
            CurtainManager.hide() // App is authorized
            return
        }

        // 6. Debounce: prevent rapid re-triggering
        val now = System.currentTimeMillis()
        if (packageName == lastTriggeredPackage && (now - lastTriggerTime) < DEBOUNCE_MS) {
            // Wait for existing auth to complete or relock delay to pass
            return
        }

        lastTriggeredPackage = packageName
        lastTriggerTime = now

        Log.d(TAG, "Locked app confirmed: $packageName")

        // 7. Launch native auth screen
        showAuthScreen(packageName)
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

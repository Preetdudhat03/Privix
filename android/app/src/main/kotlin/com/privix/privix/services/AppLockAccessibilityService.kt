package com.privix.privix.services

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

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
    }

    private lateinit var lockPrefs: LockPreferences
    private var lastTriggeredPackage: String? = null
    private var lastTriggerTime: Long = 0

    override fun onCreate() {
        super.onCreate()
        lockPrefs = LockPreferences(this)
        isRunning = true
        Log.d(TAG, "AppLockAccessibilityService created")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isRunning = true
        Log.d(TAG, "AppLockAccessibilityService connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return
        
        // Skip system packages
        if (packageName in SYSTEM_PACKAGES) return
        
        // Skip if it's a launcher (covers various OEM launchers)
        if (packageName.contains("launcher", ignoreCase = true)) return

        // Check if this app is in our locked list
        if (!lockPrefs.isAppLocked(packageName)) return

        // Check if currently unlocked within relock timeout
        if (lockPrefs.isAppCurrentlyUnlocked(packageName)) return

        // Debounce: prevent rapid re-triggering for the same package
        val now = System.currentTimeMillis()
        if (packageName == lastTriggeredPackage && (now - lastTriggerTime) < DEBOUNCE_MS) {
            return
        }

        lastTriggeredPackage = packageName
        lastTriggerTime = now

        Log.d(TAG, "Locked app detected: $packageName — showing overlay")

        // Launch overlay lock screen
        showLockOverlay(packageName)
    }

    private fun showLockOverlay(packageName: String) {
        val intent = Intent(this, OverlayService::class.java).apply {
            putExtra(OverlayService.EXTRA_LOCKED_PACKAGE, packageName)
            action = OverlayService.ACTION_SHOW_OVERLAY
        }
        startService(intent)
    }

    override fun onInterrupt() {
        Log.d(TAG, "AppLockAccessibilityService interrupted")
    }

    override fun onDestroy() {
        isRunning = false
        Log.d(TAG, "AppLockAccessibilityService destroyed")
        super.onDestroy()
    }
}

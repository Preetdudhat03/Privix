package com.privix.privix.services

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.os.Handler
import android.os.Looper
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
 */
class AppLockAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "PrivixAccessibility"
        
        // Debounce interval to prevent rapid re-triggers
        private const val DEBOUNCE_MS = 500L
        
        // Delay interval before checking the target package to ensure stability (prevents popup false positives)
        private const val STABILITY_DELAY_MS = 150L

        // System popups and overlays that should NEVER trigger a change or count as a transition.
        // Extremely critical for Samsung One UI (Bluetooth overlays, Edge panels)
        private val SYSTEM_OVERLAYS = setOf(
            "com.android.systemui",
            "android",
            "com.samsung.android.app.cocktailbarservice", // Edge Panel
            "com.samsung.android.bixby.agent", // Bixby overlay
            "com.samsung.android.smartclip", // Smart select screen overlay
            "com.sec.android.app.sysscope", // System popup
            "com.samsung.android.smartsuggestions",
            "com.samsung.android.bluetoothtethering",
            "com.android.settings.intelligence",
            "com.samsung.android.app.routines",
            "com.android.incallui" // Often an overlay when receiving calls
        )
        
        // Launchers and core exit packages. Moving here means the user exited the app.
        private val HOME_PACKAGES = setOf(
            "com.android.launcher",
            "com.android.launcher3",
            "com.google.android.apps.nexuslauncher",
            "com.sec.android.app.launcher", // Samsung OneUI Launcher
            "com.samsung.android.oneui.launcher",
            "com.miui.home", // Xiaomi Launcher
            "com.sec.android.app.easylauncher",
            "com.huawei.android.launcher"
        )

        // Utility/Settings apps that we ignore for locking but treat as real app transitions.
        private val IGNORED_SYSTEM_APPS = setOf(
            "com.android.settings",
            "com.android.packageinstaller",
            "com.privix.privix" // Our own app
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
    
    // Handler for debouncing rapid window events
    private val debounceHandler = Handler(Looper.getMainLooper())

    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                Log.d(TAG, "Screen off: clearing all unlocks")
                lockPrefs.clearUnlockedApps()
                UnlockManager.clear()
                lastForegroundPackage = null
                debounceHandler.removeCallbacksAndMessages(null)
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
        // Optimize: We only care about explicit window state changes (app launches/popups).
        // Ignoring TYPE_WINDOW_CONTENT_CHANGED & TYPE_WINDOWS_CHANGED drastically reduces noise.
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val eventPackage = event.packageName?.toString() ?: return
        
        // 1. FILTER OUT NOISE: Ignore all known overlays completely (e.g. Edge Panel, Bluetooth popup).
        // They do not signify that the user navigated away from the application.
        if (SYSTEM_OVERLAYS.contains(eventPackage)) {
            Log.d(TAG, "Ignoring system overlay: $eventPackage")
            return
        }

        // 2. DELAY & DEBOUNCE: Valid transition event detected. Wait briefly.
        // This ensures the window state is stable before triggering a lock or revocation.
        debounceHandler.removeCallbacksAndMessages(null)
        val verificationRunnable = Runnable {
            processStableAppSwitch(eventPackage)
        }
        debounceHandler.postDelayed(verificationRunnable, STABILITY_DELAY_MS)
    }

    private fun processStableAppSwitch(targetPackage: String) {
        // Resolve actual active top package if available to be extra safe
        val currentTopPackage = getTopPackageName()
        
        // If the *actual* top package is still a system overlay, abort. 
        if (currentTopPackage != null && SYSTEM_OVERLAYS.contains(currentTopPackage)) {
            Log.d(TAG, "Top package is still an overlay ($currentTopPackage), aborting.")
            return
        }
        
        // Prefer the actual application window if we found one, otherwise fallback to the event target.
        val packageName = currentTopPackage ?: targetPackage

        // SYNC locked apps cache promptly
        if (lockedAppsCache.isEmpty() || packageName == "com.privix.privix") {
            lockedAppsCache = lockPrefs.getLockedApps()
        }

        val previousPackage = lastForegroundPackage

        // 3. HANDLE EXIT: Are we transitioning to the Home Screen or Settings?
        val isHomeOrIgnored = HOME_PACKAGES.contains(packageName) || IGNORED_SYSTEM_APPS.contains(packageName)
        
        if (isHomeOrIgnored) {
            // User exited a locked app and went back to Launcher or Settings
            if (previousPackage != null && !HOME_PACKAGES.contains(previousPackage) && !IGNORED_SYSTEM_APPS.contains(previousPackage)) {
                if (lockedAppsCache.contains(previousPackage)) {
                    Log.d(TAG, "User exited $previousPackage to $packageName. Revoking session.")
                    UnlockManager.forgetApp(previousPackage)
                    lockPrefs.removeAppUnlocked(previousPackage)
                }
            }
            lastForegroundPackage = packageName
            return
        }

        // 4. SKIP REDUNDANT: Prevent same-app lock loop
        if (packageName == previousPackage) {
            return
        }

        // 5. REQUIREMENT CHECK: Does it need locking?
        val isLocked = lockedAppsCache.contains(packageName) || lockPrefs.isAppLocked(packageName)
        if (!isLocked) {
             lastForegroundPackage = packageName
             return
        }

        // 6. SESSION CHECK: Check if it's already unlocked in this active session
        if (UnlockManager.isAppSessionUnlocked(packageName) || lockPrefs.isAppCurrentlyUnlocked(packageName)) {
            lastForegroundPackage = packageName
            return
        }

        // 7. FIRE LOCK: Check debounce to prevent multi-fires during the instant trigger
        val now = System.currentTimeMillis()
        if (packageName == lastTriggeredPackage && (now - lastTriggerTime) < DEBOUNCE_MS) {
            return
        }

        lastForegroundPackage = packageName
        lastTriggeredPackage = packageName
        lastTriggerTime = now

        Log.d(TAG, "TRIGGERING LOCK for: $packageName")
        CurtainManager.show(this)
        showAuthScreen(packageName)
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
        debounceHandler.removeCallbacksAndMessages(null)
        try {
            unregisterReceiver(screenOffReceiver)
        } catch (e: Exception) {
            // Already unregistered
        }
        Log.d(TAG, "AppLockAccessibilityService destroyed")
        super.onDestroy()
    }
}


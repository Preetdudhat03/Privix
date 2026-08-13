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
            "com.android.incallui", // Often an overlay when receiving calls
            "com.samsung.android.app.smartcapture", // Samsung Screenshot Toolbar
            "com.samsung.android.smartcapture", // Older Samsung Capture UI
            "com.samsung.android.app.screenrecorder" // Samsung Screen Recorder UI
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
    
    // Transition Guard: avoid locking apps we JUST left (prevents background noise)
    private var lastExitedPackage: String? = null
    private var lastExitedTime: Long = 0
    
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

    // Helper to dynamically check if a package is a system overlay, including all Samsung Edge Panels
    private fun isSystemOverlay(pkg: String): Boolean {
        if (SYSTEM_OVERLAYS.contains(pkg)) return true
        
        // Catch all Samsung Edge Panels dynamically (appsedge, taskedge, clipboardedge, peopleedge)
        if (pkg.startsWith("com.samsung.") && pkg.contains("edge", ignoreCase = true)) return true
        if (pkg.startsWith("com.samsung.android.app.smartcapture")) return true
        if (pkg.startsWith("com.samsung.android.smartclip")) return true
        
        return false
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Optimize: We only care about explicit window state changes (app launches/popups).
        // Ignoring TYPE_WINDOW_CONTENT_CHANGED & TYPE_WINDOWS_CHANGED drastically reduces noise.
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val eventPackage = event.packageName?.toString() ?: return
        
        // 1. FILTER OUT NOISE: Ignore all known overlays completely (e.g. Edge Panel, Bluetooth popup).
        // They do not signify that the user navigated away from the application.
        if (isSystemOverlay(eventPackage)) {
            Log.d(TAG, "Ignoring system overlay: $eventPackage")
            return
        }

        // 2. ZERO-LATENCY OVERLAY: If target is locked & not session-unlocked, trigger curtain immediately (0ms)
        // so no app content is ever revealed to the user while waiting for stability check.
        if (lockedAppsCache.isEmpty()) {
            lockedAppsCache = lockPrefs.getLockedApps()
        }
        if (lockedAppsCache.contains(eventPackage) &&
            !UnlockManager.isAppSessionUnlocked(eventPackage) &&
            !lockPrefs.isAppCurrentlyUnlocked(eventPackage) &&
            eventPackage != "com.privix.privix") {
            CurtainManager.show(this)
        }

        // 3. DELAY & DEBOUNCE: Process stable app switch to verify window state.
        debounceHandler.removeCallbacksAndMessages(null)
        val verificationRunnable = Runnable {
            processStableAppSwitch(eventPackage)
        }
        debounceHandler.postDelayed(verificationRunnable, STABILITY_DELAY_MS)
    }

    private fun processStableAppSwitch(targetPackage: String) {
        // Resolve actual active top package focusing heavily on what user is interacting with
        val currentTopPackage = getTopPackageName()
        
        // If the *actual* top package is still a system overlay, abort. 
        if (currentTopPackage != null && isSystemOverlay(currentTopPackage)) {
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
            // CRITICAL FIX: If we see a Home package event, ensure it's not just a phantom background event 
            // caused by UI cleanups (like Edge Panel closing or Screenshot toolbar disappearing).
            // A genuine Home exit means the launcher ACTUALLY has window focus.
            val isGenuineHomeExit = isPackageTrulyFocused(packageName)
            val isIgnoredSystemApp = IGNORED_SYSTEM_APPS.contains(packageName)
            
            // If it's the Launcher but not in focus, it's a momentary screen flash. Abort.
            if (!isIgnoredSystemApp && !isGenuineHomeExit) {
                Log.d(TAG, "Phantom Launcher event blocked (no focus): $packageName")
                return
            }

            // User genuinely exited a locked app and went back to Launcher or Settings
            if (previousPackage != null && !HOME_PACKAGES.contains(previousPackage) && !IGNORED_SYSTEM_APPS.contains(previousPackage)) {
                if (lockedAppsCache.contains(previousPackage)) {
                    // NEVER revoke session if we are transitioning to our OWN app (Auth screen)
                    if (packageName != "com.privix.privix") {
                        Log.d(TAG, "User exited $previousPackage to $packageName. Revoking session.")
                        UnlockManager.forgetApp(previousPackage)
                        lockPrefs.removeAppUnlocked(previousPackage)
                        
                        // --- TRANSITION GUARD: Track that we just left this app ---
                        lastExitedPackage = previousPackage
                        lastExitedTime = System.currentTimeMillis()
                    } else {
                        Log.d(TAG, "Neutral transition from $previousPackage to $packageName (Auth Screen). Session preserved.")
                    }
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
        
        // --- TRANSITION GUARD CHECK ---
        val now = System.currentTimeMillis()
        if (packageName == lastExitedPackage && (now - lastExitedTime) < 1500) {
            // We just exited this app. Check if it's REALLY focused before locking again.
            // If the launcher is technically still visible or this app doesn't have focus, ignore.
            if (!isPackageTrulyFocused(packageName)) {
                // Log.d(TAG, "Post-exit phantom event for $packageName suppressed.")
                return
            }
        }

        // 6. SESSION CHECK: Check if it's already unlocked in this active session
        if (UnlockManager.isAppSessionUnlocked(packageName) || lockPrefs.isAppCurrentlyUnlocked(packageName)) {
            lastForegroundPackage = packageName
            return
        }

        // 7. FIRE LOCK: Check debounce to prevent multi-fires during the instant trigger
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
     */
    private fun getTopPackageName(): String? {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
            val windowList = windows
            if (!windowList.isNullOrEmpty()) {
                // 1. Iterate backwards to find the top-most application window that actually has focus
                for (i in windowList.size - 1 downTo 0) {
                    val window = windowList[i]
                    if (window.type == android.view.accessibility.AccessibilityWindowInfo.TYPE_APPLICATION && window.isFocused) {
                        return window.root?.packageName?.toString()
                    }
                }
                
                // 2. Fallback to just the top-most application window regardless of focus
                // Note: We skip returning the Launcher here if it lacks focus to prevent false background exits
                for (i in windowList.size - 1 downTo 0) {
                    val window = windowList[i]
                    if (window.type == android.view.accessibility.AccessibilityWindowInfo.TYPE_APPLICATION) {
                        val pkg = window.root?.packageName?.toString()
                        if (pkg != null && !HOME_PACKAGES.contains(pkg)) {
                            return pkg
                        }
                    }
                }
            }
        }
        // Fallback to the active window root
        return rootInActiveWindow?.packageName?.toString()
    }
    
    /**
     * Confirms if the given package currently actively holds window focus.
     */
    private fun isPackageTrulyFocused(pkgToCheck: String): Boolean {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
            val windowList = windows
            if (!windowList.isNullOrEmpty()) {
                for (i in windowList.size - 1 downTo 0) {
                    val window = windowList[i]
                    if (window.isFocused) {
                        return window.root?.packageName?.toString() == pkgToCheck
                    }
                }
            }
        }
        return true // Fallback to safe passage if we can't reliably check focus
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


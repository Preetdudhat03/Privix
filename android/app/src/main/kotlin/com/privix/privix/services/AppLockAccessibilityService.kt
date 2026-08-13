package com.privix.privix.services

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.privix.privix.AuthActivity

/**
 * Senior Production-Grade Accessibility Detection Engine for Privix App Lock.
 * 
 * Features:
 * - WindowCategory State Machine to distinguish User Apps vs. System UI (Samsung Edge Panel, Screenshot, etc.)
 * - Zero-Latency 0ms Curtain Overlay for initial locks
 * - Resilient session persistence during system interruptions
 * - Structured diagnostic logging [Privix-A11Y]
 */
class AppLockAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "PrivixAccessibility"
        
        // Debounce interval to prevent rapid re-triggers
        private const val DEBOUNCE_MS = 500L
        
        // Stability delay for window focus confirmation
        private const val STABILITY_DELAY_MS = 150L

        @Volatile
        var isRunning = false
            private set
            
        var lastForegroundPackage: String? = null
        private var lockedAppsCache: Set<String> = emptySet()
    }

    private lateinit var lockPrefs: LockPreferences
    private var lastTriggeredPackage: String? = null
    private var lastTriggerTime: Long = 0
    
    // Transition Guard: avoid locking apps we JUST left
    private var lastExitedPackage: String? = null
    private var lastExitedTime: Long = 0
    
    private val debounceHandler = Handler(Looper.getMainLooper())

    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                Log.d(TAG, "[Privix-A11Y] Screen OFF: Clearing all unlock sessions")
                lockPrefs.clearUnlockedApps()
                UnlockManager.clear()
                LockSessionManager.clearAll()
                lastForegroundPackage = null
                debounceHandler.removeCallbacksAndMessages(null)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        lockPrefs = LockPreferences(this)
        isRunning = true
        CurtainManager.init(this)
        
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        registerReceiver(screenOffReceiver, filter)
        
        Log.d(TAG, "[Privix-A11Y] Service created & overlay initialized")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isRunning = true
        CurtainManager.init(this)
        Log.d(TAG, "[Privix-A11Y] Service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val eventPackage = event.packageName?.toString() ?: return
        val className = event.className?.toString() ?: "Unknown"
        
        val windowInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            event.source?.window
        } else {
            null
        }

        val category = WindowClassifier.classify(eventPackage, windowInfo)
        val authenticatedApp = LockSessionManager.getAuthenticatedPackage()

        // ─── DIAGNOSTIC LOGGING (STEP 2) ──────────────────────────────────
        Log.d(TAG, "[Privix-A11Y] event=TYPE_WINDOW_STATE_CHANGED pkg=$eventPackage class=$className category=$category previousApp=$lastForegroundPackage authenticatedApp=$authenticatedApp curtainVisible=${CurtainManager.isVisible}")

        // ─── STEP 7: PRIVIX OVERLAY MUST NOT TRIGGER ITSELF ───────────────
        if (category == WindowCategory.PRIVIX_OVERLAY) {
            return
        }

        // ─── STEP 3 & 6: HANDLE SYSTEM UI (EDGE PANEL, SCREENSHOT, ETC.) ─
        if (category == WindowCategory.SYSTEM_UI) {
            LockSessionManager.onSystemUiEvent(eventPackage)
            // If curtain was accidentally triggered on a system overlay, hide it
            if (CurtainManager.isVisible && authenticatedApp != null) {
                CurtainManager.hide("SystemUI_Active")
            }
            return
        }

        // ─── ZERO-LATENCY INSTANT LOCK CHECK FOR NEW LOCKED APP ────────────
        if (lockedAppsCache.isEmpty()) {
            lockedAppsCache = lockPrefs.getLockedApps()
        }

        val isLockedApp = lockedAppsCache.contains(eventPackage) || lockPrefs.isAppLocked(eventPackage)
        val isAppSessionUnlocked = LockSessionManager.isAppUnlocked(eventPackage) || lockPrefs.isAppCurrentlyUnlocked(eventPackage)

        if (isLockedApp && !isAppSessionUnlocked && eventPackage != "com.privix.privix") {
            // Trigger 0ms instant black curtain protection
            CurtainManager.show(this)
        }

        // Debounce window evaluation
        debounceHandler.removeCallbacksAndMessages(null)
        debounceHandler.postDelayed({
            processStableAppSwitch(eventPackage, category)
        }, STABILITY_DELAY_MS)
    }

    private fun processStableAppSwitch(targetPackage: String, category: WindowCategory) {
        val currentTopPackage = getTopPackageName()
        val currentTopCategory = WindowClassifier.classify(currentTopPackage)

        // If top package is still System UI, abort
        if (currentTopCategory == WindowCategory.SYSTEM_UI) {
            Log.d(TAG, "[Privix-A11Y] Top package is System UI ($currentTopPackage). Maintaining active session.")
            return
        }

        val packageName = currentTopPackage ?: targetPackage
        val previousPackage = lastForegroundPackage

        // SYNC locked apps cache
        if (lockedAppsCache.isEmpty() || packageName == "com.privix.privix") {
            lockedAppsCache = lockPrefs.getLockedApps()
        }

        // ─── STEP 4 & 10: RETURN FROM SYSTEM UI TO UNLOCKED APP ────────────
        val authenticatedApp = LockSessionManager.getAuthenticatedPackage()
        if (packageName == authenticatedApp) {
            LockSessionManager.onReturnFromSystemUi()
            lastForegroundPackage = packageName
            if (CurtainManager.isVisible) {
                CurtainManager.hide("ReturnedToUnlockedApp")
            }
            Log.d(TAG, "[Privix-A11Y] Returned to authenticated app ($packageName). NO LOCK REQUIRED.")
            return
        }

        // ─── HANDLE HOME LAUNCHER EXIT ─────────────────────────────────────
        if (currentTopCategory == WindowCategory.HOME_LAUNCHER) {
            val isGenuineHomeExit = isPackageTrulyFocused(packageName)
            if (!isGenuineHomeExit) {
                Log.d(TAG, "[Privix-A11Y] Phantom Launcher event blocked (no focus): $packageName")
                return
            }

            if (previousPackage != null && previousPackage != "com.privix.privix" && WindowClassifier.classify(previousPackage) == WindowCategory.PRIMARY_USER_APP) {
                if (lockedAppsCache.contains(previousPackage)) {
                    Log.d(TAG, "[Privix-A11Y] Genuine Home exit from $previousPackage. Invalidating session.")
                    UnlockManager.forgetApp(previousPackage)
                    lockPrefs.removeAppUnlocked(previousPackage)
                    lastExitedPackage = previousPackage
                    lastExitedTime = System.currentTimeMillis()
                }
            }
            lastForegroundPackage = packageName
            return
        }

        // Skip redundant same-package evaluation
        if (packageName == previousPackage) {
            return
        }

        // ─── CHECK IF TARGET REQUIRES LOCKING ──────────────────────────────
        val isLocked = lockedAppsCache.contains(packageName) || lockPrefs.isAppLocked(packageName)
        if (!isLocked) {
            lastForegroundPackage = packageName
            if (CurtainManager.isVisible) {
                CurtainManager.hide("UnlockedTargetApp")
            }
            return
        }

        // ─── TRANSITION GUARD ──────────────────────────────────────────────
        val now = System.currentTimeMillis()
        if (packageName == lastExitedPackage && (now - lastExitedTime) < 1500) {
            if (!isPackageTrulyFocused(packageName)) {
                return
            }
        }

        // ─── CHECK ACTIVE SESSION ──────────────────────────────────────────
        if (LockSessionManager.isAppUnlocked(packageName) || lockPrefs.isAppCurrentlyUnlocked(packageName)) {
            lastForegroundPackage = packageName
            if (CurtainManager.isVisible) {
                CurtainManager.hide("SessionActive")
            }
            return
        }

        // ─── DEBOUNCE MULTI-FIRE ───────────────────────────────────────────
        if (packageName == lastTriggeredPackage && (now - lastTriggerTime) < DEBOUNCE_MS) {
            return
        }

        // If switching from one locked app to ANOTHER locked app, invalidate old session
        if (authenticatedApp != null && authenticatedApp != packageName) {
            Log.d(TAG, "[Privix-A11Y] App switch detected ($authenticatedApp -> $packageName). Invalidating old session.")
            UnlockManager.forgetApp(authenticatedApp)
            lockPrefs.removeAppUnlocked(authenticatedApp)
        }

        lastForegroundPackage = packageName
        lastTriggeredPackage = packageName
        lastTriggerTime = now

        Log.d(TAG, "[Privix-A11Y] TRIGGERING LOCK for: $packageName")
        CurtainManager.show(this)
        showAuthScreen(packageName)
    }

    private fun getTopPackageName(): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val windowList = windows
            if (!windowList.isNullOrEmpty()) {
                for (i in windowList.size - 1 downTo 0) {
                    val window = windowList[i]
                    if (window.type == android.view.accessibility.AccessibilityWindowInfo.TYPE_APPLICATION && window.isFocused) {
                        return window.root?.packageName?.toString()
                    }
                }
                
                for (i in windowList.size - 1 downTo 0) {
                    val window = windowList[i]
                    if (window.type == android.view.accessibility.AccessibilityWindowInfo.TYPE_APPLICATION) {
                        val pkg = window.root?.packageName?.toString()
                        if (pkg != null && WindowClassifier.classify(pkg) != WindowCategory.HOME_LAUNCHER) {
                            return pkg
                        }
                    }
                }
            }
        }
        return rootInActiveWindow?.packageName?.toString()
    }
    
    private fun isPackageTrulyFocused(pkgToCheck: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
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
        return true
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
        Log.d(TAG, "[Privix-A11Y] Service interrupted")
    }

    override fun onDestroy() {
        isRunning = false
        debounceHandler.removeCallbacksAndMessages(null)
        try {
            unregisterReceiver(screenOffReceiver)
        } catch (e: Exception) {
            // Unregistered
        }
        Log.d(TAG, "[Privix-A11Y] Service destroyed")
        super.onDestroy()
    }
}

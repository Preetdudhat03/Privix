package com.privix.privix.services

import android.util.Log

/**
 * Thread-safe bridge to LockSessionManager.
 * Manages unlock session states across native AccessibilityService and AuthActivity.
 */
object UnlockManager {

    @Synchronized
    fun markUnlocked(packageName: String) {
        LockSessionManager.onAuthenticationSuccess(packageName)
    }

    @Synchronized
    fun forgetApp(packageName: String) {
        LockSessionManager.invalidateSession("User navigated to another application or launcher")
    }

    @Synchronized
    fun isAppSessionUnlocked(packageName: String): Boolean {
        return LockSessionManager.isAppUnlocked(packageName)
    }

    @Synchronized
    fun clear() {
        LockSessionManager.clearAll()
    }
}

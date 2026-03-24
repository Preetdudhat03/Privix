package com.privix.privix.services

import android.util.Log

/**
 * Thread-safe singleton to track currently unlocked apps in memory.
 * This prevents the "Infinite Loop" where AccessibilityEvents fire faster 
 * than SharedPreferences can write to disk.
 */
object UnlockManager {
    private val unlockedApps = mutableMapOf<String, Long>()
    
    // Minimum time an app stays unlocked regardless of settings (to prevent bounce-back loops)
    private const val SESSION_GRACE_PERIOD_MS = 3000L

    @Synchronized
    fun markUnlocked(packageName: String) {
        Log.d("UnlockManager", "Marking $packageName as session-unlocked")
        unlockedApps[packageName] = System.currentTimeMillis()
    }

    @Synchronized
    fun isAppSessionUnlocked(packageName: String): Boolean {
        val lastUnlock = unlockedApps[packageName] ?: return false
        val isUnlocked = (System.currentTimeMillis() - lastUnlock) < SESSION_GRACE_PERIOD_MS
        if (isUnlocked) {
            Log.d("UnlockManager", "App $packageName is in session grace period")
        }
        return isUnlocked
    }

    @Synchronized
    fun clear() {
        unlockedApps.clear()
    }
}

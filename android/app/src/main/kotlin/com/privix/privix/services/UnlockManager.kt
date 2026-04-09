package com.privix.privix.services

import android.util.Log

/**
 * Thread-safe singleton to track currently unlocked apps in memory.
 * This prevents the "Infinite Loop" where AccessibilityEvents fire faster 
 * than SharedPreferences can write to disk.
 */
object UnlockManager {
    private val unlockedApps = mutableMapOf<String, Long>()
    
    // Minimum time an app stays unlocked (to prevent bounce-back loops during Auth Activity start)
    private const val SESSION_GRACE_PERIOD_MS = 1500L

    @Synchronized
    fun markUnlocked(packageName: String) {
        val now = System.currentTimeMillis()
        Log.d("UnlockManager", "Marking $packageName as session-unlocked at $now")
        unlockedApps[packageName] = now
    }

    /**
     * Immediately revokes the unlock status for a specific app.
     * Use this when the user leaves the app to ensure re-lock on return.
     */
    @Synchronized
    fun forgetApp(packageName: String) {
        if (unlockedApps.containsKey(packageName)) {
            Log.d("UnlockManager", "Forgetting $packageName (Strict Security)")
            unlockedApps.remove(packageName)
        }
    }

    @Synchronized
    fun isAppSessionUnlocked(packageName: String): Boolean {
        val now = System.currentTimeMillis()
        val lastUnlock = unlockedApps[packageName] ?: return false
        val diff = now - lastUnlock
        val isUnlocked = diff < SESSION_GRACE_PERIOD_MS
        
        if (isUnlocked) {
            Log.d("UnlockManager", "App $packageName is in session grace period (diff: ${diff}ms)")
        } else {
            // Log.d("UnlockManager", "App $packageName unlock expired (diff: ${diff}ms)")
        }
        return isUnlocked
    }

    @Synchronized
    fun clear() {
        unlockedApps.clear()
    }
}

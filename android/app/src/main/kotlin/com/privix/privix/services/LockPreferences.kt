package com.privix.privix.services

import android.content.Context
import android.content.SharedPreferences

/**
 * Shared preferences bridge between Flutter (via platform channel) and native services.
 * 
 * WHY: The AccessibilityService runs in a separate context from Flutter. 
 * It cannot access flutter_secure_storage or Flutter's SharedPreferences.
 * This class provides a shared data store readable by both sides.
 */
class LockPreferences(context: Context) {

    companion object {
        private const val PREFS_NAME = "privix_lock_prefs"
        private const val KEY_LOCKED_APPS = "locked_apps"
        private const val KEY_PIN_HASH = "pin_hash"
        private const val KEY_PIN_LENGTH = "pin_length"
        private const val KEY_BIOMETRIC_ENABLED = "biometric_enabled"
        private const val KEY_RELOCK_TIMEOUT = "relock_timeout_ms"
        private const val KEY_UNLOCKED_APPS = "unlocked_apps"
        private const val KEY_PIN_SET = "pin_set"

        // Relock timeout constants (milliseconds)
        const val RELOCK_IMMEDIATELY = 0L
        const val RELOCK_30_SECONDS = 30_000L
        const val RELOCK_1_MINUTE = 60_000L
        const val RELOCK_5_MINUTES = 300_000L
        const val RELOCK_ALWAYS_UNLOCKED = -1L
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // --- Locked Apps ---

    fun getLockedApps(): Set<String> {
        return prefs.getStringSet(KEY_LOCKED_APPS, emptySet()) ?: emptySet()
    }

    fun setLockedApps(apps: Set<String>) {
        prefs.edit().putStringSet(KEY_LOCKED_APPS, apps).apply()
    }

    fun isAppLocked(packageName: String): Boolean {
        return getLockedApps().contains(packageName)
    }

    // --- PIN ---

    fun setPinHash(hash: String, pinLength: Int) {
        prefs.edit()
            .putString(KEY_PIN_HASH, hash)
            .putInt(KEY_PIN_LENGTH, pinLength)
            .putBoolean(KEY_PIN_SET, true)
            .apply()
    }

    fun getPinLength(): Int {
        return prefs.getInt(KEY_PIN_LENGTH, 4)
    }

    fun getPinHash(): String? {
        return prefs.getString(KEY_PIN_HASH, null)
    }

    fun isPinSet(): Boolean {
        return prefs.getBoolean(KEY_PIN_SET, false)
    }

    // --- Biometric ---

    fun setBiometricEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_BIOMETRIC_ENABLED, enabled).apply()
    }

    fun isBiometricEnabled(): Boolean {
        return prefs.getBoolean(KEY_BIOMETRIC_ENABLED, false)
    }

    // --- Relock Timeout ---

    fun setRelockTimeout(timeoutMs: Long) {
        prefs.edit().putLong(KEY_RELOCK_TIMEOUT, timeoutMs).apply()
    }

    fun getRelockTimeout(): Long {
        return prefs.getLong(KEY_RELOCK_TIMEOUT, RELOCK_IMMEDIATELY)
    }

    // --- Recently Unlocked Apps (with timestamps) ---

    fun markAppUnlocked(packageName: String) {
        prefs.edit().putLong("unlocked_$packageName", System.currentTimeMillis()).commit()
    }

    fun isAppCurrentlyUnlocked(packageName: String): Boolean {
        var timeout = getRelockTimeout()
        if (timeout == RELOCK_IMMEDIATELY) {
            // Give a 2.5 second grace period so the underlying app can regain focus 
            // after the BioPrompt completes without instantly triggering another lock
            timeout = 2500L
        }

        val timestamp = prefs.getLong("unlocked_$packageName", 0L)
        if (timestamp == 0L) return false

        if (timeout == RELOCK_ALWAYS_UNLOCKED) return true

        return (System.currentTimeMillis() - timestamp) < timeout
    }

    fun clearUnlockedApps() {
        val editor = prefs.edit()
        for (key in prefs.all.keys) {
            if (key.startsWith("unlocked_")) {
                editor.remove(key)
            }
        }
        editor.commit()
    }
}

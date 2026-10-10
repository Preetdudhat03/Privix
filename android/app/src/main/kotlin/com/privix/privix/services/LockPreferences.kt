package com.privix.privix.services

import android.content.Context
import android.content.SharedPreferences

/**
 * Shared preferences bridge between Flutter (via platform channel) and native services.
 * 
 * WHY: Both AccessibilityService and ForegroundService run in native Android contexts.
 * This class provides a shared data store readable and writable by both Flutter and native layers.
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
        private const val KEY_ENGINE_MODE = "engine_mode"
        private const val KEY_PAUSED_UNTIL = "paused_until_timestamp"

        // Engine mode constants
        const val ENGINE_USAGE_STATS = "usage_stats"
        const val ENGINE_ACCESSIBILITY = "accessibility"

        // Relock timeout constants (milliseconds)
        const val RELOCK_IMMEDIATELY = 0L
        const val RELOCK_30_SECONDS = 30_000L
        const val RELOCK_1_MINUTE = 60_000L
        const val RELOCK_5_MINUTES = 300_000L
        const val RELOCK_ALWAYS_UNLOCKED = -1L
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // --- Engine Mode ---

    fun getEngineMode(): String {
        return prefs.getString(KEY_ENGINE_MODE, ENGINE_USAGE_STATS) ?: ENGINE_USAGE_STATS
    }

    fun setEngineMode(mode: String) {
        prefs.edit().putString(KEY_ENGINE_MODE, mode).apply()
    }

    // --- Temporary Pause Protection ---

    fun pauseForMinutes(minutes: Int) {
        val until = System.currentTimeMillis() + (minutes * 60 * 1000L)
        prefs.edit().putLong(KEY_PAUSED_UNTIL, until).apply()
        CurtainManager.hide("ProtectionPaused")
    }

    fun resumeProtection() {
        prefs.edit().remove(KEY_PAUSED_UNTIL).apply()
    }

    fun isPaused(): Boolean {
        val until = prefs.getLong(KEY_PAUSED_UNTIL, 0L)
        if (until == 0L) return false
        val now = System.currentTimeMillis()
        if (now >= until) {
            resumeProtection()
            return false
        }
        return true
    }

    fun getPausedRemainingSeconds(): Long {
        val until = prefs.getLong(KEY_PAUSED_UNTIL, 0L)
        if (until == 0L) return 0L
        val remaining = (until - System.currentTimeMillis()) / 1000L
        return if (remaining > 0) remaining else 0L
    }

    // --- Locked Apps ---

    fun getLockedApps(): Set<String> {
        return prefs.getStringSet(KEY_LOCKED_APPS, emptySet()) ?: emptySet()
    }

    fun setLockedApps(apps: Set<String>) {
        prefs.edit().putStringSet(KEY_LOCKED_APPS, apps).apply()
    }

    fun isAppLocked(packageName: String): Boolean {
        if (isPaused()) return false
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

    // --- Recently Unlocked Apps ---

    fun markAppUnlocked(packageName: String) {
        prefs.edit().putLong("unlocked_$packageName", System.currentTimeMillis()).apply()
        LockSessionManager.onAuthenticationSuccess(packageName)
    }

    fun isAppCurrentlyUnlocked(packageName: String): Boolean {
        if (isPaused()) return true

        if (LockSessionManager.isAppUnlocked(packageName)) {
            return true
        }

        val timeout = getRelockTimeout()
        if (timeout == RELOCK_ALWAYS_UNLOCKED) return true

        val timestamp = prefs.getLong("unlocked_$packageName", 0L)
        if (timestamp == 0L) return false

        return (System.currentTimeMillis() - timestamp) < timeout
    }

    fun removeAppUnlocked(packageName: String) {
        prefs.edit().remove("unlocked_$packageName").apply()
        LockSessionManager.invalidateSession("Manual removal")
    }

    fun clearUnlockedApps() {
        val editor = prefs.edit()
        for (key in prefs.all.keys) {
            if (key.startsWith("unlocked_")) {
                editor.remove(key)
            }
        }
        editor.apply()
        LockSessionManager.clearAll()
    }
}

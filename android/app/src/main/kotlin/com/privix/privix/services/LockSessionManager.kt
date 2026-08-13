package com.privix.privix.services

import android.util.Log

/**
 * Formal Lock State Machine for Privix.
 */
enum class LockState {
    /** No lock active (unlocked app or user on Home screen) */
    IDLE,

    /** Protected app detected, lock screen is required */
    LOCK_REQUIRED,

    /** Lock screen / Curtain overlay is active and covering the protected app */
    LOCK_VISIBLE,

    /** Temporary System UI (Notification Shade, Quick Settings, Edge Panel) is open over unauthenticated lock screen */
    SYSTEM_UI_OVERLAY_ACTIVE,

    /** User successfully authenticated via Fingerprint / Face / PIN */
    AUTHENTICATED
}

/**
 * Encapsulates an active authentication session for a protected application.
 */
data class UnlockSession(
    val packageName: String,
    val authenticatedAt: Long = System.currentTimeMillis(),
    var lastActiveAt: Long = System.currentTimeMillis()
)

/**
 * Native thread-safe state machine for managing app lock session states.
 * Guarantees the critical invariant:
 * UNAUTHENTICATED PROTECTED APP = LOCK MUST REMAIN ACTIVE.
 * Temporary System UI (Notification panel, Edge Panel, screenshots) will NEVER invalidate or bypass the lock.
 */
object LockSessionManager {
    private const val TAG = "PrivixLock"

    @Volatile
    private var activeSession: UnlockSession? = null

    @Volatile
    var currentPrimaryApp: String? = null
        private set

    @Volatile
    var pendingLockedPackage: String? = null
        private set

    @Volatile
    var lockState: LockState = LockState.IDLE
        private set

    @Volatile
    var isSystemUiActive: Boolean = false
        private set

    /**
     * Marks that a locked application has been detected and must remain covered until authenticated.
     */
    @Synchronized
    fun onProtectedAppDetected(packageName: String) {
        if (activeSession?.packageName == packageName) {
            lockState = LockState.AUTHENTICATED
            return
        }
        pendingLockedPackage = packageName
        if (lockState != LockState.SYSTEM_UI_OVERLAY_ACTIVE) {
            lockState = LockState.LOCK_VISIBLE
        }
        Log.d(TAG, "[PrivixLock] Protected app detected ($packageName). State: $lockState")
    }

    /**
     * Marks that a temporary System UI (Notification Shade, Quick Settings, Edge Panel, Screenshot) is active.
     * Crucial: Keeps pending locked package & lock state intact!
     */
    @Synchronized
    fun onSystemUiEvent(systemUiPackage: String) {
        isSystemUiActive = true
        if (pendingLockedPackage != null && activeSession?.packageName != pendingLockedPackage) {
            lockState = LockState.SYSTEM_UI_OVERLAY_ACTIVE
            Log.d(TAG, "[PrivixLock] System UI ($systemUiPackage) active over UNAUTHENTICATED app ($pendingLockedPackage). Lock state remains: $lockState")
        } else {
            Log.d(TAG, "[PrivixLock] System UI ($systemUiPackage) active over authenticated session (${activeSession?.packageName}).")
        }
    }

    /**
     * Called when System UI closes and focus returns to the user application.
     */
    @Synchronized
    fun onReturnFromSystemUi() {
        isSystemUiActive = false
        if (pendingLockedPackage != null && activeSession?.packageName != pendingLockedPackage) {
            lockState = LockState.LOCK_VISIBLE
            Log.d(TAG, "[PrivixLock] System UI closed. Returning to UNAUTHENTICATED protected app ($pendingLockedPackage). Lock state: $lockState")
        }
    }

    /**
     * Called ONLY after successful PIN or Biometric authentication.
     */
    @Synchronized
    fun onAuthenticationSuccess(packageName: String) {
        val now = System.currentTimeMillis()
        Log.d(TAG, "[PrivixLock] Authentication SUCCESS for package: $packageName at $now")
        activeSession = UnlockSession(packageName = packageName, authenticatedAt = now, lastActiveAt = now)
        currentPrimaryApp = packageName
        pendingLockedPackage = null
        lockState = LockState.AUTHENTICATED
    }

    /**
     * Updates the active primary app without revoking an existing valid session.
     */
    @Synchronized
    fun setPrimaryApp(packageName: String) {
        currentPrimaryApp = packageName
        activeSession?.let {
            if (it.packageName == packageName) {
                it.lastActiveAt = System.currentTimeMillis()
            }
        }
    }

    /**
     * Verifies if a given package has an active, valid authentication session.
     */
    @Synchronized
    fun isAppUnlocked(packageName: String): Boolean {
        val session = activeSession ?: return false
        if (session.packageName != packageName) return false

        session.lastActiveAt = System.currentTimeMillis()
        return true
    }

    /**
     * Gets the currently authenticated package name if any.
     */
    @Synchronized
    fun getAuthenticatedPackage(): String? {
        return activeSession?.packageName
    }

    /**
     * Revokes the active session when the user genuinely switches to another application or presses Back/Home.
     */
    @Synchronized
    fun invalidateSession(reason: String) {
        Log.d(TAG, "[PrivixLock] Invalidating lock/session states. Reason: $reason (Previous pending: $pendingLockedPackage, active: ${activeSession?.packageName})")
        activeSession = null
        pendingLockedPackage = null
        lockState = LockState.IDLE
    }

    /**
     * Clears all session states (e.g. Screen Off).
     */
    @Synchronized
    fun clearAll() {
        Log.d(TAG, "[PrivixLock] Clearing all unlock sessions and pending locks.")
        activeSession = null
        pendingLockedPackage = null
        currentPrimaryApp = null
        lockState = LockState.IDLE
        isSystemUiActive = false
    }
}

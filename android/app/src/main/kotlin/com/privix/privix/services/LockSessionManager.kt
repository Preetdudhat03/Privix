package com.privix.privix.services

import android.util.Log

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
 * Preserves active authentication sessions when temporary System UI (Samsung Edge Panel,
 * screenshots, volume controls, notification shade) interrupts the app flow.
 */
object LockSessionManager {
    private const val TAG = "PrivixSessionManager"

    @Volatile
    private var activeSession: UnlockSession? = null

    @Volatile
    var currentPrimaryApp: String? = null
        private set

    @Volatile
    var isSystemUiActive: Boolean = false
        private set

    /**
     * Marks an app as authenticated in an active session.
     */
    @Synchronized
    fun onAppUnlocked(packageName: String) {
        val now = System.currentTimeMillis()
        Log.d(TAG, "[Privix-Session] Authentication SUCCESS for package: $packageName at $now")
        activeSession = UnlockSession(packageName = packageName, authenticatedAt = now, lastActiveAt = now)
        currentPrimaryApp = packageName
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
     * Marks that a temporary System UI (Edge Panel, Screenshot toolbar, etc.) is currently active.
     * Keeps the primary app's authentication session intact.
     */
    @Synchronized
    fun onSystemUiEvent(packageName: String) {
        isSystemUiActive = true
        Log.d(TAG, "[Privix-Session] System UI active ($packageName). Preserving session for: ${activeSession?.packageName}")
    }

    /**
     * Called when System UI closes and focus returns to the primary user app.
     */
    @Synchronized
    fun onReturnFromSystemUi() {
        isSystemUiActive = false
        Log.d(TAG, "[Privix-Session] System UI closed. Active session remains: ${activeSession?.packageName}")
    }

    /**
     * Verifies if a given package has an active, valid authentication session.
     */
    @Synchronized
    fun isAppUnlocked(packageName: String): Boolean {
        val session = activeSession ?: return false
        if (session.packageName != packageName) return false

        // Update last active timestamp
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
     * Revokes the active session when the user genuinely switches to another application.
     */
    @Synchronized
    fun invalidateSession(reason: String) {
        if (activeSession != null) {
            Log.d(TAG, "[Privix-Session] Invalidating active session (${activeSession?.packageName}). Reason: $reason")
            activeSession = null
        }
    }

    /**
     * Clears all session states (e.g. Screen Off).
     */
    @Synchronized
    fun clearAll() {
        Log.d(TAG, "[Privix-Session] Clearing all unlock sessions.")
        activeSession = null
        currentPrimaryApp = null
        isSystemUiActive = false
    }
}

package com.privix.privix.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.privix.privix.services.LockPreferences

/**
 * Clears all "recently unlocked" state on device reboot.
 * 
 * WHY: After a reboot, all apps should require re-authentication.
 * The AccessibilityService restarts automatically (Android behavior),
 * but our unlock timestamps persist in SharedPreferences, so we
 * must explicitly clear them.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PrivixBootReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Boot completed — clearing unlock states")
            context?.let {
                val lockPrefs = LockPreferences(it)
                lockPrefs.clearUnlockedApps()
            }
        }
    }
}

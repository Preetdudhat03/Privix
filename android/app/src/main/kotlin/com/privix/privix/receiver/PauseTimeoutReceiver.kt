package com.privix.privix.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.privix.privix.services.LockPreferences
import com.privix.privix.services.PrivixTileService

/**
 * BroadcastReceiver triggered by AlarmManager when the 15-minute protection pause expires.
 * Automatically restores active lock protection and updates the Samsung Quick Settings tile.
 */
class PauseTimeoutReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PauseTimeoutReceiver"
        const val ACTION_PAUSE_TIMEOUT = "com.privix.privix.ACTION_PAUSE_TIMEOUT"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return
        Log.d(TAG, "[PrivixLock] Pause timer expired. Automatically resuming protection.")
        val prefs = LockPreferences(context)
        prefs.resumeProtection()
        PrivixTileService.requestUpdate(context)
    }
}

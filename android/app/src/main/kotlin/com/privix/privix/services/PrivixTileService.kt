package com.privix.privix.services

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import androidx.annotation.RequiresApi
import com.privix.privix.AuthActivity
import com.privix.privix.R

/**
 * Samsung One UI / Android Quick Settings Tile.
 * Allows user to quickly pause Privix App Lock for 15 minutes (or resume)
 * directly from the notification shade without going into Android Settings.
 * Dynamically counts down remaining pause time (15m, 14m, ... 1m, 45s) and auto-resumes.
 * Protected: Pausing requires biometric/device credential verification.
 */
@RequiresApi(Build.VERSION_CODES.N)
class PrivixTileService : TileService() {

    companion object {
        private const val TAG = "PrivixTile"

        fun requestUpdate(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    requestListeningState(
                        context.applicationContext,
                        ComponentName(context.applicationContext, PrivixTileService::class.java)
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error requesting tile state update", e)
                }
            }
        }
    }

    private val countdownHandler = Handler(Looper.getMainLooper())
    private var isListening = false

    private val countdownRunnable = object : Runnable {
        override fun run() {
            if (!isListening) return
            val prefs = LockPreferences(this@PrivixTileService)
            if (prefs.isPaused()) {
                updateTileState()
                countdownHandler.postDelayed(this, 1000L)
            } else {
                updateTileState()
            }
        }
    }

    override fun onTileAdded() {
        super.onTileAdded()
        updateTileState()
    }

    override fun onStartListening() {
        super.onStartListening()
        isListening = true
        updateTileState()

        val prefs = LockPreferences(this)
        countdownHandler.removeCallbacks(countdownRunnable)
        if (prefs.isPaused()) {
            countdownHandler.postDelayed(countdownRunnable, 1000L)
        }
    }

    override fun onStopListening() {
        isListening = false
        countdownHandler.removeCallbacks(countdownRunnable)
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        val prefs = LockPreferences(this)
        if (prefs.isPaused()) {
            // Resuming protection is always safe to do without authentication
            prefs.resumeProtection()
            updateTileState()
            countdownHandler.removeCallbacks(countdownRunnable)
        } else {
            // Pausing protection MUST require authentication (prevents unauthorized bypass)
            if (isLocked) {
                unlockAndRun {
                    launchPauseAuth()
                }
            } else {
                launchPauseAuth()
            }
        }
    }

    private fun launchPauseAuth() {
        val pauseIntent = Intent(this, AuthActivity::class.java).apply {
            putExtra("action", "pause_protection")
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pendingIntent = PendingIntent.getActivity(
                this,
                1002,
                pauseIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(pauseIntent)
        }
    }

    private fun updateTileState() {
        val tile = qsTile ?: return
        val prefs = LockPreferences(this)

        if (prefs.isPaused()) {
            val remainingSecs = prefs.getPausedRemainingSeconds()
            if (remainingSecs <= 0) {
                // Timeout reached
                prefs.resumeProtection()
                setTileActive(tile)
                return
            }

            tile.state = Tile.STATE_INACTIVE
            tile.label = "Privix (Paused)"
            tile.icon = Icon.createWithResource(this, R.drawable.ic_qs_privix_paused)

            val mins = (remainingSecs + 59) / 60
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                tile.subtitle = if (mins > 1) {
                    "${mins}m remaining"
                } else {
                    "${remainingSecs}s remaining"
                }
            } else {
                tile.label = if (mins > 1) "Privix (${mins}m)" else "Privix (${remainingSecs}s)"
            }
        } else {
            setTileActive(tile)
        }
        tile.updateTile()
    }

    private fun setTileActive(tile: Tile) {
        tile.state = Tile.STATE_ACTIVE
        tile.label = "Privix Lock"
        tile.icon = Icon.createWithResource(this, R.drawable.ic_qs_privix)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = "Protected"
        }
        tile.updateTile()
    }
}

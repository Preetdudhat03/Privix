package com.privix.privix.services

import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

/**
 * Samsung One UI / Android Quick Settings Tile.
 * Allows user to quickly pause Privix App Lock for 15 minutes (or resume)
 * directly from the notification shade without going into Android Settings.
 */
@RequiresApi(Build.VERSION_CODES.N)
class PrivixTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        updateTileState()
    }

    override fun onClick() {
        super.onClick()
        val prefs = LockPreferences(this)
        if (prefs.isPaused()) {
            prefs.resumeProtection()
        } else {
            // Pause for 15 minutes
            prefs.pauseForMinutes(15)
        }
        updateTileState()
    }

    private fun updateTileState() {
        val tile = qsTile ?: return
        val prefs = LockPreferences(this)

        if (prefs.isPaused()) {
            tile.state = Tile.STATE_INACTIVE
            tile.label = "Privix (Paused)"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val remainingMins = (prefs.getPausedRemainingSeconds() / 60) + 1
                tile.subtitle = "Paused for ${remainingMins}m"
            }
        } else {
            tile.state = Tile.STATE_ACTIVE
            tile.label = "Privix Lock"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                tile.subtitle = if (prefs.getEngineMode() == LockPreferences.ENGINE_USAGE_STATS) {
                    "Usage Mode"
                } else {
                    "0ms Mode"
                }
            }
        }
        tile.updateTile()
    }
}

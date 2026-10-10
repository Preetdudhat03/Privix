package com.privix.privix.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.privix.privix.AuthActivity

/**
 * Usage Access Detection Engine for Privix App Lock.
 * 
 * WHY THIS SERVICE EXISTS:
 * Many government apps (mAadhaar, DigiLocker, Umang, PAN, e-gov portals) and banking apps
 * (SBI YONO, BHIM UPI, HDFC, ICICI, etc.) deliberately BLOCK or CRASH if ANY 3rd-party
 * Accessibility Service is enabled on the device.
 * 
 * By using UsageStatsManager + this lightweight Foreground Service:
 * - NO Accessibility Service is enabled in Android Settings.
 * - Government & Banking apps run 100% cleanly without security warnings.
 * - Privix reliably locks sensitive apps when they enter the foreground.
 */
class AppLockForegroundService : Service() {

    companion object {
        private const val TAG = "PrivixForeground"
        private const val CHANNEL_ID = "privix_app_lock_service_channel"
        private const val NOTIFICATION_ID = 9021

        @Volatile
        var isRunning = false
            private set

        fun start(context: Context) {
            val intent = Intent(context, AppLockForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, AppLockForegroundService::class.java)
            context.stopService(intent)
        }
    }

    private lateinit var lockPrefs: LockPreferences
    private lateinit var usageStatsManager: UsageStatsManager
    private val handler = Handler(Looper.getMainLooper())
    private var lastForegroundPackage: String? = null
    private var lastPollTime: Long = 0L

    private val pollRunnable = object : Runnable {
        override fun run() {
            try {
                checkForegroundApp()
            } catch (e: Exception) {
                Log.e(TAG, "Error in usage stats polling", e)
            }
            // Poll every 250ms for responsive detection
            handler.postDelayed(this, 250L)
        }
    }

    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                Log.d(TAG, "[UsageStats] Screen OFF: Clearing unlock sessions")
                lockPrefs.clearUnlockedApps()
                UnlockManager.clear()
                LockSessionManager.clearAll()
                lastForegroundPackage = null
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        lockPrefs = LockPreferences(this)
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        CurtainManager.init(this)
        isRunning = true

        startForeground(NOTIFICATION_ID, createNotification())

        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        registerReceiver(screenOffReceiver, filter)

        lastPollTime = System.currentTimeMillis() - 2000L
        handler.post(pollRunnable)
        Log.d(TAG, "AppLockForegroundService created and polling started")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    private fun checkForegroundApp() {
        if (lockPrefs.isPaused()) {
            return
        }

        if (lockPrefs.getEngineMode() != LockPreferences.ENGINE_USAGE_STATS) {
            return
        }

        val now = System.currentTimeMillis()
        val events = usageStatsManager.queryEvents(now - 2000L, now)
        val event = UsageEvents.Event()

        var currentTopPackage: String? = null

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                currentTopPackage = event.packageName
            }
        }

        if (currentTopPackage == null) {
            return
        }

        // Privix itself should not trigger lock screen
        if (currentTopPackage == "com.privix.privix") {
            return
        }

        // System UI / Home Launcher transitions
        val category = WindowClassifier.classify(currentTopPackage)
        if (category == WindowCategory.SYSTEM_UI) {
            return
        }

        if (category == WindowCategory.HOME_LAUNCHER) {
            if (lastForegroundPackage != null && lockPrefs.isAppLocked(lastForegroundPackage!!)) {
                UnlockManager.forgetApp(lastForegroundPackage!!)
                lockPrefs.removeAppUnlocked(lastForegroundPackage!!)
            }
            lastForegroundPackage = currentTopPackage
            return
        }

        if (currentTopPackage == lastForegroundPackage) {
            return
        }

        val isLocked = lockPrefs.isAppLocked(currentTopPackage)
        if (!isLocked) {
            lastForegroundPackage = currentTopPackage
            if (CurtainManager.isVisible && LockSessionManager.pendingLockedPackage == null) {
                CurtainManager.hide("UnlockedAppResumed")
            }
            return
        }

        val isUnlocked = LockSessionManager.isAppUnlocked(currentTopPackage) ||
                lockPrefs.isAppCurrentlyUnlocked(currentTopPackage)

        if (isUnlocked) {
            lastForegroundPackage = currentTopPackage
            if (CurtainManager.isVisible) {
                CurtainManager.hide("ActiveUnlockedSession")
            }
            return
        }

        // Target requires authentication!
        lastForegroundPackage = currentTopPackage
        Log.d(TAG, "[UsageStats] Locking package: $currentTopPackage")

        LockSessionManager.onProtectedAppDetected(currentTopPackage)
        CurtainManager.show(this)

        val authIntent = Intent(this, AuthActivity::class.java).apply {
            putExtra("packageName", currentTopPackage)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
        }
        startActivity(authIntent)
    }

    private fun createNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Privix Protection Service",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Keeps Privix App Lock running reliably in the background without needing Accessibility Service."
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Privix App Lock")
            .setContentText("Protected • Usage Access Mode (Gov & Bank Safe)")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacksAndMessages(null)
        try {
            unregisterReceiver(screenOffReceiver)
        } catch (_: Exception) {}
        Log.d(TAG, "AppLockForegroundService destroyed")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

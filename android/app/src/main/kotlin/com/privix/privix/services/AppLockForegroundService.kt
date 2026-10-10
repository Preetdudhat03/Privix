package com.privix.privix.services

import android.app.ActivityOptions
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
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
 * High-performance Usage Access Detection Engine for Privix App Lock.
 * Optimized for ultra-low latency (75ms polling when screen is interactive)
 * with zero background drain when screen is off.
 */
class AppLockForegroundService : Service() {

    companion object {
        private const val TAG = "PrivixForeground"
        private const val CHANNEL_ID = "privix_app_lock_service_channel"
        private const val NOTIFICATION_ID = 9021
        private const val POLL_INTERVAL_MS = 75L // 75ms responsive detection loop

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
    private var lastProcessedEventTime: Long = 0L
    private var isScreenInteractive = true

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (isScreenInteractive) {
                try {
                    checkForegroundApp()
                } catch (e: Exception) {
                    Log.e(TAG, "Error in usage stats polling", e)
                }
                handler.postDelayed(this, POLL_INTERVAL_MS)
            }
        }
    }

    private val screenStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    Log.d(TAG, "[UsageStats] Screen OFF: Pausing polling & clearing unlock sessions")
                    isScreenInteractive = false
                    handler.removeCallbacks(pollRunnable)
                    lockPrefs.clearUnlockedApps()
                    UnlockManager.clear()
                    LockSessionManager.clearAll()
                    lastForegroundPackage = null
                    lastProcessedEventTime = 0L
                }
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> {
                    Log.d(TAG, "[UsageStats] Screen ON: Resuming low-latency polling")
                    if (!isScreenInteractive) {
                        isScreenInteractive = true
                        lastProcessedEventTime = System.currentTimeMillis() - 500L
                        handler.removeCallbacks(pollRunnable)
                        handler.post(pollRunnable)
                    }
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        lockPrefs = LockPreferences(this)
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        CurtainManager.init(this)
        isRunning = true
        lastProcessedEventTime = System.currentTimeMillis() - 1000L

        startForeground(NOTIFICATION_ID, createNotification())

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenStateReceiver, filter)

        isScreenInteractive = true
        handler.post(pollRunnable)
        Log.d(TAG, "AppLockForegroundService initialized with 75ms polling")
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
        val queryStart = if (lastProcessedEventTime > 0) lastProcessedEventTime else (now - 1000L)
        val events = usageStatsManager.queryEvents(queryStart, now)
        val event = UsageEvents.Event()

        var latestEventTime = lastProcessedEventTime
        var currentTopPackage: String? = null

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED && event.timeStamp > latestEventTime) {
                latestEventTime = event.timeStamp
                currentTopPackage = event.packageName
            }
        }

        if (currentTopPackage == null) {
            return
        }

        lastProcessedEventTime = latestEventTime

        // Privix itself should not trigger lock screen
        if (currentTopPackage == "com.privix.privix") {
            return
        }

        // System UI transitions
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
        Log.d(TAG, "[UsageStats] Locking package at 0ms: $currentTopPackage")

        LockSessionManager.onProtectedAppDetected(currentTopPackage)
        CurtainManager.show(this)

        val authIntent = Intent(this, AuthActivity::class.java).apply {
            putExtra("packageName", currentTopPackage)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                val options = ActivityOptions.makeBasic().apply {
                    setPendingIntentBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                }
                val pi = PendingIntent.getActivity(
                    this,
                    0,
                    authIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    options.toBundle()
                )
                pi.send()
            } else {
                startActivity(authIntent)
            }
            Log.d(TAG, "[UsageStats] AuthActivity dispatched successfully for $currentTopPackage")
        } catch (e: Exception) {
            Log.e(TAG, "[UsageStats] Error starting AuthActivity via PendingIntent, trying direct startActivity", e)
            try {
                startActivity(authIntent)
            } catch (e2: Exception) {
                Log.e(TAG, "[UsageStats] Direct startActivity also failed", e2)
            }
        }
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
            unregisterReceiver(screenStateReceiver)
        } catch (_: Exception) {}
        Log.d(TAG, "AppLockForegroundService destroyed")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

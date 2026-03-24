package com.privix.privix.services

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.TextView
import com.privix.privix.R
import java.security.MessageDigest

/**
 * System overlay service that shows a full-screen lock screen on top of locked apps.
 * 
 * WHY: SYSTEM_ALERT_WINDOW is the only way to display UI on top of another app
 * before the user can interact with it. This runs as a foreground Service to
 * survive system cleanup. The overlay captures all touch input, preventing
 * access to the locked app underneath.
 */
class OverlayService : Service() {

    companion object {
        private const val TAG = "PrivixOverlay"
        const val EXTRA_LOCKED_PACKAGE = "locked_package"
        const val ACTION_SHOW_OVERLAY = "com.privix.SHOW_OVERLAY"
        const val ACTION_HIDE_OVERLAY = "com.privix.HIDE_OVERLAY"
        
        @Volatile
        var isOverlayShowing = false
            private set
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var currentLockedPackage: String? = null
    private lateinit var lockPrefs: LockPreferences

    // PIN state
    private var enteredPin = StringBuilder()
    private val pinDots = mutableListOf<View>()
    private var pinLength = 4 // Will be determined from stored PIN hash length context

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        lockPrefs = LockPreferences(this)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW_OVERLAY -> {
                val packageName = intent.getStringExtra(EXTRA_LOCKED_PACKAGE)
                if (packageName != null) {
                    showOverlay(packageName)
                }
            }
            ACTION_HIDE_OVERLAY -> {
                hideOverlay()
            }
        }
        return START_STICKY
    }

    private fun showOverlay(packageName: String) {
        // Prevent duplicate overlays
        if (isOverlayShowing && currentLockedPackage == packageName) {
            Log.d(TAG, "Overlay already showing for $packageName")
            return
        }

        // If overlay is showing for a different app, remove it first
        if (isOverlayShowing) {
            removeOverlayView()
        }

        currentLockedPackage = packageName
        enteredPin.clear()

        try {
            val inflater = getSystemService(LAYOUT_INFLATER_SERVICE) as LayoutInflater
            overlayView = inflater.inflate(R.layout.overlay_lock_screen, null)

            setupPinUI(overlayView!!, packageName)

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
                // Remove FLAG_NOT_FOCUSABLE implicitly by not adding it, 
                // but let's be explicit and clear it if it was default (it isn't)
                flags = flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()
                
                // Cover the entire screen including status bar
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    layoutInDisplayCutoutMode = 
                        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }

            windowManager?.addView(overlayView, params)
            isOverlayShowing = true
            Log.d(TAG, "Overlay shown for $packageName")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay", e)
        }
    }

    private fun setupPinUI(view: View, packageName: String) {
        // Set app name
        val appNameText = view.findViewById<TextView>(R.id.tvLockedAppName)
        try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            val appName = pm.getApplicationLabel(appInfo).toString()
            appNameText?.text = appName
        } catch (e: Exception) {
            appNameText?.text = packageName
        }

        // Setup PIN dots
        pinDots.clear()
        pinDots.add(view.findViewById(R.id.pinDot1))
        pinDots.add(view.findViewById(R.id.pinDot2))
        pinDots.add(view.findViewById(R.id.pinDot3))
        pinDots.add(view.findViewById(R.id.pinDot4))
        // Optional dots 5 and 6 for 6-digit PIN
        view.findViewById<View>(R.id.pinDot5)?.let { pinDots.add(it) }
        view.findViewById<View>(R.id.pinDot6)?.let { pinDots.add(it) }

        // Determine PIN length from stored hash metadata
        pinLength = lockPrefs.getPinLength()
        // Show/hide dots based on PIN length
        for (i in pinDots.indices) {
            pinDots[i].visibility = if (i < pinLength) View.VISIBLE else View.GONE
        }

        // Setup number buttons
        val buttonIds = listOf(
            R.id.btn0, R.id.btn1, R.id.btn2, R.id.btn3, R.id.btn4,
            R.id.btn5, R.id.btn6, R.id.btn7, R.id.btn8, R.id.btn9
        )
        for (i in buttonIds.indices) {
            view.findViewById<View>(buttonIds[i])?.setOnClickListener {
                onDigitPressed(i.toString(), view)
            }
        }

        // Backspace button
        view.findViewById<ImageButton>(R.id.btnBackspace)?.setOnClickListener {
            onBackspacePressed(view)
        }

        // Error text (hidden initially)
        view.findViewById<TextView>(R.id.tvError)?.visibility = View.INVISIBLE

        updatePinDots()
    }

    private fun onDigitPressed(digit: String, view: View) {
        if (enteredPin.length >= pinLength) return

        enteredPin.append(digit)
        updatePinDots()

        if (enteredPin.length == pinLength) {
            verifyPin(view)
        }
    }

    private fun onBackspacePressed(view: View) {
        if (enteredPin.isNotEmpty()) {
            enteredPin.deleteCharAt(enteredPin.length - 1)
            updatePinDots()
        }
        // Hide error when user starts correcting
        view.findViewById<TextView>(R.id.tvError)?.visibility = View.INVISIBLE
    }

    private fun updatePinDots() {
        for (i in pinDots.indices) {
            if (i < pinLength) {
                pinDots[i].isActivated = i < enteredPin.length
            }
        }
    }

    private fun verifyPin(view: View) {
        val storedHash = lockPrefs.getPinHash() ?: return
        val inputHash = hashPin(enteredPin.toString())

        if (inputHash == storedHash) {
            // Correct PIN — unlock
            currentLockedPackage?.let { lockPrefs.markAppUnlocked(it) }
            hideOverlay()
        } else {
            // Wrong PIN — show error, vibrate, clear
            val errorText = view.findViewById<TextView>(R.id.tvError)
            errorText?.text = "Wrong PIN. Try again."
            errorText?.visibility = View.VISIBLE
            
            vibrateError()
            
            enteredPin.clear()
            updatePinDots()
        }
    }

    private fun hashPin(pin: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hashBytes = digest.digest(pin.toByteArray())
        return hashBytes.joinToString("") { "%02x".format(it) }
    }

    private fun vibrateError() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                val vibrator = vibratorManager.defaultVibrator
                vibrator.vibrate(VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                vibrator.vibrate(VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE))
            }
        } catch (e: Exception) {
            Log.w(TAG, "Vibration failed", e)
        }
    }

    private fun hideOverlay() {
        removeOverlayView()
        currentLockedPackage = null
        Log.d(TAG, "Overlay hidden")
    }

    private fun removeOverlayView() {
        try {
            overlayView?.let {
                windowManager?.removeView(it)
                overlayView = null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to remove overlay view", e)
        }
        isOverlayShowing = false
    }

    override fun onDestroy() {
        removeOverlayView()
        super.onDestroy()
    }
}

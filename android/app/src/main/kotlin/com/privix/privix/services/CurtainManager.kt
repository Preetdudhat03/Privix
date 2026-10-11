package com.privix.privix.services

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.util.Log

/**
 * Manages an instant full-screen AMOLED black overlay (the "Curtain") 
 * to instantly cover locked apps with 0ms latency while AuthActivity opens.
 *
 * Automatically removes the overlay from WindowManager as soon as authentication
 * finishes or user navigates away, preventing the persistent "Displaying over other apps"
 * system notification.
 */
object CurtainManager {
    private const val TAG = "CurtainManager"
    private var curtainView: View? = null
    private var windowManager: WindowManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val autoDismissRunnable = Runnable {
        Log.d(TAG, "[CurtainManager] Safety auto-dismiss triggered (2.5s timeout reached)")
        hide("SafetyTimeout")
    }

    val isVisible: Boolean
        get() = curtainView != null && curtainView?.isAttachedToWindow == true

    /**
     * Optional warm-up for WindowManager service reference.
     * Does NOT add any view to WindowManager to prevent unwanted system notifications.
     */
    fun init(context: Context) {
        val appContext = context.applicationContext ?: context
        mainHandler.post {
            try {
                if (windowManager == null) {
                    windowManager = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error initializing WindowManager", e)
            }
        }
    }

    /**
     * Shows the full-screen black curtain to prevent screen leakage.
     * Dynamically attaches to WindowManager and schedules a safety auto-dismiss.
     */
    fun show(context: Context) {
        val appContext = context.applicationContext ?: context
        if (!Settings.canDrawOverlays(appContext)) {
            Log.w(TAG, "Cannot show curtain: SYSTEM_ALERT_WINDOW permission not granted")
            return
        }

        mainHandler.post {
            try {
                mainHandler.removeCallbacks(autoDismissRunnable)

                if (windowManager == null) {
                    windowManager = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                }

                if (curtainView == null) {
                    curtainView = View(appContext).apply {
                        setBackgroundColor(0xFF000000.toInt()) // Pure AMOLED Black
                        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                        isFocusable = true
                        isClickable = true
                    }

                    val layoutParams = WindowManager.LayoutParams(
                        WindowManager.LayoutParams.MATCH_PARENT,
                        WindowManager.LayoutParams.MATCH_PARENT,
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                        PixelFormat.OPAQUE
                    ).apply {
                        gravity = Gravity.CENTER
                        alpha = 1.0f
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                        }
                    }

                    windowManager?.addView(curtainView, layoutParams)
                    Log.d(TAG, "[CurtainManager] Curtain overlay attached to WindowManager (0ms shield active)")
                }

                // Safety timeout: automatically remove overlay after 2500ms so it can NEVER linger
                mainHandler.postDelayed(autoDismissRunnable, 2500L)
            } catch (e: Exception) {
                Log.e(TAG, "Error displaying curtain overlay", e)
            }
        }
    }

    /**
     * Hides and COMPLETELY REMOVES the curtain from WindowManager.
     * This immediately dismisses Android's "Privix is displaying over other apps" notification.
     */
    fun hide(reason: String = "Unknown") {
        mainHandler.post {
            mainHandler.removeCallbacks(autoDismissRunnable)
            try {
                val view = curtainView
                if (view != null) {
                    if (view.isAttachedToWindow) {
                        windowManager?.removeViewImmediate(view)
                        Log.d(TAG, "[CurtainManager] Curtain overlay removed from WindowManager (Reason: $reason)")
                    }
                    curtainView = null
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error removing curtain overlay", e)
                curtainView = null
            }
        }
    }
}

package com.privix.privix.services

import android.content.Context
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.util.Log

/**
 * Manages a solid full-screen AMOLED black overlay (the "Curtain") 
 * to instantly cover locked apps with 0ms latency.
 * Protected with FLAG_SECURE to prevent screenshot / screen-recording exposure.
 */
object CurtainManager {
    private const val TAG = "CurtainManager"
    private var curtainView: View? = null
    private var windowManager: WindowManager? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val autoDismissRunnable = Runnable {
        hide("SafetyTimeout")
    }

    val isVisible: Boolean
        get() = curtainView?.visibility == View.VISIBLE

    /**
     * Pre-initializes the curtain view to ensure zero-latency when needed.
     */
    fun init(context: Context) {
        val appContext = context.applicationContext ?: context
        if (!Settings.canDrawOverlays(appContext)) {
            Log.w(TAG, "Cannot init curtain: SYSTEM_ALERT_WINDOW permission not granted")
            return
        }

        mainHandler.post {
            if (curtainView != null) return@post
            try {
                windowManager = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                curtainView = View(appContext).apply {
                    setBackgroundColor(0xFF000000.toInt()) // Pure AMOLED Black
                    visibility = View.GONE
                    importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                    isFocusable = false
                    isClickable = false
                }

                layoutParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_SECURE,
                    PixelFormat.OPAQUE
                ).apply {
                    gravity = Gravity.CENTER
                    alpha = 1.0f
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                        layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                    }
                }

                windowManager?.addView(curtainView, layoutParams)
                Log.d(TAG, "Curtain persistent opaque window attached successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Error initializing curtain window", e)
                curtainView = null
            }
        }
    }

    fun show(context: Context) {
        val appContext = context.applicationContext ?: context
        if (curtainView == null) {
            init(appContext)
        }

        mainHandler.post {
            try {
                mainHandler.removeCallbacks(autoDismissRunnable)
                curtainView?.let { view ->
                    if (view.visibility != View.VISIBLE) {
                        layoutParams?.flags = WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or
                                WindowManager.LayoutParams.FLAG_SECURE
                        layoutParams?.let { lp -> windowManager?.updateViewLayout(view, lp) }
                        view.visibility = View.VISIBLE
                        view.isFocusable = true
                        view.isClickable = true
                        view.invalidate()
                        Log.d(TAG, "Curtain toggled: VISIBLE (0ms shield applied)")
                    }
                }
                // Safety timeout: automatically hide overlay after 2500ms so it can NEVER linger
                mainHandler.postDelayed(autoDismissRunnable, 2500L)
            } catch (e: Exception) {
                Log.e(TAG, "Error showing curtain", e)
            }
        }
    }

    fun hide(reason: String = "Unknown") {
        mainHandler.post {
            mainHandler.removeCallbacks(autoDismissRunnable)
            try {
                curtainView?.let { view ->
                    if (view.visibility != View.GONE) {
                        view.visibility = View.GONE
                        view.isFocusable = false
                        view.isClickable = false
                        layoutParams?.flags = WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or
                                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                                WindowManager.LayoutParams.FLAG_SECURE
                        layoutParams?.let { lp -> windowManager?.updateViewLayout(view, lp) }
                        Log.d(TAG, "Curtain toggled: GONE (Reason: $reason)")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error hiding curtain", e)
            }
        }
    }
}

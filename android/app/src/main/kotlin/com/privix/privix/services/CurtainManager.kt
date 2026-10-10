package com.privix.privix.services

import android.content.Context
import android.graphics.PixelFormat
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.util.Log

/**
 * Manages a solid full-screen AMOLED black overlay (the "Curtain") 
 * to instantly cover locked apps with 0ms latency.
 */
object CurtainManager {
    private const val TAG = "CurtainManager"
    private var curtainView: View? = null
    private var windowManager: WindowManager? = null
    private var layoutParams: WindowManager.LayoutParams? = null

    val isVisible: Boolean
        get() = curtainView?.visibility == View.VISIBLE

    /**
     * Pre-initializes the curtain view to ensure zero-latency when needed.
     */
    fun init(context: Context) {
        if (curtainView != null) return
        if (!Settings.canDrawOverlays(context)) {
            Log.w(TAG, "Cannot init curtain: SYSTEM_ALERT_WINDOW permission not granted")
            return
        }

        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            curtainView = View(context).apply {
                setBackgroundColor(0xFF000000.toInt()) // Pure AMOLED Black
                visibility = View.GONE
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                isFocusable = true
                isClickable = true
            }

            layoutParams = WindowManager.LayoutParams(
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
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                    layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }

            windowManager?.addView(curtainView, layoutParams)
            Log.d(TAG, "Curtain persistent opaque window attached")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing curtain", e)
        }
    }

    fun show(context: Context) {
        if (curtainView == null) {
            init(context)
        }

        try {
            curtainView?.let { view ->
                if (view.visibility != View.VISIBLE) {
                    view.visibility = View.VISIBLE
                    view.invalidate()
                    Log.d(TAG, "Curtain toggled: VISIBLE (0ms overlay applied)")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error showing curtain", e)
        }
    }

    fun hide(reason: String = "Unknown") {
        try {
            curtainView?.let { view ->
                if (view.visibility != View.GONE) {
                    view.visibility = View.GONE
                    Log.d(TAG, "Curtain toggled: GONE (Reason: $reason)")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error hiding curtain", e)
        }
    }
}

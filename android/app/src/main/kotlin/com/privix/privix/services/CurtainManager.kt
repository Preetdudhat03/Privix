package com.privix.privix.services

import android.content.Context
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.util.Log

/**
 * Manages a solid full-screen overlay (the "Curtain") to hide locked apps 
 * with zero latency. This is faster than an Activity.
 */
object CurtainManager {
    private var curtainView: View? = null
    private var windowManager: WindowManager? = null

    fun show(context: Context) {
        if (curtainView != null) return

        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            curtainView = View(context).apply {
                setBackgroundColor(0xFF0D0D1A.toInt()) // Privix dark background
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }

            windowManager?.addView(curtainView, params)
        } catch (e: Exception) {
            Log.e("CurtainManager", "Error showing curtain", e)
        }
    }

    fun hide() {
        try {
            if (curtainView != null) {
                windowManager?.removeView(curtainView)
                curtainView = null
                Log.d("CurtainManager", "Curtain hidden")
            }
        } catch (e: Exception) {
            Log.e("CurtainManager", "Error hiding curtain", e)
            curtainView = null
        }
    }
}

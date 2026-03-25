package com.privix.privix.services

import android.content.Context
import android.graphics.Color
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
    private var layoutParams: WindowManager.LayoutParams? = null
    private var isVisible = false

    private fun initIfNeeded(context: Context) {
        if (curtainView == null) {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            curtainView = View(context).apply {
                setBackgroundColor(0xFF0D0D1A.toInt()) // Privix dark background
            }
            layoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                PixelFormat.OPAQUE
            ).apply {
                gravity = Gravity.CENTER
                // Remove all animations for instant appearance
                windowAnimations = 0
            }
        }
    }

    fun show(context: Context) {
        if (isVisible) return
        
        try {
            initIfNeeded(context)
            windowManager?.addView(curtainView, layoutParams)
            isVisible = true
            Log.d("CurtainManager", "Curtain shown instantly")
        } catch (e: Exception) {
            // Log but don't crash; if already added, we catch it here
            isVisible = true 
        }
    }

    fun hide() {
        if (!isVisible) return
        
        try {
            if (curtainView != null) {
                windowManager?.removeViewImmediate(curtainView)
                isVisible = false
                Log.d("CurtainManager", "Curtain hidden immediately")
            }
        } catch (e: Exception) {
            Log.e("CurtainManager", "Error hiding curtain", e)
            isVisible = false
        }
    }
}

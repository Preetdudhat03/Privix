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
    private var layoutParams: WindowManager.LayoutParams? = null

    /**
     * Pre-initializes the curtain view to ensure zero-latency when needed.
     * The window is added ONCE and kept persistent.
     */
    fun init(context: Context) {
        if (curtainView != null) return
        
        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            curtainView = View(context).apply {
                setBackgroundColor(0xFF0D0D1A.toInt()) // Privix dark background
                visibility = View.GONE
            }

            layoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                        WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or
                        WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }
            
            windowManager?.addView(curtainView, layoutParams)
            Log.d("CurtainManager", "Curtain persistent window added (hidden)")
        } catch (e: Exception) {
            Log.e("CurtainManager", "Error initializing curtain", e)
        }
    }

    fun show(context: Context) {
        if (curtainView == null) {
            init(context)
        }
        
        try {
            curtainView?.visibility = View.VISIBLE
            Log.d("CurtainManager", "Curtain toggled: VISIBLE")
        } catch (e: Exception) {
            Log.e("CurtainManager", "Error showing curtain", e)
        }
    }

    fun hide() {
        try {
            curtainView?.visibility = View.GONE
            Log.d("CurtainManager", "Curtain toggled: GONE")
        } catch (e: Exception) {
            Log.e("CurtainManager", "Error hiding curtain", e)
        }
    }
}

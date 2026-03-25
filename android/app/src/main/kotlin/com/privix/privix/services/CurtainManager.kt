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
 * with zero latency. Pre-adds the view to WindowManager once.
 */
object CurtainManager {
    private var curtainView: View? = null
    private var windowManager: WindowManager? = null
    private var isAdded = false

    fun init(context: Context) {
        if (isAdded) return
        
        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            curtainView = View(context).apply {
                setBackgroundColor(0xFF0D0D1A.toInt()) // Privix dark background
                visibility = View.GONE
            }
            
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                PixelFormat.OPAQUE
            ).apply {
                gravity = Gravity.CENTER
                windowAnimations = 0 // Instant appearance
            }

            windowManager?.addView(curtainView, params)
            isAdded = true
            Log.d("CurtainManager", "Curtain view persistently added")
        } catch (e: Exception) {
            Log.e("CurtainManager", "Init failed", e)
        }
    }

    fun show(context: Context) {
        init(context) // Ensure it's there
        curtainView?.let {
            if (it.visibility != View.VISIBLE) {
                it.visibility = View.VISIBLE
                Log.d("CurtainManager", "Curtain set to VISIBLE")
            }
        }
    }

    fun hide() {
        curtainView?.let {
            if (it.visibility != View.GONE) {
                it.post {
                    it.visibility = View.GONE
                    Log.d("CurtainManager", "Curtain set to GONE")
                }
            }
        }
    }

    fun cleanup() {
        try {
            if (isAdded) {
                windowManager?.removeViewImmediate(curtainView)
                curtainView = null
                isAdded = false
            }
        } catch (e: Exception) {
            // view might already be gone
        }
    }
}

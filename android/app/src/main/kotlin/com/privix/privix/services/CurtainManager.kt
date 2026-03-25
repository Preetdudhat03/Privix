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
 * with absolute zero latency. Uses window resizing to stay "Active" in the 
 * system's composition layer even when hidden.
 */
object CurtainManager {
    private var curtainView: View? = null
    private var windowManager: WindowManager? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var isAdded = false
    private var isShown = false

    fun init(context: Context) {
        if (isAdded) return
        
        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            curtainView = View(context).apply {
                setBackgroundColor(0xFF0D0D1A.toInt()) // Privix dark background
            }
            
            // Start with a 1x1 window that is NOT touchable (effectively hidden)
            layoutParams = WindowManager.LayoutParams(
                1, 1,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.LEFT
                x = 0
                y = 0
                windowAnimations = 0
            }

            windowManager?.addView(curtainView, layoutParams)
            isAdded = true
            isShown = false
            Log.d("CurtainManager", "Curtain pre-allocated as 1x1 OPAQUE")
        } catch (e: Exception) {
            Log.e("CurtainManager", "Init failed", e)
        }
    }

    fun show(context: Context) {
        init(context)
        if (isShown) return

        try {
            curtainView?.let { view ->
                layoutParams?.let { params ->
                    params.width = WindowManager.LayoutParams.MATCH_PARENT
                    params.height = WindowManager.LayoutParams.MATCH_PARENT
                    params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
                    windowManager?.updateViewLayout(view, params)
                    isShown = true
                    Log.d("CurtainManager", "Curtain expanded to MATCH_PARENT")
                }
            }
        } catch (e: Exception) {
            Log.e("CurtainManager", "Show failed", e)
        }
    }

    fun hide() {
        if (!isShown) return
        
        try {
            curtainView?.let { view ->
                layoutParams?.let { params ->
                    params.width = 1
                    params.height = 1
                    params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                    windowManager?.updateViewLayout(view, params)
                    isShown = false
                    Log.d("CurtainManager", "Curtain collapsed to 1x1")
                }
            }
        } catch (e: Exception) {
            Log.e("CurtainManager", "Hide failed", e)
        }
    }

    fun cleanup() {
        try {
            if (isAdded) {
                windowManager?.removeViewImmediate(curtainView)
                curtainView = null
                isAdded = false
            }
        } catch (e: Exception) {}
    }
}

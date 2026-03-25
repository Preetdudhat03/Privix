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
                visibility = View.INVISIBLE
            }
            
            // Persistent FULL SCREEN window, initially INVISIBLE and NOT TOUCHABLE
            layoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
                windowAnimations = 0
            }

            windowManager?.addView(curtainView, layoutParams)
            isAdded = true
            isShown = false
            Log.d("CurtainManager", "Curtain pre-allocated as MATCH_PARENT INVISIBLE")
        } catch (e: Exception) {
            Log.e("CurtainManager", "Init failed", e)
        }
    }

    fun show(context: Context) {
        init(context)
        cancelHide()
        if (isShown) return

        try {
            curtainView?.let { view ->
                layoutParams?.let { params ->
                    view.visibility = View.VISIBLE
                    params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
                    windowManager?.updateViewLayout(view, params)
                    isShown = true
                    Log.d("CurtainManager", "Curtain set to VISIBLE")
                }
            }
        } catch (e: Exception) {
            Log.e("CurtainManager", "Show failed", e)
        }
    }

    private val hideRunnable = Runnable { hide() }

    fun hide() {
        cancelHide() // Ensure no pending delay triggers after manual hide
        if (!isShown) return
        
        try {
            curtainView?.let { view ->
                layoutParams?.let { params ->
                    view.visibility = View.INVISIBLE
                    params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                    windowManager?.updateViewLayout(view, params)
                    isShown = false
                    Log.d("CurtainManager", "Curtain set to INVISIBLE")
                }
            }
        } catch (e: Exception) {
            Log.e("CurtainManager", "Hide failed", e)
        }
    }

    fun hideWithDelay(delayMs: Long) {
        curtainView?.removeCallbacks(hideRunnable)
        curtainView?.postDelayed(hideRunnable, delayMs)
    }

    fun cancelHide() {
        curtainView?.removeCallbacks(hideRunnable)
    }

    fun cleanup() {
        cancelHide()
        try {
            if (isAdded) {
                windowManager?.removeViewImmediate(curtainView)
                curtainView = null
                isAdded = false
            }
        } catch (e: Exception) {}
    }
}

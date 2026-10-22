package com.privix.privix

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import com.privix.privix.services.AppLockAccessibilityService
import com.privix.privix.services.AppLockForegroundService
import com.privix.privix.services.CurtainManager
import com.privix.privix.services.LockPreferences
import com.privix.privix.services.LockSessionManager
import com.privix.privix.services.PrivixTileService
import com.privix.privix.services.UnlockManager

class AuthActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "AuthActivity"
        @Volatile
        var isResumedActive = false
            private set
    }

    private var targetPackage: String? = null
    private var isAuthSuccessful = false
    private var isBiometricPromptShowing = false
    private var isExiting = false
    private var isPauseAction = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private var backInvokedCallback: OnBackInvokedCallback? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Instant 0ms transition: remove any window slide or fade delay
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            overrideActivityTransition(OVERRIDE_TRANSITION_OPEN, 0, 0)
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }

        // Immediately paint window decor solid black
        window.decorView.setBackgroundColor(0xFF000000.toInt())
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Security Hardening: Block screenshots, screen recording, and recent task preview
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        
        // Match CurtainManager layout to prevent any edge flicker revealing the underlying app
        window.addFlags(
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }

        // Register modern back press callbacks (AndroidX & Android 13+ Predictive Back)
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                Log.d(TAG, "[PrivixLock] Back invoked via OnBackPressedDispatcher -> exitToHome")
                exitToHome()
            }
        })

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            backInvokedCallback = OnBackInvokedCallback {
                Log.d(TAG, "[PrivixLock] Back invoked via OnBackInvokedDispatcher -> exitToHome")
                exitToHome()
            }
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                backInvokedCallback!!
            )
        }

        window.decorView.setOnClickListener {
            if (!isAuthSuccessful && !isBiometricPromptShowing) {
                if (isPauseAction) {
                    promptBiometricAuthForPause()
                } else {
                    targetPackage?.let { promptBiometricAuth(it) }
                }
            }
        }
        
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val action = intent?.getStringExtra("action")
        if (action == "pause_protection") {
            isPauseAction = true
            isAuthSuccessful = false
            Log.d(TAG, "[PrivixLock] AuthActivity launched for pause_protection action")
            promptBiometricAuthForPause()
            return
        }

        val pkg = intent?.getStringExtra("packageName") ?: return exitToHome()
        targetPackage = pkg
        isPauseAction = false
        isAuthSuccessful = false
        LockSessionManager.onProtectedAppDetected(pkg)
        Log.d(TAG, "[PrivixLock] AuthActivity initialized for package: $pkg")

        promptBiometricAuth(pkg)
    }

    private fun promptBiometricAuthForPause() {
        if (isAuthSuccessful || isBiometricPromptShowing) {
            return
        }

        val executor = ContextCompat.getMainExecutor(this)
        val biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    isBiometricPromptShowing = false
                    Log.d(TAG, "[PrivixLock] Pause biometric error: $errString ($errorCode)")
                    finish()
                }

                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    isBiometricPromptShowing = false
                    isAuthSuccessful = true
                    Log.d(TAG, "[PrivixLock] Pause authentication SUCCEEDED. Pausing for 15 minutes.")
                    LockPreferences(this@AuthActivity).pauseForMinutes(15)
                    PrivixTileService.requestUpdate(this@AuthActivity)
                    finish()
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    Log.d(TAG, "[PrivixLock] Pause authentication failed (wrong biometric/credential)")
                }
            })

        val promptInfoBuilder = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Pause Protection")
            .setSubtitle("Authenticate to pause Privix App Lock for 15 minutes")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            promptInfoBuilder.setAllowedAuthenticators(
                androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG or 
                androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
        } else {
            @Suppress("DEPRECATION")
            promptInfoBuilder.setDeviceCredentialAllowed(true)
        }

        try {
            isBiometricPromptShowing = true
            biometricPrompt.authenticate(promptInfoBuilder.build())
        } catch (e: Exception) {
            isBiometricPromptShowing = false
            Log.e(TAG, "[PrivixLock] Failed to launch BiometricPrompt for pause", e)
            finish()
        }
    }

    private fun promptBiometricAuth(pkg: String) {
        if (isAuthSuccessful || isBiometricPromptShowing) {
            return
        }

        val executor = ContextCompat.getMainExecutor(this)
        val biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    isBiometricPromptShowing = false
                    Log.d(TAG, "[PrivixLock] Biometric prompt event/error: $errString (code: $errorCode)")
                    
                    if (isAuthSuccessful) return

                    // System UI interruptions (Notification Shade, Quick Settings, Edge Panel)
                    if (errorCode == BiometricPrompt.ERROR_CANCELED || LockSessionManager.isSystemUiActive) {
                        Log.d(TAG, "[PrivixLock] Biometric canceled by System UI / focus change. Keeping lock active.")
                        return
                    }

                    // User pressed Back, Negative button, or dismissed prompt -> Immediately exit to Home!
                    if (errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                        errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON) {
                        Log.d(TAG, "[PrivixLock] User canceled authentication -> exitToHome")
                        exitToHome()
                        return
                    }

                    Log.w(TAG, "[PrivixLock] Biometric error ($errorCode): $errString")
                }

                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    isBiometricPromptShowing = false
                    isAuthSuccessful = true
                    Log.d(TAG, "[PrivixLock] Authentication SUCCESS for $pkg")
                    
                    // Authoritative Unlock Path
                    LockSessionManager.onAuthenticationSuccess(pkg)
                    UnlockManager.markUnlocked(pkg)
                    LockPreferences(this@AuthActivity).markAppUnlocked(pkg)
                    
                    CurtainManager.hide("AuthSuccess")
                    finish()
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    Log.d(TAG, "[PrivixLock] Authentication failed (wrong fingerprint/face)")
                }
            })

        val promptInfoBuilder = BiometricPrompt.PromptInfo.Builder()
            .setTitle("App Locked")
            .setSubtitle("Unlock to access application")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            promptInfoBuilder.setAllowedAuthenticators(
                androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG or 
                androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
        } else {
            @Suppress("DEPRECATION")
            promptInfoBuilder.setDeviceCredentialAllowed(true)
        }

        try {
            isBiometricPromptShowing = true
            biometricPrompt.authenticate(promptInfoBuilder.build())
        } catch (e: Exception) {
            isBiometricPromptShowing = false
            Log.e(TAG, "[PrivixLock] Failed to launch BiometricPrompt", e)
        }
    }

    override fun onResume() {
        super.onResume()
        isResumedActive = true
        
        // Once AuthActivity is drawn, its solid black window covers the locked app.
        // Dismiss the curtain overlay window so Android does not post the overlay notification.
        window.decorView.post {
            CurtainManager.hide("AuthActivityRendered")
        }

        // If resuming after System UI interruption and prompt is not showing, re-prompt automatically
        if (!isAuthSuccessful && !isBiometricPromptShowing) {
            mainHandler.postDelayed({
                if (!isAuthSuccessful && !isBiometricPromptShowing && isResumedActive) {
                    if (isPauseAction) {
                        promptBiometricAuthForPause()
                    } else {
                        targetPackage?.let { promptBiometricAuth(it) }
                    }
                }
            }, 100L)
        }
    }

    override fun onPause() {
        isResumedActive = false
        isBiometricPromptShowing = false
        super.onPause()
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && backInvokedCallback != null) {
            try {
                onBackInvokedDispatcher.unregisterOnBackInvokedCallback(backInvokedCallback!!)
            } catch (_: Exception) {}
        }

        // FAIL-SAFE: If destroyed without successful authentication, ensure protected app is never accessible
        if (!isAuthSuccessful && !isPauseAction) {
            val pkg = targetPackage
            if (pkg != null) {
                LockSessionManager.invalidateSession("AuthActivity destroyed without unlock")
                UnlockManager.forgetApp(pkg)
                LockPreferences(this).removeAppUnlocked(pkg)
            }
            AppLockAccessibilityService.lastForegroundPackage = null
            AppLockForegroundService.resetLastForegroundPackage()

            if (!isExiting) {
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                try {
                    startActivity(homeIntent)
                } catch (_: Exception) {}
            }
        }
        super.onDestroy()
    }

    private fun exitToHome() {
        if (isPauseAction) {
            finish()
            return
        }

        if (isExiting) return
        isExiting = true

        Log.d(TAG, "[PrivixLock] Exiting to Home safely from AuthActivity")
        val pkg = targetPackage
        if (pkg != null) {
            LockSessionManager.invalidateSession("User exited to Home")
            UnlockManager.forgetApp(pkg)
            LockPreferences(this).removeAppUnlocked(pkg)
        }
        
        AppLockAccessibilityService.lastForegroundPackage = null
        AppLockForegroundService.resetLastForegroundPackage()

        // Shield transition with solid curtain to guarantee 0ms flicker of the underlying app
        CurtainManager.show(this)

        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        try {
            startActivity(homeIntent)
        } catch (e: Exception) {
            Log.e(TAG, "[PrivixLock] Failed to start Home intent", e)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }

        moveTaskToBack(true)
        finishAndRemoveTask()

        mainHandler.postDelayed({
            CurtainManager.hide("ExitToHomeFallback")
        }, 500L)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        Log.d(TAG, "[PrivixLock] onBackPressed invoked -> exitToHome")
        exitToHome()
    }
}

package com.privix.privix

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import com.privix.privix.services.LockPreferences
import com.privix.privix.services.UnlockManager
import com.privix.privix.services.CurtainManager
import com.privix.privix.services.LockSessionManager
import com.privix.privix.services.LockState

class AuthActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "AuthActivity"
        var isResumedActive = false
            private set
    }

    private var targetPackage: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Ensure the screen stays on during authentication
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Match CurtainManager layout to prevent any edge flicker revealing the underlying app
        window.addFlags(
            android.view.WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode = android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val pkg = intent?.getStringExtra("packageName") ?: return finish()
        targetPackage = pkg
        LockSessionManager.onProtectedAppDetected(pkg)
        Log.d(TAG, "[PrivixLock] AuthActivity initialized for package: $pkg")

        promptBiometricAuth(pkg)
    }

    private fun promptBiometricAuth(pkg: String) {
        val executor = ContextCompat.getMainExecutor(this)
        val biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    Log.d(TAG, "[PrivixLock] Biometric prompt event/error: $errString (code: $errorCode)")
                    
                    // CRITICAL FIX: System UI interruptions (Notification Shade, Quick Settings, Edge Panel)
                    // fire cancellation errors (code 10 or 13). DO NOT exit to home! Keep lock screen active.
                    if (errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                        errorCode == BiometricPrompt.ERROR_CANCELED ||
                        errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON) {
                        Log.d(TAG, "[PrivixLock] Biometric canceled by System UI / touch outside. Preserving lock state.")
                        // Do NOT call exitToHome()! Keep AuthActivity & Curtain overlay alive.
                    } else {
                        Log.w(TAG, "[PrivixLock] Biometric error ($errorCode): $errString")
                    }
                }

                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
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

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            promptInfoBuilder.setAllowedAuthenticators(
                androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG or 
                androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
        } else {
            @Suppress("DEPRECATION")
            promptInfoBuilder.setDeviceCredentialAllowed(true)
        }

        try {
            biometricPrompt.authenticate(promptInfoBuilder.build())
        } catch (e: Exception) {
            Log.e(TAG, "[PrivixLock] Failed to launch BiometricPrompt", e)
        }
    }

    override fun onResume() {
        super.onResume()
        isResumedActive = true
        
        val pkg = targetPackage
        if (pkg != null && !LockSessionManager.isAppUnlocked(pkg)) {
            // Re-assert zero-latency curtain overlay for unauthenticated user
            CurtainManager.show(this)
            Log.d(TAG, "[PrivixLock] AuthActivity onResume for UNAUTHENTICATED package ($pkg). Curtain remains VISIBLE.")
        }
    }

    override fun onPause() {
        isResumedActive = false
        super.onPause()
        
        // Ensure curtain remains attached if user is unauthenticated
        val pkg = targetPackage
        if (pkg != null && !LockSessionManager.isAppUnlocked(pkg)) {
            CurtainManager.show(this)
            Log.d(TAG, "[PrivixLock] AuthActivity onPause while UNAUTHENTICATED ($pkg). Overlay preserved.")
        }
    }

    private fun exitToHome() {
        Log.d(TAG, "[PrivixLock] User explicitly exited to Home from lock screen")
        val pkg = targetPackage
        if (pkg != null) {
            LockSessionManager.invalidateSession("User exited to Home")
        }
        CurtainManager.hide("ExitToHome")
        
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(homeIntent)
        finishAffinity()
    }

    override fun onBackPressed() {
        // Explicit user back press -> navigate safely to Home screen
        super.onBackPressed()
        exitToHome()
    }
}

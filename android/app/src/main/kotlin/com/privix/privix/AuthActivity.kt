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

class AuthActivity : AppCompatActivity() {
    private var wasCurtainHidden = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Ensure the screen stays on during authentication
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val packageName = intent?.getStringExtra("packageName") ?: return finish()
        Log.d("AuthActivity", "Prompting system auth for $packageName")

        val executor = ContextCompat.getMainExecutor(this)
        val biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    Log.d("AuthActivity", "Auth error: $errString")
                    exitToHome()
                }

                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    Log.d("AuthActivity", "Auth success for $packageName")
                    UnlockManager.markUnlocked(packageName)
                    LockPreferences(this@AuthActivity).markAppUnlocked(packageName)
                    finishWithReason("AuthSuccess")
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    Log.d("AuthActivity", "Auth failed")
                }
            })

        val promptInfoBuilder = BiometricPrompt.PromptInfo.Builder()
            .setTitle("App Locked")
            .setSubtitle("Unlock to access the app")

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            promptInfoBuilder.setAllowedAuthenticators(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG or androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL)
        } else {
            @Suppress("DEPRECATION")
            promptInfoBuilder.setDeviceCredentialAllowed(true)
        }

        val promptInfo = promptInfoBuilder.build()

        try {
            biometricPrompt.authenticate(promptInfo)
        } catch (e: Exception) {
            Log.e("AuthActivity", "Failed to show BiometricPrompt", e)
            exitToHome()
        }
    }

    override fun onResume() {
        super.onResume()
        // Hide the curtain only when AuthActivity is in the foreground and ready.
        // Increased delay to 300ms (from 150ms) to ensure the system biometric dialog 
        // is fully visible before removing our overlay, preventing a flicker.
        window.decorView.postDelayed({
            if (!isFinishing && !wasCurtainHidden) {
                hideCurtain("ActivityResumed")
            }
        }, 300)
    }

    /**
     * Helper to safely hide curtain once.
     */
    private fun hideCurtain(reason: String) {
        if (!wasCurtainHidden) {
            CurtainManager.hide(reason)
            wasCurtainHidden = true
        }
    }

    private fun finishWithReason(reason: String) {
        hideCurtain(reason)
        finish()
    }

    override fun finish() {
        hideCurtain("FinishCalled")
        super.finish()
    }

    override fun onPause() {
        super.onPause()
        // If we are leaving the app (not just showing a dialog), ensure curtain is gone.
        // But if were just paused by the biometric prompt, don't hide yet if the timer is still running.
        if (isFinishing) {
            hideCurtain("ActivityPausingFinal")
        }
    }

    private fun exitToHome() {
        hideCurtain("ExitToHome")
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(homeIntent)
        finishAffinity()
    }
    
    override fun onDestroy() {
        hideCurtain("ActivityDestroyed")
        super.onDestroy()
    }
    
    override fun onBackPressed() {
        // Intercept back presses to exit to home
        super.onBackPressed()
        exitToHome()
    }
}

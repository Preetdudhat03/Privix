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
                    finish()
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
        // We use post to ensure the window is actually rendered before removing the overlay.
        window.decorView.postDelayed({
            CurtainManager.hide()
        }, 50)
    }

    override fun onPause() {
        super.onPause()
        // Ensure the curtain is hidden if the user backgrounds the auth screen
        CurtainManager.hide()
    }

    private fun exitToHome() {
        CurtainManager.hide()
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(homeIntent)
        finishAffinity()
    }
    
    override fun onDestroy() {
        CurtainManager.hide() // Safety net
        super.onDestroy()
    }
    
    override fun onBackPressed() {
        // Intercept back presses to exit to home
        super.onBackPressed()
        exitToHome()
    }
}

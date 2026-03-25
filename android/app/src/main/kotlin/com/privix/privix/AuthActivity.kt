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
        
        val packageName = intent.getStringExtra("packageName") ?: return finish()
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
                    
                    // Auth successful: hide the curtain so the user can see the app 
                    CurtainManager.hide()
                    finish()
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    Log.d("AuthActivity", "Auth failed")
                    // BiometricPrompt handles retries natively
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

        if (savedInstanceState == null) {
            try {
                biometricPrompt.authenticate(promptInfo)
            } catch (e: Exception) {
                Log.e("AuthActivity", "Failed to show BiometricPrompt", e)
                exitToHome()
            }
        }
    }

    private fun exitToHome() {
        // Hide curtain BEFORE exiting so the home screen is visible
        CurtainManager.hide()
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(homeIntent)
        finishAffinity()
    }
    
    override fun onResume() {
        super.onResume()
        // DO NOT hide curtain here yet, BiometricPrompt is a system dialog
        // and might be showing OVER our activity.
    }

    override fun onDestroy() {
        // Curtain is hidden when finishing successfully or exiting to home
        super.onDestroy()
    }
    
    override fun onBackPressed() {
        // Intercept back presses to exit to home
        super.onBackPressed()
        exitToHome()
    }
}

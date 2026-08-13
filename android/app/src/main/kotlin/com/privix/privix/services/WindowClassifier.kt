package com.privix.privix.services

import android.content.Context
import android.content.Intent
import android.content.contentvalues.ContentValues.TAG
import android.content.pm.PackageManager
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo

/**
 * Robust window classifier to distinguish between user apps, system UI overlays, launchers, and Privix.
 */
object WindowClassifier {

    private const val PRIVIX_PACKAGE = "com.privix.privix"

    // Core Android Home Launchers
    private val HOME_PACKAGES = setOf(
        "com.android.launcher",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.sec.android.app.launcher",       // Samsung OneUI Launcher
        "com.samsung.android.oneui.launcher",
        "com.sec.android.app.easylauncher",
        "com.miui.home",                      // Xiaomi Launcher
        "com.huawei.android.launcher",
        "com.oppo.launcher",                  // Oppo / OnePlus Launcher
        "com.vivo.launcher"                   // Vivo Launcher
    )

    // Known System UI overlays & system controls (including Samsung One UI specific overlays)
    private val KNOWN_SYSTEM_OVERLAYS = setOf(
        "com.android.systemui",
        "android",
        "com.samsung.android.app.cocktailbarservice",  // Samsung Edge Panel
        "com.samsung.android.bixby.agent",             // Bixby Overlay
        "com.samsung.android.smartclip",               // Samsung Smart Select
        "com.sec.android.app.sysscope",                // Samsung System popup
        "com.samsung.android.smartsuggestions",
        "com.samsung.android.bluetoothtethering",
        "com.android.settings.intelligence",
        "com.samsung.android.app.routines",
        "com.android.incallui",                        // Phone Call Overlay
        "com.samsung.android.incallui",
        "com.samsung.android.app.smartcapture",        // Samsung Screenshot Toolbar
        "com.samsung.android.smartcapture",            // Older Samsung Capture UI
        "com.samsung.android.app.screenrecorder",      // Samsung Screen Recorder UI
        "com.samsung.android.selectionservice",        // Samsung Text Selection
        "com.samsung.android.app.clipboardedge",       // Samsung Clipboard Edge
        "com.samsung.android.app.appsedge",            // Samsung Apps Edge
        "com.samsung.android.app.taskedge",            // Samsung Tasks Edge
        "com.samsung.android.app.peopleedge"           // Samsung People Edge
    )

    /**
     * Classifies an accessibility event & package into a WindowCategory.
     */
    fun classify(pkg: String?, windowInfo: AccessibilityWindowInfo? = null): WindowCategory {
        if (pkg.isNullOrEmpty()) return WindowCategory.UNKNOWN

        // 1. Privix's own overlay / activity
        if (pkg == PRIVIX_PACKAGE) {
            return WindowCategory.PRIVIX_OVERLAY
        }

        // 2. WindowInfo type inspection
        if (windowInfo != null) {
            when (windowInfo.type) {
                AccessibilityWindowInfo.TYPE_SYSTEM_OVERLAY,
                AccessibilityWindowInfo.TYPE_INPUT_METHOD,
                AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY,
                AccessibilityWindowInfo.TYPE_SPLIT_SCREEN_DIVIDER -> {
                    return WindowCategory.SYSTEM_UI
                }
            }
        }

        // 3. Known System Overlays set check
        if (KNOWN_SYSTEM_OVERLAYS.contains(pkg)) {
            return WindowCategory.SYSTEM_UI
        }

        // 4. Dynamic pattern matching for Samsung One UI & Android System overlays
        if (pkg.startsWith("com.samsung.") && (
            pkg.contains("edge", ignoreCase = true) ||
            pkg.contains("capture", ignoreCase = true) ||
            pkg.contains("smartclip", ignoreCase = true) ||
            pkg.contains("bixby", ignoreCase = true) ||
            pkg.contains("cocktail", ignoreCase = true)
        )) {
            return WindowCategory.SYSTEM_UI
        }

        if (pkg == "android" || pkg.startsWith("com.android.systemui")) {
            return WindowCategory.SYSTEM_UI
        }

        // 5. Check Home Launchers
        if (HOME_PACKAGES.contains(pkg)) {
            return WindowCategory.HOME_LAUNCHER
        }

        // Default to Primary User App
        return WindowCategory.PRIMARY_USER_APP
    }
}

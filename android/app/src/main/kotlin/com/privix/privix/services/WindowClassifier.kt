package com.privix.privix.services

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
        // Core System UI & Framework
        "android",
        "com.android.systemui",

        // Permission Controllers (AOSP, Google, Samsung)
        "com.google.android.permissioncontroller",
        "com.android.permissioncontroller",
        "com.samsung.android.permissioncontroller",

        // Storage Access Framework & Document Pickers
        "com.google.android.documentsui",
        "com.android.documentsui",

        // Media & Photo Pickers
        "com.google.android.providers.media.module",
        "com.android.providers.media.module",

        // Intent Resolvers / Sharesheet / Chooser
        "com.android.intentresolver",
        "com.android.internal.app.ResolverActivity",

        // Google Play Services transient dialogs & auth sheets
        "com.google.android.gms",

        // Credential Manager & System Autofill
        "com.android.credentialmanager",
        "com.samsung.android.samsungpassautofill",
        "com.samsung.android.spay",

        // System Pairing, Bluetooth & Devices
        "com.android.companiondevicemanager",
        "com.android.bluetooth",

        // System dialogs & Installers
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.android.printspooler",
        "com.android.captiveportallogin",
        "com.android.vpndialogs",
        "com.android.certinstaller",
        "com.android.settings.intelligence",

        // Phone call UI overlays
        "com.android.incallui",
        "com.samsung.android.incallui",
        "com.samsung.android.app.telephonyui",

        // Samsung One UI overlays & system tools
        "com.samsung.android.app.cocktailbarservice",  // Samsung Edge Panel
        "com.samsung.android.bixby.agent",             // Bixby Overlay
        "com.samsung.android.smartclip",               // Samsung Smart Select
        "com.sec.android.app.sysscope",                // Samsung System popup
        "com.samsung.android.smartsuggestions",
        "com.samsung.android.bluetoothtethering",
        "com.android.settings.intelligence",
        "com.samsung.android.app.routines",
        "com.samsung.android.app.smartcapture",        // Samsung Screenshot Toolbar
        "com.samsung.android.smartcapture",            // Older Samsung Capture UI
        "com.samsung.android.app.screenrecorder",      // Samsung Screen Recorder UI
        "com.samsung.android.selectionservice",        // Samsung Text Selection
        "com.samsung.android.honeyboard",             // Samsung Keyboard & Clipboard
        "com.samsung.android.app.clipboardedge",       // Samsung Clipboard Edge
        "com.samsung.android.app.appsedge",            // Samsung Apps Edge
        "com.samsung.android.app.taskedge",            // Samsung Tasks Edge
        "com.samsung.android.app.peopleedge",          // Samsung People Edge
        "com.sec.android.app.popupcalculator"
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
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                when (windowInfo.type) {
                    AccessibilityWindowInfo.TYPE_SYSTEM,
                    AccessibilityWindowInfo.TYPE_INPUT_METHOD,
                    AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY,
                    AccessibilityWindowInfo.TYPE_SPLIT_SCREEN_DIVIDER -> {
                        return WindowCategory.SYSTEM_UI
                    }
                }
            }
        }

        val lowerPkg = pkg.lowercase()

        // 3. Known System Overlays set check
        if (KNOWN_SYSTEM_OVERLAYS.contains(pkg) || KNOWN_SYSTEM_OVERLAYS.contains(lowerPkg)) {
            return WindowCategory.SYSTEM_UI
        }

        // 4. Dynamic pattern matching for permission dialogs, pickers, and OEM system overlays
        if (lowerPkg.contains("permissioncontroller") ||
            lowerPkg.contains("documentsui") ||
            lowerPkg.contains("providers.media.module") ||
            lowerPkg.contains("intentresolver") ||
            lowerPkg.contains("credentialmanager") ||
            lowerPkg.contains("samsungpassautofill")
        ) {
            return WindowCategory.SYSTEM_UI
        }

        if (lowerPkg.startsWith("com.samsung.") && (
            lowerPkg.contains("edge") ||
            lowerPkg.contains("capture") ||
            lowerPkg.contains("smartclip") ||
            lowerPkg.contains("bixby") ||
            lowerPkg.contains("cocktail") ||
            lowerPkg.contains("telephonyui")
        )) {
            return WindowCategory.SYSTEM_UI
        }

        if (lowerPkg == "android" || lowerPkg.startsWith("com.android.systemui")) {
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

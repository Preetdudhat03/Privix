package com.privix.privix.services

/**
 * Categorizes windows to distinguish real application switches from temporary system UI.
 */
enum class WindowCategory {
    /** Regular third-party user application (Instagram, WhatsApp, Chrome, etc.) */
    PRIMARY_USER_APP,

    /** Temporary system UI (Samsung Edge Panel, Screenshot tools, Notification Shade, Volume panel, Keyboards, System dialogs) */
    SYSTEM_UI,

    /** Privix's own overlay screen or authentication activity */
    PRIVIX_OVERLAY,

    /** System Home screen / Launcher */
    HOME_LAUNCHER,

    /** Unknown or transient window */
    UNKNOWN
}

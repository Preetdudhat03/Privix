# Privix — Offline App Lock 🛡️

[![Latest Release](https://img.shields.io/github/v/release/Preetdudhat03/Privix?color=007AFF&label=Latest%20Release)](https://github.com/Preetdudhat03/Privix/releases/tag/v2.0.0)
[![Build & Publish Release](https://github.com/Preetdudhat03/Privix/actions/workflows/release.yml/badge.svg)](https://github.com/Preetdudhat03/Privix/actions/workflows/release.yml)
[![Platform](https://img.shields.io/badge/Platform-Android%207.0%2B-brightgreen)](https://developer.android.com)
[![Flutter](https://img.shields.io/badge/Flutter-v3.27%2B-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT%20%2F%20Personal-orange)](LICENSE)

**Privix** is a high-performance, offline Android app locking application built with **Flutter** and **Kotlin**. It provides real-time protection for sensitive applications using biometric authentication (fingerprint/face unlock) or a PIN.

Designed with **Samsung One UI 9** aesthetics and Device Care design philosophy, Privix ensures your personal data, messaging apps, photos, and financial tools remain completely private without collecting any user telemetry or requiring internet access.

---

## 🏛️ Government & Banking App Compatibility Mode

Many government applications (*mAadhaar, DigiLocker, Umang, PAN*) and banking applications (*SBI YONO, BHIM UPI, HDFC, ICICI*) enforce strict security policies that block execution if **any** third-party Accessibility Service is enabled on the device.

Privix solves this with a **Dual Detection Engine**:
1. **Usage Access Mode (Recommended for Banking & Gov Apps)**:
   - Uses Android's native `PACKAGE_USAGE_STATS` (`UsageStatsManager`) and a dedicated background foreground service.
   - **Accessibility Service remains completely OFF in Android Settings.**
   - Government and banking apps detect **zero** accessibility services and run cleanly without error or blocking!
2. **Accessibility Mode (0ms Instant Curtain)**:
   - High-speed window state detection for users who prioritize instantaneous overlay without banking app restrictions.

---

## 🛡️ Threat Warning & Security Fixes

Previous builds could trigger Google Play Protect or Samsung Knox "Threat Warnings" due to intrusive accessibility flags and debug signing. We have eliminated this:
- **`canRetrieveWindowContent` permanently set to `false`**: Privix cannot and does not read any screen content, keystrokes, OTPs, or passwords.
- **Restricted Event Scope**: Service only listens to `typeWindowStateChanged` for package names.
- **Backup & Extraction Disabled**: `android:allowBackup="false"` and `android:fullBackupContent="false"` in manifest.
- **100% Offline**: Zero internet permissions (`android.permission.INTERNET` is neither requested nor used).

---

## ✨ Key Features

- 🎨 **Samsung One UI 9 Design Hierarchy**
  - Expansive collapsible viewing headers with live status capsule pills.
  - Device Care style circular security gauge widget with health score (0-100%).
  - Inset grouped island cards with thumb-friendly layout.
  - Segmented pill filter bar and One UI squircle search bar.
  - Samsung Quick Settings Tile (`PrivixTileService`) for 1-tap pause/resume from notification shade.

- ⚡ **Dual Detection Engines**
  - **Usage Access Mode**: Safe with mAadhaar, DigiLocker, Umang, and banking apps.
  - **Accessibility Mode**: 0ms hardware-speed curtain overlay.

- 🔒 **Smart 1-Tap Category Locking**
  - **Lock Sensitive Apps**: Instantly detect and lock messaging, social media, finance, and gallery apps (*WhatsApp, Instagram, Photos, Paytm, Google Pay, Telegram, etc.*) in a single tap.
  - **Filter Categories**: Sort installed apps by **All**, **Locked**, **Sensitive**, and **User Apps**.

- 🔑 **Flexible Authentication**
  - Android System Biometrics (*Strong Biometric / Face / Fingerprint*)
  - Custom Numeric PIN keypad with animated digit indicators, haptic feedback, and error shake effects.

- 🚀 **Butter-Smooth Performance (60 / 120 FPS)**
  - Native Kotlin icon scaling and WebP/PNG memory compression.
  - Flutter in-memory **LRU Icon Cache** with background pre-warming for stutter-free scrolling through hundreds of installed apps.

- ⏱️ **Customizable Relock Timers**
  Configure when locked apps require re-authentication:
  - Immediately (0 seconds)
  - 15 seconds
  - 30 seconds
  - 1 minute
  - 5 minutes
  - Until screen turns off

- 🎨 **Modern Aesthetics & UX**
  - Full support for Light and Dark modes.
  - Smooth micro-animations and subtle haptic feedback on interactions.
  - Dynamic security status card and protection score.

- 🛡️ **100% Offline & Privacy First**
  Requires **zero network permissions**. All credentials, encrypted hashes, and preferences remain strictly on your local device.

---

## 🛠️ Architecture & Tech Stack

- **Frontend**: Flutter (Dart) with Material 3 & One UI 7 design tokens.
- **Backend Service**: Kotlin (`FlutterFragmentActivity`, `AccessibilityService`, `BiometricPrompt`).
- **Communication**: Platform Channels (`MethodChannel`) for real-time Flutter ↔ Kotlin inter-process communication.
- **Security**: SHA-256 PIN hashing + `flutter_secure_storage` & native `SharedPreferences`.

```
  ┌─────────────────────────────────────────────────────────┐
  │                    Flutter UI Layer                     │
  │     (HomeScreen, AppSelectionScreen, SettingsScreen)   │
  └───────────────────────────┬─────────────────────────────┘
                              │ MethodChannel
  ┌───────────────────────────▼─────────────────────────────┐
  │                   Native Kotlin Layer                   │
  │  ┌───────────────────────────────────────────────────┐  │
  │  │        AppLockAccessibilityService (0ms)          │  │
  │  └────────────────────────┬──────────────────────────┘  │
  │  ┌────────────────────────▼──────────────────────────┐  │
  │  │         CurtainManager & AuthActivity             │  │
  │  └───────────────────────────────────────────────────┘  │
  └─────────────────────────────────────────────────────────┘
```

---

## 📋 Required Android Permissions

Privix requires specific system permissions to function reliably:

| Permission | Purpose |
| :--- | :--- |
| **Accessibility Service** | Detects foreground app window switches in real time. |
| **Draw Over Apps** (`SYSTEM_ALERT_WINDOW`) | Displays the instant lock screen overlay over protected apps. |
| **Battery Optimization Exemption** | Prevents Android OS from killing the background protection service. |

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.27+ recommended)
- Android SDK (API 24 / Android 7.0 or higher)
- Java Development Kit (JDK 17+)
- An Android device or emulator with Biometric / PIN capability

### Build & Run

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Preetdudhat03/Privix.git
   cd Privix
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run code analysis**:
   ```bash
   flutter analyze
   ```

4. **Build and launch on a connected device**:
   ```bash
   flutter run
   ```

---

## 👤 Developer

Developed with ❤️ by **Preet Dudhat**  
GitHub: [@Preetdudhat03](https://github.com/Preetdudhat03)

---

## 📄 License

This project is released for personal and educational use.

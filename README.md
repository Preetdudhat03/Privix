# Privix — Offline App Lock 🛡️

[![Latest Release](https://img.shields.io/github/v/release/Preetdudhat03/Privix?color=007AFF&label=Latest%20Release)](https://github.com/Preetdudhat03/Privix/releases/tag/v2.0.0)
[![Build & Publish Release](https://github.com/Preetdudhat03/Privix/actions/workflows/release.yml/badge.svg)](https://github.com/Preetdudhat03/Privix/actions/workflows/release.yml)
[![Platform](https://img.shields.io/badge/Platform-Android%207.0%2B-brightgreen)](https://developer.android.com)
[![Flutter](https://img.shields.io/badge/Flutter-v3.27%2B-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT%20%2F%20Personal-orange)](LICENSE)

**Privix** is a high-performance, offline Android app locking application built with **Flutter** and **Kotlin**. It provides real-time, zero-latency protection for sensitive applications using biometric authentication (fingerprint/face unlock) or a PIN.

Designed with **One UI 7** aesthetics, Privix ensures your personal data, messaging apps, photos, and financial tools remain completely private without collecting any user telemetry or requiring internet access.

---

## 📥 Latest Release (v2.0.0)

🚀 **[Download Latest APK — Privix v2.0.0](https://github.com/Preetdudhat03/Privix/releases/tag/v2.0.0)**

### Release Highlights:
- ⚡ **Zero-Latency App Lock Protection (0ms Overlay)**: Instant AMOLED black screen curtain to prevent content preview leaks before authentication.
- 🔒 **1-Tap Sensitive App Locking**: Pre-configured preset to lock social media, financial, gallery, and messaging apps (*WhatsApp, Instagram, Photos, Paytm, Google Pay, Telegram*).
- 🚀 **Butter-Smooth Performance**: Native Kotlin icon scaling + Flutter LRU memory icon cache for stutter-free 60/120 FPS list scrolling.
- 🔑 **Enhanced Pin & Biometric Keypad**: Animated keypad indicators, haptic feedback, and error shake effects.

---

## ✨ Key Features

- ⚡ **Zero-Latency Protection (0ms Overlay)**
  Uses native Android `AccessibilityService` events to instantly cover locked applications with a solid AMOLED black curtain overlay, preventing any content preview window before authentication.

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

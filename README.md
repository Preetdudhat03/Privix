# Privix 🛡️

**Privix** is a high-performance, premium app locker for Android built with Flutter and Native Kotlin. It utilizes the Android Accessibility API and Biometric Prompt to provide a secure, zero-latency locking experience.

## ✨ Features

- ⚡ **Zero-Latency Locking**: An advanced "Gap-less" curtain strategy ensures that locked app interfaces are hidden instantly, with zero visible frames of the locked content.
- 🧬 **Biometric Integration**: Seamless use of system-level biometrics (Fingerprint, Face, Iris) and device credentials (PIN/Pattern).
- 🚀 **Performance Optimized**: Lazy loading of app icons and a high-efficiency native caching system ensure the UI remains smooth even with hundreds of installed apps.
- 🎨 **Premium UI/UX**: A dark-themed, glassmorphic design that feels native and professional.

## 🛠️ Architecture

Privix uses a hybrid architecture for maximum performance:

1.  **Flutter (UI Layer)**: Handles the app selection, settings, and general user interactions.
2.  **Kotlin (Engine Layer)**:
    -   `AppLockAccessibilityService`: Real-time detection of app transitions across the OS.
    -   `CurtainManager`: A low-level WindowManager overlay that manages the "Zero-Latency" curtain.
    -   `AuthActivity`: A dedicated activity for handling system authentication dialogs.

## 🚀 Key Optimizations

### 1. Zero-Latency Curtain
Unlike traditional app lockers that add an overlay *after* detecting an app launch, Privix maintains a pre-allocated curtain in the `WindowManager`. This curtain is toggled at the visibility level, bypassing the overhead of IPC calls during critical transitions.

### 2. Gap-less Auth Strategy
We've synchronized the curtain lifecycle with the `AuthActivity` state. The curtain remains opaque until the authentication system is fully covering the screen, eliminating the brief "flash" typical in other app lockers.

### 3. Native Icon Lazy Loading
App icons are fetched and encoded on-demand on the native side. This prevents the "Select Apps" screen from lagging while processing dozens of large binary icons simultaneously.

## 📝 Prerequisites

- Flutter SDK
- Android SDK 30+
- Accessibility Permission
- Draw Over Other Apps Permission

## ⚙️ Development

1.  Clone the repository.
2.  Run `flutter pub get`.
3.  Connect an Android device.
4.  Run `flutter run`.

---
*Privix - Precision. Privacy. Performance.*

# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# AndroidX Biometric Rules
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# Privix Native Classes and Services
-keep class com.privix.privix.** { *; }
-keepclassmembers class com.privix.privix.** { *; }
-keep class com.privix.privix.services.** { *; }
-keep class com.privix.privix.receiver.** { *; }

# Preserve Coroutines & Reflection
-keepattributes *Annotation*,InnerClasses,Signature,EnclosingMethod,SourceFile,LineNumberTable

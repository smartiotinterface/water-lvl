# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep model classes
-keep class com.smartiot.smart_iot_interface.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# flutter_blue_plus — BLE library
-keep class com.boskokg.flutter_blue_plus.** { *; }
-dontwarn com.boskokg.flutter_blue_plus.**

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# Play Core — Flutter deferred components (R8 fix)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

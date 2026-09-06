# StreamersTip — draft R8 keep rules
# Do NOT enable isMinifyEnabled until docs/R8_COMPATIBILITY_AUDIT.md smoke matrix passes.

# ---- Flutter / embedding ----
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ---- App native PlatformView + Media3 channel ----
-keep class com.streamerstip.streamersTipApp.** { *; }
-keepclassmembers class com.streamerstip.streamersTipApp.** {
  <init>(...);
  *;
}

# Media3 / ExoPlayer (align app + video_player versions before minify)
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# ---- Firebase / Play Services ----
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes SourceFile,LineNumberTable
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.crashlytics.** { *; }

# ---- Google Sign-In ----
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ---- Play Billing ----
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# ---- flutter_secure_storage / crypto ----
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# ---- flutter_local_notifications + Gson ----
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# ---- ML Kit (mobile_scanner) ----
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }

# ---- Biometrics ----
-keep class androidx.biometric.** { *; }

# ---- Parcelable ----
-keepclassmembers class * implements android.os.Parcelable {
  public static final ** CREATOR;
}

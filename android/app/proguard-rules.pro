# Flutter Base Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.admob.** { *; }

# Firebase & Firestore
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-keepattributes Signature,Exceptions,*Annotation*

# Just Audio (ExoPlayer)
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.google.android.exoplayer2.** { *; }

# AdMob / Google Mobile Ads
-keep public class com.google.android.gms.ads.** {
   public *;
}

# Hive (Storage)
-keep class io.hive.** { *; }
-dontwarn io.hive.**

# ML Kit (Text Recognition)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Missing classes from R8 (auto-generated)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# Prevent shrinking of resource names used by plugins
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Fix: DebugProbesKt.bin Present — Debug Artifact in Release Build
-dontwarn kotlin.coroutines.jvm.internal.DebugProbesKt
-keep class kotlin.coroutines.jvm.internal.DebugProbesKt { *; }
# To fully exclude the file if it's being packaged as a resource:
# This usually handled by packagingOptions in build.gradle.kts

# Aggressive size optimization rules
-optimizationpasses 5
-dontpreverify
-allowaccessmodification
-mergeinterfacesaggressively
-repackageclasses ''

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** d(...);
    public static *** e(...);
}

# Remove debug code
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    public static *** checkParameterIsNotNull(...);
    public static *** checkNotNull(...);
    public static *** checkNotNullParameter(...);
    public static *** checkExpressionValueIsNotNull(...);
}

# Optimize Kotlin/Java standard library
-dontwarn java.lang.invoke.*
-dontwarn java.lang.reflect.*
-dontwarn sun.misc.*

# Remove unused classes from common libraries
-dontwarn org.apache.commons.**
-dontwarn org.apache.http.**
-dontwarn org.json.**

# Keep only essential Firebase classes
-keep class com.google.firebase.FirebaseApp { *; }
-keep class com.google.firebase.auth.FirebaseAuth { *; }
-keep class com.google.firebase.firestore.FirebaseFirestore { *; }
-keep class com.google.firebase.messaging.FirebaseMessaging { *; }
-keep class com.google.firebase.appcheck.FirebaseAppCheck { *; }
-keep class com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProvider { *; }
-keep class com.google.firebase.appcheck.debug.DebugAppCheckProvider { *; }

# Remove unused Google Play Services classes
-keep class com.google.android.gms.common.GooglePlayServicesNotAvailableException { *; }
-keep class com.google.android.gms.common.GooglePlayServicesRepairableException { *; }

# Optimize image loading libraries
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# Remove unused annotation classes
-keepattributes *Annotation*
-keepclassmembers class * {
    @androidx.annotation.Keep <methods>;
}

# ──────────────────────────────────────────────────────────────
# ProGuard / R8 rules for Moko (com.moko.app)
# ──────────────────────────────────────────────────────────────

# ── Video Player, Chewie & BetterPlayer (ExoPlayer & Media3) ───
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class com.brianegan.brianegan.** { *; }
-keep class com.jhomlala.better_player.** { *; }
-keep class androidx.media.** { *; }
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**
-dontwarn androidx.media.**
-dontwarn com.jhomlala.better_player.**

# ── Keep JNI / Native methods for video rendering ─────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── OkHttp3 / Okio / Network ──────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class * extends okhttp3.Response { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ── Android WebKit & WebView Flutter ──────────────────────────
-keepclassmembers class * extends android.webkit.WebView {
    public *;
}
-keep class android.webkit.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }

# ── Wakelock ──────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.wakelock.** { *; }

# ── AndroidX WorkManager (Room-backed) ────────────────────────
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>(...);
}

# ── AndroidX Startup ──────────────────────────────────────────
-keep class androidx.startup.** { *; }

# ── Google Mobile Ads (AdMob) ─────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# ── Firebase ──────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }

# ── Flutter Engine & Plugins ──────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ── General safety & warnings suppression ─────────────────────
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**

# ── Google Play Core ──────────────────────────────────────────
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

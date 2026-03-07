# Flutter apps are mostly reflected; keep rules minimal and additive.
# Add explicit keep rules here only if release build reports missing classes.

-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep MethodChannel entry points used from Dart.
-keepclassmembers class me.cubevlmu.qbox.MainActivity {
    public void configureFlutterEngine(...);
}

# Flutter embedding references Play Core classes for deferred components.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
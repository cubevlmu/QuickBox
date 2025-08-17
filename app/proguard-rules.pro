-keep class me.cubevlmu.quickbox.MainActivity { *; }

-keep class androidx.recyclerview.** { *; }
-keep class androidx.appcompat.** { *; }
-keep class android.support.v7.widget.** { *; }

-dontwarn android.support.**
-dontwarn androidx.**

-dontwarn java.lang.invoke.*

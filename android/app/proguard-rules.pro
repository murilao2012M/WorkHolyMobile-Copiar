# Flutter e Firebase fornecem suas próprias regras de consumidor.
# Remove logs de depuração do APK release.
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
}
-dontwarn com.google.android.play.core.**

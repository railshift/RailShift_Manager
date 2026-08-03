# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Workmanager
-keep class dev.fluttercommunity.workmanager.** { *; }

# Gson & Generics (Fixes "Missing type parameter" crash)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keep class com.google.gson.** { *; }

# Prevent R8 from obfuscating notification models
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

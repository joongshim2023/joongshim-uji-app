# flutter_local_notifications: Gson TypeToken 제네릭 시그니처 보존
# ProGuard/R8 코드 축소 시 Gson이 generic type 정보를 잃는 문제 방지
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Gson 클래스 보존
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Gson @SerializedName 어노테이션 필드 보존
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# flutter_local_notifications 알림 관련 클래스 보존
-keep class com.dexterous.** { *; }

# Firebase 관련
-keep class com.google.firebase.** { *; }

# 일반적인 Java 제네릭 보존
-keepattributes EnclosingMethod

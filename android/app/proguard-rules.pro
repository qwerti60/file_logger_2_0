 -keep class io.flutter.plugin.** { *; }
 -keep class io.flutter.util.** { *; }
 -keep class io.flutter.view.** { *; }
 -keep class io.flutter.** { *; }
 -keep class io.flutter.plugins.** { *; }
 -keep class com.google.firebase.** { *; }
 -dontwarn io.flutter.embedding.**
 -ignorewarnings
# Сохранение общей сигнатуры и характеристик классов
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# Сохранение конструкторов и полей TypeToken
-keep class com.google.gson.reflect.TypeToken {
    <init>(...);
    <fields>;
}

# Глобальная защита внутренних механизмов Gson
-keep class com.google.gson.internal.** { *; }
-keep class com.google.gson.**
-keep interface com.google.gson.**

# Объекты, создаваемые разработчиком
-keep class com.example.file_logger20.** { *; }

# Отключение предупреждений
-dontwarn com.google.gson.internal.*

# Оптимизация работы с внутренними структурами Gson
-assumenosideeffects class com.google.gson.internal.$Gson$Preconditions {
    boolean checkNotNull(*);
    static *** checkNotNull(***, ***);
}
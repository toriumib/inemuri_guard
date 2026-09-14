# flutter_local_notifications は予約通知を Gson の TypeToken で読み書きする。
# R8 が generic の Signature を落とすと、release ビルドだけ起動時に
# "Missing type parameter." で main() が死んで画面が白いまま止まる
# （2026-09-14 実機で確認。debug ビルドでは再現しない）。
-keepattributes Signature
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type

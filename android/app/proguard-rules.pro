# 仅在 isMinifyEnabled = true 时生效（当前 release 已显式关闭 R8）。
# 若将来开启混淆优化包体积，务必保留以下规则：
# mobile_scanner (MLKit Barcode + CameraX) 依赖反射/JNI 调用的类不可裁剪，
# 否则扫码功能仅在 release 失效（debug 不运行 R8，无法复现）。
-keep class com.google.mlkit.** { *; }
-keep class com.google.photos.vision.barhopper.** { *; }
-keep class com.google.barhopper.deeplearning.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn com.google.mlkit.**

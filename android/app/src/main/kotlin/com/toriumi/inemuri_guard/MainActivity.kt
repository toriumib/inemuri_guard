package com.toriumi.inemuri_guard

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 背面でも瞼を見続けるための自前実装。詳しくは EyeService の説明を。
        EyePlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}

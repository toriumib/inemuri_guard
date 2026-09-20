package com.toriumi.inemuri_guard

import android.os.Build
import android.os.Bundle
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // アラームの全画面インテントで起こされたとき、ロック画面の上に出て
        // 画面も点ける。目覚まし時計と同じ振る舞い。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        // 「車に乗りましたか？」の通知チャンネル。受信機がプロセスの無い状態で
        // 出すことがあるので、アプリを開いたときに先に作っておく。
        CarTriggerReceiver.ensureChannel(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        flutterEngine?.let {
            MethodChannel(it.dartExecutor.binaryMessenger, "inemuri/readiness")
                .invokeMethod("startRequested", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 背面でも瞼を見続けるための自前実装。詳しくは EyeService の説明を。
        EyePlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        ReadinessPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}

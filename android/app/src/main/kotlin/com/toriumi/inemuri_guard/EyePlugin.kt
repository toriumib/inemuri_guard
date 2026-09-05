package com.toriumi.inemuri_guard

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * [EyeService] と Dart のあいだの配線。
 *
 * - MethodChannel `inemuri/eye` … 開始・停止・稼働確認
 * - EventChannel  `inemuri/eye_events` … 1フレームごとの目の開き具合
 *
 * 判定（しきい値・PERCLOS）は Dart 側に置いたままにしている。
 * 同じ判断を native と Dart の二か所に書くと、必ず片方だけ直して食い違うため。
 */
class EyePlugin(private val context: Context, messenger: BinaryMessenger) {

    private val method = MethodChannel(messenger, "inemuri/eye")
    private val events = EventChannel(messenger, "inemuri/eye_events")
    private val main = Handler(Looper.getMainLooper())

    init {
        method.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val text = call.argument<String>("text") ?: "動作中"
                    val i = Intent(context, EyeService::class.java).apply {
                        action = EyeService.ACTION_START
                        putExtra(EyeService.EXTRA_TEXT, text)
                        putExtra(
                            EyeService.EXTRA_LENS,
                            if (call.argument<Boolean>("back") == true) "back" else "front"
                        )
                    }
                    // camera 型の前景サービスは、アプリが前面にいるこの瞬間しか
                    // 開始できない（Android 14+）。Dart 側も開始操作の直後に呼ぶ。
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(i)
                    } else {
                        context.startService(i)
                    }
                    result.success(true)
                }
                "acquire", "release" -> {
                    val act = if (call.method == "acquire")
                        EyeService.ACTION_ACQUIRE else EyeService.ACTION_RELEASE
                    // すでに前景サービスとして動いているので startService でよい。
                    // ここで startForegroundService を使うと「背面からの開始」と
                    // みなされて camera 型が SecurityException で落ちる。
                    context.startService(
                        Intent(context, EyeService::class.java).apply {
                            action = act
                            // 取得の直前にレンズが切り替わっていても拾えるよう、
                            // ここでも運ぶ。
                            putExtra(
                                EyeService.EXTRA_LENS,
                                if (call.argument<Boolean>("back") == true) "back" else "front"
                            )
                        }
                    )
                    result.success(true)
                }
                "stop" -> {
                    context.stopService(Intent(context, EyeService::class.java))
                    result.success(true)
                }
                "isRunning" -> result.success(EyeService.isRunning)

                // ── 通知で起こす（Slack/Teams/メール） ──
                "nudgeIsGranted" -> result.success(NudgeListener.isEnabled(context))
                "nudgeOpenSettings" -> {
                    NudgeListener.openSettings(context); result.success(true)
                }
                "nudgeSetEnabled" -> {
                    NudgeListener.enabled = call.argument<Boolean>("on") ?: false
                    result.success(true)
                }
                "nudgeApps" -> result.success(NudgeListener.WATCHED.values.toList())
                "nudgeSetFilter" -> {
                    NudgeListener.senderFilter =
                        call.argument<List<String>>("filter") ?: emptyList()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 通知で起こす側の流し口。目の値とは別の口にしてある。
        EventChannel(messenger, "inemuri/nudge_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    NudgeListener.sink = { label -> main.post { sink?.success(label) } }
                }

                override fun onCancel(args: Any?) {
                    NudgeListener.sink = null
                }
            }
        )

        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                // 見張れなくなったことも同じ口から流す。黙って止まるのが
                // 一番まずい壊れ方なので、失敗こそ確実に届ける。
                EyeService.errorSink = { message ->
                    main.post { sink?.success(mapOf("error" to message)) }
                }
                EyeService.sink = { faceFound, left, right ->
                    // EventSink は必ずメインスレッドから叩く。
                    // カメラのハンドラスレッドから直接呼ぶと落ちる。
                    main.post {
                        sink?.success(
                            mapOf(
                                "face" to faceFound,
                                "left" to left,
                                "right" to right
                            )
                        )
                    }
                }
            }

            override fun onCancel(args: Any?) {
                EyeService.sink = null
                EyeService.errorSink = null
            }
        })
    }
}

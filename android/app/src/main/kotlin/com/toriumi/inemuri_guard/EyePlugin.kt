package com.toriumi.inemuri_guard

import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.DetectedActivity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * [EyeService] と Dart のあいだの配線。
 *
 * - MethodChannel `inemuri/eye` … 開始・停止・稼働確認
 * - EventChannel  `inemuri/eye_events` … 1フレームごとの目の開き具合
 * - MethodChannel `inemuri/torch` … 外側のライト（フラッシュLED）の点滅
 * - MethodChannel `inemuri/drive` ＋ EventChannel `inemuri/drive_events` …
 *   乗り物に乗り続けているか（休憩の勧めに使う）
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
                // 電話アプリは端末ごとに違うので同じ名前を複数のパッケージに
                // 割り当ててある。並べて見せるときは重複を落とす。
                "nudgeApps" -> result.success(
                    NudgeListener.WATCHED.values.distinct()
                )
                "nudgeSetFilter" -> {
                    NudgeListener.senderFilter =
                        call.argument<List<String>>("filter") ?: emptyList()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── 外側のライト（フラッシュLED） ──
        MethodChannel(messenger, "inemuri/torch").setMethodCallHandler { call, result ->
            when (call.method) {
                "has" -> result.success(torchCameraId() != null)
                "on", "off" -> result.success(setTorch(call.method == "on"))
                else -> result.notImplemented()
            }
        }

        // ── 車に乗り続けていたら休憩を勧める ──
        val drive = MethodChannel(messenger, "inemuri/drive")
        drive.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    // 実行時権限（身体活動認識）が要るのは Android 10 から。
                    // それより前は Play services 側の宣言だけで動く。
                    // 権限そのものは Dart 側（permission_handler）で取って
                    // から来る。ここは保険。
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                        ContextCompat.checkSelfPermission(
                            context, android.Manifest.permission.ACTIVITY_RECOGNITION
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    requestDriveUpdates()
                    result.success(true)
                }
                "stop" -> {
                    removeDriveUpdates()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "inemuri/drive_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    DriveReceiver.sink = { inVehicle ->
                        main.post { sink?.success(inVehicle) }
                    }
                }

                override fun onCancel(args: Any?) {
                    DriveReceiver.sink = null
                }
            }
        )

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

    /** ライトを持っているカメラの id。背面（外側）を優先する。 */
    private fun torchCameraId(): String? {
        val cm = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        var anyFlash: String? = null
        for (id in cm.cameraIdList) {
            try {
                val ch = cm.getCameraCharacteristics(id)
                if (ch.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) != true) continue
                // 外側（背面）のライトのほうが部屋へ光が広がるので優先。
                if (ch.get(CameraCharacteristics.LENS_FACING) ==
                    CameraCharacteristics.LENS_FACING_BACK
                ) return id
                anyFlash = anyFlash ?: id
            } catch (_: Exception) {}
        }
        return anyFlash
    }

    /**
     * ライトを点す/消す。setTorchMode はカメラを開かずに済むが、
     * 「そのカメラを誰かが開いている間」は失敗する。失敗したとき、
     * 開いているのが自分の常駐サービス（背面で見張っている間）なら
     * セッション経由で光らせてもらう。
     */
    private fun setTorch(on: Boolean): Boolean {
        val cm = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val id = torchCameraId() ?: return false
        return try {
            cm.setTorchMode(id, on)
            true
        } catch (e: Exception) {
            Log.d("EyePlugin", "setTorchMode できなかった（$e）。セッション経由を試す")
            context.startService(
                Intent(context, EyeService::class.java).apply {
                    action = EyeService.ACTION_TORCH
                    putExtra(EyeService.EXTRA_TORCH_ON, on)
                }
            )
            // 適用されたかは同期して分からない。鳴らし損ねよりは鳴りすぎがまし。
            true
        }
    }

    /** 乗り物への乗り降りの通知を OS に頼む。低消費電力の API。 */
    private var drivePi: PendingIntent? = null
    private fun requestDriveUpdates() {
        val request = ActivityTransitionRequest(
            listOf(
                ActivityTransition.Builder()
                    .setActivityType(DetectedActivity.IN_VEHICLE)
                    .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                    .build(),
                ActivityTransition.Builder()
                    .setActivityType(DetectedActivity.IN_VEHICLE)
                    .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
                    .build()
            )
        )
        val pi = PendingIntent.getBroadcast(
            context, 0,
            Intent(context, DriveReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        drivePi = pi
        ActivityRecognition.getClient(context)
            .requestActivityTransitionUpdates(request, pi)
            .addOnFailureListener { Log.w("EyePlugin", "車検知の登録に失敗: $it") }
    }
    private fun removeDriveUpdates() {
        drivePi?.let {
            ActivityRecognition.getClient(context)
                .removeActivityTransitionUpdates(it)
                .addOnFailureListener { Log.w("EyePlugin", "車検知の解除に失敗: $it") }
        }
        drivePi = null
    }
}

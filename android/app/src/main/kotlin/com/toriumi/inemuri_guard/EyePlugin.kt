package com.toriumi.inemuri_guard

import android.Manifest
import android.app.PendingIntent
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.DetectedActivity
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.view.KeyEvent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * [EyeService] と Dart のあいだの配線。
 *
 * - MethodChannel `inemuri/eye` … 開始・停止・稼働確認
 * - EventChannel  `inemuri/eye_events` … 1フレームごとの目の開き具合
 * - MethodChannel `inemuri/torch` … 外側のライト（フラッシュLED）の点滅
 * - MethodChannel `inemuri/alarm_keys` ＋ EventChannel `inemuri/alarm_key_events` …
 *   アラーム中だけ、音量キー・ホーム／履歴キー・メディアキー（ハンドルのボタン・
 *   イヤホンのボタン）を「止めたい」の合図として受ける
 *
 * 判定（しきい値・PERCLOS）は Dart 側に置いたままにしている。
 * 同じ判断を native と Dart の二か所に書くと、必ず片方だけ直して食い違うため。
 */
class EyePlugin(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        /** SDK に定数が無い（AudioManager の隠し定数）。音量が変わるたびに OS が送る。 */
        private const val VOLUME_CHANGED = "android.media.VOLUME_CHANGED_ACTION"
    }


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

        // ── 車に乗ったら始める ──
        // Bluetooth の機器一覧（車を選ぶ）、運転検知の登録、乗車・降車の知らせ。
        MethodChannel(messenger, "inemuri/car").setMethodCallHandler { call, result ->
            when (call.method) {
                "bondedDevices" -> result.success(bondedDevices())
                "startDrive" -> result.success(requestDriveUpdates())
                "stopDrive" -> { removeDriveUpdates(); result.success(true) }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "inemuri/car_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    CarTriggerReceiver.sink = { ev -> main.post { sink?.success(ev) } }
                }

                override fun onCancel(args: Any?) {
                    CarTriggerReceiver.sink = null
                }
            }
        )

        // ── 外からアラームを止める（音量キー・ホーム／履歴キー） ──
        // 別のアプリを前に出しているとき、アプリに戻らずに止めたい、への答え。
        // 押せる＝起きているので、どのキーでも止めてよい。電源キーは画面が
        // 勝手に消えたときと区別できない（車で裏向きに置いて画面が消えただけで
        // アラームが止まる）ので、ここでは受けない。
        MethodChannel(messenger, "inemuri/alarm_keys").setMethodCallHandler { call, result ->
            when (call.method) {
                "watch" -> { watchKeys(); result.success(true) }
                "unwatch" -> { unwatchKeys(); result.success(true) }
                // 音声認識の開始直後は、システムが音量を触る（ミュート等）ことがあり、
                // それを音量キーと誤認して止めてしまった（実機 20:06:57）。少しの間だけ聞かない。
                "ignoreVolume" -> {
                    val ms = (call.argument<Number>("ms") ?: 1500).toLong()
                    ignoreVolumeUntil = System.currentTimeMillis() + ms
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "inemuri/alarm_key_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    keysSink = sink
                }

                override fun onCancel(args: Any?) {
                    keysSink = null
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
                EyeService.sink = { faceFound, left, right, pose ->
                    // EventSink は必ずメインスレッドから叩く。
                    // カメラのハンドラスレッドから直接呼ぶと落ちる。
                    main.post {
                        sink?.success(
                            mapOf(
                                "face" to faceFound,
                                "left" to left,
                                "right" to right,
                                "pitch" to pose?.get(0)?.toDouble(),
                                "yaw" to pose?.get(1)?.toDouble(),
                                "roll" to pose?.get(2)?.toDouble()
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

    /** ペアリング済みの Bluetooth 機器。車を選ばせるための一覧。 */
    private fun bondedDevices(): List<Map<String, String>> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) !=
            PackageManager.PERMISSION_GRANTED
        ) return emptyList()
        val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
            ?: return emptyList()
        return try {
            adapter.bondedDevices.map { d ->
                mapOf("name" to (d.name ?: d.address), "address" to d.address)
            }.sortedBy { it["name"] }
        } catch (e: SecurityException) {
            emptyList()
        }
    }

    /** 乗り物への乗り降りの通知を OS に頼む。低消費電力の API。権限は Dart 側で取ってから来る。 */
    private var drivePi: PendingIntent? = null
    private fun requestDriveUpdates(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACTIVITY_RECOGNITION) !=
            PackageManager.PERMISSION_GRANTED
        ) return false
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
            context, 3,
            Intent(context, CarTriggerReceiver::class.java).setAction("com.stop.sleeping.DRIVE"),
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
        )
        drivePi = pi
        ActivityRecognition.getClient(context)
            .requestActivityTransitionUpdates(request, pi)
            .addOnFailureListener { Log.w("EyePlugin", "運転検知の登録に失敗: $it") }
        return true
    }

    private fun removeDriveUpdates() {
        drivePi?.let {
            ActivityRecognition.getClient(context)
                .removeActivityTransitionUpdates(it)
                .addOnFailureListener { Log.w("EyePlugin", "運転検知の解除に失敗: $it") }
        }
        drivePi = null
    }

    private var keysSink: EventChannel.EventSink? = null
    private var keysReceiver: BroadcastReceiver? = null
    @Volatile private var ignoreVolumeUntil = 0L

    /** アラームが鳴っている間だけ、音量の変化とホーム／履歴キーを聞く。 */
    private fun watchKeys() {
        if (keysReceiver != null) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, i: Intent) {
                // 何が来たかをログに残す（実機で「勝手に止まる」の原因を追うため）。
                Log.d("EyePlugin", "alarm key broadcast: ${i.action} " +
                    "stream=${i.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)} " +
                    "prev=${i.getIntExtra("android.media.EXTRA_PREV_VOLUME_STREAM_VALUE", -1)} " +
                    "now=${i.getIntExtra("android.media.EXTRA_VOLUME_STREAM_VALUE", -1)} " +
                    "reason=${i.getStringExtra("reason")}")
                val why = when (i.action) {
                    VOLUME_CHANGED -> {
                        // 本人がキーを押した変化だけ。値が変わっていない放送、
                        // 通知・システム音など本人が触らないストリーム、
                        // 音声認識の開始直後の変化は捨てる。
                        val stream = i.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)
                        val prev = i.getIntExtra("android.media.EXTRA_PREV_VOLUME_STREAM_VALUE", -1)
                        val now = i.getIntExtra("android.media.EXTRA_VOLUME_STREAM_VALUE", -1)
                        val userStream = stream == 2 || stream == 3 || stream == 4  // RING, MUSIC, ALARM
                        if (prev == now || !userStream || System.currentTimeMillis() < ignoreVolumeUntil) return
                        "volume"
                    }
                    Intent.ACTION_CLOSE_SYSTEM_DIALOGS -> {
                        // 通知シェードの開閉や画面消灯でも飛ぶ放送なので、
                        // ホームと履歴のキーだけを本人の操作として受ける。
                        val reason = i.getStringExtra("reason")
                        if (reason == "homekey" || reason == "recentapps") "home" else return
                    }
                    else -> return
                }
                main.post { keysSink?.success(why) }
            }
        }
        val f = IntentFilter().apply {
            addAction(VOLUME_CHANGED)
            addAction(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
        }
        // どちらも OS だけが送れる保護付きの放送。Android 14 以降は
        // 動的登録に export の明示が要る。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(r, f, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(r, f)
        }
        keysReceiver = r
        startMediaButtons()
    }

    private fun unwatchKeys() {
        keysReceiver?.let {
            try { context.unregisterReceiver(it) } catch (_: Exception) {}
        }
        keysReceiver = null
        stopMediaButtons()
    }

    /**
     * 運転中に届く物理ボタンは、ハンドルの再生／一時停止（Bluetooth の AVRCP）と
     * イヤホンのボタン。どちらも OS は「いま鳴らしている MediaSession」へ届けるので、
     * 鳴っている間だけ自分のセッションを再生中にして、押されたら「止めたい」にする。
     */
    private var media: MediaSession? = null
    private fun startMediaButtons() {
        if (media != null) return
        try {
            val ms = MediaSession(context, "inemuri-alarm")
            val fire = { Log.d("EyePlugin", "media button"); main.post { keysSink?.success("media") } }
            ms.setCallback(object : MediaSession.Callback() {
                override fun onMediaButtonEvent(mediaButtonIntent: Intent): Boolean {
                    val ev = mediaButtonIntent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)
                        ?: return super.onMediaButtonEvent(mediaButtonIntent)
                    if (ev.action == KeyEvent.ACTION_DOWN) fire()
                    return true
                }
                override fun onPlay() { fire() }
                override fun onPause() { fire() }
                override fun onStop() { fire() }
                override fun onSkipToNext() { fire() }
                override fun onSkipToPrevious() { fire() }
            })
            ms.setPlaybackState(
                PlaybackState.Builder()
                    .setActions(
                        PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or
                            PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_STOP or
                            PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS
                    )
                    .setState(PlaybackState.STATE_PLAYING, 0L, 1f)
                    .build()
            )
            ms.isActive = true
            media = ms
        } catch (e: Exception) {
            Log.w("EyePlugin", "MediaSession を作れなかった", e)
        }
    }

    private fun stopMediaButtons() {
        media?.let {
            try { it.isActive = false; it.release() } catch (_: Exception) {}
        }
        media = null
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
            // 自分の常駐サービスが背面カメラを持っている間はここに来る。
            // Service を startService で起こし直すと、背面にいるときに
            // 「バックグラウンドからの起動」で蹴られるので、動いている本体を直接呼ぶ。
            Log.d("EyePlugin", "setTorchMode できなかった（$e）。セッション経由を試す")
            EyeService.instance?.applyTorch(on) ?: false
        }
    }
}

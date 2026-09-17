package com.toriumi.inemuri_guard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.ImageReader
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions

/**
 * 背面でも瞼を見続けるための常駐サービス。
 *
 * ## なぜ自前で書いたか
 *
 * Flutter の camera プラグインは CameraX を **Activity** のライフサイクルに
 * 縛る。そのためホームに戻した瞬間に CameraX が unbind し、Android が
 * カメラを回収する。常駐サービスを立てても防げない（実機の
 * `dumpsys media.camera` に DISCONNECT が出るのを確認済み）。
 *
 * カメラを **Service** が持てば、この縛りから外れる。ここでは Camera2 を
 * 直接開き、ML Kit も native 側で回して、瞼の開き具合だけを Dart へ送る。
 * しきい値や PERCLOS の判定は Dart 側に一本化したままにしてある
 * （二か所に同じ判断を置くと、必ず片方だけ直して食い違う）。
 *
 * ## 注意
 *
 * - `camera` 型のフォアグラウンドサービスは **アプリが前面にいる間しか
 *   開始できない**（Android 14+）。開始は必ずユーザー操作の直後に行う。
 * - プレビューは持たない。画面に映すのは前面にいるときだけでよく、
 *   ここで Surface を増やすと消費電力と複雑さが上がる。
 */
class EyeService : Service() {

    companion object {
        private const val TAG = "EyeService"
        const val ACTION_START = "com.toriumi.inemuri_guard.START_EYE"
        /** 背面に入る直前にカメラを受け取る。 */
        const val ACTION_ACQUIRE = "com.toriumi.inemuri_guard.ACQUIRE_EYE"
        /** 前面に戻るのでカメラを手放す。Flutter 側がプレビューに使う。 */
        const val ACTION_RELEASE = "com.toriumi.inemuri_guard.RELEASE_EYE"
        const val ACTION_STOP = "com.toriumi.inemuri_guard.STOP_EYE"
        const val EXTRA_TEXT = "text"
        /** "back" なら背面カメラ、それ以外は前面。 */
        const val EXTRA_LENS = "lens"

        private const val CHANNEL_ID = "eye_watch"
        private const val NOTIFICATION_ID = 4711

        /**
         * 解析の間隔。瞼の開閉は秒単位の現象なので、毎フレーム回す必要はない。
         * ACCURATE の解析は SHARP A105SH で 150〜255ms かかった（実測）。
         * 160ms だと解析が間に合わず busy でフレームを捨てるだけなので、
         * 最初から 250ms（4fps）にしておく。PERCLOS には十分で、発熱も減る。
         */
        private const val MIN_FRAME_GAP_MS = 250L

        /** Dart 側へ結果を渡す口。EyePlugin が差し込む。 */
        @Volatile
        var sink: ((faceFound: Boolean, left: Double?, right: Double?, pose: FloatArray?) -> Unit)? = null

        /**
         * 背面での見張りが**始められなかった/途切れた**ことを Dart へ伝える口。
         *
         * これが無いと、カメラを開けなかったときにサービスだけ静かに死んで、
         * 画面には「検知開始中」が出たままになる。見張っていないのに
         * 見張っているように見えるのが、この道具で一番あってはならない壊れ方。
         */
        @Volatile
        var errorSink: ((message: String) -> Unit)? = null

        /** 前面(false)か背面(true)か。Dart から渡される。 */
        @Volatile
        var useBackLens: Boolean = false

        @Volatile
        var isRunning: Boolean = false
            private set

        /** 動いている Service 本体。EyePlugin がライトの点滅で直接呼ぶ。 */
        @Volatile
        var instance: EyeService? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    private var cameraDevice: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var reader: ImageReader? = null
    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    private var detector: FaceDetector? = null
    private var busy = false
    private var lastFrameAt = 0L

    /**
     * カメラを開き始めてから、撮影が始まる（または失敗する）までの間。
     *
     * Flutter は背面へ回るとき hidden と paused を続けて送るので、引き継ぎの
     * 要求が二度届く。[isRunning] は撮影が始まって初めて true になるため、
     * それだけを見ていると開いている最中にもう一度開いてしまい、
     * 自分自身とカメラを奪い合って ERROR で落ちる（実機で確認）。
     */
    private var opening = false

    /** ML Kit に渡す回転角。端末とレンズで違うので決め打ちにしない。 */
    private var sensorOrientation = 270

    /** この端末が受け付ける AF モード。固定焦点なら OFF しか入っていない。 */
    private var afMode: Int? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // レンズの指定は毎回運ばれてくる。取得の直前に切り替わっていても
        // 拾えるよう、action を見る前に反映する。
        intent?.getStringExtra(EXTRA_LENS)?.let { useBackLens = it == "back" }
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_ACQUIRE -> {
                // ここで初めてカメラを開く。
                // ⚠️ サービス自体は ACTION_START のとき＝アプリが前面にいるうちに
                //    前景化してある。Android 14 は camera 型の前景サービスを
                //    「背面から開始」できないので、背面に入ってから
                //    startForegroundService すると SecurityException で落ちる
                //    （実機のログで確認済み）。開始と取得を分けているのはこのため。
                startForegroundWithType("動作中")
                if (!isRunning && !opening) openCamera()
            }
            ACTION_RELEASE -> {
                closeCamera()
                startForegroundWithType("画面を開いています")
            }
            else -> {
                // 前面にいるうちに前景化だけしておく。カメラはまだ Flutter 側が
                // プレビューに使っているので触らない。
                val text = intent?.getStringExtra(EXTRA_TEXT) ?: "動作中"
                startForegroundWithType(text)
            }
        }
        return START_STICKY
    }

    private fun startForegroundWithType(text: String) {
        createChannel()
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE
        )
        // 中身を明かさない文面にしてある。ロック画面に「居眠りを検知中」と
        // 出ること自体が、周りへの告知になってしまうため。
        val n: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("居眠りガード")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setContentIntent(open)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14 以降は型の申告が必須。camera を宣言しないと
            // SecurityException で落ちる。
            // camera と microphone の両方を申告する。瞼検知(カメラ)と
            // 寝息検知(マイク)のどちらを使っていても背面で止まらないように。
            // ⚠️ 型は「開始時」に確定する。あとから足せないので、片方しか
            //    使わない場合でも両方申告しておく。
            startForeground(
                NOTIFICATION_ID, n,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }

    private fun createChannel() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            CHANNEL_ID, "見張り中", NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "検知を続けているあいだ表示されます。"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        nm.createNotificationChannel(ch)
    }

    private fun openCamera() {
        opening = true
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            failed("カメラの許可がありません")
            return
        }

        detector = FaceDetection.getClient(
            FaceDetectorOptions.Builder()
                // 目の開き具合は classification でしか取れない。
                .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
                // 眼鏡・マスクで顔の一部が隠れても拾えるよう ACCURATE にした。
                // FAST の2〜3倍遅いが、瞼の開閉は秒単位なので 6fps あれば足りる。
                // 解析時間が MIN_FRAME_GAP_MS を超えるなら間隔のほうを広げる。
                // Dart 側（drowsiness_detector.dart）と同じ設定にしてある。
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
                .enableTracking()
                .build()
        )

        thread = HandlerThread("eye-cam").also { it.start() }
        handler = Handler(thread!!.looper)

        val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        // 机の上なら前面、車のスタンドで運転席へ向けるなら背面、と本人が選ぶ。
        val wantFacing = if (useBackLens) CameraCharacteristics.LENS_FACING_BACK
            else CameraCharacteristics.LENS_FACING_FRONT
        val frontId = cm.cameraIdList.firstOrNull {
            cm.getCameraCharacteristics(it)
                .get(CameraCharacteristics.LENS_FACING) == wantFacing
        } ?: cm.cameraIdList.firstOrNull()

        if (frontId == null) {
            failed("使えるカメラが見つかりません")
            return
        }

        // 解析にしか使わないので小さくてよい。消費電力と発熱に直結する。
        reader = ImageReader.newInstance(640, 480, ImageFormat.YUV_420_888, 2).apply {
            setOnImageAvailableListener({ r -> onFrame(r) }, handler)
        }

        // 向きも AF も端末とレンズごとに違う。開ける前に聞いておく。
        sensorOrientation = try {
            cm.getCameraCharacteristics(frontId)
                .get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 270
        } catch (_: Exception) { 270 }
        afMode = pickAfMode(cm, frontId)
        Log.d(TAG, "カメラを開く id=$frontId 向き=$sensorOrientation AF=$afMode")

        try {
            cm.openCamera(frontId, object : CameraDevice.StateCallback() {
                override fun onOpened(device: CameraDevice) {
                    cameraDevice = device
                    startSession(device)
                }

                override fun onDisconnected(device: CameraDevice) {
                    device.close(); cameraDevice = null
                    failed("カメラが他のアプリに使われました")
                }

                override fun onError(device: CameraDevice, error: Int) {
                    device.close(); cameraDevice = null
                    failed("カメラのエラー（$error）")
                }
            }, handler)
        } catch (e: SecurityException) {
            Log.e(TAG, "カメラを開けない", e)
            failed("カメラを開けませんでした")
        }
    }

    /**
     * 見張れなくなったことを、隠さずに Dart へ伝えてから止まる。
     * 黙って [stopSelf] すると「検知開始中」の表示だけが残る。
     */
    private fun failed(message: String) {
        opening = false
        Log.w(TAG, "見張りを続けられない: $message")
        errorSink?.invoke(message)
        stopSelf()
    }

    /**
     * この端末のフロントカメラが受け付ける AF モードを選ぶ。
     *
     * 固定焦点のカメラは `CONTROL_AF_AVAILABLE_MODES` が `[OFF]` しか返さない。
     * そこへ CONTINUOUS_PICTURE を投げると HAL が
     * `Function not implemented (-38)` で撮影要求ごと蹴り、
     * 背面の見張りが丸ごと死ぬ（SHARP A105SH の実機で確認）。
     * 端末に聞いてから決める。
     */
    private fun pickAfMode(cm: CameraManager, id: String): Int? {
        val modes = try {
            cm.getCameraCharacteristics(id)
                .get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)
        } catch (_: Exception) { null } ?: return null
        val wanted = CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
        return if (modes.contains(wanted.toByte().toInt())) wanted
        else modes.firstOrNull()
    }

    private fun startSession(device: CameraDevice) {
        val surface = reader?.surface ?: return
        val req = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
            addTarget(surface)
            // 端末が受け付けるモードだけを指定する。対応していない値を渡すと
            // 撮影要求ごと蹴られて、背面の見張りが丸ごと死ぬ。
            afMode?.let { set(CaptureRequest.CONTROL_AF_MODE, it) }
        }
        @Suppress("DEPRECATION")
        device.createCaptureSession(
            listOf(surface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(s: CameraCaptureSession) {
                    session = s
                    isRunning = true
                    opening = false
                    try {
                        s.setRepeatingRequest(req.build(), null, handler)
                    } catch (e: Exception) {
                        Log.e(TAG, "撮影を開始できない", e)
                        failed("カメラの撮影を開始できませんでした")
                    }
                }

                override fun onConfigureFailed(s: CameraCaptureSession) {
                    failed("カメラを構成できませんでした")
                }
            },
            handler
        )
    }

    private fun onFrame(r: ImageReader) {
        val image = try { r.acquireLatestImage() } catch (e: Exception) { null } ?: return
        val now = System.currentTimeMillis()
        if (busy || now - lastFrameAt < MIN_FRAME_GAP_MS) {
            image.close(); return
        }
        lastFrameAt = now
        busy = true

        val det = detector
        if (det == null) { image.close(); busy = false; return }

        try {
            // 前面カメラなので鏡像だが、目の開閉の判定に左右の別は要らない。
            val input = InputImage.fromMediaImage(image, sensorOrientation)
            val startedAt = System.currentTimeMillis()
            det.process(input)
                .addOnSuccessListener { faces ->
                    val f = faces.firstOrNull()
                    lastAnalysisMs = System.currentTimeMillis() - startedAt
                    logReading(f != null, f?.leftEyeOpenProbability, f?.rightEyeOpenProbability)
                    sink?.invoke(
                        f != null,
                        f?.leftEyeOpenProbability?.toDouble(),
                        f?.rightEyeOpenProbability?.toDouble(),
                        // 頭の角度（度）。俯き・横倒し・脇見の判定は Dart 側。
                        f?.let { floatArrayOf(it.headEulerAngleX, it.headEulerAngleY, it.headEulerAngleZ) }
                    )
                }
                .addOnFailureListener { e -> Log.w(TAG, "顔検出に失敗", e) }
                .addOnCompleteListener {
                    image.close()
                    busy = false
                }
        } catch (e: Exception) {
            Log.w(TAG, "フレームを扱えない", e)
            image.close(); busy = false
        }
    }

    /**
     * 背面でも本当に見続けているかを、あとから logcat で確かめられるようにする。
     * 毎フレーム出すとログが溢れて肝心の行が流れるので 2 秒に 1 行だけ。
     * `adb logcat -s EyeService` で追える。
     */
    private var lastLogAt = 0L

    /** 直近1フレームの解析にかかった時間。ACCURATE が間隔（MIN_FRAME_GAP_MS）に
     *  収まっているかを logcat で確かめるためのもの。 */
    private var lastAnalysisMs = 0L

    private fun logReading(face: Boolean, left: Float?, right: Float?) {
        val now = System.currentTimeMillis()
        if (now - lastLogAt < 2000L) return
        lastLogAt = now
        if (!face) {
            Log.d(TAG, "解析中 顔なし (${lastAnalysisMs}ms)")
        } else {
            Log.d(TAG, "解析中 目の開き 左=$left 右=$right (${lastAnalysisMs}ms)")
        }
    }

    /**
     * 開いているカメラのライトを、撮影要求を作り直して点す/消す。
     *
     * setTorchMode は「そのカメラを誰も開いていない」間しか効かない。
     * 背面カメラで見張っている最中（この Service がカメラを持っている
     * とき）はここを通る。セッションが無い（前面では Flutter 側が持って
     * いる等）なら false を返し、呼び出し側は setTorchMode へ戻る。
     */
    fun applyTorch(on: Boolean): Boolean {
        val s = session ?: return false
        val device = cameraDevice ?: return false
        val surface = reader?.surface ?: return false
        val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val hasFlash = try {
            cm.getCameraCharacteristics(device.id)
                .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        } catch (_: Exception) { false }
        if (!hasFlash) return false
        return try {
            val req = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                addTarget(surface)
                afMode?.let { set(CaptureRequest.CONTROL_AF_MODE, it) }
                set(
                    CaptureRequest.FLASH_MODE,
                    if (on) CaptureRequest.FLASH_MODE_TORCH else CaptureRequest.FLASH_MODE_OFF
                )
            }
            s.setRepeatingRequest(req.build(), null, handler)
            true
        } catch (e: Exception) {
            Log.w(TAG, "ライトを${if (on) "点せ" else "消せ"}なかった", e)
            false
        }
    }

    private fun closeCamera() {
        isRunning = false
        opening = false
        try { session?.close() } catch (_: Exception) {}
        try { cameraDevice?.close() } catch (_: Exception) {}
        try { reader?.close() } catch (_: Exception) {}
        try { detector?.close() } catch (_: Exception) {}
        session = null; cameraDevice = null; reader = null; detector = null
        thread?.quitSafely(); thread = null; handler = null
    }

    override fun onDestroy() {
        closeCamera()
        instance = null
        super.onDestroy()
    }
}

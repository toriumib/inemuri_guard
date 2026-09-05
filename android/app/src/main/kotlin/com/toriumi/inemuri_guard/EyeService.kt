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

        private const val CHANNEL_ID = "eye_watch"
        private const val NOTIFICATION_ID = 4711

        /** 解析の間隔。瞼の開閉は秒単位の現象なので、毎フレーム回す必要はない。 */
        private const val MIN_FRAME_GAP_MS = 160L

        /** Dart 側へ結果を渡す口。EyePlugin が差し込む。 */
        @Volatile
        var sink: ((faceFound: Boolean, left: Double?, right: Double?) -> Unit)? = null

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private var cameraDevice: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var reader: ImageReader? = null
    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    private var detector: FaceDetector? = null
    private var busy = false
    private var lastFrameAt = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
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
                if (!isRunning) openCamera()
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
            startForeground(
                NOTIFICATION_ID, n,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
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
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "カメラ権限が無いので開けない")
            stopSelf()
            return
        }

        detector = FaceDetection.getClient(
            FaceDetectorOptions.Builder()
                // 目の開き具合は classification でしか取れない。
                .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                .build()
        )

        thread = HandlerThread("eye-cam").also { it.start() }
        handler = Handler(thread!!.looper)

        val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val frontId = cm.cameraIdList.firstOrNull {
            cm.getCameraCharacteristics(it)
                .get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
        } ?: cm.cameraIdList.firstOrNull()

        if (frontId == null) {
            Log.w(TAG, "カメラが無い")
            stopSelf()
            return
        }

        // 解析にしか使わないので小さくてよい。消費電力と発熱に直結する。
        reader = ImageReader.newInstance(640, 480, ImageFormat.YUV_420_888, 2).apply {
            setOnImageAvailableListener({ r -> onFrame(r) }, handler)
        }

        try {
            cm.openCamera(frontId, object : CameraDevice.StateCallback() {
                override fun onOpened(device: CameraDevice) {
                    cameraDevice = device
                    startSession(device)
                }

                override fun onDisconnected(device: CameraDevice) {
                    Log.w(TAG, "カメラが切断された")
                    device.close(); cameraDevice = null; stopSelf()
                }

                override fun onError(device: CameraDevice, error: Int) {
                    Log.e(TAG, "カメラのエラー: $error")
                    device.close(); cameraDevice = null; stopSelf()
                }
            }, handler)
        } catch (e: SecurityException) {
            Log.e(TAG, "カメラを開けない", e); stopSelf()
        }
    }

    private fun startSession(device: CameraDevice) {
        val surface = reader?.surface ?: return
        val req = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
            addTarget(surface)
            set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
        }
        @Suppress("DEPRECATION")
        device.createCaptureSession(
            listOf(surface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(s: CameraCaptureSession) {
                    session = s
                    isRunning = true
                    try {
                        s.setRepeatingRequest(req.build(), null, handler)
                    } catch (e: Exception) {
                        Log.e(TAG, "撮影を開始できない", e); stopSelf()
                    }
                }

                override fun onConfigureFailed(s: CameraCaptureSession) {
                    Log.e(TAG, "セッションを構成できない"); stopSelf()
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
            val input = InputImage.fromMediaImage(image, 270)
            det.process(input)
                .addOnSuccessListener { faces ->
                    val f = faces.firstOrNull()
                    sink?.invoke(
                        f != null,
                        f?.leftEyeOpenProbability?.toDouble(),
                        f?.rightEyeOpenProbability?.toDouble()
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

    private fun closeCamera() {
        isRunning = false
        try { session?.close() } catch (_: Exception) {}
        try { cameraDevice?.close() } catch (_: Exception) {}
        try { reader?.close() } catch (_: Exception) {}
        try { detector?.close() } catch (_: Exception) {}
        session = null; cameraDevice = null; reader = null; detector = null
        thread?.quitSafely(); thread = null; handler = null
    }

    override fun onDestroy() {
        closeCamera()
        super.onDestroy()
    }
}

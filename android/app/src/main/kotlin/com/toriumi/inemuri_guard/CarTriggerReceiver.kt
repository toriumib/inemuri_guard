package com.toriumi.inemuri_guard

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionResult
import com.google.android.gms.location.DetectedActivity

/**
 * 「車に乗った」を受け取って、見張りを始める道を作る受け口。
 *
 * 受けるもの：
 * - 車の Bluetooth（設定で選んだ機器）の接続・切断。この放送はアプリが
 *   死んでいても manifest の受信機に届く（暗黙の放送の制限から除外されている）
 * - 身体活動認識の「乗り物に乗った／降りた」（設定で ON にしたときだけ登録）
 *
 * できること・できないこと：
 * - Android 10 以降、背面から勝手に画面は出せない。判定は Dart 側にあるので、
 *   アプリを前に出さないと見張りは始まらない。そこで**全画面インテントの通知**を
 *   出す——画面がロック中（乗車時はたいていそう）なら画面いっぱいに開いて
 *   自動開始が走る＝手間ゼロ。解除中ならヘッドアップ通知で 1 タップ
 * - 降りた（切断／降車）ときは、動いていれば見張りを止め、通知も消す
 */
class CarTriggerReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CarTrigger"
        const val CHANNEL_ID = "car_start"
        const val NOTIFICATION_ID = 4712
        const val EXTRA_AUTOSTART = "autostart"

        /** Flutter の shared_preferences はこのファイルに "flutter." 付きで保存される。 */
        private const val PREFS = "FlutterSharedPreferences"
        const val KEY_BT_ADDRESS = "flutter.car_bt_address"
        const val KEY_BT_NAME = "flutter.car_bt_name"
        const val KEY_START_ON_DRIVE = "flutter.start_on_drive"

        /** Dart が生きていれば、そちらにも知らせる（見張りの開始・停止をきれいに）。 */
        @Volatile
        var sink: ((event: String) -> Unit)? = null

        fun carAddress(context: Context): String? =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_BT_ADDRESS, null)

        fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL_ID) != null) return
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "車に乗ったら始める", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "車の Bluetooth につながった・運転を検知したときに、見張りを始めるための通知"
                    setSound(null, null)
                    enableVibration(true)
                }
            )
        }

        /**
         * 「乗った」を受けたときの共通の出口。
         * アプリが前面で動いていれば Dart に直接「始めて」と言う。
         * そうでなければ全画面インテントの通知を出す。
         */
        fun onBoarded(context: Context, why: String) {
            Log.i(TAG, "乗車を検知: $why")
            sink?.let { it("boarded:$why"); return }
            ensureChannel(context)
            val open = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                putExtra(EXTRA_AUTOSTART, true)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val pi = PendingIntent.getActivity(
                context, 1, open,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val n = Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("車に乗りましたか？")
                .setContentText("タップで居眠りの見張りを始めます（$why）")
                .setCategory(Notification.CATEGORY_ALARM)
                .setPriority(Notification.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pi)
                // ロック中ならこれで画面いっぱいにアプリが開き、自動開始が走る。
                .setFullScreenIntent(pi, true)
                .setTimeoutAfter(3 * 60 * 1000L)
                .build()
            context.getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, n)
        }

        /** 「降りた」。動いていれば止める。 */
        fun onLeft(context: Context, why: String) {
            Log.i(TAG, "降車を検知: $why")
            context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
            val s = sink
            if (s != null) {
                s("left:$why")
            } else if (EyeService.isRunning || EyeService.instance != null) {
                // Dart が居ない（プロセスが死んでいる）のにサービスだけ残っている場合。
                context.startService(Intent(context, EyeService::class.java).apply { action = EyeService.ACTION_STOP })
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            BluetoothDevice.ACTION_ACL_CONNECTED, BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                val car = carAddress(context) ?: return
                @Suppress("DEPRECATION")
                val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                } else {
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                }
                if (device?.address != car) return
                if (intent.action == BluetoothDevice.ACTION_ACL_CONNECTED) onBoarded(context, "Bluetooth")
                else onLeft(context, "Bluetooth")
            }
            // 動作確認用（adb shell am broadcast -a com.stop.sleeping.TEST_BOARD -n com.stop.sleeping/.CarTriggerReceiver）。
            // 通知を出す／消すだけで、他に何もしないので開けておいてよい。
            "com.stop.sleeping.TEST_BOARD" -> onBoarded(context, "テスト")
            "com.stop.sleeping.TEST_LEFT" -> onLeft(context, "テスト")
            else -> {
                // 身体活動認識（乗り物に乗った／降りた）。PendingIntent 経由で届く。
                val result = ActivityTransitionResult.extractResult(intent) ?: return
                val latest = result.transitionEvents.lastOrNull() ?: return
                if (latest.activityType != DetectedActivity.IN_VEHICLE) return
                if (latest.transitionType == ActivityTransition.ACTIVITY_TRANSITION_ENTER) onBoarded(context, "運転を検知")
                else onLeft(context, "運転を検知")
            }
        }
    }
}

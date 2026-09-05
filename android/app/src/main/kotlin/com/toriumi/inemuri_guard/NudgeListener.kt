package com.toriumi.inemuri_guard

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * Slack / Teams / メールの通知が来たら起こすための受け口。
 *
 * ## なぜ通知を読む方式にしたか
 *
 * 各サービスの API を叩くなら OAuth と常駐サーバが要る。個人開発で持つには
 * 重すぎるし、会社のワークスペースだと管理者の承認も要る。
 * **端末に届く通知を読む**なら、その全部が要らない。
 *
 * ## 断っておくこと
 *
 * 通知の中身は**読むだけで、どこにも送らないし保存もしない**。
 * 見ているのは「どのアプリから来たか」だけで、本文もタイトルも使っていない。
 * 通知アクセスは Android でもっとも強い権限のひとつなので、
 * 必要最小限しか触らない。
 *
 * この権限はユーザーが設定画面で明示的に許可しないと有効にならない
 * （[isEnabled] / [openSettings]）。勝手には有効にできない。
 */
class NudgeListener : NotificationListenerService() {

    companion object {
        private const val TAG = "NudgeListener"

        /** 起こす対象のアプリ。ここに無いものは完全に無視する。 */
        val WATCHED = mapOf(
            "com.Slack" to "Slack",
            "com.microsoft.teams" to "Teams",
            "com.microsoft.office.outlook" to "Outlook",
            "com.google.android.gm" to "Gmail",
            "jp.naver.line.android" to "LINE",
            "com.discord" to "Discord",
        )

        /** Dart 側へ「呼ばれた」ことだけを伝える。中身は渡さない。 */
        @Volatile
        var sink: ((appLabel: String) -> Unit)? = null

        /** この機能を使うと本人が決めたか。Dart から設定される。 */
        @Volatile
        var enabled: Boolean = false

        /** 通知アクセスが許可されているか。 */
        fun isEnabled(context: Context): Boolean {
            val flat = Settings.Secure.getString(
                context.contentResolver, "enabled_notification_listeners"
            ) ?: return false
            val me = ComponentName(context, NudgeListener::class.java)
            return flat.split(":").any {
                ComponentName.unflattenFromString(it) == me
            }
        }

        /** 通知アクセスの設定画面を開く。ユーザー自身に許可してもらうしかない。 */
        fun openSettings(context: Context) {
            context.startActivity(
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (!enabled) return
        val pkg = sbn?.packageName ?: return
        // 「なぜ鳴らないのか」を追えるようにしておく。対象外も含めて残す。
        Log.d(TAG, "通知を受け取った: $pkg")
        val label = WATCHED[pkg] ?: return

        // 自分が出している常駐通知で自分を起こさないように。
        if (pkg == packageName) return
        // 進行中の通知（音楽再生や同期中など）は「呼ばれた」ではない。
        if (sbn.isOngoing) return

        Log.d(TAG, "起こす対象の通知: $label")
        sink?.invoke(label)
    }
}

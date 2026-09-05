package com.toriumi.inemuri_guard

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.app.Notification
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
 * 通知の中身は**どこにも送らないし保存もしない**。端末の中だけで見て、
 * 起こすかどうかを決めたらその場で捨てる。
 *
 * ⚠️ 差出人の絞り込み（[senderFilter]）を設定した場合に限り、
 * 通知の**タイトルと本文を照合に使う**。「このメールアドレスから届いたときだけ
 * 起こす」を実現するには、届いた通知の文字を見る以外に方法がないため。
 * 絞り込みが空のときは、これまでどおり「どのアプリから来たか」しか見ない。
 * 照合はすべて端末内で行い、一致したかどうかだけを Dart へ渡す。
 * 本文そのものはアプリの外へ出ないし、ログにも残さない。
 *
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
            // 着信。端末ごとに電話アプリが違うので、素の Android・Google・
            // メーカー製のどれでも拾えるように並べてある。
            // 着信中の通知は isOngoing が立つので、電話だけは別扱いにする
            // （[isCall] を参照）。
            "com.android.server.telecom" to "電話",
            "com.android.dialer" to "電話",
            "com.google.android.dialer" to "電話",
            "com.samsung.android.incallui" to "電話",
            "jp.co.sharp.android.shphonemenu" to "電話",
        )

        /** 着信かどうか。着信の通知は「進行中」で届くので判定を分ける。 */
        private fun isCall(label: String) = label == "電話"

        /** Dart 側へ「呼ばれた」ことだけを伝える。中身は渡さない。 */
        @Volatile
        var sink: ((appLabel: String) -> Unit)? = null

        /** この機能を使うと本人が決めたか。Dart から設定される。 */
        @Volatile
        var enabled: Boolean = false

        /**
         * 差出人・件名の絞り込み。空なら絞り込まない（対象アプリの通知すべてで起こす）。
         * 「部長のアドレスからのメールだけ起こしてほしい」に応えるためのもの。
         * どれか一つでも通知の文字に含まれていれば起こす。
         */
        @Volatile
        var senderFilter: List<String> = emptyList()

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
        // ⚠️ 出すのはパッケージ名だけ。通知の中身はログに残さない。
        Log.d(TAG, "通知を受け取った: $pkg")
        val label = WATCHED[pkg] ?: return

        // 自分が出している常駐通知で自分を起こさないように。
        if (pkg == packageName) return
        // 進行中の通知（音楽再生や同期中など）は「呼ばれた」ではない。
        // ただし着信だけは例外で、鳴っている間ずっと「進行中」で届く。
        // ここで弾くと、いちばん起きるべき電話で起こせなくなる。
        if (sbn.isOngoing && !isCall(label)) return

        if (!matchesFilter(sbn)) {
            Log.d(TAG, "対象アプリだが絞り込みに一致しない: $label")
            return
        }

        Log.d(TAG, "起こす対象の通知: $label")
        sink?.invoke(label)
    }

    /**
     * 絞り込みに一致するか。空なら常に true（＝アプリ単位でしか見ない）。
     *
     * 照合はここだけで完結し、読んだ文字はこのメソッドの外へ出さない。
     * 返すのは真偽値だけ。
     */
    private fun matchesFilter(sbn: StatusBarNotification): Boolean {
        val needles = senderFilter
        if (needles.isEmpty()) return true
        val extras = sbn.notification?.extras ?: return false
        val hay = buildString {
            append(extras.getCharSequence(Notification.EXTRA_TITLE) ?: "")
            append(' ')
            append(extras.getCharSequence(Notification.EXTRA_TEXT) ?: "")
            append(' ')
            append(extras.getCharSequence(Notification.EXTRA_SUB_TEXT) ?: "")
            append(' ')
            append(extras.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: "")
        }.lowercase()
        return needles.any { hay.contains(it.trim().lowercase()) }
    }
}

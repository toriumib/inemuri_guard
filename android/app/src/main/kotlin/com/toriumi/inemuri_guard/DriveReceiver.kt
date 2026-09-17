package com.toriumi.inemuri_guard

import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionResult
import com.google.android.gms.location.DetectedActivity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 「乗り物に乗り始めた／降りた」を受け取るだけの受け口。
 *
 * 身体活動認識（ActivityTransition）は OS がバックグラウンドで動かし、
 * ここに PendingIntent で届く。乗り続けているか・いつ勧めるかの判断は
 * すべて Dart 側（DriveNudgeService）に置いてある。同じ判断を二か所に
 * 書くと、必ず片方だけ直して食い違うため（EyeService と同じ方針）。
 *
 * なお「乗り物」は車・バス・電車・自転車を区別しない。ここでは
 * 区別せずに Dart へ渡し、勧め方（90秒続いたら・45分は再勧誘しない）で
 * 乗り物一般に成り立つようにしている。
 */
class DriveReceiver : BroadcastReceiver() {

    companion object {
        /** Dart へ「乗り物に乗っているか」を渡す口。EyePlugin が差し込む。 */
        @Volatile
        var sink: ((inVehicle: Boolean) -> Unit)? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val result = ActivityTransitionResult.extractResult(intent) ?: return
        val sink = sink ?: return
        // 1回の放送に複数の転移が積まれていることがある。最後のものが最新。
        val latest = result.transitionEvents.lastOrNull() ?: return
        if (latest.activityType != DetectedActivity.IN_VEHICLE) return
        sink(latest.transitionType == ActivityTransition.ACTIVITY_TRANSITION_ENTER)
    }
}

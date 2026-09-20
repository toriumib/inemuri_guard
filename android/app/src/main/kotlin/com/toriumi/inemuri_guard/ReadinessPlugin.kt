package com.toriumi.inemuri_guard

import android.app.Activity
import android.app.NotificationManager
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** User-invoked system setup, with no automatic changes to system settings. */
class ReadinessPlugin(private val activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "inemuri/readiness").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "consumeStartRequest" -> {
                        val intent = activity.intent
                        val requested = intent.getBooleanExtra(CarTriggerReceiver.EXTRA_AUTOSTART, false) ||
                            intent.action == "com.stop.sleeping.START" ||
                            (intent.data?.scheme == "inemuri" && intent.data?.host == "start")
                        if (requested) {
                            intent.removeExtra(CarTriggerReceiver.EXTRA_AUTOSTART)
                            intent.action = Intent.ACTION_MAIN
                            intent.data = null
                        }
                        result.success(requested)
                    }
                    "status" -> {
                        val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val notifications = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        result.success(mapOf(
                            "alarmVolume" to audio.getStreamVolume(AudioManager.STREAM_ALARM),
                            "alarmMax" to audio.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                            "notifications" to (Build.VERSION.SDK_INT < 24 || notifications.areNotificationsEnabled()),
                            "canAddTile" to (Build.VERSION.SDK_INT >= 33)
                        ))
                    }
                    "soundSettings" -> {
                        activity.startActivity(Intent(Settings.ACTION_SOUND_SETTINGS))
                        result.success(true)
                    }
                    "notificationSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= 26) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                android.net.Uri.parse("package:" + activity.packageName))
                        }
                        activity.startActivity(intent)
                        result.success(true)
                    }
                    "addTile" -> {
                        if (Build.VERSION.SDK_INT >= 33) {
                            activity.getSystemService(StatusBarManager::class.java).requestAddTileService(
                                ComponentName(activity, WatchTileService::class.java),
                                activity.getString(R.string.app_name), Icon.createWithResource(activity, R.mipmap.ic_launcher),
                                activity.mainExecutor
                            ) { code -> result.success(code == StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED ||
                                code == StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED) }
                        } else result.success(false)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("unavailable", activity.getString(R.string.settings_open_failed), null)
            }
        }
    }
}

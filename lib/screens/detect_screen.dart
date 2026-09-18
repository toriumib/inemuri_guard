import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

import '../services/alarm_service.dart';
import '../services/breathing_detector.dart';
import '../services/drowsiness_detector.dart';
import '../services/notification_service.dart';
import '../services/sleep_log_service.dart';
import '../services/stats_service.dart';
import '../services/torch.dart';
import '../services/voice_stop.dart';
import '../theme/app_theme.dart';
import '../widgets/camera_stage.dart';
import '../widgets/range_slider_row.dart';

class DetectScreen extends StatefulWidget {
  const DetectScreen({super.key});

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  bool _wasEyeAlarming = false;
  bool _wasBreathAlarming = false;
  bool _wasLookingAway = false;

  /// 車で眠気を検知したあと、「安全な場所で休憩」の案内を出しているか。
  /// 閉じるまで残す——鳴っている最中ではなく、停めてから読むものだから。
  bool _restAdvice = false;
  late final DrowsinessDetector _detector;
  late final BreathingDetector _breathing;

  @override
  void initState() {
    super.initState();
    _detector = context.read<DrowsinessDetector>();
    _breathing = context.read<BreathingDetector>();
    _detector.addListener(_sensorChanged);
    _breathing.addListener(_sensorChanged);
    // 外側のライトの点滅は車で使うときだけ。保存値を鳴らし側へ渡す。
    context.read<AlarmService>().useTorch =
        context.read<StatsService>().carMode && Torch.isSupported;
    // 前面ではカメラを持っている側（Flutter）しかライトを点せない。
    Torch.viaController = _detector.setTorch;
    // 脇見の判定は車のときだけ。保存値を検知器へ渡す。
    _detector.carMode = context.read<StatsService>().carMode;
    _sensorChanged();
  }

  /// 地図アプリを開く。[query] があれば近くをその語で探す（例: 駐車場）。
  /// geo: を受けるアプリが無ければブラウザの Google マップに逃がす。
  Future<void> _openMaps({String? query}) async {
    final geo = Uri.parse(
      query == null ? 'geo:0,0' : 'geo:0,0?q=${Uri.encodeComponent(query)}',
    );
    try {
      if (await launchUrl(geo, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    final web = Uri.parse(
      query == null
          ? 'https://www.google.com/maps'
          : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    try {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _sensorChanged() {
    // Microtasks run even when Android stops scheduling UI frames.
    // Read the latest state so stopping detection cancels a queued alarm.
    scheduleMicrotask(() {
      if (mounted) _syncAlarms();
    });
  }

  @override
  void dispose() {
    _detector.removeListener(_sensorChanged);
    _breathing.removeListener(_sensorChanged);
    super.dispose();
  }

  void _syncAlarms() {
    final detector = _detector;
    final breathing = _breathing;
    final alarm = context.read<AlarmService>();
    final stats = context.read<StatsService>();
    final sleepLog = context.read<SleepLogService>();

    // React once per episode without depending on a widget rebuild.
    if (detector.alarmFiring != _wasEyeAlarming) {
      final firing = detector.alarmFiring;
      _wasEyeAlarming = firing;
      if (firing) {
        final car = stats.carMode;
        alarm.start(
          reason: car
              ? '目を閉じたままの状態を検知しました。安全な場所で休憩しましょう'
              : '目を閉じたままの状態を検知しました',
        );
        stats.bumpAlarm('目を閉じたままの状態を検知');
        sleepLog.add(SleepEventType.detected, note: '目の開閉');
        if (car) {
          // 車では「起こす」で終わらせない。SA・路肩・駐車場で休む、まで言う。
          // 画面を見ていない（マップを前に出している・裏向きに置いている）
          // ときのために通知でも残す。
          setState(() => _restAdvice = true);
          if (WidgetsBinding.instance.lifecycleState !=
              AppLifecycleState.resumed) {
            context.read<NotificationService>().fireRestAdvice();
          }
        }
      } else if (!breathing.alarmFiring) {
        alarm.stop();
      }
    }
    // 脇見（車モード）。アラームではなく一段弱い知らせ——短い音と振動だけ。
    if (detector.lookAwayAlert && !_wasLookingAway) {
      alarm.preview();
      Vibration.hasVibrator().then((has) {
        if (has == true) Vibration.vibrate(duration: 300);
      });
    }
    _wasLookingAway = detector.lookAwayAlert;
    if (breathing.alarmFiring != _wasBreathAlarming) {
      final firing = breathing.alarmFiring;
      _wasBreathAlarming = firing;
      if (firing) {
        alarm.start(reason: '規則的な寝息のような音を検知しました');
        stats.bumpAlarm('寝息のような音を検知');
        sleepLog.add(SleepEventType.detected, note: '寝息');
      } else if (!detector.alarmFiring) {
        alarm.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final detector = context.watch<DrowsinessDetector>();
    final breathing = context.watch<BreathingDetector>();
    final alarm = context.read<AlarmService>();
    final stats = context.watch<StatsService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_restAdvice) ...[
            _RestAdviceCard(
              onFindParking: () => _openMaps(query: '駐車場'),
              onClose: () => setState(() => _restAdvice = false),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Web 版と同じ並び: 大きな映像 → 4つの読み取り → 大きなボタン。
                  // 机に置いて遠くから見る道具なので、映像と状態の一語が主役。
                  CameraStage(
                    detector: detector,
                    showPreview: stats.showCameraPreview,
                  ),
                  const SizedBox(height: 10),
                  ReadoutTiles(
                    detector: detector,
                    alertsToday: stats.alarmCount,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: detector.state == DetectorState.watching
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: c.accentAlert,
                              side: BorderSide(color: c.accentAlert),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              await detector.stop();
                              if (!breathing.alarmFiring) await alarm.stop();
                            },
                            child: const Text('止める'),
                          )
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: c.accentGood,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: detector.state == DetectorState.starting
                                ? null
                                : () async {
                                    detector.setThresholdSeconds(
                                      stats.eyeThresholdSeconds,
                                    );
                                    await detector.start();
                                  },
                            child: Text(
                              detector.state == DetectorState.starting
                                  ? '起動中…'
                                  : '見張りを始める',
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => stats.setShowCameraPreview(
                            !stats.showCameraPreview,
                          ),
                          icon: Icon(
                            stats.showCameraPreview
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          label: Text(
                            stats.showCameraPreview ? '映像を隠す' : '映像を出す',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => alarm.preview(),
                          icon: const Icon(Icons.volume_up_outlined, size: 18),
                          label: const Text('音を試す'),
                        ),
                      ),
                    ],
                  ),
                  if (stats.carMode) ...[
                    const SizedBox(height: 10),
                    // 見張りは常駐サービスで続くので、マップを前に出してよい。
                    // それを知らないと「アプリを閉じたら止まる」と思って
                    // 画面を切り替えられない。
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _openMaps(),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text(
                          detector.state == DetectorState.watching
                              ? 'マップを開く（見張りは続きます）'
                              : 'マップを開く',
                        ),
                      ),
                    ),
                  ],
                  if (detector.noFaceSeen &&
                      detector.state == DetectorState.watching &&
                      detector.faceLostLong) ...[
                    const SizedBox(height: 10),
                    // 3秒たっても見つからないなら、よくある原因を言う。
                    // 眼鏡の反射とマスクは、検出器がいちばん苦手にするもの。
                    Text(
                      '顔を検出できません。眼鏡の反射やマスクで見つけにくいことがあります。'
                      '顔を明るく、カメラを目の高さに。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: c.accentNap),
                    ),
                  ],
                  const SizedBox(height: 18),
                  RangeSliderRow(
                    title: '何秒目を閉じたら起こす？',
                    value: stats.eyeThresholdSeconds,
                    color: c.accentAlert,
                    onChanged: (v) {
                      stats.setEyeThresholdSeconds(v);
                      detector.setThresholdSeconds(v);
                    },
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('背面カメラで見張る'),
                    // 実機（360dp・文字大きめ）では長い文が細い柱になる。
                    // 免責の全文は設定の「このアプリについて」にあるので、ここは要点だけ。
                    subtitle: const Text(
                      'スタンドに載せて画面を外へ向けるときに。机なら切ったままで。'
                      '車内では補助としてのみ——見逃し・誤作動があり、注意義務の代わりには'
                      'なりません（免責は設定の「このアプリについて」）。',
                    ),
                    value: stats.useBackCamera,
                    onChanged: (v) async {
                      await stats.setUseBackCamera(v);
                      await detector.setUseBackCamera(v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('車で使う'),
                    subtitle: Text(
                      '眠気を検知したら、休憩できる場所（SA・PA・駐車場・路肩）の案内を出します。'
                      '${Torch.isSupported ? 'アラーム中は外側のライトも点滅（裏向きに置いたとき用）。' : ''}'
                      'マップを開いたまま見張れます。',
                    ),
                    value: stats.carMode,
                    onChanged: (v) async {
                      await stats.setCarMode(v);
                      alarm.useTorch = v && Torch.isSupported;
                      detector.carMode = v;
                    },
                  ),
                  if (VoiceStop.isSupported)
                    ListenableBuilder(
                      listenable: VoiceStop.instance,
                      builder: (context, _) => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('声で止める'),
                        subtitle: Text(
                          VoiceStop.instance.unavailable
                              ? 'この端末では音声認識が使えませんでした。音・振動・ボタンで止められます。'
                              : '鳴っている間「起きた」「止めて」と言うと止まります。'
                                    '端末の音声認識を使います（寝息検知を使っている間は声では止められません）。'
                                    '${VoiceStop.instance.lastHeard.isEmpty ? '' : '\n直近に聞こえた言葉: 「${VoiceStop.instance.lastHeard}」'}',
                        ),
                        value: stats.voiceStop,
                        onChanged: (v) async {
                          await stats.setVoiceStop(v);
                          alarm.useVoice = v;
                          if (v) await VoiceStop.instance.prepare();
                        },
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('暗いところでは画面で照らす'),
                    subtitle: const Text(
                      '暗くて顔が見つからないとき、画面を白く明るくして顔を照らします。'
                      '顔が見つかると元に戻ります。',
                    ),
                    value: stats.illuminateInDark,
                    onChanged: (v) => stats.setIlluminateInDark(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('開いた瞬間から見張る'),
                    subtitle: const Text('アプリを開くだけでカメラが始まります。'),
                    value: stats.autoStartDetection,
                    onChanged: (v) => stats.setAutoStartDetection(v),
                  ),
                  if (detector.backgroundFailure != null) ...[
                    const SizedBox(height: 12),
                    // 見張れていないのに「検知中」と出したままにしない。
                    // 起きなかった理由が分からないのが、この道具で一番困る。
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.accentAlert.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, color: c.accentAlert),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '他のアプリを開いている間の見張りが止まりました'
                              '（${detector.backgroundFailure}）。'
                              'この画面を開いている間は見張っています。',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 28),
                  _ToneRow(alarm: alarm),
                  if (detector.state == DetectorState.denied) ...[
                    const SizedBox(height: 12),
                    Text(
                      'カメラを起動できませんでした。設定でカメラ権限を許可してください。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: c.accentAlert),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _LogList(stats: stats),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const BreathingCard(),
        ],
      ),
    );
  }
}

class BreathingCard extends StatefulWidget {
  const BreathingCard({super.key});

  @override
  State<BreathingCard> createState() => _BreathingCardState();
}

class _BreathingCardState extends State<BreathingCard> {
  int thresholdSeconds = 20;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final breathing = context.watch<BreathingDetector>();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('寝息センサー（マイク）', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '静かで規則的な呼吸音が続いたら検知します。カメラと併用可。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '音量レベル',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${breathing.currentDb.toStringAsFixed(0)} dB',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: breathing.regularityScore.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: c.surface2,
                valueColor: AlwaysStoppedAnimation(
                  breathing.regularityScore > 0.8 ? c.accentNap : c.accentGood,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '規則的な呼吸を検知している時間',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${breathing.regularFor.inSeconds}秒',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ChipThresholdPicker(
              title: '何秒続いたら起こす？',
              options: const [15, 20, 30, 45],
              value: thresholdSeconds,
              suffix: '秒',
              color: c.accentAlert,
              onChanged: (v) {
                setState(() => thresholdSeconds = v);
                breathing.setThresholdSeconds(v);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accentAlert,
                      foregroundColor: c.accentAlertInk,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: breathing.state == MicState.listening
                        ? null
                        : () async {
                            breathing.setThresholdSeconds(thresholdSeconds);
                            await breathing.start();
                          },
                    child: Text(
                      breathing.state == MicState.starting
                          ? '起動中…'
                          : 'マイク検知を開始',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: breathing.state == MicState.listening
                        ? breathing.stop
                        : null,
                    child: const Text('停止'),
                  ),
                ),
              ],
            ),
            if (breathing.state == MicState.denied) ...[
              const SizedBox(height: 12),
              Text(
                'マイクを起動できませんでした。設定でマイク権限を許可してください。',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: c.accentAlert),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


/// Big, tappable seconds picker shared by both sensor cards — replaces the
/// old dropdown, which was too small/fiddly to hit reliably.
class _ChipThresholdPicker extends StatelessWidget {
  final String title;
  final List<int> options;
  final int value;
  final String suffix;
  final Color color;
  final ValueChanged<int> onChanged;

  const _ChipThresholdPicker({
    required this.title,
    required this.options,
    required this.value,
    required this.suffix,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(
                  '$o$suffix',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: value == o,
                onSelected: (_) => onChanged(o),
                selectedColor: color,
                labelStyle: TextStyle(
                  color: value == o ? Colors.white : c.text,
                ),
                backgroundColor: c.surface2,
                side: BorderSide(color: c.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 車で眠気を検知したあとの案内。起こすだけで終わらせず、
/// どこで休むか（SA・PA・駐車場・路肩）と、探す入口（地図）まで出す。
/// 運転中に操作させないため、読むだけで済む文にし、閉じるまで残す。
class _RestAdviceCard extends StatelessWidget {
  final VoidCallback onFindParking;
  final VoidCallback onClose;
  const _RestAdviceCard({required this.onFindParking, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: c.accentNap.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_cafe_outlined, color: c.accentNap),
                const SizedBox(width: 8),
                Text('休憩しましょう', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '眠気を検知しました。次の SA・PA、駐車場、路肩など安全な場所に停めて、'
              '15〜20分でも休んでください。眠気は根性では消えません。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accentNap,
                      foregroundColor: c.accentNapInk,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onFindParking,
                    icon: const Icon(Icons.local_parking_outlined, size: 18),
                    label: const Text('近くの駐車場を探す'),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(onPressed: onClose, child: const Text('閉じる')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToneRow extends StatelessWidget {
  final AlarmService alarm;
  const _ToneRow({required this.alarm});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('アラーム音', style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<AlarmTone>(
              value: alarm.tone,
              underline: const SizedBox(),
              items: AlarmTone.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (t) {
                if (t != null) alarm.setTone(t);
              },
            ),
            IconButton(
              tooltip: '音を確認',
              icon: const Icon(Icons.play_circle_outline),
              onPressed: alarm.preview,
            ),
          ],
        ),
      ],
    );
  }
}



class _LogList extends StatelessWidget {
  final StatsService stats;
  const _LogList({required this.stats});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (stats.log.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        Text('検知履歴', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        for (final entry in stats.log)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${entry.time.hour.toString().padLeft(2, '0')}:${entry.time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

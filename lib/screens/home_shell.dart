import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../services/ad_service.dart';
import '../services/alarm_service.dart';
import '../services/breathing_detector.dart';
import '../services/drowsiness_detector.dart';
import '../services/hydration_service.dart';
import '../services/nap_timer_service.dart';
import '../services/nudge_service.dart';
import '../services/pomodoro_service.dart';
import '../services/sleep_log_service.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_hero.dart';
import 'detect_screen.dart';
import 'improve_screen.dart';
import 'log_screen.dart';
import 'nap_screen.dart';
import 'settings_screen.dart';

/// Five destinations is past what a top TabBar handles comfortably on a
/// phone, so navigation lives at the bottom — which also gives the content
/// area back the vertical space the old header was eating.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  BannerAd? _banner;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final detector = context.read<DrowsinessDetector>();
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        detector.handleAppPaused();
        // 背面ではポモドーロの合図を OS の通知に任せる（予約を消さない）。
        context.read<PomodoroService>().onBackground();
      case AppLifecycleState.resumed:
        detector.handleAppResumed();
        // 通知アクセスの許可画面から戻ってきた場合をここでも拾う。
        // 設定タブを開いていないと気づけない作りだと、許可したのに
        // 効いていない状態のまま放置される。
        context.read<NudgeService>().refreshGranted();
        // 背面にいる間に区間が終わっていたら、ここで拾う。
        context.read<PomodoroService>().onForeground();
        // 水分補給の予約は「今日の残り＋明日」しか張っていない。
        // 戻ってくるたびに張り直して、途切れないようにする。
        context.read<HydrationService>().replan();
      case AppLifecycleState.inactive:
        break;
    }
  }

  static const _pages = [
    DetectScreen(),
    NapScreen(),
    LogScreen(),
    ImproveScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 「呼ばれたら起こす」の購読はここで始める。通知が来たら、居眠り検知と
    // 同じ鳴らし方（こっそりモードの段階的な強め方）に乗せる。
    context.read<NudgeService>().load(
      onNudge: (app) {
        if (!mounted) return;
        context.read<AlarmService>().start(reason: '$app の通知が届きました');
      },
    );
    final stats = context.read<StatsService>();
    if (!stats.adsRemoved) {
      _banner = context.read<AdService>().createBanner(
        onLoaded: () => setState(() {}),
      );
    }
    // 開いた瞬間から見張る。机に置いて開くだけで始まるのがこの道具の使い方。
    // 初回はカメラの許可ダイアログが出る。断られたら denied になるだけで、
    // 次回以降は「検知を開始」を押してもらう（毎回ダイアログを出し続けない）。
    if (stats.autoStartDetection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final detector = context.read<DrowsinessDetector>();
        if (detector.state == DetectorState.idle) {
          detector.setThresholdSeconds(stats.eyeThresholdSeconds);
          detector.start();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final detector = context.watch<DrowsinessDetector>();
    final breathing = context.watch<BreathingDetector>();
    final nap = context.watch<NapTimerService>();
    final pomo = context.watch<PomodoroService>();
    final alarm = context.watch<AlarmService>();
    final stats = context.watch<StatsService>();
    final log = context.watch<SleepLogService>();

    // Tear the banner down for good once ads are bought off, rather than just
    // hiding it — otherwise it keeps loading and costing bandwidth.
    if (stats.adsRemoved && _banner != null) {
      final banner = _banner;
      _banner = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => banner?.dispose());
    }

    final anyAlarming =
        detector.alarmFiring ||
        breathing.alarmFiring ||
        nap.phase == NapPhase.done;

    final (mode, label, value) = _status(
      detector,
      breathing,
      nap,
      pomo,
      anyAlarming,
    );

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: StatusHero(
                    mode: mode,
                    label: label,
                    value: value,
                    primaryLabel: detector.state == DetectorState.starting
                        ? '起動中…'
                        : (detector.state == DetectorState.watching
                              ? '停止'
                              : '検知を開始'),
                    primaryIsStop: detector.state == DetectorState.watching,
                    onPrimary: detector.state == DetectorState.starting
                        ? null
                        : () async {
                            if (detector.state == DetectorState.watching) {
                              await detector.stop();
                              if (!breathing.alarmFiring) await alarm.stop();
                            } else {
                              await detector.start();
                            }
                          },
                    // 目のアラーム中はスヌーズを出さない——目を開ければ止まる。
                    // ただしカメラが顔を見失っているときは止めようが無いので出す。
                    onSnooze: anyAlarming &&
                            !(detector.alarmFiring && !detector.faceLostLong)
                        ? () {
                            alarm.stop();
                            if (detector.alarmFiring) {
                              detector.snooze();
                              stats.bumpAlarm('スヌーズ 3分');
                            } else if (breathing.alarmFiring) {
                              breathing.snooze();
                              stats.bumpAlarm('スヌーズ 3分');
                            } else {
                              nap.snooze();
                            }
                          }
                        : null,
                  ),
                ),
                Expanded(
                  child: IndexedStack(index: _index, children: _pages),
                ),
                if (_banner != null && !stats.adsRemoved)
                  SizedBox(
                    width: _banner!.size.width.toDouble(),
                    height: _banner!.size.height.toDouble(),
                    child: AdWidget(ad: _banner!),
                  ),
              ],
            ),
          ),
          AlarmFlashOverlay(active: anyAlarming),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: c.surface,
        indicatorColor: c.accentAlert.withValues(alpha: 0.15),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.visibility_outlined),
            selectedIcon: Icon(Icons.visibility),
            label: '検知',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bedtime_outlined),
            selectedIcon: Icon(Icons.bedtime),
            label: '仮眠',
          ),
          NavigationDestination(
            // A dot on the tab is the only nudge toward the consult card —
            // a persistent pattern deserves to be noticed, but not nagged at.
            icon: Badge(
              isLabelVisible: log.needsClinicalAttention,
              backgroundColor: c.accentAlert,
              child: const Icon(Icons.event_note_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: log.needsClinicalAttention,
              backgroundColor: c.accentAlert,
              child: const Icon(Icons.event_note),
            ),
            label: '記録',
          ),
          const NavigationDestination(
            icon: Icon(Icons.self_improvement_outlined),
            selectedIcon: Icon(Icons.self_improvement),
            label: '改善',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }

  (StatusMode, String, String) _status(
    DrowsinessDetector detector,
    BreathingDetector breathing,
    NapTimerService nap,
    PomodoroService pomo,
    bool anyAlarming,
  ) {
    if (anyAlarming) {
      // 目のアラームは「目を開けるまで止まらない」。残り秒数を出して、
      // 何をすれば止まるのかを画面で言う。
      final remain = (DrowsinessDetector.eyesOpenToStop - detector.openFor)
          .inSeconds
          .clamp(0, DrowsinessDetector.eyesOpenToStop.inSeconds);
      return (
        StatusMode.alert,
        (detector.alarmFiring || breathing.alarmFiring) ? '居眠り検知' : '仮眠タイマー',
        detector.alarmFiring
            ? (detector.openFor > Duration.zero
                  ? '目を開けたまま あと$remain秒'
                  : '⚠ 起きて！目を開けてください')
            : (breathing.alarmFiring ? '⚠ 寝息を検知しました！' : '⏰ 起床時間！'),
      );
    }
    if (nap.phase == NapPhase.running) {
      return (StatusMode.warn, '仮眠タイマー', '${nap.minutes}分仮眠中');
    }
    if (detector.cameraPausedInBackground &&
        detector.state == DetectorState.watching) {
      // 背面ではカメラが取り上げられている。復帰した瞬間にこの表示が
      // 見えるので、何が起きていたのかが分かる。
      return (StatusMode.warn, '居眠り検知', '画面を開くと再開します');
    }
    if (detector.state == DetectorState.watching ||
        breathing.state == MicState.listening) {
      final eyeClosingIn = detector.closedThreshold.inSeconds;
      final eyeRatio = eyeClosingIn == 0
          ? 0.0
          : detector.closedFor.inSeconds / eyeClosingIn;
      final breathClosingIn = breathing.alarmThreshold.inSeconds;
      final breathRatio = breathClosingIn == 0
          ? 0.0
          : breathing.regularFor.inSeconds / breathClosingIn;
      final ratio = eyeRatio > breathRatio ? eyeRatio : breathRatio;
      return (
        ratio > 0.5 ? StatusMode.warn : StatusMode.watching,
        '居眠り検知',
        ratio > 0.5 ? '眠気の兆候あり' : '検知開始中',
      );
    }
    if (pomo.isRunning || pomo.isPaused) {
      return (
        StatusMode.watching,
        'ポモドーロ',
        '${pomo.isWorkPhase ? '作業中' : '休憩中'} ${pomo.formatted}',
      );
    }
    return (StatusMode.idle, '現在のモード', '待機中');
  }
}

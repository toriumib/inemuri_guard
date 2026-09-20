import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../theme/app_theme.dart';

enum StatusMode { idle, watching, warn, alert }

class StatusHero extends StatelessWidget {
  final StatusMode mode;
  final String label;
  final String value;
  final VoidCallback? onSnooze;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryIsStop;
  const StatusHero({
    super.key,
    required this.mode,
    required this.label,
    required this.value,
    this.onSnooze,
    this.primaryLabel,
    this.onPrimary,
    this.primaryIsStop = false,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = switch (mode) {
      StatusMode.idle => c.text,
      StatusMode.watching => c.accentGood,
      StatusMode.warn => c.accentNap,
      StatusMode.alert => c.accentAlert,
    };
    final status = Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(
            mode == StatusMode.alert
                ? Icons.notification_important_outlined
                : mode == StatusMode.watching
                ? Icons.check_circle_outline
                : Icons.info_outline,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
    final Widget? action = onSnooze != null
        ? FilledButton(onPressed: onSnooze, child: const Text('止める'))
        : primaryLabel == null
        ? null
        : OutlinedButton(onPressed: onPrimary, child: Text(primaryLabel!));
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (action == null) return status;
            if (constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(16) > 21) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [status, const SizedBox(height: 8), action],
              );
            }
            return Row(
              children: [
                Expanded(child: status),
                const SizedBox(width: 12),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Pulsing full-screen tint shown while an alarm is firing.
class AlarmFlashOverlay extends StatefulWidget {
  final bool active;
  const AlarmFlashOverlay({super.key, required this.active});

  @override
  State<AlarmFlashOverlay> createState() => _AlarmFlashOverlayState();
}

/// アラーム中の画面。
///
/// 以前は赤を 0.9 秒でふわっと明滅させていた。閉じたまぶた越しに届くのは
/// 色ではなく**明るさの差**なので、白と暗を 2.5Hz で切り替え、しかも
/// 画面の明るさを最大に上げる。終わったら元の明るさに戻す。
/// タップは透過する（止める操作の邪魔をしない）。
class _AlarmFlashOverlayState extends State<AlarmFlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(covariant AlarmFlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _start();
    } else if (!widget.active && oldWidget.active) {
      _stop();
    }
  }

  void _start() {
    _ctrl.repeat(reverse: true);
    // 端末の明るさ設定に関係なく最大へ。失敗しても点滅は続ける。
    ScreenBrightness.instance
        .setApplicationScreenBrightness(1.0)
        .catchError((_) {});
  }

  void _stop() {
    _ctrl.stop();
    ScreenBrightness.instance.resetApplicationScreenBrightness().catchError(
      (_) {},
    );
  }

  @override
  void dispose() {
    if (widget.active) {
      ScreenBrightness.instance.resetApplicationScreenBrightness().catchError(
        (_) {},
      );
    }
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        // 白（不透明に近い）と暗（薄い黒）を往復。UI は一瞬隠れるが、
        // それが目的——まぶた越しの明暗差を最大にする。
        builder: (context, _) => Container(
          color: _ctrl.value > 0.5
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// 暗くて顔が消えたときの「照明」。画面を白く、明るさを最大にして、
/// 前面カメラに顔を見せる。アラームの点滅とは別物なので、鳴っている間は
/// 出さない（呼び出し側で切る）。タップは下へ通す。
class IlluminateOverlay extends StatefulWidget {
  final bool active;
  const IlluminateOverlay({super.key, required this.active});

  @override
  State<IlluminateOverlay> createState() => _IlluminateOverlayState();
}

class _IlluminateOverlayState extends State<IlluminateOverlay> {
  @override
  void initState() {
    super.initState();
    if (widget.active) _brighten();
  }

  @override
  void didUpdateWidget(covariant IlluminateOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _brighten();
    if (!widget.active && oldWidget.active) _restore();
  }

  void _brighten() {
    ScreenBrightness.instance
        .setApplicationScreenBrightness(1.0)
        .catchError((_) {});
  }

  void _restore() {
    ScreenBrightness.instance.resetApplicationScreenBrightness().catchError(
      (_) {},
    );
  }

  @override
  void dispose() {
    if (widget.active) _restore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        color: Colors.white.withValues(alpha: 0.9),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: const Text(
          '暗いので画面で照らしています。\n顔が見つかると元に戻ります。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 15, height: 1.6),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum StatusMode { idle, watching, warn, alert }

class StatusHero extends StatelessWidget {
  final StatusMode mode;
  final String label;
  final String value;
  final VoidCallback? onSnooze;

  /// Start/stop detection straight from the header. The same control also
  /// lives inside the 検知 tab, but that one sits below the fold — and the
  /// header is on every tab, so this is the one that's always reachable.
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
    final dotColor = switch (mode) {
      StatusMode.idle => c.accentGood,
      StatusMode.watching => c.accentGood,
      StatusMode.warn => c.accentNap,
      StatusMode.alert => c.accentAlert,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: mode == StatusMode.alert ? 1.3 : 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.25),
                      blurRadius: 0,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
            // While an alarm is going off, silencing it is the only thing
            // anyone wants — the start/stop control steps aside for snooze.
            if (onSnooze != null)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.accentAlert,
                  foregroundColor: c.accentAlertInk,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                onPressed: onSnooze,
                child: const Text('スヌーズ'),
              )
            else if (primaryLabel != null)
              primaryIsStop
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.text,
                        side: BorderSide(color: c.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      onPressed: onPrimary,
                      child: Text(primaryLabel!),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accentAlert,
                        foregroundColor: c.accentAlertInk,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      onPressed: onPrimary,
                      child: Text(primaryLabel!),
                    ),
          ],
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

class _AlarmFlashOverlayState extends State<AlarmFlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AlarmFlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.active) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final c = AppColors.of(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Container(
          color: c.accentAlert.withValues(alpha: 0.22 * _ctrl.value),
        ),
      ),
    );
  }
}

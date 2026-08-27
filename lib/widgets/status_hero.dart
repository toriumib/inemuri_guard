import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum StatusMode { idle, watching, warn, alert }

class StatusHero extends StatelessWidget {
  final StatusMode mode;
  final String label;
  final String value;
  final VoidCallback? onSnooze;

  const StatusHero({
    super.key,
    required this.mode,
    required this.label,
    required this.value,
    this.onSnooze,
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
            if (onSnooze != null)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.accentAlert,
                  foregroundColor: c.accentAlertInk,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
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

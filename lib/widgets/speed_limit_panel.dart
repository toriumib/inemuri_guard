import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_language.dart';
import '../services/alarm_service.dart';
import '../services/drowsiness_detector.dart';
import '../services/speed_limit_service.dart';
import '../services/stats_service.dart';

/// 制限速度と現在の速度。車モードで見張っている間だけ位置を取る。
/// [service] を渡すと、その持ち主（ドラレコ画面）が止め時を決め、
/// [active] が true の間だけ動く。
class SpeedLimitPanel extends StatefulWidget {
  const SpeedLimitPanel({super.key, this.service, this.active = false});
  final SpeedLimitService? service;
  final bool active;

  @override
  State<SpeedLimitPanel> createState() => _SpeedLimitPanelState();
}

class _SpeedLimitPanelState extends State<SpeedLimitPanel> {
  late final SpeedLimitService svc =
      widget.service ??
      SpeedLimitService(
        onOverspeed: () =>
            unawaited(context.read<AlarmService>().warn().catchError((_) {})),
      );

  @override
  void dispose() {
    if (widget.service == null) svc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsService>();
    final state = context.watch<DrowsinessDetector>().state;
    final watching =
        state == DetectorState.watching || state == DetectorState.alarming;
    final want =
        stats.speedLimitAlert &&
        (widget.service != null ? widget.active : stats.carMode && watching);
    if (want != svc.running) {
      scheduleMicrotask(() => want ? svc.start() : svc.stop());
    }
    if (!stats.speedLimitAlert) return const SizedBox();
    if (widget.service == null && !stats.carMode) return const SizedBox();
    final l = context.l10n;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        if (!svc.running && svc.error == null) return const SizedBox();
        final err = switch (svc.error) {
          'denied' => l.speedLimitDenied,
          'location-off' => l.speedLimitLocationOff,
          'network' => l.speedLimitNetwork,
          _ => null,
        };
        final over =
            svc.limit != null &&
            svc.speed != null &&
            svc.speed! > svc.limit! + OverspeedJudge.margin;
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: over ? Colors.red : Colors.red.shade700,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Text(
                            svc.limit?.toString() ?? '–',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        svc.limit == null
                            ? l.speedLimitUnknown
                            : l.speedLimitNow('${svc.limit}'),
                      ),
                    ),
                    if (svc.speed != null)
                      Text(
                        l.speedNow(svc.speed!.round().toString()),
                        style: TextStyle(
                          color: over ? Colors.red : null,
                          fontWeight: over ? FontWeight.bold : null,
                        ),
                      ),
                  ],
                ),
                if (err != null) ...[const SizedBox(height: 6), Text(err)],
                const SizedBox(height: 4),
                Text(l.osmCredit, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }
}

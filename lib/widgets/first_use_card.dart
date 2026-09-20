import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/stats_service.dart';
import '../services/drowsiness_detector.dart';
import '../services/alarm_service.dart';

class FirstUseCard extends StatefulWidget {
  const FirstUseCard({super.key});
  @override
  State<FirstUseCard> createState() => _FirstUseCardState();
}

class _FirstUseCardState extends State<FirstUseCard> {
  bool _tried = false, _busy = false, _dismissed = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsService>();
    final detector = context.watch<DrowsinessDetector>();
    if (stats.setupCompleted || _dismissed) return const SizedBox.shrink();
    final ready =
        detector.state == DetectorState.watching &&
        !detector.inputStalled &&
        !detector.cameraPausedInBackground &&
        !detector.noFaceSeen &&
        detector.eyesAvailable;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.setupTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(ready ? context.l10n.setupReady : context.l10n.setupSteps),
            if (_error != null) Text(_error!),
            OutlinedButton.icon(
              onPressed: !ready || _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        await context.read<AlarmService>().preview();
                        if (mounted) setState(() => _tried = true);
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => _error = context.l10n.soundOutputFailed,
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: const Icon(Icons.volume_up),
              label: Text(context.l10n.checkSound),
            ),
            if (_tried)
              FilledButton(
                onPressed: !ready || _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await stats.completeSetup();
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              _busy = false;
                              _error = context.l10n.saveFailed;
                            });
                          }
                        }
                      },
                child: Text(context.l10n.setupComplete),
              ),
            TextButton(
              onPressed: () => setState(() => _dismissed = true),
              child: Text(context.l10n.dismissForNow),
            ),
            Text(context.l10n.setupHint),
          ],
        ),
      ),
    );
  }
}

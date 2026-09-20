import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/drowsiness_detector.dart';
import '../services/breathing_detector.dart';
import '../services/alert_coordinator.dart';

class MonitoringStatus extends StatelessWidget {
  const MonitoringStatus({super.key});
  @override
  Widget build(BuildContext context) {
    final detector = context.watch<DrowsinessDetector>();
    final breathing = context.watch<BreathingDetector>();
    final alerts = context.watch<AlertCoordinator>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detector.monitoringLabelFor(context.l10n),
          key: const Key('camera-health'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (detector.state == DetectorState.watching &&
            (detector.noFaceSeen ||
                detector.inputStalled ||
                !detector.eyesAvailable))
          Text(
            detector.inputStalled
                ? context.l10n.cameraRecoveryHint
                : detector.noFaceSeen
                ? context.l10n.faceRecoveryHint
                : context.l10n.eyeRecoveryHint,
          ),
        if (breathing.state != MicState.idle)
          Text(switch (breathing.state) {
            MicState.listening => context.l10n.micListening,
            MicState.starting => context.l10n.micStarting,
            MicState.failed => breathing.failure ?? context.l10n.micStopped,
            MicState.denied => context.l10n.micPermission,
            MicState.idle => '',
          }, key: const Key('mic-health')),
        if (alerts.outputFailure != null) Text(alerts.outputFailure!),
      ],
    );
  }
}

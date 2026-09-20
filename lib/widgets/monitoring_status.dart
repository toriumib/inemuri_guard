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
          detector.monitoringLabel,
          key: const Key('camera-health'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (detector.state == DetectorState.watching &&
            (detector.noFaceSeen ||
                detector.inputStalled ||
                !detector.eyesAvailable))
          Text(
            detector.inputStalled
                ? '下の「カメラをつなぎ直す」を押してください。他のアプリがカメラを使用中なら閉じてください。'
                : detector.noFaceSeen
                ? '一人でカメラに映り、顔を明るくしてください。対象が変わったときは見張りを再開してください。'
                : '眼鏡の反射や顔の向きを調整してください。目を読み取れない間は閉眼を判定できません。',
          ),
        if (breathing.state != MicState.idle)
          Text(switch (breathing.state) {
            MicState.listening => 'マイク入力あり（呼吸音の補助検知）',
            MicState.starting => 'マイクを起動中',
            MicState.failed => breathing.failure ?? 'マイク入力停止',
            MicState.denied => 'マイク権限を確認してください',
            MicState.idle => '',
          }, key: const Key('mic-health')),
        if (alerts.outputFailure != null) Text(alerts.outputFailure!),
      ],
    );
  }
}

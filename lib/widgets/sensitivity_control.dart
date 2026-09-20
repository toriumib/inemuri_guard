import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/stats_service.dart';
import '../services/drowsiness_detector.dart';
import '../theme/app_theme.dart';
import 'range_slider_row.dart';

class SensitivityControl extends StatelessWidget {
  const SensitivityControl({super.key});
  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsService>();
    final detector = context.watch<DrowsinessDetector>();
    final enabled = detector.state != DetectorState.starting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('検知の感度', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final option in DetectionSensitivity.values)
              ChoiceChip(
                label: Text(switch (option) {
                  DetectionSensitivity.standard => '標準',
                  DetectionSensitivity.sensitive => '敏感',
                  DetectionSensitivity.custom => '詳細設定',
                }),
                selected: stats.sensitivity == option,
                onSelected: enabled
                    ? (_) async {
                        detector.setThresholdSeconds(
                          option == DetectionSensitivity.standard
                              ? 5
                              : option == DetectionSensitivity.sensitive
                              ? 3
                              : stats.eyeThresholdSeconds,
                        );
                        await stats.setSensitivity(option);
                      }
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '閉眼・姿勢の傾きが連続${stats.eyeThresholdSeconds}秒で警告。'
          '敏感にすると短い動作でも鳴りやすくなります。PERCLOSと呼吸音の設定は変わりません。',
        ),
        if (stats.sensitivity == DetectionSensitivity.custom)
          RangeSliderRow(
            title: '連続何秒で知らせる？',
            value: stats.eyeThresholdSeconds,
            color: AppColors.of(context).accentAlert,
            onChanged: (value) {
              detector.setThresholdSeconds(value);
              stats.setEyeThresholdSeconds(value);
            },
          ),
      ],
    );
  }
}

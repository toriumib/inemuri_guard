import '../l10n/app_language.dart';
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
        Text(
          context.l10n.sensitivityTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final option in DetectionSensitivity.values)
              ChoiceChip(
                label: Text(switch (option) {
                  DetectionSensitivity.standard =>
                    context.l10n.sensitivityStandard,
                  DetectionSensitivity.sensitive =>
                    context.l10n.sensitivitySensitive,
                  DetectionSensitivity.custom => context.l10n.sensitivityCustom,
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
        Text(context.l10n.sensitivityExplanation(stats.eyeThresholdSeconds)),
        if (stats.sensitivity == DetectionSensitivity.custom)
          RangeSliderRow(
            title: context.l10n.thresholdTitle,
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

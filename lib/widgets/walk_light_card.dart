import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../screens/dashcam_screen.dart';
import '../screens/walk_screen.dart';
import '../services/torch.dart';

/// 夜道ライト。歩く人が車に見つけてもらうための点滅（Torch.beacon）。
class WalkLightCard extends StatelessWidget {
  const WalkLightCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        key: const PageStorageKey('walk-light'),
        leading: const Icon(Icons.directions_walk),
        title: Text(context.l10n.walkLightTitle),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.walkLightBody),
          const SizedBox(height: 12),
          if (!Torch.isSupported)
            Text(context.l10n.walkLightUnsupported)
          else
            ValueListenableBuilder<bool>(
              valueListenable: Torch.beaconOn,
              builder: (context, on, _) => FilledButton.icon(
                onPressed: () => on ? Torch.stop() : Torch.beacon(),
                icon: Icon(on ? Icons.flashlight_off : Icons.flashlight_on),
                label: Text(
                  on ? context.l10n.walkLightStop : context.l10n.walkLightStart,
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WalkScreen()),
            ),
            icon: const Icon(Icons.directions_walk),
            label: Text(context.l10n.walkModeOpen),
          ),
        ],
      ),
    );
  }
}

/// ドラレコの入口。
class DashcamCard extends StatelessWidget {
  const DashcamCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.videocam_outlined),
        title: Text(context.l10n.dashcamTitle),
        subtitle: Text(context.l10n.dashcamOpen),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DashcamScreen()),
        ),
      ),
    );
  }
}

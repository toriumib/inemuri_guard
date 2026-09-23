import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
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
        ],
      ),
    );
  }
}

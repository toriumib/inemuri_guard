import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/device_readiness.dart';

class QuickSetupCard extends StatelessWidget {
  const QuickSetupCard({super.key, this.showShortcut = false});
  final bool showShortcut;
  Future<void> _open(BuildContext context, String action) async {
    final readiness = context.read<DeviceReadiness>();
    if (action == 'notificationSettings') {
      final permission = await Permission.notification.request();
      if (permission.isGranted) {
        await readiness.refresh();
        return;
      }
    }
    final ok = await readiness.open(action);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.deviceSettingsFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceReadiness>();
    if (!device.silent && device.notifications != false && !showShortcut) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.beforeUsing,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (device.silent) ...[
              Text(context.l10n.volumeZero),
              OutlinedButton.icon(
                onPressed: device.busy
                    ? null
                    : () => _open(context, 'soundSettings'),
                icon: const Icon(Icons.volume_up_outlined),
                label: Text(context.l10n.openVolume),
              ),
            ],
            if (device.notifications == false) ...[
              Text(context.l10n.notificationHint),
              OutlinedButton.icon(
                onPressed: device.busy
                    ? null
                    : () => _open(context, 'notificationSettings'),
                icon: const Icon(Icons.notifications_outlined),
                label: Text(context.l10n.enableNotifications),
              ),
            ],
            if (showShortcut) ...[
              Text(context.l10n.shortcutHint),
              if (device.canAddTile)
                OutlinedButton.icon(
                  onPressed: device.busy || device.tileAdded
                      ? null
                      : () => _open(context, 'addTile'),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: Text(
                    device.tileAdded
                        ? context.l10n.shortcutAdded
                        : context.l10n.addShortcut,
                  ),
                )
              else
                Text(context.l10n.shortcutManual),
            ],
          ],
        ),
      ),
    );
  }
}

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
        const SnackBar(content: Text('設定を変更できませんでした。端末の設定から変更できます。')),
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
            Text('使う前に確認', style: Theme.of(context).textTheme.titleMedium),
            if (device.silent) ...[
              const Text('アラーム音量が0です。音量を上げて「音を試す」で確認してください。'),
              OutlinedButton.icon(
                onPressed: device.busy
                    ? null
                    : () => _open(context, 'soundSettings'),
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('音量の設定を開く'),
              ),
            ],
            if (device.notifications == false) ...[
              const Text('通知を許可すると、アプリの外からもアラームを止められます。'),
              OutlinedButton.icon(
                onPressed: device.busy
                    ? null
                    : () => _open(context, 'notificationSettings'),
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('通知を使えるようにする'),
              ),
            ],
            if (showShortcut) ...[
              const Text('画面上から下にスワイプするクイック設定に置くと、アプリを探さず開けます。'),
              if (device.canAddTile)
                OutlinedButton.icon(
                  onPressed: device.busy || device.tileAdded
                      ? null
                      : () => _open(context, 'addTile'),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: Text(device.tileAdded ? 'クイック設定に追加済み' : 'クイック設定に追加'),
                )
              else
                const Text('クイック設定の編集ボタンから「居眠りガード」を追加できます。'),
            ],
          ],
        ),
      ),
    );
  }
}

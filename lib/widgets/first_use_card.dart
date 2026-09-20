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
            Text('はじめの準備', style: Theme.of(context).textTheme.titleLarge),
            Text(
              ready
                  ? '顔と目を確認できました。次は音を確かめましょう。'
                  : '① 下の「見張りを始める」を押してカメラを許可\n② 顔と目が映る位置に置く\n③ 音を確認する',
            ),
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
                            () => _error = '再生できませんでした。音量や出力先を確認してください。',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: const Icon(Icons.volume_up),
              label: const Text('音を確認する'),
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
                              _error = '保存できませんでした。もう一度お試しください。';
                            });
                          }
                        }
                      },
                child: const Text('聞こえた・準備完了'),
              ),
            TextButton(
              onPressed: () => setState(() => _dismissed = true),
              child: const Text('今回は閉じる'),
            ),
            const Text('次回からこの案内を省き、前回の設定で使えます。通知や時計は設定から後で追加できます。'),
          ],
        ),
      ),
    );
  }
}

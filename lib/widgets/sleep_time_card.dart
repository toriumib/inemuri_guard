import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/sleep_time_log_service.dart';
import '../theme/app_theme.dart';

/// 睡眠時間の記録カード。記録タブ、「指摘された」の直下。
///
/// 寝た時刻と起きた時刻だけを入れる。日中の眠気が「寝不足」のせいかを、
/// あとから自分で確かめるための日記。診断ではないし、相談カードの
/// 判定にも流し込まない。
class SleepTimeCard extends StatefulWidget {
  const SleepTimeCard({super.key});

  @override
  State<SleepTimeCard> createState() => _SleepTimeCardState();
}

class _SleepTimeCardState extends State<SleepTimeCard> {
  late DateTime _wakeDate;
  late TimeOfDay _bed;
  late TimeOfDay _wake;
  String? _message;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _wakeDate = DateTime(now.year, now.month, now.day);
    _bed = const TimeOfDay(hour: 23, minute: 0);
    // 5分に丸めた「今」。起きてすぐ開く使い方を想定。
    _wake = TimeOfDay(hour: now.hour, minute: (now.minute ~/ 5) * 5);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _wakeDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _wakeDate = d);
  }

  Future<void> _pickTime(bool bed) async {
    final t = await showTimePicker(
      context: context,
      initialTime: bed ? _bed : _wake,
    );
    if (t == null) return;
    setState(() => bed ? _bed = t : _wake = t);
  }

  Future<void> _save() async {
    final log = context.read<SleepTimeLogService>();
    var wake = DateTime(
      _wakeDate.year,
      _wakeDate.month,
      _wakeDate.day,
      _wake.hour,
      _wake.minute,
    );
    var bed = DateTime(
      _wakeDate.year,
      _wakeDate.month,
      _wakeDate.day,
      _bed.hour,
      _bed.minute,
    );
    // 23:00 に寝て 6:30 に起きた → 寝たのは前の晩。
    if (!bed.isBefore(wake)) bed = bed.subtract(const Duration(days: 1));
    final ok = await log.add(bed: bed, wake: wake);
    setState(() {
      _message = ok
          ? '記録しました。${_fmtHours(wake.difference(bed).inMinutes / 60)}'
          : '時刻の組み合わせがおかしいようです。';
    });
  }

  static String _fmtHours(double h) => '${h.toStringAsFixed(1)}時間';
  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _fmtTod(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final log = context.watch<SleepTimeLogService>();
    final week = log.lastDays(7);
    final avg = log.averageHours(7);
    final counted = week.whereType<double>().length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('睡眠時間', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '寝た時刻と起きた時刻だけを記録します。日中の眠気が「寝不足」の'
              'せいかを、あとから自分で確かめるためのものです。診断ではありません。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            _PickRow(
              label: '起きた日',
              value:
                  '${_wakeDate.month}/${_wakeDate.day}',
              onTap: _pickDate,
            ),
            _PickRow(
              label: '寝た時刻',
              hint: '起きた時刻より遅ければ前の晩として扱います',
              value: _fmtTod(_bed),
              onTap: () => _pickTime(true),
            ),
            _PickRow(
              label: '起きた時刻',
              value: _fmtTod(_wake),
              onTap: () => _pickTime(false),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accentNap,
                    foregroundColor: c.accentNapInk,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _save,
                  child: const Text('記録する'),
                ),
                const SizedBox(width: 12),
                if (_message != null)
                  Expanded(
                    child: Text(
                      _message!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _WeekBars(hours: week, color: c.accentNap),
            const SizedBox(height: 8),
            Center(
              child: Text(
                avg == null
                    ? 'まだ記録がありません。'
                    : '7日平均 ${_fmtHours(avg)}（$counted日ぶん）',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (log.entries.isNotEmpty) ...[
              Divider(height: 26, color: c.border),
              for (final e in log.entries.take(14))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${e.wake.month}/${e.wake.day}  '
                          '${_two(e.bed.hour)}:${_two(e.bed.minute)} → '
                          '${_two(e.wake.hour)}:${_two(e.wake.minute)}  '
                          '${_fmtHours(e.hours)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: '消す',
                        onPressed: () => log.remove(e),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final String label;
  final String? hint;
  final String value;
  final VoidCallback onTap;
  const _PickRow({
    required this.label,
    this.hint,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      subtitle: hint == null ? null : Text(hint!),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

/// 直近7日の棒。記録の無い日は薄い短い棒で「無い」と分かるように。
/// 10時間で満杯。
class _WeekBars extends StatelessWidget {
  final List<double?> hours;
  final Color color;
  const _WeekBars({required this.hours, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const labels = ['日', '月', '火', '水', '木', '金', '土'];
    final today = DateTime.now();
    return Column(
      children: [
        SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < hours.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      height: hours[i] == null
                          ? 3
                          : (hours[i]! / 10 * 70).clamp(3, 70),
                      decoration: BoxDecoration(
                        color: hours[i] == null
                            ? c.border
                            : color.withValues(alpha: 0.8),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < hours.length; i++)
              Expanded(
                child: Text(
                  labels[today
                      .subtract(Duration(days: hours.length - 1 - i))
                      .weekday %
                      7],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: c.textDim),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

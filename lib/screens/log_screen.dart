import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sleep_symptoms.dart';
import '../services/sleep_log_service.dart';
import '../theme/app_theme.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = context.watch<SleepLogService>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _RecordCard(),
        const SizedBox(height: 16),
        _PatternCard(log: log),
        const SizedBox(height: 16),
        if (log.needsClinicalAttention) ...[
          const _ConsultCard(),
          const SizedBox(height: 16),
        ],
        _SymptomCard(log: log),
        const SizedBox(height: 16),
        _HistoryCard(log: log),
      ],
    );
  }
}

/// The manual "someone told me I was asleep" button. Being noticed by another
/// person is a stronger signal than a sensor hit, so it gets top billing.
class _RecordCard extends StatelessWidget {
  const _RecordCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final log = context.read<SleepLogService>();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('居眠りを記録', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '人から「寝てたよ」と言われたときに押してください。'
              'アプリが検知できなかった居眠りも記録に残せます。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: c.accentAlert,
                  foregroundColor: c.accentAlertInk,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.record_voice_over_outlined, size: 20),
                label: const Text('指摘された'),
                onPressed: () async {
                  await log.add(SleepEventType.pointedOut);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('記録しました'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  final SleepLogService log;
  const _PatternCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const week = Duration(days: 7);
    const fortnight = Duration(days: 14);

    final weekUnintended = log.unintendedSince(week).length;
    final daysAffected = log.daysAffectedLast(fortnight);
    final pointedOut = log.countLast(fortnight, SleepEventType.pointedOut);
    final histogram = log.hourHistogram(const Duration(days: 30));
    final peak = _peakHour(histogram);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('パターン', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            _StatLine(label: '今週の居眠り', value: '$weekUnintended回'),
            _StatLine(label: '過去2週間で居眠りした日数', value: '$daysAffected日'),
            _StatLine(label: '過去2週間に指摘された回数', value: '$pointedOut回'),
            if (peak != null) _StatLine(label: '起きやすい時間帯', value: '$peak時ごろ'),
            const SizedBox(height: 14),
            Text(
              '時間帯の分布（過去30日）',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            _HourChart(histogram: histogram, color: c.accentAlert),
          ],
        ),
      ),
    );
  }

  int? _peakHour(List<int> histogram) {
    var best = -1;
    var bestCount = 0;
    for (var h = 0; h < histogram.length; h++) {
      if (histogram[h] > bestCount) {
        bestCount = histogram[h];
        best = h;
      }
    }
    return bestCount == 0 ? null : best;
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _StatLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: c.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// 24 slim bars — enough to see "always after lunch" vs "all day", which is
/// exactly the distinction worth bringing to a doctor.
class _HourChart extends StatelessWidget {
  final List<int> histogram;
  final Color color;
  const _HourChart({required this.histogram, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final maxValue = histogram.fold<int>(0, (m, v) => v > m ? v : m);
    return Column(
      children: [
        SizedBox(
          height: 54,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var h = 0; h < 24; h++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.7),
                    child: Container(
                      height: maxValue == 0
                          ? 2
                          : (histogram[h] / maxValue * 50).clamp(2, 50),
                      decoration: BoxDecoration(
                        color: histogram[h] == 0
                            ? c.border
                            : color.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final t in ['0時', '6時', '12時', '18時', '23時'])
              Text(t, style: TextStyle(fontSize: 10, color: c.textDim)),
          ],
        ),
      ],
    );
  }
}

/// Shown only when the pattern has persisted. Says "go talk to a doctor" —
/// never "you have X".
class _ConsultCard extends StatelessWidget {
  const _ConsultCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.accentAlert.withValues(alpha: 0.5)),
          color: c.accentAlert.withValues(alpha: 0.06),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_hospital_outlined,
                  size: 18,
                  color: c.accentAlert,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '一度受診を検討しませんか',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '日中の居眠りが何日にもわたって続いています。'
              '「気合いが足りない」ではなく、睡眠時無呼吸症候群・ナルコレプシー・糖尿病・'
              '甲状腺機能低下症・貧血など、治療できる病気が背景にあることがあります。\n\n'
              '睡眠外来、または内科・かかりつけ医に相談してみてください。'
              'このアプリの記録画面を見せると、いつ・どのくらい眠くなるかを説明しやすくなります。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: c.border),
              ),
              child: Text(
                'これは診断ではありません。このアプリは記録を取るだけで、'
                '病気があるかどうかを判定することはできません。',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SymptomCard extends StatelessWidget {
  final SleepLogService log;
  const _SymptomCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final checkedUrgent = sleepSymptoms.any(
      (s) => s.urgent && log.checkedSymptomIds.contains(s.id),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('気になる症状', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '当てはまるものにチェックすると、受診時に伝えるべき内容がまとまります。'
              'チェックの数で病気が決まるわけではありません。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            for (final s in sleepSymptoms)
              _SymptomTile(
                symptom: s,
                checked: log.checkedSymptomIds.contains(s.id),
                onChanged: (v) => log.toggleSymptom(s.id, v),
              ),
            if (checkedUrgent) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.accentAlert.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: c.accentAlert.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: c.accentAlert,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '運転中の眠気は命に関わります。原因がはっきりするまで運転は控え、'
                        '早めに医療機関を受診してください。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

class _SymptomTile extends StatelessWidget {
  final SleepSymptom symptom;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _SymptomTile({
    required this.symptom,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: Checkbox(
                value: checked,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    symptom.label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 13.5,
                      fontWeight: symptom.urgent
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: symptom.urgent ? c.accentAlert : c.text,
                    ),
                  ),
                  if (checked) ...[
                    const SizedBox(height: 3),
                    Text(
                      symptom.detail,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 11.5),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        for (final r in symptom.related)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: c.surface2,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: c.border),
                            ),
                            child: Text(
                              r,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: c.textDim,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final SleepLogService log;
  const _HistoryCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final recent = log.events.take(30).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('履歴', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '記録は端末内にのみ保存され、約90日で自動的に消えます。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            if (recent.isEmpty)
              Text('まだ記録はありません。', style: Theme.of(context).textTheme.bodyMedium)
            else
              for (final e in recent)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        switch (e.type) {
                          SleepEventType.pointedOut =>
                            Icons.record_voice_over_outlined,
                          SleepEventType.detected => Icons.visibility_outlined,
                          SleepEventType.nap => Icons.bedtime_outlined,
                        },
                        size: 17,
                        color: e.type == SleepEventType.nap
                            ? c.accentNap
                            : c.accentAlert,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          e.note == null
                              ? e.type.label
                              : '${e.type.label}・${e.note}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(fontSize: 13),
                        ),
                      ),
                      Text(
                        _fmt(e.time),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          color: c.textDim,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.only(left: 6),
                        tooltip: 'この記録を削除',
                        onPressed: () => log.remove(e),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime t) {
    two(int v) => v.toString().padLeft(2, '0');
    return '${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}';
  }
}

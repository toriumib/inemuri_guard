import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 「何秒／何分」を1本のスライダーで選ぶ行。
///
/// 選択肢を並べる形だと、刻みの間の値（7秒、12秒）が選べず、しかも
/// 選択肢を増やすほど画面を食う。連続量にはスライダーが素直。
/// 検知のしきい値（秒）とポモドーロの長さ（分）で共用している。
///
/// 保存は指を離したときだけ。動かすたびに書くと、指の動きに
/// SharedPreferences への書き込みが張り付く。
class RangeSliderRow extends StatefulWidget {
  final String title;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String unit;
  final String minLabel;
  final String maxLabel;
  const RangeSliderRow({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.onChanged,
    this.min = 3,
    this.max = 60,
    this.step = 1,
    this.unit = '秒',
    this.minLabel = '敏感',
    this.maxLabel = '鈍感',
  });

  @override
  State<RangeSliderRow> createState() => RangeSliderRowState();
}

class RangeSliderRowState extends State<RangeSliderRow> {
  /// 指を動かしている間の値。離すまで保存しない（動かすたびに
  /// SharedPreferences へ書くと、指の動きに書き込みが張り付く）。
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final shown = (_dragging ?? widget.value.toDouble()).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              '$shown${widget.unit}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: widget.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          value: shown.toDouble().clamp(
            widget.min.toDouble(),
            widget.max.toDouble(),
          ),
          min: widget.min.toDouble(),
          max: widget.max.toDouble(),
          divisions: (widget.max - widget.min) ~/ widget.step,
          label: '$shown${widget.unit}',
          activeColor: widget.color,
          // 溝の色を明示する。テーマ任せだとカードの白地に溶けて、
          // つまみだけが宙に浮いて見える（実機で確認）。
          inactiveColor: c.border,
          onChanged: (v) => setState(() => _dragging = v),
          onChangeEnd: (v) {
            setState(() => _dragging = null);
            widget.onChanged(v.round());
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.min}${widget.unit}（${widget.minLabel}）',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 12, color: c.textDim),
            ),
            Text(
              '${widget.max}${widget.unit}（${widget.maxLabel}）',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 12, color: c.textDim),
            ),
          ],
        ),
      ],
    );
  }
}

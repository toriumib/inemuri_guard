// 走行動画の検出結果（tools/road_eval/detect_video.py の出力）を、
// アプリと同じ判定（DriveJudge）で再生し、知らせの回数と 1 時間あたりの数を出す。
//
//   dart run tool/replay_road.dart out.jsonl [速度km/h] [--trace]
//
// 速度は動画に入っていないので、一定の値を渡す（既定 40km/h）。
// 誤報の数え方: 出た知らせを動画で見返し、本当に危なかったかを人が判定する。
// 時刻を出すのはそのため。
import 'dart:convert';
import 'dart:io';

import 'package:inemuri_guard/services/road_logic.dart';

RoadKind _kind(String k) => RoadKind.values.firstWhere(
  (v) => v.name == k,
  orElse: () => RoadKind.other,
);

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/replay_road.dart out.jsonl [speedKmh]');
    exit(64);
  }
  final trace = args.contains('--trace');
  final rest = args.where((a) => a != '--trace').toList();
  final speed = rest.length > 1 ? double.parse(rest[1]) : 40.0;
  final judge = DriveJudge();
  final t0 = DateTime(2026);
  final counts = <RoadEvent, int>{};
  var lastMs = 0;
  for (final line in File(rest[0]).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final j = jsonDecode(line) as Map<String, dynamic>;
    final ms = j['t'] as int;
    lastMs = ms;
    final objs = [
      for (final o in j['o'] as List)
        RoadObject(
          _kind(o['k'] as String),
          (o['s'] as num).toDouble(),
          (o['l'] as num).toDouble(),
          (o['t'] as num).toDouble(),
          (o['r'] as num).toDouble(),
          (o['b'] as num).toDouble(),
        ),
    ];
    final events = judge.feed(
      objects: objs,
      now: t0.add(Duration(milliseconds: ms)),
      speedKmh: speed,
    );
    if (trace) {
      final l = judge.lead;
      stdout.writeln(
        '  t=${ms}ms lead=${l == null ? '-' : l.width.toStringAsFixed(3)} '
        'ttc=${judge.ttc?.toStringAsFixed(2) ?? '-'}',
      );
    }
    for (final e in events) {
      counts[e] = (counts[e] ?? 0) + 1;
      final s = ms / 1000;
      stdout.writeln(
        '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toStringAsFixed(1).padLeft(4, '0')}  ${e.name}',
      );
    }
  }
  final hours = lastMs / 3600000;
  stdout.writeln('--- ${(lastMs / 1000).toStringAsFixed(0)} 秒');
  for (final e in counts.entries) {
    final perHour = hours > 0 ? e.value / hours : 0;
    stdout.writeln('${e.key.name}: ${e.value} 回（1 時間あたり ${perHour.toStringAsFixed(1)} 回）');
  }
}

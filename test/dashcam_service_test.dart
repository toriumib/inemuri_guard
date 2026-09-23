import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/dashcam_service.dart';

void main() {
  test('新しい順に keep 本を残し、古いものだけを消す', () {
    final paths = [
      '/d/20260923-100300.mp4',
      '/d/20260923-100000.mp4',
      '/d/20260923-100200.mp4',
      '/d/20260923-100100.mp4',
    ];
    expect(DashcamService.overflow(paths, 2), [
      '/d/20260923-100100.mp4',
      '/d/20260923-100000.mp4',
    ]);
    expect(DashcamService.overflow(paths, 4), isEmpty);
  });

  test('ファイル名は並べ替えで時刻順になる形', () {
    expect(DashcamService.stamp(DateTime(2026, 9, 3, 7, 5, 9)), '20260903-070509');
  });
}

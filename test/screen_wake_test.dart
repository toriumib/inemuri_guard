import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/screen_wake.dart';

void main() {
  setUp(ScreenWake.resetForTest);

  group('ScreenWake ref counting', () {
    test('stays held until every holder releases', () async {
      await ScreenWake.acquire('detect');
      await ScreenWake.acquire('nap');
      expect(ScreenWake.isHeld, isTrue);

      // The bug this guards: detection finishing used to let the screen sleep
      // while a nap was still counting down.
      await ScreenWake.release('detect');
      expect(ScreenWake.isHeld, isTrue);

      await ScreenWake.release('nap');
      expect(ScreenWake.isHeld, isFalse);
    });

    test(
      'acquiring twice under one key still releases with one call',
      () async {
        await ScreenWake.acquire('detect');
        await ScreenWake.acquire('detect');
        await ScreenWake.release('detect');
        expect(ScreenWake.isHeld, isFalse);
      },
    );

    test('releasing a key that never acquired does nothing', () async {
      await ScreenWake.acquire('nap');
      await ScreenWake.release('detect');
      expect(ScreenWake.isHeld, isTrue);
    });
  });
}

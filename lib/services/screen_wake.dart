import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Ref-counted wrapper around the screen wakelock.
///
/// The wakelock is a single global flag, so two independent features holding
/// it at once (detection running *and* a nap counting down) would otherwise
/// clobber each other: whichever finished first would call `disable()` and
/// let the screen sleep while the other still needed it.
///
/// Each holder acquires under its own key and releases the same key; the
/// screen only sleeps again once every holder has let go.
class ScreenWake {
  ScreenWake._();

  static final Set<String> _holders = {};

  static Future<void> acquire(String key) async {
    final wasEmpty = _holders.isEmpty;
    _holders.add(key);
    if (wasEmpty) {
      await _apply(true);
    }
  }

  static Future<void> release(String key) async {
    if (!_holders.remove(key)) return;
    if (_holders.isEmpty) {
      await _apply(false);
    }
  }

  /// Visible for debugging/tests.
  static bool get isHeld => _holders.isNotEmpty;

  @visibleForTesting
  static void resetForTest() => _holders.clear();

  static Future<void> _apply(bool on) async {
    try {
      if (on) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      // No wakelock support (tests, unusual OEM builds) — never crash over it.
      debugPrint('ScreenWake could not set wakelock to $on: $e');
    }
  }
}

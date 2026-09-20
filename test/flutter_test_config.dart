import 'dart:async';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';

/// Existing regression cases use Japanese. Internationalization cases override
/// this explicitly, so a developer's own device locale cannot change a test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.localesTestValue = const [Locale('ja', 'JP')];
  });
  tearDown(binding.platformDispatcher.clearLocalesTestValue);
  await testMain();
}

import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/services/support_service.dart';

void main() {
  test('store and review links use the distributed application id', () {
    expect(
      Uri.parse(SupportService.storeUrl).queryParameters['id'],
      'com.stop.sleeping',
    );
  });
  test(
    'Japanese shares the store; other languages use the English Web entry',
    () {
      expect(
        SupportService.shareMessage('ja'),
        contains(SupportService.storeUrl),
      );
      for (final language in ['en', 'es', 'fr']) {
        final text = SupportService.shareMessage(language);
        expect(text, contains('https://inemuri.toriumis.com/en/'));
        expect(text, isNot(contains('play.google.com')));
        expect(RegExp(r'[\u3040-\u30ff\u3400-\u9fff]').hasMatch(text), false);
      }
    },
  );
}

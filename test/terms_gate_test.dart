import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inemuri_guard/screens/terms_gate.dart';

/// 初回の同意画面。運転用途を残す代わりの入口なので、
/// 「車内の条件が見える」「押すと同意が伝わる」の 2 点だけを固定する。
void main() {
  testWidgets('車内利用の条件と、同意ボタンが出る', (tester) async {
    var accepted = 0;
    await tester.pumpWidget(
      MaterialApp(home: TermsGate(onAccept: () => accepted++)),
    );
    expect(find.textContaining('車内では補助としてのみ'), findsOneWidget);
    expect(find.textContaining('見逃し・誤作動'), findsOneWidget);
    await tester.tap(find.text('同意して始める'));
    expect(accepted, 1);
  });
}

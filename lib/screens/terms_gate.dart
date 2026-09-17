import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// 初回だけの同意画面。運転用途を「外す」代わりに、最初に規約を読んで
/// 同意してもらう（2026-09-18 の決定）。同意するまで HomeShell を出さないので、
/// 自動開始もここを通った後にしか始まらない。
///
/// 全文は Web（inemuri.toriumis.com/terms/）に置き、ここは要点だけ。
/// 版（[version]）を上げると、前の版に同意した人にも再表示される。
class TermsGate extends StatelessWidget {
  /// 規約の版。文面を大きく変えたら上げる（Web の /terms/ の版と揃える）。
  static const version = 1;
  static const url = 'https://inemuri.toriumis.com/terms/';
  static const privacyUrl = 'https://inemuri.toriumis.com/app/privacy/';

  final VoidCallback onAccept;
  const TermsGate({super.key, required this.onAccept});

  static const _points = <(String, String)>[
    ('補助の道具です', '睡眠の代わり・医療機器・安全装置ではありません。'),
    (
      '見逃し・誤作動があります',
      '暗い所、眼鏡・サングラス・マスク、顔がカメラから外れたとき。'
          '鳴らなかったことを安全の根拠にしないでください。',
    ),
    (
      '車内では補助としてのみ、自己責任で',
      '運転者の注意義務の代わりにはなりません。運転中は端末を操作せず、法令に従い、'
          '眠気を感じたら SA・PA・駐車場など安全な場所に停めて休んでください。'
          '依拠による事故・損害の責任は負いません。',
    ),
    ('プライバシー', '映像も音も端末の外に出さず、保存もしません。'),
    ('現状有姿での提供', '正確さや継続を保証しません。有料機能の購入・返金は Google Play の規定に従います。'),
  ];

  static Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 12),
                children: [
                  Text('はじめに、利用規約への同意', style: text.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    '下の要点を読んで「同意して始める」を押すと使えます。',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  for (final (title, body) in _points) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: text.titleSmall),
                          const SizedBox(height: 4),
                          Text(body, style: text.bodyMedium),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => _open(url),
                        child: const Text('利用規約の全文'),
                      ),
                      TextButton(
                        onPressed: () => _open(privacyUrl),
                        child: const Text('プライバシーポリシー'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accentGood,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: onAccept,
                    child: const Text('同意して始める'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '同意しない場合は、このアプリを使えません。',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

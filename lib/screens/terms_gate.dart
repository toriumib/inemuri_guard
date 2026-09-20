import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../l10n/app_language.dart';

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

  static Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final points = [
      (l.termsAidTitle, l.termsAidBody),
      (l.termsMissTitle, l.termsMissBody),
      (l.termsDrivingTitle, l.termsDrivingBody),
      (l.privacyTitle, l.termsPrivacyBody),
      (l.termsAsIsTitle, l.termsAsIsBody),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 12),
                children: [
                  Text(l.termsTitle, style: text.headlineSmall),
                  const SizedBox(height: 6),
                  Text(l.termsIntro, style: text.bodyMedium),
                  const SizedBox(height: 18),
                  for (final (title, body) in points) ...[
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
                        onPressed: () => _open(
                          l.localeName == 'ja'
                              ? url
                              : 'https://inemuri.toriumis.com/en/terms/',
                        ),
                        child: Text(l.termsFull),
                      ),
                      TextButton(
                        onPressed: () => _open(privacyUrl),
                        child: Text(l.privacyLink),
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
                    child: Text(l.agreeStart),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.termsRequired,
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

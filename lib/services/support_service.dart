import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// ☕ Support / word-of-mouth actions, ported from the nanimonjya app's
/// top screen so this app has the same set: share, X, review, coffee.
class SupportService {
  SupportService._();

  static const packageName = 'com.toriumi.inemuri_guard';
  static const buyMeACoffeeUrl = 'https://buymeacoffee.com/toriumi';
  static const storeUrl =
      'https://play.google.com/store/apps/details?id=$packageName';

  static const shareText =
      '会社で居眠りしちゃう人へ。カメラで目の開閉を見て起こしてくれる「居眠りガード」使ってる。'
      '科学的に効果があるとされる10分パワーナップのタイマーも付いてる。';

  /// A review ask that survives Google's quota. `requestReview()` silently
  /// shows nothing when the quota is used up and still reports success, so
  /// a one-shot "ask once ever" design can end up never asking at all.
  /// Callers gate on usage count; this just performs the ask.
  static Future<void> requestInAppReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await openStoreListing();
      }
    } catch (_) {
      // Review API missing (sideloaded / no Play services) — never crash.
    }
  }

  /// Always lands on the store page, unlike the in-app dialog which Google
  /// may swallow. Used for the explicit "評価する" button.
  static Future<void> openStoreListing() async {
    final market = Uri.parse('market://details?id=$packageName');
    try {
      if (await launchUrl(market, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Play app not installed — fall through to the web listing.
    }
    await _open(storeUrl);
  }

  static Future<void> shareApp() async {
    await SharePlus.instance.share(ShareParams(text: '$shareText\n$storeUrl'));
  }

  /// 𝕏 (Twitter) intent URL, same approach as the nanimonjya app.
  static Future<void> shareOnX() async {
    final text = Uri.encodeComponent('$shareText\n$storeUrl');
    await _open('https://twitter.com/intent/tweet?text=$text');
  }

  static Future<void> openBuyMeACoffee() => _open(buyMeACoffeeUrl);

  static Future<bool> _open(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('SupportService could not open $url: $e');
      return false;
    }
  }
}

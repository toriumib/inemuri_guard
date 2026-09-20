import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../services/ad_service.dart';
import '../services/breathing_detector.dart';
import '../services/drowsiness_detector.dart';
import '../services/nap_timer_service.dart';
import '../services/pomodoro_service.dart';

bool monitoringAllowsAds({
  required DetectorState detector,
  required MicState microphone,
  required NapPhase nap,
  required PomoPhase pomodoro,
  required bool alarming,
}) =>
    detector == DetectorState.idle &&
    microphone == MicState.idle &&
    nap == NapPhase.idle &&
    pomodoro == PomoPhase.idle &&
    !alarming;

/// Kept outside IndexedStack so an offstage history tab cannot retain an ad.
class SafeAdPanel extends StatefulWidget {
  const SafeAdPanel({
    super.key,
    required this.historySelected,
    required this.settingsSelected,
    required this.idle,
    required this.setupCompleted,
    required this.premium,
    this.isIdleNow,
  });

  final bool historySelected;
  final bool settingsSelected;
  final bool idle;
  final bool setupCompleted;
  final bool premium;
  final bool Function()? isIdleNow;

  @override
  State<SafeAdPanel> createState() => _SafeAdPanelState();
}

class _SafeAdPanelState extends State<SafeAdPanel> with WidgetsBindingObserver {
  bool _historyVisitEligible = false;
  int _visibilityGeneration = 0;

  bool get _idleForAds =>
      widget.idle &&
      (widget.isIdleNow?.call() ?? true) &&
      widget.setupCompleted &&
      !widget.premium;

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  bool get _canPresent =>
      mounted &&
      _foreground &&
      widget.settingsSelected &&
      widget.idle &&
      (widget.isIdleNow?.call() ?? true);

  bool get _canShowBanner =>
      mounted &&
      _foreground &&
      widget.historySelected &&
      _historyVisitEligible &&
      _idleForAds;

  @override
  void initState() {
    super.initState();
    _historyVisitEligible = widget.historySelected && _idleForAds;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant SafeAdPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.historySelected || !_idleForAds) {
      _historyVisitEligible = false;
    } else if (!oldWidget.historySelected) {
      // Monitoring/alarm completion alone must not bring an ad back. The user
      // chooses the history tab again after finishing the activity.
      _historyVisitEligible = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _visibilityGeneration++);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = context.watch<AdService>();
    // The app-wide localization migration is still in progress. Use the device
    // locale here because MaterialApp currently falls back to English.
    final english =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode != 'ja';
    if (!_foreground) return const SizedBox.shrink();

    if (widget.settingsSelected &&
        (ads.needsForm || ads.privacyOptionsRequired || ads.hasError)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: !widget.idle || ads.busy
                  ? null
                  : () => ads.openPrivacyOptions(canPresent: () => _canPresent),
              icon: const Icon(Icons.privacy_tip_outlined),
              label: Text(english ? 'Ad privacy choices' : '広告のプライバシー設定'),
            ),
            Text(
              !widget.idle
                  ? (english
                        ? 'Stop monitoring and timers to change these settings.'
                        : '検知とタイマーを停止すると変更できます。')
                  : ads.hasError
                  ? (english
                        ? 'Ad settings could not load. Tap to retry. Monitoring still works.'
                        : '広告の設定を読み込めませんでした。タップで再試行できます。検知は使えます。')
                  : (english
                        ? 'You can use monitoring without opening this form.'
                        : 'この画面を開かなくても検知は使えます。'),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_canShowBanner || !ads.canRequestAds) {
      return const SizedBox.shrink();
    }
    return Padding(
      // Keep the banner away from the navigation destinations and stop control.
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: _ConsentBanner(
        key: ValueKey(_visibilityGeneration),
        isEligible: () => _canShowBanner,
      ),
    );
  }
}

class _ConsentBanner extends StatefulWidget {
  const _ConsentBanner({super.key, required this.isEligible});

  final bool Function() isEligible;

  @override
  State<_ConsentBanner> createState() => _ConsentBannerState();
}

class _ConsentBannerState extends State<_ConsentBanner>
    with WidgetsBindingObserver {
  BannerAd? _banner;
  bool _loaded = false;
  bool _active = true;

  bool get _eligible =>
      mounted &&
      _active &&
      widget.isEligible() &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    final ads = context.read<AdService>();
    if (!await ads.prepareBanner(stillEligible: () => _eligible) ||
        !_eligible) {
      return;
    }
    final banner = BannerAd(
      adUnitId: AdIds.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (_banner != ad) return;
          if (!_eligible || !ads.canRequestAds) {
            _release();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          if (_banner == ad) {
            _release();
            if (mounted) setState(() {});
          }
        },
      ),
    );
    _banner = banner;
    try {
      await banner.load();
    } catch (_) {
      _release();
    }
  }

  void _release() {
    final banner = _banner;
    _banner = null;
    _loaded = false;
    if (banner != null) unawaited(banner.dispose().catchError((_) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _active = false;
      _release();
    }
  }

  @override
  void dispose() {
    _active = false;
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (!_loaded || banner == null || !_eligible) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: banner.size.width.toDouble(),
      height: banner.size.height.toDouble(),
      child: AdWidget(ad: banner),
    );
  }
}

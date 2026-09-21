import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告ユニット ID。本番の ID はリポジトリに置かず、ビルド時に
/// `--dart-define=ADMOB_BANNER_UNIT_ID=...` で渡す（tools/build-release.ps1）。
/// 渡されなければ Google の公開テスト ID で動く。フォークした人の
/// ビルドが本番の広告枠を使ってしまわないようにするため。
class AdIds {
  static const _banner = String.fromEnvironment('ADMOB_BANNER_UNIT_ID');
  static String get bannerUnitId => kReleaseMode && _banner.isNotEmpty
      ? _banner
      : 'ca-app-pub-3940256099942544/6300978111'; // Google test banner
}

class AdConsentSnapshot {
  const AdConsentSnapshot({
    this.canRequestAds = false,
    this.needsForm = false,
    this.privacyOptionsRequired = false,
  });

  final bool canRequestAds;
  final bool needsForm;
  final bool privacyOptionsRequired;
}

/// SDK boundary. Monitoring never awaits this service or depends on its result.
class AdConsentGateway {
  Future<void> update() {
    final result = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => result.complete(),
      (error) => result.completeError(error),
    );
    return result.future;
  }

  Future<AdConsentSnapshot> read() async => AdConsentSnapshot(
    canRequestAds: await ConsentInformation.instance.canRequestAds(),
    needsForm:
        await ConsentInformation.instance.getConsentStatus() ==
        ConsentStatus.required,
    privacyOptionsRequired:
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required,
  );

  Future<ConsentForm> loadForm() async {
    if (!await ConsentInformation.instance.isConsentFormAvailable()) {
      throw StateError('Consent form is unavailable');
    }
    final result = Completer<ConsentForm>();
    ConsentForm.loadConsentForm(result.complete, result.completeError);
    return result.future;
  }

  Future<void> showOptions() async {
    FormError? failure;
    await ConsentForm.showPrivacyOptionsForm((error) => failure = error);
    if (failure != null) throw failure!;
  }
}

/// Only banners are used. Consent forms are opened by an explicit settings tap,
/// never by app launch, starting monitoring, or dismissing an alarm.
class AdService extends ChangeNotifier {
  AdService({AdConsentGateway? consent, Future<void> Function()? initializeAds})
    : _consent = consent ?? AdConsentGateway(),
      _initializeAds = initializeAds ?? _initializeSdk;

  static Future<void> _initializeSdk() async {
    await MobileAds.instance.initialize();
  }

  final AdConsentGateway _consent;
  final Future<void> Function() _initializeAds;
  AdConsentSnapshot _snapshot = const AdConsentSnapshot();
  Future<void>? _initialization;
  Future<void>? _sdkInitialization;
  bool _disposed = false;
  bool busy = false;
  bool hasError = false;
  int _revision = 0;

  bool get canRequestAds => !busy && !hasError && _snapshot.canRequestAds;
  bool get needsForm => _snapshot.needsForm;
  bool get privacyOptionsRequired => _snapshot.privacyOptionsRequired;

  Future<void> init() => _initialization ??= refreshConsent();

  Future<void> refreshConsent() async {
    if (busy || _disposed) return;
    busy = true;
    hasError = false;
    _revision++;
    _notify();
    try {
      await _consent.update().timeout(const Duration(seconds: 10));
      _snapshot = await _consent.read();
    } catch (_) {
      // Fail closed; no application-owned cached consent or tracking fallback.
      hasError = true;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> openPrivacyOptions({required bool Function() canPresent}) async {
    if (busy || _disposed || !canPresent()) return;
    if (hasError) {
      await refreshConsent();
      if (hasError || _disposed || !canPresent()) return;
    }
    if (!needsForm && !privacyOptionsRequired) return;
    busy = true;
    _revision++;
    _notify();
    ConsentForm? form;
    try {
      if (needsForm) {
        form = await _consent.loadForm();
        // A shortcut, alarm, tab change or app pause may occur during loading.
        if (_disposed || !canPresent()) return;
        final dismissed = Completer<void>();
        form.show((error) {
          if (error == null) {
            dismissed.complete();
          } else {
            dismissed.completeError(error);
          }
        });
        await dismissed.future;
      } else {
        if (_disposed || !canPresent()) return;
        await _consent.showOptions();
      }
      _snapshot = await _consent.read();
      hasError = false;
    } catch (_) {
      hasError = true;
    } finally {
      if (form != null) {
        try {
          await form.dispose();
        } catch (_) {
          // A native view cleanup failure must not affect monitoring.
        }
      }
      busy = false;
      _notify();
    }
  }

  Future<bool> prepareBanner({required bool Function() stillEligible}) async {
    if (_disposed || !canRequestAds || !stillEligible()) return false;
    final revision = _revision;
    try {
      // Deduplicated and lazy: premium users and monitoring screens never
      // initialize the advertising SDK or preload an unused full-screen ad.
      await (_sdkInitialization ??= _initializeAds());
      if (_disposed || revision != _revision || !stillEligible()) return false;
      final current = await _consent.read();
      return !_disposed &&
          revision == _revision &&
          canRequestAds &&
          current.canRequestAds &&
          stillEligible();
    } catch (_) {
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

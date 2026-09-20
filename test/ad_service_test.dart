import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:inemuri_guard/services/ad_service.dart';

class FakeConsent extends AdConsentGateway {
  AdConsentSnapshot snapshot = const AdConsentSnapshot();
  int updates = 0;
  int formLoads = 0;
  int optionShows = 0;
  bool failUpdate = false;
  Completer<void>? pendingUpdate;
  Completer<ConsentForm>? pendingForm;
  Completer<void>? pendingOptions;
  final form = FakeConsentForm();

  @override
  Future<void> update() async {
    updates++;
    if (failUpdate) throw StateError('offline');
    await pendingUpdate?.future;
  }

  @override
  Future<AdConsentSnapshot> read() async => snapshot;

  @override
  Future<ConsentForm> loadForm() async {
    formLoads++;
    return pendingForm == null ? form : await pendingForm!.future;
  }

  @override
  Future<void> showOptions() async {
    optionShows++;
    await pendingOptions?.future;
  }
}

class FakeConsentForm extends ConsentForm {
  int shows = 0;
  int disposals = 0;
  OnConsentFormDismissedListener? onDismiss;

  @override
  void show(OnConsentFormDismissedListener callback) {
    shows++;
    onDismiss = callback;
  }

  @override
  Future<void> dispose() async => disposals++;
}

const allowedConsent = AdConsentSnapshot(
  canRequestAds: true,
  privacyOptionsRequired: true,
);
const requiredConsent = AdConsentSnapshot(
  needsForm: true,
  privacyOptionsRequired: true,
);

Future<void> flushAsync() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'launch refreshes once without initializing ads or showing forms',
    () async {
      final consent = FakeConsent()..snapshot = requiredConsent;
      var sdkStarts = 0;
      final ads = AdService(
        consent: consent,
        initializeAds: () async => sdkStarts++,
      );
      await Future.wait([ads.init(), ads.init()]);
      expect(consent.updates, 1);
      expect(consent.formLoads, 0);
      expect(consent.optionShows, 0);
      expect(ads.needsForm, true);
      expect(await ads.prepareBanner(stillEligible: () => true), false);
      expect(sdkStarts, 0);
      ads.dispose();
    },
  );

  test(
    'consent update failure cannot use a previously allowed snapshot',
    () async {
      final consent = FakeConsent()..snapshot = allowedConsent;
      var sdkStarts = 0;
      final ads = AdService(
        consent: consent,
        initializeAds: () async => sdkStarts++,
      );
      await ads.init();
      consent.failUpdate = true;
      await ads.refreshConsent();
      expect(ads.hasError, true);
      expect(ads.privacyOptionsRequired, true);
      expect(await ads.prepareBanner(stillEligible: () => true), false);
      expect(sdkStarts, 0);
      consent.failUpdate = false;
      await ads.refreshConsent();
      expect(ads.canRequestAds, true);
      ads.dispose();
    },
  );

  test('inactive placement never initializes the SDK', () async {
    var sdkStarts = 0;
    final ads = AdService(
      consent: FakeConsent()..snapshot = allowedConsent,
      initializeAds: () async => sdkStarts++,
    );
    await ads.init();
    expect(await ads.prepareBanner(stillEligible: () => false), false);
    expect(sdkStarts, 0);
    ads.dispose();
  });

  test(
    'delayed SDK initialization is shared and rechecks monitoring',
    () async {
      final ready = Completer<void>();
      var eligible = true;
      var sdkStarts = 0;
      final ads = AdService(
        consent: FakeConsent()..snapshot = allowedConsent,
        initializeAds: () {
          sdkStarts++;
          return ready.future;
        },
      );
      await ads.init();
      final first = ads.prepareBanner(stillEligible: () => eligible);
      final second = ads.prepareBanner(stillEligible: () => eligible);
      expect(sdkStarts, 1);
      eligible = false;
      ready.complete();
      expect(await first, false);
      expect(await second, false);
      eligible = true;
      expect(await ads.prepareBanner(stillEligible: () => eligible), true);
      expect(sdkStarts, 1);
      ads.dispose();
    },
  );

  test(
    'consent changes invalidate a request waiting for SDK initialization',
    () async {
      final ready = Completer<void>();
      final consent = FakeConsent()..snapshot = allowedConsent;
      final ads = AdService(
        consent: consent,
        initializeAds: () => ready.future,
      );
      await ads.init();
      final request = ads.prepareBanner(stillEligible: () => true);
      consent.snapshot = requiredConsent;
      await ads.refreshConsent();
      ready.complete();
      expect(await request, false);
      ads.dispose();
    },
  );

  test(
    'new native consent status is checked immediately before a request',
    () async {
      final consent = FakeConsent()..snapshot = allowedConsent;
      final ads = AdService(consent: consent, initializeAds: () async {});
      await ads.init();
      consent.snapshot = requiredConsent;
      expect(await ads.prepareBanner(stillEligible: () => true), false);
      ads.dispose();
    },
  );

  test(
    'late consent form is disposed if monitoring starts while loading',
    () async {
      final pending = Completer<ConsentForm>();
      final consent = FakeConsent()
        ..snapshot = requiredConsent
        ..pendingForm = pending;
      final ads = AdService(consent: consent);
      await ads.init();
      var idle = true;
      final open = ads.openPrivacyOptions(canPresent: () => idle);
      await ads.openPrivacyOptions(canPresent: () => idle);
      expect(consent.formLoads, 1);
      idle = false;
      pending.complete(consent.form);
      await open;
      expect(consent.form.shows, 0);
      expect(consent.form.disposals, 1);
      expect(ads.busy, false);
      expect(ads.canRequestAds, false);
      ads.dispose();
    },
  );

  test(
    'explicit form choice refreshes consent and disposes the native form',
    () async {
      final consent = FakeConsent()..snapshot = requiredConsent;
      final ads = AdService(consent: consent);
      await ads.init();
      final open = ads.openPrivacyOptions(canPresent: () => true);
      await flushAsync();
      expect(consent.form.shows, 1);
      expect(ads.canRequestAds, false);
      consent.snapshot = allowedConsent;
      consent.form.onDismiss!(null);
      await open;
      expect(ads.canRequestAds, true);
      expect(consent.form.disposals, 1);
      ads.dispose();
    },
  );

  test('privacy options pause requests and respect a changed choice', () async {
    final pending = Completer<void>();
    final consent = FakeConsent()
      ..snapshot = allowedConsent
      ..pendingOptions = pending;
    final ads = AdService(consent: consent);
    await ads.init();
    await ads.openPrivacyOptions(canPresent: () => false);
    expect(consent.optionShows, 0);
    final open = ads.openPrivacyOptions(canPresent: () => true);
    expect(ads.canRequestAds, false);
    consent.snapshot = requiredConsent;
    pending.complete();
    await open;
    expect(ads.canRequestAds, false);
    expect(ads.privacyOptionsRequired, true);
    ads.dispose();
  });

  test('disposing during an update never notifies a dead service', () async {
    final pending = Completer<void>();
    final consent = FakeConsent()..pendingUpdate = pending;
    final ads = AdService(consent: consent);
    final update = ads.init();
    ads.dispose();
    pending.complete();
    await update;
  });
}

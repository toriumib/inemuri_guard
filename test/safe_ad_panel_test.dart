import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// SDK test codec lets these tests observe real load/dispose calls without ads.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:provider/provider.dart';
import 'package:inemuri_guard/services/ad_service.dart';
import 'package:inemuri_guard/services/breathing_detector.dart';
import 'package:inemuri_guard/services/drowsiness_detector.dart';
import 'package:inemuri_guard/services/nap_timer_service.dart';
import 'package:inemuri_guard/services/pomodoro_service.dart';
import 'package:inemuri_guard/widgets/safe_ad_panel.dart';

import 'ad_service_test.dart' show FakeConsent, allowedConsent, requiredConsent;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  late AdService ads;
  late FakeConsent consent;
  var history = true;
  var settings = false;
  var idle = true;
  var complete = true;
  var premium = false;
  var liveIdle = true;

  Widget app() => ChangeNotifierProvider.value(
    value: ads,
    child: MaterialApp(
      home: Scaffold(
        body: SafeAdPanel(
          historySelected: history,
          settingsSelected: settings,
          idle: idle,
          setupCompleted: complete,
          premium: premium,
          isIdleNow: () => liveIdle,
        ),
      ),
    ),
  );

  int count(String method) => calls.where((c) => c.method == method).length;
  BannerAd lastBanner() =>
      instanceManager.adFor(
            (calls.lastWhere((c) => c.method == 'loadBannerAd').arguments
                as Map)['adId'],
          )!
          as BannerAd;

  setUp(() async {
    calls.clear();
    history = true;
    settings = false;
    idle = true;
    complete = true;
    premium = false;
    liveIdle = true;
    binding.platformDispatcher.localeTestValue = const Locale('ja');
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      instanceManager.channel,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    consent = FakeConsent()..snapshot = allowedConsent;
    ads = AdService(consent: consent, initializeAds: () async {});
    await ads.init();
  });

  tearDown(() {
    ads.dispose();
    binding.platformDispatcher.clearLocaleTestValue();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      instanceManager.channel,
      null,
    );
  });

  test('all detection, recovery, nap and focus phases suppress ads', () {
    bool allowed({
      DetectorState detector = DetectorState.idle,
      MicState microphone = MicState.idle,
      NapPhase nap = NapPhase.idle,
      PomoPhase pomodoro = PomoPhase.idle,
      bool alarming = false,
    }) => monitoringAllowsAds(
      detector: detector,
      microphone: microphone,
      nap: nap,
      pomodoro: pomodoro,
      alarming: alarming,
    );
    expect(allowed(), true);
    for (final phase in DetectorState.values.where(
      (p) => p != DetectorState.idle,
    )) {
      expect(allowed(detector: phase), false, reason: '$phase');
    }
    for (final phase in MicState.values.where((p) => p != MicState.idle)) {
      expect(allowed(microphone: phase), false, reason: '$phase');
    }
    for (final phase in NapPhase.values.where((p) => p != NapPhase.idle)) {
      expect(allowed(nap: phase), false, reason: '$phase');
    }
    for (final phase in PomoPhase.values.where((p) => p != PomoPhase.idle)) {
      expect(allowed(pomodoro: phase), false, reason: '$phase');
    }
    expect(allowed(alarming: true), false);
  });

  testWidgets('requests only after setup on an idle, non-premium history tab', (
    tester,
  ) async {
    complete = false;
    await tester.pumpWidget(app());
    complete = true;
    history = false;
    await tester.pumpWidget(app());
    history = true;
    idle = false;
    await tester.pumpWidget(app());
    idle = true;
    premium = true;
    await tester.pumpWidget(app());
    expect(count('loadBannerAd'), 0);
    premium = false;
    history = false;
    await tester.pumpWidget(app());
    history = true;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(count('loadBannerAd'), 1);
    idle = false;
    await tester.pumpWidget(app());
    expect(count('disposeAd'), 1);
    idle = true;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(
      count('loadBannerAd'),
      1,
      reason: 'Finishing an alarm is not an ad trigger',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('leaving history and buying Premium release pending banners', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    final pending = lastBanner();
    history = false;
    await tester.pumpWidget(app());
    expect(count('disposeAd'), 1);
    pending.listener.onAdLoaded!(pending);
    await tester.pump();
    expect(tester.takeException(), isNull);
    history = true;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(count('loadBannerAd'), 2);
    premium = true;
    await tester.pumpWidget(app());
    expect(count('disposeAd'), 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background immediately disposes ads and cannot load more', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(count('disposeAd'), 1);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpWidget(app());
    expect(count('loadBannerAd'), 1);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(count('loadBannerAd'), 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late SDK readiness rechecks live activity before requesting', (
    tester,
  ) async {
    ads.dispose();
    final ready = Completer<void>();
    ads = AdService(consent: consent, initializeAds: () => ready.future);
    await ads.init();
    await tester.pumpWidget(app());
    liveIdle = false; // Notification/shortcut arrives before the next UI frame.
    ready.complete();
    await tester.pump();
    expect(count('loadBannerAd'), 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ad load failure releases resources without a retry loop', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    final pending = lastBanner();
    pending.listener.onAdFailedToLoad!(
      pending,
      LoadAdError(1, 'test', 'No fill', null),
    );
    await tester.pump(const Duration(seconds: 30));
    expect(count('disposeAd'), 1);
    expect(count('loadBannerAd'), 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('consent changes release ads and settings remain for Premium', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    consent.snapshot = requiredConsent;
    await ads.refreshConsent();
    await tester.pump();
    expect(count('disposeAd'), 1);
    history = false;
    settings = true;
    premium = true;
    idle = false;
    await tester.pumpWidget(app());
    expect(find.text('広告のプライバシー設定'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.byWidgetPredicate((widget) => widget is TextButton),
          )
          .onPressed,
      isNull,
    );
    idle = true;
    await tester.pumpWidget(app());
    await tester.tap(find.text('広告のプライバシー設定'));
    await tester.pump();
    expect(consent.form.shows, 1);
    consent.form.onDismiss!(null);
    await tester.pump();
    expect(count('loadBannerAd'), 1);
    await tester.pumpWidget(const SizedBox());
  });
}

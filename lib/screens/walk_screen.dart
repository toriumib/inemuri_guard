import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/app_language.dart';
import '../services/drowsiness_detector.dart';
import '../services/road_assist.dart';
import '../services/road_logic.dart';
import '../services/torch.dart';
import '../widgets/road_overlay.dart';

/// 歩行モード（WalkSafe・Oko にあたるもの）。背面カメラで
/// 「後ろから来る車」か「信号の色」を見張る。夜道ライトも同じ画面で点滅できる
/// （カメラを開いている間は、そのカメラのライトとして点す）。
class WalkScreen extends StatefulWidget {
  const WalkScreen({super.key});

  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen> with WidgetsBindingObserver {
  RoadMode mode = RoadMode.walkBehind;
  CameraController? controller;
  bool running = false;
  bool light = false;
  String? error;
  Timer? _blink;
  var _tick = 0;
  bool _disposing = false;

  late final RoadAssist road = RoadAssist(
    mode: mode,
    say: (e) => roadEventText(context.l10n, e),
    onAlert: (e) {
      // 後ろの車は長めに 2 回、信号は短く（青）／長く（赤）。
      final pattern = switch (e) {
        RoadEvent.carBehind => [0, 500, 150, 500],
        RoadEvent.signalGo => [0, 150],
        RoadEvent.signalRed => [0, 600],
        _ => [0, 300],
      };
      Vibration.vibrate(pattern: pattern).catchError((_) {});
    },
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) road.start(Localizations.localeOf(context).languageCode);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _stop();
  }

  Future<void> _start() async {
    setState(() => error = null);
    // 単体の夜道ライトはカメラを開くと使えないので、こちらの点滅に引き継ぐ。
    if (Torch.beaconOn.value) {
      await Torch.stop();
      light = true;
    }
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final c = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await c.initialize();
      await c.startImageStream(
        (img) => road.feed(img, c.description.sensorOrientation),
      );
      await WakelockPlus.enable();
      setState(() {
        controller = c;
        running = true;
      });
      if (light) _startBlink();
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  Future<void> _stop() async {
    _blink?.cancel();
    _blink = null;
    final c = controller;
    controller = null;
    if (mounted && !_disposing) setState(() => running = false);
    try {
      await c?.stopImageStream();
    } catch (_) {}
    await c?.dispose();
    await WakelockPlus.disable();
    // 見張りを止めてもライトは続ける（夜道では見張りより大事）。
    if (light) unawaited(Torch.beacon());
  }

  /// 2Hz（200ms 点・300ms 消）。夜道ライト（Torch.beacon）と同じ律動。
  void _startBlink() {
    _blink?.cancel();
    _tick = 0;
    _blink = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final c = controller;
      if (c == null) return;
      final on = _tick % 5 < 2;
      if (_tick % 5 == 0 || _tick % 5 == 2) {
        c.setFlashMode(on ? FlashMode.torch : FlashMode.off).catchError((_) {});
      }
      _tick++;
    });
  }

  void _setLight(bool v) {
    setState(() => light = v);
    if (!running) {
      unawaited(v ? Torch.beacon() : Torch.stop());
      return;
    }
    if (v) {
      _startBlink();
    } else {
      _blink?.cancel();
      _blink = null;
      controller?.setFlashMode(FlashMode.off).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _disposing = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stop());
    road.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = context.watch<DrowsinessDetector>().state;
    final busy =
        state == DetectorState.watching ||
        state == DetectorState.starting ||
        state == DetectorState.alarming;
    final c = controller;
    return Scaffold(
      appBar: AppBar(title: Text(l.walkModeTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<RoadMode>(
            segments: [
              ButtonSegment(
                value: RoadMode.walkBehind,
                icon: const Icon(Icons.directions_car),
                label: Text(l.walkBehind),
              ),
              ButtonSegment(
                value: RoadMode.walkSignal,
                icon: const Icon(Icons.traffic),
                label: Text(l.walkSignal),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) => setState(() {
              mode = s.first;
              road.mode = mode;
            }),
          ),
          const SizedBox(height: 8),
          Text(mode == RoadMode.walkBehind ? l.walkBehindHelp : l.walkSignalHelp),
          const SizedBox(height: 12),
          if (c != null && c.value.isInitialized)
            AspectRatio(
              aspectRatio: 1 / c.value.aspectRatio,
              child: Stack(
                children: [
                  Positioned.fill(child: CameraPreview(c)),
                  Positioned.fill(child: RoadOverlay(assist: road)),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: RoadEventBanner(assist: road),
                  ),
                ],
              ),
            ),
          if (running && mode == RoadMode.walkSignal)
            ListenableBuilder(
              listenable: road,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  switch (road.signal) {
                    SignalColor.red => l.signalRedShort,
                    SignalColor.go => l.signalGoShort,
                    SignalColor.unknown => l.signalUnknownShort,
                  },
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: road.signal == SignalColor.unknown ? 20 : 56,
                    fontWeight: FontWeight.bold,
                    color: switch (road.signal) {
                      SignalColor.red => Colors.red,
                      SignalColor.go => Colors.teal,
                      SignalColor.unknown => null,
                    },
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (busy && !running)
            Text(l.dashcamBusy)
          else
            FilledButton.icon(
              onPressed: running ? _stop : _start,
              icon: Icon(running ? Icons.stop : Icons.play_arrow),
              label: Text(running ? l.walkStop : l.walkStart),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.flashlight_on),
            title: Text(l.walkLightTitle),
            value: light,
            onChanged: _setLight,
          ),
          if (error != null)
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ListenableBuilder(
            listenable: road,
            builder: (context, _) => road.error == null
                ? const SizedBox()
                : Text(
                    road.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_language.dart';
import '../services/alarm_service.dart';
import '../services/dashcam_service.dart';
import '../services/drowsiness_detector.dart';
import '../services/road_assist.dart';
import '../services/road_logic.dart';
import '../services/speed_limit_service.dart';
import '../services/stats_service.dart';
import '../widgets/road_overlay.dart';
import '../widgets/speed_limit_panel.dart';
import 'emergency_screen.dart';

/// ドラレコの画面。開いている間だけ録る（DashcamService の注記を参照）。
class DashcamScreen extends StatefulWidget {
  const DashcamScreen({super.key});

  @override
  State<DashcamScreen> createState() => _DashcamScreenState();
}

class _DashcamScreenState extends State<DashcamScreen>
    with WidgetsBindingObserver {
  final cam = DashcamService();
  late final RoadAssist road = RoadAssist(
    mode: RoadMode.drive,
    say: (e) => roadEventText(context.l10n, e),
    onAlert: (e) {
      // 前方衝突だけは声を待たずに音と振動も（声は 1 秒かかる）。
      if (e == RoadEvent.forwardCollision || e == RoadEvent.overspeed) {
        context.read<AlarmService>().warn().catchError((_) {});
      }
    },
  );
  late final SpeedLimitService speed = SpeedLimitService(
    onOverspeed: () => road.announce(RoadEvent.overspeed),
    onSpeedCamera: (_) => road.announce(RoadEvent.speedCamera),
  );
  bool _emergencyOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cam.refresh();
    cam.onFrame = (img, rot) {
      road.speedKmh = speed.speed;
      road.feed(img, rot);
    };
    cam.onImpact = _openEmergency;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) road.start(Localizations.localeOf(context).languageCode);
    });
  }

  Future<void> _openEmergency() async {
    if (_emergencyOpen || !mounted) return;
    _emergencyOpen = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EmergencyScreen()),
    );
    _emergencyOpen = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 裏に回るとカメラは取り上げられる。録っているふりをしないよう、
    // その場で区切って止める。
    if (state == AppLifecycleState.paused) cam.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cam.dispose();
    road.dispose();
    speed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stats = context.watch<StatsService>();
    road.drive.laneDeparture = stats.laneDepartureAlert;
    final state = context.watch<DrowsinessDetector>().state;
    final busy =
        state == DetectorState.watching ||
        state == DetectorState.starting ||
        state == DetectorState.alarming;
    return Scaffold(
      appBar: AppBar(title: Text(l.dashcamTitle)),
      body: ListenableBuilder(
        listenable: cam,
        builder: (context, _) {
          final c = cam.controller;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                      const Positioned(
                        top: 8,
                        left: 8,
                        child: Chip(
                          avatar: Icon(Icons.circle, color: Colors.red, size: 14),
                          label: Text('REC'),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(l.dashcamIntro),
              const SizedBox(height: 12),
              if (busy && !cam.recording)
                Text(l.dashcamBusy)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: cam.recording ? cam.stop : cam.start,
                      icon: Icon(
                        cam.recording ? Icons.stop : Icons.fiber_manual_record,
                      ),
                      label: Text(
                        cam.recording ? l.dashcamStop : l.dashcamStart,
                      ),
                    ),
                    if (cam.recording)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await cam.protect();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.dashcamProtectedNow)),
                          );
                        },
                        icon: const Icon(Icons.lock),
                        label: Text(l.dashcamProtect),
                      ),
                  ],
                ),
              if (cam.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  cam.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              SpeedLimitPanel(service: speed, active: cam.recording),
              if (cam.recording) _LeadInfo(assist: road),
              const SizedBox(height: 8),
              Text(l.dashcamAssist, style: Theme.of(context).textTheme.titleSmall),
              Text(l.dashcamAssistNote, style: Theme.of(context).textTheme.bodySmall),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.laneDepartureToggle),
                subtitle: Text(l.laneDepartureHelp),
                value: stats.laneDepartureAlert,
                onChanged: stats.setLaneDepartureAlert,
              ),
              const SizedBox(height: 8),
              Text(l.dashcamLimits, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              _Clips(title: l.dashcamLocked, files: cam.lockedClips, cam: cam),
              _Clips(title: l.dashcamRecent, files: cam.loopClips, cam: cam),
            ],
          );
        },
      ),
    );
  }
}

/// 前の車までの距離の目安。
class _LeadInfo extends StatelessWidget {
  const _LeadInfo({required this.assist});
  final RoadAssist assist;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: assist,
      builder: (context, _) {
        final l = context.l10n;
        final lead = assist.lead;
        final text = assist.error ??
            (lead == null
                ? l.roadNoLead
                : l.roadLeadInfo(distanceFromWidth(lead.width).round().toString()));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            '$text · ${assist.model.name} ${assist.inferMs}ms · '
            '${assist.fps.toStringAsFixed(1)} fps',
          ),
        );
      },
    );
  }
}

class _Clips extends StatelessWidget {
  const _Clips({required this.title, required this.files, required this.cam});
  final String title;
  final List<File> files;
  final DashcamService cam;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (files.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l.dashcamEmpty),
          ),
        for (final f in files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.movie_outlined),
            title: Text(f.uri.pathSegments.last),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l.dashcamShare,
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(files: [XFile(f.path)]),
                  ),
                ),
                IconButton(
                  tooltip: l.dashcamDelete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => cam.delete(f),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

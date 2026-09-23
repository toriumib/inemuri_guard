import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_language.dart';
import '../services/dashcam_service.dart';
import '../services/drowsiness_detector.dart';

/// ドラレコの画面。開いている間だけ録る（DashcamService の注記を参照）。
class DashcamScreen extends StatefulWidget {
  const DashcamScreen({super.key});

  @override
  State<DashcamScreen> createState() => _DashcamScreenState();
}

class _DashcamScreenState extends State<DashcamScreen>
    with WidgetsBindingObserver {
  final cam = DashcamService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cam.refresh();
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

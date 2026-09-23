import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_language.dart';

/// 強い衝撃のあとに出す画面（Nexar の衝突通報にあたるもの）。
///
/// **自動では通報しない。** 誤検知（段差・スマホの落下）で 119 に掛かるほうが害が大きい。
/// 押せばすぐ掛かる大きなボタンと、位置を送る手段だけを出す。
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  Future<void> _call(String number) =>
      launchUrl(Uri(scheme: 'tel', path: number));

  Future<void> _share(BuildContext context) async {
    final text = context.l10n;
    String url;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      url = 'https://maps.google.com/?q=${p.latitude},${p.longitude}';
    } catch (_) {
      final p = await Geolocator.getLastKnownPosition();
      url = p == null
          ? '-'
          : 'https://maps.google.com/?q=${p.latitude},${p.longitude}';
    }
    await SharePlus.instance.share(
      ShareParams(text: text.emergencyShareText(url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final big = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(64),
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.emergencyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l.emergencyBody, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          if (ja) ...[
            FilledButton.icon(
              style: big.copyWith(
                backgroundColor: const WidgetStatePropertyAll(Colors.red),
              ),
              onPressed: () => _call('119'),
              icon: const Icon(Icons.local_hospital),
              label: Text(l.emergencyCall119),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: big,
              onPressed: () => _call('110'),
              icon: const Icon(Icons.local_police),
              label: Text(l.emergencyCall110),
            ),
          ] else
            FilledButton.icon(
              style: big.copyWith(
                backgroundColor: const WidgetStatePropertyAll(Colors.red),
              ),
              onPressed: () => _call('112'),
              icon: const Icon(Icons.local_hospital),
              label: Text(l.emergencyCallIntl),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: () => _share(context),
            icon: const Icon(Icons.share_location),
            label: Text(l.emergencyShare),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.emergencyOk),
          ),
        ],
      ),
    );
  }
}

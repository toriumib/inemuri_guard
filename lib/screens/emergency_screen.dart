import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_language.dart';

/// 強い衝撃のあと（Nexar の衝突通報にあたるもの）と、居眠りのアラームに
/// 反応が無いとき（ドライバー異常時対応＝EDSS の考え方）に出す画面。
///
/// **119・110 には自動で掛けない。** 誤検知（段差・スマホの落下・うたた寝の誤報）で
/// 掛かるほうが害が大きい。自動で掛けるのは、本人が登録した家族の番号だけで、
/// それも [countdown] の猶予と大きな取り消しボタンを付ける。
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({
    super.key,
    this.unresponsive = false,
    this.contact = '',
    this.onAwake,
  });

  /// 反応が無くて開いた（衝撃ではなく）。
  final bool unresponsive;

  /// 反応が無いとき掛ける番号。空なら掛けない。
  final String contact;

  /// 「起きています」を押した（アラームを止める）。
  final VoidCallback? onAwake;

  static const countdown = 15;

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  static const _ch = MethodChannel('inemuri/call');
  Timer? _timer;
  int _left = EmergencyScreen.countdown;
  String? _callResult;

  bool get _willCall => widget.unresponsive && widget.contact.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_willCall) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_left <= 1) {
          t.cancel();
          unawaited(_callFamily());
        }
        if (mounted) setState(() => _left--);
      });
    }
  }

  Future<void> _callFamily() async {
    String r;
    try {
      r = await _ch.invokeMethod<String>('call', {'number': widget.contact}) ?? 'failed';
    } catch (_) {
      r = 'failed';
    }
    if (mounted) setState(() => _callResult = r);
  }

  void _awake() {
    _timer?.cancel();
    widget.onAwake?.call();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
      appBar: AppBar(
        title: Text(widget.unresponsive ? l.unresponsiveTitle : l.emergencyTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.unresponsive) ...[
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(96),
                backgroundColor: Colors.green.shade700,
                textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              onPressed: _awake,
              child: Text(l.imAwake),
            ),
            const SizedBox(height: 16),
            Text(
              _callResult == 'called'
                  ? l.unresponsiveCalled
                  : _callResult == 'dialer'
                  ? l.unresponsiveDialer
                  : _willCall
                  ? l.unresponsiveCountdown('$_left', widget.contact)
                  : l.unresponsiveNoContact,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
          ] else ...[
            Text(l.emergencyBody, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
          ],
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
            onPressed: widget.unresponsive ? _awake : () => Navigator.of(context).pop(),
            child: Text(l.emergencyOk),
          ),
        ],
      ),
    );
  }
}

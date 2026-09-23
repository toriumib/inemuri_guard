import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'road_logic.dart';

/// 制限速度の知らせ（車モード）。
///
/// 道路ごとの制限速度は OpenStreetMap の maxspeed タグを Overpass API で引く。
/// **位置が外部のサーバーへ出る唯一の機能**なので、出す量を最小にする:
/// - 正確な位置ではなく、約 2km 四方の区画（[tileDeg]）の四隅だけを送る
/// - 速度・向き・時刻・端末の識別子は送らない。当運営者のサーバーは通らない
/// - 取った区画は端末のメモリに持ち、同じ区画は二度と問い合わせない
/// タグの無い道路は推測しない（法定速度で埋めると標識の 40 を見落とす）。
///
/// 地図データ © OpenStreetMap contributors（ODbL）。画面に表記すること。
class SpeedLimitService extends ChangeNotifier {
  SpeedLimitService({this.onOverspeed, this.onSpeedCamera});

  /// 超過を知らせる（AlarmService.warn につなぐ）。
  final void Function()? onOverspeed;

  /// 進行方向の前にオービス（OSM の highway=speed_camera）が近づいた。
  /// 同じオービスでは一度だけ。引数は距離（m）。
  final void Function(double meters)? onSpeedCamera;

  /// 前方のオービスまでの距離（m）。無ければ null。
  double? cameraMeters;
  final Set<String> _announcedCams = {};

  static const tileDeg = 0.02;
  static const matchMeters = 25.0;
  static const _servers = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  /// 現在の制限速度（km/h）。null は不明（タグ無し・未取得）。
  int? limit;

  /// 現在の速度（km/h）。null は未取得。
  double? speed;
  bool running = false;
  String? error;

  final judge = OverspeedJudge();
  final Map<String, List<SpeedWay>> _tiles = {};
  final Map<String, List<(double, double)>> _cams = {};
  final Set<String> _loading = {};
  final Map<String, DateTime> _failedAt = {};
  StreamSubscription<Position>? _sub;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _starting = false;

  Future<void> start() async {
    if (running || _starting) return;
    _starting = true;
    error = null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error = 'location-off';
        _notify();
        return;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        error = 'denied';
        _notify();
        return;
      }
      running = true;
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_onPosition, onError: (Object e) => error = '$e');
    } catch (e) {
      error = '$e';
    } finally {
      _starting = false;
    }
    _notify();
  }

  Future<void> stop() async {
    running = false;
    await _sub?.cancel();
    _sub = null;
    limit = speed = cameraMeters = null;
    judge.reset();
    _notify();
  }

  void _onPosition(Position pos) {
    speed = pos.speed < 0 ? null : pos.speed * 3.6;
    final key = tileKey(pos.latitude, pos.longitude);
    final ways = _tiles[key];
    if (ways == null) {
      unawaited(_load(key));
      limit = null;
    } else {
      limit = nearestLimit(ways, pos.latitude, pos.longitude, matchMeters);
      final cams = _cams[key] ?? const [];
      final hit = cameraAhead(
        cams,
        pos.latitude,
        pos.longitude,
        pos.speed > 2 ? pos.heading : null,
      );
      cameraMeters = hit?.$2;
      if (hit != null) {
        final id = '${cams[hit.$1].$1},${cams[hit.$1].$2}';
        if (_announcedCams.add(id)) onSpeedCamera?.call(hit.$2);
      }
    }
    if (judge.feed(speed, limit, DateTime.now())) onOverspeed?.call();
    _notify();
  }

  Future<void> _load(String key) async {
    if (_loading.contains(key)) return;
    // 全サーバーが落ちたら 30 秒は問い合わせない（位置は 5m ごとに来るので、
    // そのたびに叩くと公開サーバーの迷惑になる）。
    final failed = _failedAt[key];
    if (failed != null &&
        DateTime.now().difference(failed) < const Duration(seconds: 30)) {
      return;
    }
    _loading.add(key);
    try {
      final parts = key.split(',').map(int.parse).toList();
      final s = parts[0] * tileDeg, w = parts[1] * tileDeg;
      final bbox = '$s,$w,${s + tileDeg},${w + tileDeg}';
      final q =
          '[out:json][timeout:20];(way($bbox)["highway"]["maxspeed"];'
          'node($bbox)["highway"="speed_camera"];);out tags geom;';
      for (final url in _servers) {
        try {
          final body = await _post(url, q);
          _tiles[key] = parseOverpass(body);
          _cams[key] = parseSpeedCameras(body);
          if (_tiles.length > 30) {
            _cams.remove(_tiles.keys.first);
            _tiles.remove(_tiles.keys.first);
          }
          _failedAt.remove(key);
          error = null;
          break;
        } catch (e) {
          error = 'network';
        }
      }
      if (!_tiles.containsKey(key)) _failedAt[key] = DateTime.now();
    } finally {
      _loading.remove(key);
      _notify();
    }
  }

  static Future<String> _post(String url, String query) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.postUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.userAgentHeader, 'InemuriGuard (toriumis.com)');
      req.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      req.write('data=${Uri.encodeQueryComponent(query)}');
      final res = await req.close().timeout(const Duration(seconds: 25));
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw HttpException('${res.statusCode}');
      return text;
    } finally {
      client.close(force: true);
    }
  }

  static String tileKey(double lat, double lon) =>
      '${(lat / tileDeg).floor()},${(lon / tileDeg).floor()}';

  /// "40" / "40 km/h" / "30 mph" → km/h。"JP:urban" などの区分や
  /// "none"・"signals" は数字にならないので null（推測しない）。
  static int? parseMaxspeed(String raw) {
    final m = RegExp(r'^\s*(\d+)\s*(mph|km/h|kmh)?\s*$').firstMatch(raw);
    if (m == null) return null;
    final v = int.parse(m.group(1)!);
    return m.group(2) == 'mph' ? (v * 1.609).round() : v;
  }

  static List<SpeedWay> parseOverpass(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final out = <SpeedWay>[];
    for (final e in (json['elements'] as List? ?? const [])) {
      final el = e as Map<String, dynamic>;
      final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      final v = parseMaxspeed('${tags['maxspeed'] ?? ''}');
      final geom = el['geometry'] as List?;
      if (v == null || geom == null || geom.length < 2) continue;
      out.add(
        SpeedWay(v, [
          for (final g in geom)
            ((g['lat'] as num).toDouble(), (g['lon'] as num).toDouble()),
        ]),
      );
    }
    return out;
  }

  /// 固定式の速度取締機（オービス）。OSM の highway=speed_camera の点。
  /// 日本の登録は網羅的ではない（載っていないオービスは知らせられない）。
  static List<(double, double)> parseSpeedCameras(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return [
      for (final e in (json['elements'] as List? ?? const []))
        if ((e as Map)['type'] == 'node' &&
            (e['tags'] as Map?)?['highway'] == 'speed_camera' &&
            e['lat'] != null)
          ((e['lat'] as num).toDouble(), (e['lon'] as num).toDouble()),
    ];
  }

  /// [maxMeters] 以内でいちばん近い道路の制限速度。
  static int? nearestLimit(
    List<SpeedWay> ways,
    double lat,
    double lon,
    double maxMeters,
  ) {
    const r = 6371000.0;
    final kx = r * math.cos(lat * math.pi / 180) * math.pi / 180;
    const ky = r * math.pi / 180;
    int? best;
    var bestD = maxMeters;
    for (final w in ways) {
      for (var i = 0; i + 1 < w.points.length; i++) {
        final ax = (w.points[i].$2 - lon) * kx, ay = (w.points[i].$1 - lat) * ky;
        final bx = (w.points[i + 1].$2 - lon) * kx;
        final by = (w.points[i + 1].$1 - lat) * ky;
        final dx = bx - ax, dy = by - ay;
        final len2 = dx * dx + dy * dy;
        final t = len2 == 0
            ? 0.0
            : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
        final px = ax + t * dx, py = ay + t * dy;
        final d = math.sqrt(px * px + py * py);
        if (d <= bestD) {
          bestD = d;
          best = w.limit;
        }
      }
    }
    return best;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}

class SpeedWay {
  const SpeedWay(this.limit, this.points);
  final int limit;
  final List<(double, double)> points;
}

/// 超過の判定。GPS の速度は揺れるので、[margin] を超えた状態が
/// [hold] 続いたら一度だけ知らせ、[cooldown] は黙る。
class OverspeedJudge {
  static const margin = 5.0;
  static const hold = Duration(seconds: 3);
  static const cooldown = Duration(seconds: 60);

  DateTime? _since;
  DateTime? _lastAt;

  bool feed(double? speed, int? limit, DateTime now) {
    if (speed == null || limit == null || speed <= limit + margin) {
      _since = null;
      return false;
    }
    _since ??= now;
    if (now.difference(_since!) < hold) return false;
    if (_lastAt != null && now.difference(_lastAt!) < cooldown) return false;
    _lastAt = now;
    return true;
  }

  void reset() => _since = _lastAt = null;
}

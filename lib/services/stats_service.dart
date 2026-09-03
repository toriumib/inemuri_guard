import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_skin.dart';

class LogEntry {
  final DateTime time;
  final String text;
  LogEntry(this.time, this.text);

  Map<String, dynamic> toJson() => {'t': time.toIso8601String(), 'm': text};
  factory LogEntry.fromJson(Map<String, dynamic> j) =>
      LogEntry(DateTime.parse(j['t'] as String), j['m'] as String);
}

/// Tracks today's nap/alarm counts and a short rolling event log.
/// Counts reset automatically when the calendar day changes.
class StatsService extends ChangeNotifier {
  static const _kDate = 'stats_date';
  static const _kNaps = 'stats_naps';
  static const _kNapMinutes = 'stats_nap_minutes';
  static const _kAlarms = 'stats_alarms';
  static const _kLog = 'stats_log';
  static const _kAdsRemoved = 'ads_removed';
  static const _kShowCameraPreview = 'show_camera_preview';
  static const _kWatchBridge = 'watch_bridge_beta';
  static const _kOwnedSkins = 'owned_skins';
  static const _kSelectedSkin = 'selected_skin';
  static const _kNapsAllTime = 'stats_naps_all_time';

  int napCount = 0;
  int napMinutesToday = 0;
  int alarmCount = 0;
  int napsAllTime = 0;
  bool adsRemoved = false;
  bool showCameraPreview = true;
  bool watchBridge = true;
  Set<String> ownedSkinIds = {};
  AppSkin selectedSkin = AppSkin.paper;
  final List<LogEntry> log = [];

  bool ownsSkin(AppSkin skin) => skin.isFree || ownedSkinIds.contains(skin.id);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final savedDate = prefs.getString(_kDate);
    if (savedDate == today) {
      napCount = prefs.getInt(_kNaps) ?? 0;
      napMinutesToday = prefs.getInt(_kNapMinutes) ?? 0;
      alarmCount = prefs.getInt(_kAlarms) ?? 0;
    } else {
      napCount = 0;
      napMinutesToday = 0;
      alarmCount = 0;
      await prefs.setString(_kDate, today);
      await prefs.setInt(_kNaps, 0);
      await prefs.setInt(_kNapMinutes, 0);
      await prefs.setInt(_kAlarms, 0);
    }
    adsRemoved = prefs.getBool(_kAdsRemoved) ?? false;
    showCameraPreview = prefs.getBool(_kShowCameraPreview) ?? true;
    watchBridge = prefs.getBool(_kWatchBridge) ?? true;
    napsAllTime = prefs.getInt(_kNapsAllTime) ?? 0;
    ownedSkinIds = (prefs.getStringList(_kOwnedSkins) ?? []).toSet();
    final savedSkin = AppSkin.fromId(prefs.getString(_kSelectedSkin));
    // Never leave the app wearing a skin the user doesn't own — e.g. after a
    // refund, or restoring onto a device where the purchase didn't carry.
    selectedSkin = ownsSkin(savedSkin) ? savedSkin : AppSkin.paper;
    final raw = prefs.getStringList(_kLog) ?? [];
    log
      ..clear()
      ..addAll(
        raw.map(
          (s) => LogEntry.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ),
      );
    notifyListeners();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// Returns true the moment today's cumulative nap time crosses 30 minutes
  /// — the Hori-style "short sleeper" territory the UI jokes about.
  Future<bool> bumpNap(int minutes) async {
    final crossedShortSleeperLine =
        napMinutesToday < 30 && napMinutesToday + minutes >= 30;
    napCount++;
    napMinutesToday += minutes;
    napsAllTime++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNaps, napCount);
    await prefs.setInt(_kNapMinutes, napMinutesToday);
    await prefs.setInt(_kNapsAllTime, napsAllTime);
    notifyListeners();
    return crossedShortSleeperLine;
  }

  Future<void> bumpAlarm(String reason) async {
    alarmCount++;
    log.insert(0, LogEntry(DateTime.now(), reason));
    while (log.length > 6) {
      log.removeLast();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAlarms, alarmCount);
    await prefs.setStringList(
      _kLog,
      log.map((e) => jsonEncode(e.toJson())).toList(),
    );
    notifyListeners();
  }

  Future<void> setAdsRemoved(bool value) async {
    adsRemoved = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdsRemoved, value);
    notifyListeners();
  }

  Future<void> setShowCameraPreview(bool value) async {
    showCameraPreview = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowCameraPreview, value);
    notifyListeners();
  }

  Future<void> setWatchBridge(bool value) async {
    watchBridge = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWatchBridge, value);
    notifyListeners();
  }

  Future<void> grantSkin(AppSkin skin) async {
    if (skin.isFree) return;
    ownedSkinIds.add(skin.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kOwnedSkins, ownedSkinIds.toList());
    notifyListeners();
  }

  Future<void> selectSkin(AppSkin skin) async {
    if (!ownsSkin(skin)) return;
    selectedSkin = skin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedSkin, skin.id);
    notifyListeners();
  }
}

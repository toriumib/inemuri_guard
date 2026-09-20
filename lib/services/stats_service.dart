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
enum DetectionSensitivity { standard, sensitive, custom }

class StatsService extends ChangeNotifier {
  DetectionSensitivity sensitivity = DetectionSensitivity.standard;
  Future<void> setSensitivity(DetectionSensitivity value) async {
    sensitivity = value;
    if (value != DetectionSensitivity.custom) {
      eyeThresholdSeconds = value == DetectionSensitivity.standard ? 5 : 3;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('detection_sensitivity', value.name);
    await prefs.setInt(_kEyeThresholdSeconds, eyeThresholdSeconds);
    notifyListeners();
  }

  static const _kDate = 'stats_date';
  static const _kNaps = 'stats_naps';
  static const _kNapMinutes = 'stats_nap_minutes';
  static const _kAlarms = 'stats_alarms';
  static const _kLog = 'stats_log';
  static const _kAdsRemoved = 'ads_removed';
  static const _kPremium = 'premium';
  static const _kShowCameraPreview = 'show_camera_preview';
  static const _kUseBackCamera = 'use_back_camera';
  static const _kEyeThresholdSeconds = 'eye_threshold_seconds';
  static const _kAutoStart = 'auto_start_detection';
  static const _kWatchBridge = 'watch_bridge_beta';
  static const _kCarMode = 'car_mode';
  static const _kTermsAccepted = 'terms_accepted_v';
  static const _kIlluminate = 'illuminate_in_dark';
  static const _kVoiceStop = 'voice_stop';
  static const _kOwnedSkins = 'owned_skins';
  static const _kSelectedSkin = 'selected_skin';
  static const _kNapsAllTime = 'stats_naps_all_time';

  int napCount = 0;
  int napMinutesToday = 0;
  int alarmCount = 0;
  int napsAllTime = 0;
  bool adsRemoved = false;

  /// プレミアム（買い切り 980円）を買ったか。広告なし・テーマ全部・通知の
  /// 差出人フィルタが付く。判定は [isPremium] を使う（旧商品の救済込み）。
  bool premium = false;
  bool showCameraPreview = true;

  /// 背面カメラで見張るか。車のスタンドに載せて運転席へ向けるときに使う。
  /// 既定は前面（机の上に置いて自分に向ける、いちばん多い使い方）。
  bool useBackCamera = false;

  /// 何秒目を閉じ続けたら鳴らすか。選んだ値が次の起動でも残るように持つ。
  int eyeThresholdSeconds = 5;

  /// 開いた瞬間から検知を始めるか。机に置いて開くだけで見張りが始まるのが
  /// この道具の使い方なので既定は ON。切りたい人のために設定に置く。
  bool autoStartDetection = true;
  bool watchBridge = true;

  /// 車で使うか。ON にすると、眠気を検知したとき「安全な場所で休憩」の
  /// 案内（画面のカードと通知）を出し、脇見を知らせ、マップを開いたまま
  /// 見張るためのボタンを出す。既定は OFF（机で使う人が多い）。
  /// 検知画面の「使う場所」で決める。裏向き（背面カメラ）は開発中の機能。
  bool carMode = false;

  /// 同意した利用規約の版。0 は未同意。TermsGate.version より小さければ
  /// 起動時にもう一度同意画面を出す。
  int termsAcceptedVersion = 0;

  /// 暗くて顔が消えたとき、画面を白く明るくして照明代わりにするか。
  /// 前面カメラは赤外線を持たないので、暗い部屋では画面が唯一の光源。
  bool illuminateInDark = true;

  /// 鳴っている間、声で止められるようにするか。既定 ON。
  /// マイクの許可が無ければ何も起きない（ON にしたときに聞く）。
  bool voiceStop = true;
  bool setupCompleted = false;
  Future<void> completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_completed_v1', true);
    setupCompleted = true;
    notifyListeners();
  }

  bool flashAlarm = false;
  Future<void> setFlashAlarm(bool value) async {
    flashAlarm = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flash_alarm', value);
    notifyListeners();
  }

  Set<String> ownedSkinIds = {};
  AppSkin selectedSkin = AppSkin.paper;
  final List<LogEntry> log = [];

  /// 「広告除去」「テーマ」を単品で買った人はプレミアム扱いにする。
  /// 商品を 980 円に一本化したときに、先に買った人が損をしないための救済。
  bool get isPremium => premium || adsRemoved || ownedSkinIds.isNotEmpty;

  bool ownsSkin(AppSkin skin) =>
      skin.isFree || isPremium || ownedSkinIds.contains(skin.id);

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
    premium = prefs.getBool(_kPremium) ?? false;
    showCameraPreview = prefs.getBool(_kShowCameraPreview) ?? true;
    useBackCamera = prefs.getBool(_kUseBackCamera) ?? false;
    eyeThresholdSeconds = (prefs.getInt(_kEyeThresholdSeconds) ?? 5).clamp(
      3,
      60,
    );
    final savedSensitivity = prefs.getString('detection_sensitivity');
    sensitivity = DetectionSensitivity.values.firstWhere(
      (v) => v.name == savedSensitivity,
      orElse: () => eyeThresholdSeconds == 5
          ? DetectionSensitivity.standard
          : DetectionSensitivity.custom,
    );
    autoStartDetection = prefs.getBool(_kAutoStart) ?? true;
    watchBridge = prefs.getBool(_kWatchBridge) ?? true;
    carMode = prefs.getBool(_kCarMode) ?? false;
    termsAcceptedVersion = prefs.getInt(_kTermsAccepted) ?? 0;
    illuminateInDark = prefs.getBool(_kIlluminate) ?? true;
    voiceStop = prefs.getBool(_kVoiceStop) ?? true;
    flashAlarm = prefs.getBool('flash_alarm') ?? false;
    setupCompleted = prefs.getBool('setup_completed_v1') ?? false;
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

  Future<void> setPremium(bool value) async {
    premium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPremium, value);
    notifyListeners();
  }

  Future<void> setShowCameraPreview(bool value) async {
    showCameraPreview = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowCameraPreview, value);
    notifyListeners();
  }

  Future<void> setUseBackCamera(bool value) async {
    useBackCamera = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseBackCamera, value);
    notifyListeners();
  }

  Future<void> setAutoStartDetection(bool value) async {
    autoStartDetection = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoStart, value);
    notifyListeners();
  }

  Future<void> setEyeThresholdSeconds(int value) async {
    eyeThresholdSeconds = value.clamp(3, 60);
    sensitivity = DetectionSensitivity.custom;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kEyeThresholdSeconds, eyeThresholdSeconds);
    await prefs.setString('detection_sensitivity', sensitivity.name);
    notifyListeners();
  }

  Future<void> setWatchBridge(bool value) async {
    watchBridge = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWatchBridge, value);
    notifyListeners();
  }

  Future<void> setVoiceStop(bool value) async {
    voiceStop = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVoiceStop, value);
    notifyListeners();
  }

  Future<void> setIlluminateInDark(bool value) async {
    illuminateInDark = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIlluminate, value);
    notifyListeners();
  }

  Future<void> acceptTerms(int version) async {
    termsAcceptedVersion = version;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTermsAccepted, version);
    notifyListeners();
  }

  Future<void> setCarMode(bool value) async {
    carMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCarMode, value);
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

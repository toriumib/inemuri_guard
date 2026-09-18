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
/// どこで使うか。設定はこの 1 択だけ——背面カメラと車モードはここから決まる。
/// 机: 前面カメラ。車・画面を自分に: 前面カメラ＋車の機能。車・裏向き: 背面カメラ＋車の機能＋ライト。
enum Placement { desk, carFront, carBack }

class StatsService extends ChangeNotifier {
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
  /// 直接は触らず [setPlacement] で決める（背面カメラと一緒に決まる）。
  bool carMode = false;

  Placement get placement => !carMode
      ? Placement.desk
      : (useBackCamera ? Placement.carBack : Placement.carFront);

  /// 使う場所を 1 回選ぶだけで、カメラの向きと車の機能が決まる。
  /// ライトの点滅は背面カメラ（裏向き）のときだけ有効（呼び出し側が見る）。
  Future<void> setPlacement(Placement p) async {
    carMode = p != Placement.desk;
    useBackCamera = p == Placement.carBack;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCarMode, carMode);
    await prefs.setBool(_kUseBackCamera, useBackCamera);
    notifyListeners();
  }

  /// 同意した利用規約の版。0 は未同意。TermsGate.version より小さければ
  /// 起動時にもう一度同意画面を出す。
  int termsAcceptedVersion = 0;

  /// 暗くて顔が消えたとき、画面を白く明るくして照明代わりにするか。
  /// 前面カメラは赤外線を持たないので、暗い部屋では画面が唯一の光源。
  bool illuminateInDark = true;

  /// 鳴っている間、声で止められるようにするか。既定 ON。
  /// マイクの許可が無ければ何も起きない（ON にしたときに聞く）。
  bool voiceStop = true;
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
    eyeThresholdSeconds = prefs.getInt(_kEyeThresholdSeconds) ?? 5;
    autoStartDetection = prefs.getBool(_kAutoStart) ?? true;
    watchBridge = prefs.getBool(_kWatchBridge) ?? true;
    carMode = prefs.getBool(_kCarMode) ?? false;
    termsAcceptedVersion = prefs.getInt(_kTermsAccepted) ?? 0;
    illuminateInDark = prefs.getBool(_kIlluminate) ?? true;
    voiceStop = prefs.getBool(_kVoiceStop) ?? true;
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
    eyeThresholdSeconds = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kEyeThresholdSeconds, value);
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

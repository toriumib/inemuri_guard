import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'alarm_keys.dart';
import '../l10n/app_language.dart';

/// 鳴っている間だけ音声認識を回し、「起きた」「止めて」で止める。
///
/// 物理キーと通知のボタンで「戻らずに止める」は足りているが、手が
/// 離せない（運転中・両手が塞がっている）ときの第三の道として入れる。
///
/// 制約を隠さない：
/// - 端末の音声認識（Google）を使う。無い・オフラインで動かない端末では
///   黙って無効になり、[unavailable] が立つ（設定に出す）
/// - マイクは寝息検知と取り合う。寝息検知が聞いている間は声の道を開かない
///   （AlarmService.micBusy）。寝息検知を止めるとその検知の鳴動まで消えてしまうため
/// - 無音で認識が切れるので、鳴っている間は [maxFor] まで聞き直し続ける
class VoiceStop extends ChangeNotifier {
  VoiceStop._();
  static final VoiceStop instance = VoiceStop._();

  static const words = <String>[
    '起きた',
    'おきた',
    '起きて',
    'おきて',
    '起きる',
    '止めて',
    'とめて',
    '止まれ',
    'とまれ',
    'ストップ',
    '大丈夫',
    'だいじょうぶ',
  ];
  static const maxFor = Duration(seconds: 90);

  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _active = false;
  int _generation = 0;
  String? _localeId;
  DateTime? _deadline;
  Timer? _restart;

  /// この端末では音声認識が使えない（初期化に失敗した）。
  bool unavailable = false;

  /// 聞き取っている最中か（設定画面の表示用）。
  bool get listening => _active;

  /// 直近に聞き取った文（設定画面で「聞こえているか」を見せる）。
  String lastHeard = '';

  void Function()? onStop;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @visibleForTesting
  static bool matches(String heard) {
    final normalized = heard.toLowerCase().replaceAll('’', "'");
    final japanese = normalized.replaceAll(RegExp(r'\s+'), '');
    return words.any(japanese.contains) ||
        RegExp(r"\b(stop|i'm\s+awake|i\s+am\s+awake)\b").hasMatch(normalized);
  }

  /// Preserve the recognizer's locale ID, including its regional variant.
  @visibleForTesting
  static String? selectLocale(
    List<String> available,
    String language,
    String? systemLocale,
  ) {
    String normalized(String value) => value.replaceAll('_', '-').toLowerCase();
    final matching = available
        .where((id) => normalized(id).split('-').first == language)
        .toList();
    if (matching.isEmpty) return null;
    for (final id in matching) {
      if (systemLocale != null && normalized(id) == normalized(systemLocale)) {
        return id;
      }
    }
    final preferred = language == 'ja' ? 'ja-jp' : 'en-us';
    return matching.firstWhere(
      (id) => normalized(id) == preferred,
      orElse: () => matching.first,
    );
  }

  Future<bool> _selectLocale() async {
    try {
      _localeId = selectLocale(
        (await _stt.locales()).map((locale) => locale.localeId).toList(),
        AppLanguage.current.localeName,
        (await _stt.systemLocale())?.localeId,
      );
    } catch (_) {
      _localeId = null;
    }
    unavailable = _localeId == null;
    notifyListeners();
    return !unavailable;
  }

  /// 設定で ON にしたときに呼ぶ。マイクの許可を聞き、認識器を用意する。
  /// 鳴っている最中に許可ダイアログが出るのを避けるため、ここで先に済ませる。
  Future<bool> prepare() async {
    if (!isSupported) return false;
    final granted = (await Permission.microphone.request()).isGranted;
    if (!granted) return false;
    if (!_initialized) await _init();
    return _initialized && await _selectLocale();
  }

  Future<void> _init() async {
    try {
      _initialized = await _stt.initialize(
        onError: (e) => debugPrint('VoiceStop error: ${e.errorMsg}'),
        onStatus: _onStatus,
      );
    } catch (e) {
      _initialized = false;
    }
    unavailable = !_initialized;
    notifyListeners();
  }

  Future<void> start() async {
    if (!isSupported || _active) return;
    final generation = ++_generation;
    // 許可が無いなら黙って何もしない。鳴っている最中にダイアログは出さない。
    if (!await Permission.microphone.isGranted) return;
    if (generation != _generation) return;
    if (!_initialized) {
      await _init();
      if (!_initialized) return;
    }
    if (generation != _generation) return;
    if (!await _selectLocale()) return;
    if (generation != _generation) return;
    _active = true;
    _deadline = DateTime.now().add(maxFor);
    notifyListeners();
    await _listen();
  }

  Future<void> _listen() async {
    if (!_active) return;
    final generation = _generation;
    // 認識の開始でシステムが音量を触ることがある。音量キーと取り違えない。
    await AlarmKeys.ignoreVolumeBriefly(2000);
    if (!_active || generation != _generation) return;
    try {
      await _stt.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      debugPrint('VoiceStop listen failed: $e');
      _scheduleRestart();
    }
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!_active) return;
    lastHeard = r.recognizedWords;
    notifyListeners();
    if (matches(r.recognizedWords)) {
      final cb = onStop;
      unawaited(stop());
      cb?.call();
    }
  }

  void _onStatus(String status) {
    // 無音で切れる（done / notListening）。鳴っている間は聞き直す。
    if (!_active) return;
    if (status == 'done' || status == 'notListening') _scheduleRestart();
  }

  void _scheduleRestart() {
    if (!_active) return;
    if (_deadline != null && DateTime.now().isAfter(_deadline!)) {
      unawaited(stop());
      return;
    }
    _restart?.cancel();
    _restart = Timer(const Duration(milliseconds: 400), () {
      if (_active && !_stt.isListening) unawaited(_listen());
    });
  }

  Future<void> stop() async {
    _generation++;
    _restart?.cancel();
    _restart = null;
    if (!_active) return;
    _active = false;
    try {
      await _stt.stop();
    } catch (_) {}
    notifyListeners();
  }
}

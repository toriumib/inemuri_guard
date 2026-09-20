/// 「この時刻に通知を出しておいて」を頼む口。
///
/// ポモドーロと水分補給は、アプリが背面にいても・プロセスが死んでいても
/// 合図が要る。それは OS に予約するしかない。実装は [NotificationService]。
/// インターフェースに切ってあるのは、サービスのテストで「何番を・いつ
/// 予約したか」を偽物で数えるため（drowsiness_detector の clock と同じ発想）。
abstract class NotificationScheduler {
  /// [at] に [channel] で通知を出す。同じ [id] は上書き。
  /// 時刻は inexact（数分遅れることがある）。正確さが要る用途には使わない。
  Future<void> scheduleAt({
    required int id,
    required String channel,
    required String title,
    required String body,
    required DateTime at,
  });

  Future<void> cancel(int id);

  /// [from] 以上 [toExclusive] 未満の id をまとめて取り消す。
  Future<void> cancelRange(int from, int toExclusive);
}

/// 通知 id の割り当て。ぶつからないように一覧にしておく。
class NotificationIds {
  NotificationIds._();

  /// 居眠り・仮眠のアラーム（既存）。
  static const alarm = 1001;
  static const watchTest = 1002;

  /// ポモドーロの区間終了。
  static const pomodoro = 1100;

  /// 車で眠気を検知したときの「安全な場所で休憩」の案内。
  static const restAdvice = 1200;

  /// 水分補給。今日の残り＋明日ぶんを先に予約するので幅を取る。
  static const hydrationFrom = 2000;
  static const hydrationToExclusive = 2100;
}

/// 通知チャンネルの id。
class NotificationChannels {
  NotificationChannels._();

  /// 既存。全画面・最大重要度。
  static const alarm = 'sleep_alarm';

  /// ポモドーロ。音と振動はあるが全画面にはしない。
  static const pomodoro = 'pomodoro';

  /// 車で眠気を検知したときの休憩の案内。ヘッドアップで出し、消すまで残る。
  static const restAdvice = 'rest_advice';

  /// 水分補給。控えめ。ヘッドアップ無し。
  static const hydration = 'hydration';
}

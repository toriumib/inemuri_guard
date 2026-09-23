// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => '居眠りガード';

  @override
  String get setupTitle => 'はじめの準備';

  @override
  String get setupReady => '顔と目を確認できました。次は音を確かめましょう。';

  @override
  String get setupSteps => '① 下の「見張りを始める」を押してカメラを許可\n② 顔と目が映る位置に置く\n③ 音を確認する';

  @override
  String get soundOutputFailed => '再生できませんでした。音量や出力先を確認してください。';

  @override
  String get checkSound => '音を確認する';

  @override
  String get saveFailed => '保存できませんでした。もう一度お試しください。';

  @override
  String get setupComplete => '聞こえた・準備完了';

  @override
  String get dismissForNow => '今回は閉じる';

  @override
  String get setupHint => '次回からこの案内を省き、前回の設定で使えます。通知や時計は設定から後で追加できます。';

  @override
  String get cameraRecoveryHint =>
      '下の「カメラをつなぎ直す」を押してください。他のアプリがカメラを使用中なら閉じてください。';

  @override
  String get faceRecoveryHint =>
      '一人でカメラに映り、顔を明るくしてください。対象が変わったときは見張りを再開してください。';

  @override
  String get eyeRecoveryHint => '眼鏡の反射や顔の向きを調整してください。目を読み取れない間は閉眼を判定できません。';

  @override
  String get micListening => 'マイク入力あり（呼吸音の補助検知）';

  @override
  String get micStarting => 'マイクを起動中';

  @override
  String get micStopped => 'マイク入力停止';

  @override
  String get micPermission => 'マイク権限を確認してください';

  @override
  String get deviceSettingsFailed => '設定を変更できませんでした。端末の設定から変更できます。';

  @override
  String get beforeUsing => '使う前に確認';

  @override
  String get volumeZero => 'アラーム音量が0です。音量を上げて「音を試す」で確認してください。';

  @override
  String get openVolume => '音量の設定を開く';

  @override
  String get notificationHint => '通知を許可すると、アプリの外からもアラームを止められます。';

  @override
  String get enableNotifications => '通知を使えるようにする';

  @override
  String get shortcutHint => '画面上から下にスワイプするクイック設定に置くと、アプリを探さず開けます。';

  @override
  String get shortcutAdded => 'クイック設定に追加済み';

  @override
  String get addShortcut => 'クイック設定に追加';

  @override
  String get shortcutManual => 'クイック設定の編集ボタンから「居眠りガード」を追加できます。';

  @override
  String get sensitivityTitle => '検知の感度';

  @override
  String get sensitivityStandard => '標準';

  @override
  String get sensitivitySensitive => '敏感';

  @override
  String get sensitivityCustom => '詳細設定';

  @override
  String get thresholdTitle => '連続何秒で知らせる？';

  @override
  String get mapsFailed => '地図を開けませんでした。';

  @override
  String get positionPhone => 'スマホを立てて、自分に向けるだけ。';

  @override
  String get continueWorking => '見張っています。そのまま作業を続けられます。';

  @override
  String get positionHint => '顔と目が映る位置に置いてください。細かな設定は後から変えられます。';

  @override
  String get preparing => '準備しています…';

  @override
  String get stopMonitoring => '見張りを止める';

  @override
  String get startMonitoring => '見張りを始める';

  @override
  String get soundFailed => '音を再生できませんでした。音量の設定を確認してください。';

  @override
  String get testSound => '音を試す';

  @override
  String get hidePreview => '映像を隠す';

  @override
  String get showPreview => '映像を確認';

  @override
  String get cameraPermission => 'カメラの許可を設定する';

  @override
  String get reconnectCamera => 'カメラをつなぎ直す';

  @override
  String get restSafely => '安全な場所で休憩しましょう';

  @override
  String get restSafelyHint => '眠気を感じたら、安全な場所に停めて休んでください。地図は停車してから操作してください。';

  @override
  String get close => '閉じる';

  @override
  String get watchOptions => '感度・使う場所を変える';

  @override
  String get car => '車';

  @override
  String get desk => '机の上';

  @override
  String get drivingWarning => '運転中は操作しないでください。補助の道具であり、安全を保証するものではありません。';

  @override
  String get parkThenMaps => '停車して地図を開く';

  @override
  String get detectionDetails => '検知の詳しい情報';

  @override
  String get falseAlertHint => '起きていたのに鳴りましたか？感度を調整できます。';

  @override
  String get adjustSensitivity => '感度を調整';

  @override
  String get sensitivityManual => '感度は自動で変わりません。必要な場合だけ変更してください。';

  @override
  String get starting => '起動中…';

  @override
  String get stop => '停止';

  @override
  String get beginDetection => '検知を開始';

  @override
  String get navDetect => '検知';

  @override
  String get navNap => '仮眠';

  @override
  String get navHistory => '記録';

  @override
  String get navImprove => '改善';

  @override
  String get navSettings => '設定';

  @override
  String get notification => '通知';

  @override
  String get notificationArrived => '通知が届きました';

  @override
  String get drowsinessDetection => '居眠り検知';

  @override
  String get napTimer => '仮眠タイマー';

  @override
  String get raiseHead => '⚠ 起きて！頭を起こしてください';

  @override
  String get openEyes => '⚠ 起きて！目を開けてください';

  @override
  String get breathingAlert => '⚠ 寝息を検知しました！';

  @override
  String get wakeTime => '⏰ 起床時間！';

  @override
  String get monitoringStatus => '監視状態';

  @override
  String get restartMic => 'マイク検知を再開してください';

  @override
  String get returnToResume => '画面を開くと再開します';

  @override
  String get drowsinessSigns => '眠気の兆候あり';

  @override
  String get monitoringMic => 'マイクを監視中';

  @override
  String get pomodoro => 'ポモドーロ';

  @override
  String get currentMode => '現在のモード';

  @override
  String get idle => '待機中';

  @override
  String get previewHidden => '映像は表示していません。検知は続いています。';

  @override
  String get cameraStartingHint => 'カメラを起動しています…';

  @override
  String get cameraUnavailableHint => 'カメラを使えませんでした。許可を確認してください。';

  @override
  String get pressStartHint => '下のボタンを押すと始まります';

  @override
  String get eyesUnknown => '目 —';

  @override
  String get faceMissing => '顔 なし';

  @override
  String get headTilted => '頭が傾いています';

  @override
  String get lookingAway => 'よそ見が続いています';

  @override
  String get poseOnlyHint => '目を読めません。姿勢のみ監視中';

  @override
  String get checkingEyesPose => '目と姿勢を確認中';

  @override
  String get none => 'なし';

  @override
  String get detected => '検出';

  @override
  String get stopAlarm => '止める';

  @override
  String get illuminating => '暗いので画面で照らしています。\n顔が見つかると元に戻ります。';

  @override
  String get awakeStop => '起きた・止める';

  @override
  String get eyesOpenToStop => '止めるには、目を開けたまま 3 秒。';

  @override
  String get cameraUnavailable => 'カメラを使用できません';

  @override
  String get cameraStarting => 'カメラを起動中';

  @override
  String get monitoringStopped => '監視停止中';

  @override
  String get cameraInputStopped => 'カメラ入力が停止しています';

  @override
  String get targetFaceMissing => '対象の顔が見えません';

  @override
  String get poseOnly => '姿勢のみ監視中（目を読めません）';

  @override
  String get checkingFaceEyes => '顔・目を確認中';

  @override
  String get watchingEyesPose => '目と姿勢を監視中';

  @override
  String get watchingEyes => '目を監視中';

  @override
  String get running => '動作中';

  @override
  String get eyesClosedReason => '目を閉じたままの状態を検知しました';

  @override
  String get headTiltReason => '頭の傾きが続いています。姿勢を戻してください';

  @override
  String get breathingReason => '規則的な寝息のような音を検知しました';

  @override
  String get napReason => '仮眠の終了時刻です';

  @override
  String get alarmOutputFailed => 'アラーム出力に失敗しました。音の設定を確認してください。';

  @override
  String get micInputFailed => 'マイク入力が停止しました。権限を確認して再開してください。';

  @override
  String get toneChime => 'チャイム';

  @override
  String get toneSiren => 'サイレン';

  @override
  String get toneBell => 'ベル連打';

  @override
  String get possibleDrowsiness => '居眠りの兆候を検知しました';

  @override
  String get wakeUp => '起きてください';

  @override
  String get alarmChannel => '居眠り・仮眠アラーム';

  @override
  String get alarmChannelDescription =>
      '目を閉じた/寝息を検知した、または仮眠タイマー終了時に鳴らす通知（対応する時計への通知転送）';

  @override
  String get pomodoroDescription => '作業・休憩の区間が終わったときの合図';

  @override
  String get hydration => '水分補給';

  @override
  String get hydrationDescription => '決めた間隔で水を一口すすめる通知';

  @override
  String get restChannel => '休憩の案内';

  @override
  String get restChannelDescription => '車で眠気を検知したときに、安全な場所で休憩するようすすめる通知';

  @override
  String get watchTestTitle => '居眠りガード・時計の通知テスト';

  @override
  String get watchTestBody => '時計が振動したか確認してください。これはテストです。';

  @override
  String get takeRest => '休憩しましょう';

  @override
  String sensitivityExplanation(int seconds) {
    return '閉眼・姿勢の傾きが連続$seconds秒で警告。敏感にすると短い動作でも鳴りやすくなります。PERCLOSと呼吸音の設定は変わりません。';
  }

  @override
  String optionsSummary(String sensitivity, String placement) {
    return '$sensitivity・$placement';
  }

  @override
  String eyesOpenRemaining(int seconds) {
    return '目を開けたまま あと$seconds秒';
  }

  @override
  String napRunning(int minutes) {
    return '$minutes分仮眠中';
  }

  @override
  String pomodoroStatus(String phase, String time) {
    return '$phase $time';
  }

  @override
  String eyeReading(String state, String percent) {
    return '目 $state $percent%';
  }

  @override
  String closedDuration(String seconds) {
    return '閉じて ${seconds}s';
  }

  @override
  String nudgeReason(String app) {
    return '$app の通知が届きました';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String sliderEndpoint(String value, String label) {
    return '$value（$label）';
  }

  @override
  String get workPhase => '作業中';

  @override
  String get breakPhase => '休憩中';

  @override
  String get eyesClosed => '閉';

  @override
  String get eyesOpen => '開';

  @override
  String get lessSensitive => '鈍感';

  @override
  String get restBody => '眠気を検知しました。安全に駐車できる場所に停めて休んでください。';

  @override
  String get restDetails =>
      '眠気を検知しました。安全に駐車できる場所に停めて休んでください。タップで開くと、近くの駐車場を地図で探せます。';

  @override
  String get termsTitle => 'はじめに、利用規約への同意';

  @override
  String get termsIntro => '下の要点を読んで「同意して始める」を押すと使えます。';

  @override
  String get termsAidTitle => '補助の道具です';

  @override
  String get termsAidBody => '睡眠の代わり・医療機器・安全装置ではありません。';

  @override
  String get termsMissTitle => '見逃し・誤作動があります';

  @override
  String get termsMissBody =>
      '暗い所、眼鏡・サングラス・マスク、顔がカメラから外れたとき。鳴らなかったことを安全の根拠にしないでください。';

  @override
  String get termsDrivingTitle => '車内では補助としてのみ、自己責任で';

  @override
  String get termsDrivingBody =>
      '運転者の注意義務の代わりにはなりません。運転中は端末を操作せず、法令に従い、眠気を感じたら SA・PA・駐車場など安全な場所に停めて休んでください。依拠による事故・損害の責任は負いません。';

  @override
  String get privacyTitle => 'プライバシー';

  @override
  String get termsPrivacyBody =>
      'カメラ映像と呼吸音の検知は端末内で行い、録画・録音は保存しません。任意の「声で止める」は端末の音声認識を使い、提供元へ音声が送られる場合があります。広告・課金サービスにも通信があります。';

  @override
  String get termsAsIsTitle => '現状有姿での提供';

  @override
  String get termsAsIsBody => '正確さや継続を保証しません。有料機能の購入・返金は Google Play の規定に従います。';

  @override
  String get termsFull => '利用規約の全文';

  @override
  String get privacyLink => 'プライバシーポリシー';

  @override
  String get agreeStart => '同意して始める';

  @override
  String get termsRequired => '同意しない場合は、このアプリを使えません。';

  @override
  String get voiceStopTitle => '声で止める';

  @override
  String get voiceUnavailable => 'この言語の音声認識を使えませんでした。画面・音量キー・通知の停止ボタンを使ってください。';

  @override
  String get voiceStopHint =>
      '鳴っている間に「起きた」「止めて」と言うと止まります。端末の音声認識を使い、提供元へ音声が送られる場合があります。呼吸音の検知中は使えません。';

  @override
  String get walkLightTitle => '夜道ライト（歩くとき）';

  @override
  String get walkLightBody =>
      '外側のライトを 2 秒に 4 回点滅させ、車からあなたを見つけやすくします。反射材と違い、車のライトが当たらない横や斜めからも見えます。ライトを車道側へ向けて、胸ポケットやストラップで身につけてください。画面を見ながら歩かないでください。';

  @override
  String get walkLightStart => '点滅を始める';

  @override
  String get walkLightStop => '点滅を止める';

  @override
  String get walkLightUnsupported => 'この端末ではライトを使えません。';
}

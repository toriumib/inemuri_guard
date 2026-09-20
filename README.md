# 居眠りガード (inemuri_guard)

オフィスでの居眠り対策 Android アプリ。カメラで目の開閉を見て居眠りを検知し、
科学的根拠のある長さのパワーナップを計り、居眠りのパターンを記録する。

`applicationId`: `com.stop.sleeping`(Play Console 側で先に登録された名前。namespace は com.toriumi.inemuri_guard のまま)

## 画面

| タブ | 内容 |
|---|---|
| 検知 | ML Kit で瞼の開閉を監視＋マイクで寝息のリズムを検知。どちらもアラームを鳴らせる |
| 仮眠 | 5/10/20/30分のパワーナップタイマー（既定は10分）。各長さの効果を根拠つきで表示 |
| 記録 | 「指摘された」手動記録・パターン分析・症状チェック・履歴（端末内90日） |
| 改善 | 出典つきの睡眠衛生5項目と CBT-I の案内 |
| 設定 | テーマ購入／広告除去／時計にも通知(β)／購入復元／レビュー／共有／Buy Me a Coffee |

## 検知の仕組み

`lib/services/drowsiness_detector.dart` が2つの経路でアラームを上げる。

1. **連続閉眼** — 目が閉じたまま既定5秒続いたら発火（安価な市販の居眠り防止メガネと同じ考え方）
2. **PERCLOS** — 直近60秒のうち目が閉じていた割合が15%以上。完全には閉じきらない
   「重いまばたき」の蓄積を捉える指標で、自動車グレードの眠気検知で使われている

ML Kit の値は直近4フレームの移動平均で平滑化し、1フレームのブレで誤発火しないようにしている。

`lib/services/breathing_detector.dart` はマイクの音量エンベロープからピーク間隔を取り、
その変動係数が小さい（＝規則的な呼吸のリズム）状態が続いたかを見る簡易ヒューリスティック。

## 医療情報の扱い ⚠️

このアプリは**診断をしない**。記録タブの受診サジェストは「医師に相談することをすすめる」だけで、
病名を断定するコードは存在しない。この方針を変更しないこと。

- `SleepLogService.needsClinicalAttention` は保守的な閾値（過去14日で5日以上 or 10回以上）で
  **カードを出すかどうかだけ**を決める。一過性の寝不足では出ない
- `models/sleep_symptoms.dart` は**点数化しない**単なる症状チェックリスト。
  Epworth Sleepiness Scale や STOP-BANG は**著作権があり商用利用にライセンスが要る**ため
  意図的に採用していない。`related` は「医師が鑑別しうる病名」であって利用者の診断ではない
- 改善タブは「睡眠衛生だけでは慢性不眠に臨床的な改善は出ない、CBT-I が第一選択」と
  正直に書く。効果を誇張しない

### 引用文献

- Brooks A, Lack L. *SLEEP.* 2006;29(6):831-840. — 10分仮眠が最も効率的
- Hilditch CJ, McHill AW. *Nat Sci Sleep.* 2019;11:155-165. — 睡眠慣性
- Gardiner C, et al. *Sleep Med Rev.* 2023;69:101764. — カフェインは就寝8.8時間前まで
- Trauer JM, et al. *Ann Intern Med.* 2015;163(3):191-204. — CBT-I のメタ解析
- Edinger JD, et al. *J Clin Sleep Med.* 2021;17(2):255-262. — AASM ガイドライン

## プライバシー

カメラ映像・音声はすべて端末内で処理され、外部に送信も保存もしない。
居眠りの記録は `shared_preferences` に保存され、約90日で自動的に消える。

## ビルド

```bash
flutter pub get
flutter build apk --debug        # 動作確認用
flutter build appbundle --release # Play アップロード用
```

実機での確認（エミュレータはカメラ・マイクの実センサーが無いため実機推奨）:

```bash
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-debug.apk
```

### ハマりどころ

- `share_plus` は **13.x を使うこと**。10.x を入れると win32 / wakelock_plus などの
  依存が巻き戻り、`GeneratedPluginRegistrant.java` がシンボル解決に失敗してビルドが壊れる
- 依存を大きく動かしたあとは `flutter clean` を挟む
- `flutter_local_notifications` のために core library desugaring が有効になっている
  （`android/app/build.gradle.kts`）。外すとビルドが通らない

## リリース前に必要な作業

- [ ] **本番署名キーストアの作成**（Gradle 側の配線は済み。あとは `key.jks` を作り
      `android/key.properties` を書くだけ。手順は `android/key.properties.example` 参照。
      **キーストアを失うと Play のアプリを二度と更新できない**ので、`key.jks` は repo 外に、
      パスワードはパスワードマネージャーに、それぞれ別の場所へバックアップすること）
- [ ] AdMob に新規アプリを登録し、Banner / Interstitial の実 ID を
      `lib/services/ad_service.dart` と `AndroidManifest.xml` に反映
      （現状は Google の公開テスト ID。**実 ID にしたあと自分でクリックしないこと**＝アカウント凍結のリスク）
- [ ] Play Console に課金アイテムを登録・有効化。ID は完全一致が必要で、公開後は変更不可:
      `remove_ads` / `skin_midnight` / `skin_forest` / `skin_sakura`
      （登録するまで購入 UI は出ない＝仕様どおり）
- [ ] アプリアイコンとストア掲載素材（512アイコン・フィーチャーグラフィック・スクリーンショット）
- [ ] Buy Me a Coffee リンクは Play の決済ポリシーに抵触する可能性がある。
      審査で指摘されたら設定タブから外す
- [ ] マイク検知のしきい値（`_quietCeilingDb` など）は実環境でのキャリブレーションが必要

## ツール

`tools/gen_tones.py` — アラーム音3種（chime / siren / bell）の WAV を生成する。
音を変えたいときはこれを編集して `python tools/gen_tones.py` を実行。


## 2026-09-20 検知・警告の改善（1.6.0）

- 警告管理を `AlertCoordinator` に集約。閉眼→姿勢→呼吸音→仮眠→通知の順に優先し、原因別に解除する。画面が再描画されなくても動作する。
- PERCLOS はフレーム数ではなく観測時間で集計。60秒経過を独立管理し、入力欠落時は窓を取り直す。警告中は再蓄積しない。
- 目の値が未取得・不正なら閉眼に変換せず、目を判定できない状態として表示する。
- カメラ・マイクの入力が3秒以上途絶えたら停止状態を表示する。入力停止だけで既存の警告を解除しない。
- 監視対象は一人で開始したときの追跡IDに固定。別人へ自動切替しない。見失ってIDが変わった場合は監視を停止して再開する。前面・背面のカメラ切替時には再取得する。
- 感度「標準（5秒）」「敏感（3秒）」「詳細設定（3〜60秒）」を保存。変更対象は連続閉眼・姿勢の継続時間のみ。検証済みの医療的な感度を意味しない。
- 呼吸音の警告は操作で解除する。アラーム自身の音で自動解除しない。
- 自動テスト: 不規則なフレーム間隔、複数原因の独立解除、対象固定、入力欠落、画面の状態遷移、感度の保存。
- 実機で確認する項目: 眼鏡・暗所・複数人、画面消灯と復帰、他アプリのカメラ使用、マイク権限取消、Bluetoothの音声出力。自動テストは実測の検知精度を保証しない。

### Detection and alert changes (1.6.0)

Alerts now have a single coordinator, with independent lifetimes for eye closure,
posture, breathing-like sounds, nap completion, and notifications. PERCLOS uses
elapsed observation time rather than frame counts. Missing eye measurements are
unknown, not closed; input stalls are displayed and never count as recovery.
Both camera paths lock onto a single tracking ID and require restarting monitoring
if that ID is lost. Sensitivity presets persist the consecutive closure/posture
duration (standard: 5 seconds; sensitive: 3 seconds; custom: 3–60 seconds).
Breathing alerts stay active until dismissed so the alarm cannot cancel itself.
Device testing is still required for lighting, glasses, camera handover, permissions,
and actual audio output; these are product heuristics, not validated diagnostic thresholds.

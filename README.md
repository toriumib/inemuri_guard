# 居眠りガード（Drowsiness Guard）

**カメラでまぶたと頭の傾きを見て、眠気の兆候が続いたら起こす** Android アプリ。机の上でも、車の助手席に置いても。
映像も音も端末の外に出さず、鳴ったら目を開ける・声・手元のボタンで止まります。

[English README](README.en.md) · [Google Play](https://play.google.com/store/apps/details?id=com.stop.sleeping) · [Web 版](https://inemuri.toriumis.com/app/)（[リポジトリ](https://github.com/toriumib/inemuri-web)） · [利用規約](https://inemuri.toriumis.com/terms/) · [プライバシー](https://inemuri.toriumis.com/app/privacy/)

ライセンスは **Apache-2.0**（[LICENSE](LICENSE)）。作者はスタジオトリウミ。

## なぜ OSS にするか

「インストールしてすぐ使えて、日常利用まで面倒を見る」居眠り検知を、一人で全部の端末・全部の場面で確かめるのは無理だからです。
眼鏡の反射、暗い車内、機種ごとのカメラ・音の癖、時計への通知——**実機での報告が一番の貢献**です。コードを書かなくても参加できます（[CONTRIBUTING.md](CONTRIBUTING.md)）。

## できること

| | |
|---|---|
| まぶた | 目を閉じたままの時間（3〜60 秒、既定 5 秒）と、直近 1 分で閉じていた割合（PERCLOS）。まばたきでは鳴らない |
| 頭の傾き | 普段の姿勢から 22° 以上、俯く・仰け反る・横に倒れるが続いたら鳴る。サングラスで目が読めないときは頭だけで見張る（EYES HIDDEN） |
| 背面でも | 他のアプリを開いても画面を消しても、常駐サービスがカメラを引き継いで見張り続ける |
| 触らずに止める | 目を開けたまま 3 秒／「起きた」「止めて」の声／音量・ハンドル・イヤホンのボタン／通知の「止める」 |
| 車 | 「使う場所」を車にすると、休憩できる場所（SA・PA・駐車場）の案内、よそ見の知らせ、マップを開いたまま見張り。車の Bluetooth につながったら開く |
| こっそり | 振動 → 小さい音 → 大きい音、と段階的に。イヤホンがあればそちらへ |
| ほか | 仮眠タイマー、ポモドーロ、水分補給、検知の記録、通知（Slack・Teams・メール・着信）で起こす |

医療機器ではなく、運転者の注意義務の代わりにもなりません。詳しくは[利用規約](https://inemuri.toriumis.com/terms/)。

## 仕組み（読む順）

```
lib/services/drowsiness_detector.dart   判定の本体。閉眼時間・PERCLOS・頭の姿勢・「目が読めない」・目を開けて解除
lib/services/native_eye.dart            背面で見張る native サービスとの配線
android/.../EyeService.kt               Camera2 + ML Kit を Service で回す（背面用）。判定はしない
android/.../EyePlugin.kt                MethodChannel / EventChannel の集約（目の値・ライト・キー・車・音声）
lib/services/alarm_service.dart         鳴らし方（音・振動・ライト・声で止める・キーで止める）
lib/screens/home_shell.dart             画面の骨。アラーム中の大ボタン、外から止める
lib/screens/detect_screen.dart          検知画面（始める・止める・使う場所・秒数）
```

判定は **Dart 側の 1 か所**（`DrowsinessDetector`）にしかありません。前面（Flutter の camera）と背面（native の Camera2）の 2 経路が同じ `ingestEyes` / `ingestPose` を通ります。同じ判断を 2 か所に書くと必ず片方だけ直して食い違うためです。

- 連続閉眼は、目を閉じたまま設定秒数が続いたら。**顔が現れてから一度も「開いた目」を見ていない「閉」は数えない**（サングラス対策）
- PERCLOS は直近 60 秒のうち閉じていた割合が 15% 以上。60 秒ぶん実際に溜まるまで判定しない
- 頭の姿勢は絶対角度でなく **普段からのずれ**。基準はずれが小さい間だけゆっくり追従する（落ちている最中に追従させない）
- 鳴っている間は「目を開けたまま 3 秒」（姿勢なら戻して 3 秒）で自動で止まる。顔が見えているうちはスヌーズボタンを出さない

## ビルド

Flutter 3.35 以降。`flutter pub get` のあと：

```bash
flutter test                         # 判定のテスト（カメラ無しで動く）
flutter build apk --release          # 動作確認用（広告はテスト ID・開発者モード無効）
powershell -File tools/build-release.ps1   # Play 用 AAB（下の「公開しない値」を読む）
```

**必ず release ビルドを実機に入れて起動まで確認してください。** R8 の縮小で release だけ壊れることがあります（`android/app/proguard-rules.pro` に経緯）。エミュレータにはカメラ・マイクの実センサーが無いので実機推奨です。

### 公開しない値（git 管理外）

| ファイル | 中身 | 無いとき |
|---|---|---|
| `android/key.properties` | 署名（[example](android/key.properties.example)） | debug 署名になる。Play には上げられない |
| `android/admob.properties` | AdMob のアプリ ID と広告ユニット ID（[example](android/admob.properties.example)） | Google の公開テスト ID で動く |
| `tools/release.env` | `DEV_PASSPHRASE=`（開発者モードの合言葉） | 開発者モードは開かない |

フォークして自分の名前で出す場合は、`applicationId`（`android/app/build.gradle.kts`）と上の値を自分のものに替えてください。ML Kit（顔検出）は Google Play 開発者サービスに依存します。F-Droid 向けには広告 SDK と ML Kit を外した別ビルドが要ります（未着手）。

## 医療情報の扱い ⚠️

このアプリは**診断をしない**。記録タブの受診サジェストは「医師に相談することをすすめる」だけで、病名を断定するコードは存在しない。**この方針を変更しないこと。**

- `SleepLogService.needsClinicalAttention` は保守的な閾値（過去 14 日で 5 日以上 or 10 回以上）で**カードを出すかどうかだけ**を決める
- `models/sleep_symptoms.dart` は**点数化しない**症状チェックリスト。Epworth Sleepiness Scale や STOP-BANG は著作権があり商用利用にライセンスが要るため採用していない
- 改善タブは「睡眠衛生だけでは慢性不眠に臨床的な改善は出ない、CBT-I が第一選択」と正直に書く

引用: Brooks & Lack, *SLEEP* 2006（10 分仮眠）／Hilditch & McHill, *Nat Sci Sleep* 2019（睡眠慣性）／Gardiner et al., *Sleep Med Rev* 2023（カフェイン）／Trauer et al., *Ann Intern Med* 2015（CBT-I）／Edinger et al., *J Clin Sleep Med* 2021（AASM）。アラーム音は Bruck & Thomas（520Hz 矩形波・T-3）に基づく。

## プライバシー

カメラ映像・音声は端末内で処理し、送信も録画もしない。「声で止める」は端末の音声認識（Google）を使うため、鳴っている間の音声が認識サービスで処理されることがある（設定で切れる）。記録は `shared_preferences` に保存し、約 90 日で消える。詳細は[プライバシーポリシー](https://inemuri.toriumis.com/app/privacy/)。

## 参加する

- 実機での報告（機種・OS・場面・何が起きたか）が最も価値がある → [Issue](https://github.com/toriumib/inemuri_guard/issues)
- 翻訳（`lib/l10n/`、[docs/internationalization.md](docs/internationalization.md)）
- コードは `flutter analyze` 0 件・`flutter test` 全緑・release を実機で起動、の 3 つを PR の条件にしています

手順は [CONTRIBUTING.md](CONTRIBUTING.md)、脆弱性の連絡は [SECURITY.md](SECURITY.md)。版ごとの記録は [docs/CHANGELOG.md](docs/CHANGELOG.md)。

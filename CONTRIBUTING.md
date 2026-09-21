# 参加のしかた / Contributing

日本語のあとに English があります。

## いちばん助かること：実機の報告

コードより先に、こう報告してもらえると直せます。

- 機種と Android の版（例: SHARP A105SH / Android 11）
- 場面（机・車の助手席・裏向き、明るさ、眼鏡・サングラス・マスク）
- 何をしたら、何が起きたか。起きなかったか
- 「勝手に止まった」「鳴らなかった」なら、その前後 1 分の `adb logcat`（`EyeService|alarm|VoiceStop|CarTrigger` で絞ると読みやすい）

Issue のテンプレートに沿って書けば十分です。**映像やスクリーンショットに顔を入れる必要はありません。**

## 翻訳

`lib/l10n/` の arb を直すか足してください。手順は [docs/internationalization.md](docs/internationalization.md)。機械翻訳の直貼りではなく、その言語で自然に読める文にしてください。

## コード

1. Issue を立てるか、既存の Issue に「やります」と書く（大きい変更は先に相談を）
2. 変更は小さく。隣のコード・コメント・整形を「ついでに」直さない
3. PR の条件は 3 つ：`flutter analyze` 0 件、`flutter test` 全緑、**release ビルドを実機に入れて起動まで確認**（どの機種で確かめたかを PR に書く）
4. 判定（`DrowsinessDetector`）を変えるときは、必ず対応するテストを `test/drowsiness_detector_test.dart` に足す。カメラ無しで動くので CI でも回る
5. 「絶対に検知する」「必ず起こす」といった言い回しを UI・文書に足さない。医療情報の方針（README）を変えない

コミットは 1 行目に「日付 何をしたか」（例: `2026-09-21 サングラス時の誤検知を直す`）。言語は日本語でも英語でも。

## 公開しない値

署名鍵、AdMob の ID、開発者モードの合言葉はリポジトリに入れません（README「公開しない値」）。PR に含まれていたらマージしません。

## 行動規範

短く：相手の時間を尊重し、再現手順と根拠を添え、断定より観察を書く。ハラスメントはお断りします。

---

## Contributing (English)

### The most useful thing: device reports

- Device and Android version (e.g. SHARP A105SH / Android 11)
- Situation (desk / passenger seat / phone facing away, lighting, glasses / sunglasses / mask)
- What you did, what happened — or didn't
- For "it stopped by itself" / "it didn't ring": a minute of `adb logcat` around the event (filter on `EyeService|alarm|VoiceStop|CarTrigger`)

Follow the issue template. **You never need to include your face in a video or screenshot.**

### Translations

Edit or add the `.arb` files under `lib/l10n/` — see [docs/internationalization.md](docs/internationalization.md). Write naturally in the target language; don't paste machine output.

### Code

1. Open an issue or comment "I'll take this" on an existing one (discuss large changes first)
2. Keep changes small; don't reformat or "tidy" neighbouring code
3. Three conditions for a PR: `flutter analyze` clean, `flutter test` green, and **the release build installed and started on a real device** (say which one in the PR)
4. Any change to the judgment (`DrowsinessDetector`) needs a matching test in `test/drowsiness_detector_test.dart`; it runs without a camera, so CI can run it too
5. Never add wording like "always detects" or "guaranteed to wake you"; don't change the medical-information policy in the README

Commit subject: `YYYY-MM-DD what changed`, Japanese or English.

### Private values

Signing keys, AdMob IDs and the developer-mode passphrase are never committed (see "Values kept out of git" in the README). PRs containing them won't be merged.

### Conduct

Respect people's time, include reproduction steps and evidence, prefer observations over assertions. Harassment is not tolerated.

# AI顔による実検知デモ / Actual detector demo (2026-09-08)

## 検証範囲

- Web: 公開アプリにChromiumの仮想カメラから開眼5秒・閉眼12秒のAI画像列を入力。実際のMediaPipe処理から「目が閉じていました」のアラートを確認。テストボタン・検知値注入・UIの後付けは使用していません。
- iPhone幅: 同じ公開Webを390×844のChromiumで収録。iOS Safari、iPhone実機、ネイティブiOSアプリの検証ではありません。
- Android: 既存のエミュレーター実録の秒数設定部分を使用。同じAI顔によるAndroid検知映像はまだ収録できていません。仮想シーンの画像表示・カメラ位置合わせが未完了です。
- 28秒、1080×1920、H.264/AAC。`detection-demo-voiced-ja/en.mp4`はWindows標準音声によるナレーション付き（Haruka / Zira）。`detection-demo-ja/en.mp4`は無音版。音・振動は機能説明であり、アプリ音声の録音による実証ではありません。
- 生身の眠気や検知精度を検証する動画ではありません。架空人物の静止画列を用いた機能デモです。SNSにはAI生成コンテンツの表示を付けてください。
- 公開サイト・ストアはこの版に差し替えていません。Android検知とiPhone実機は未完了のため、既存公開物を維持しています。
- ブラウザーのファイルアクセス許可後の再確認は、Play Consoleタブへの接続タイムアウトで完了できませんでした。画像のアップロード・審査送信は行っていません。

## 再現

`camera-input.y4m`は大きいためGit対象外。FFmpegでeyes-open.pngを5秒、eyes-closed.pngを12秒、640×480/15fps/yuv420pで連結して作成。
`node tools/capture_detection_promo.cjs` → `python tools/render_detection_promo.py`。
ナレーションはPowerShell 7で`./tools/narrate_detection_promo.ps1`を実行（UTF-8ソース）。
検証結果は各`*-verification.json`。人物素材は組み込みimagegenで生成し、開眼画像を参照して閉眼のみ編集。

## 生成プロンプト

Open: Photorealistic webcam portrait of a completely fictional Japanese high-school student girl, modest navy blazer and white collared shirt, head and shoulders only. Front-facing level head, both eyes clearly fully open looking at camera, no glasses or hair covering eyes, relaxed neutral mouth. Soft even daylight, plain study room, natural skin, large centered face, entire head visible, 4:3 landscape. Nonsexual educational test image, no real person's likeness, no text, logos or UI.

Closed edit: Change ONLY both eyes to naturally fully closed relaxed eyelids. Preserve exact fictional identity, head position, mouth, hairstyle, clothing, lighting, framing and background. No head tilt. Photorealistic, not squinting. Nonsexual.

## X投稿案（Web検知デモ版）

作業・勉強中、気づいたら目を閉じてた…。
「居眠りガード」はカメラで閉眼の兆候を検知してアラート。何秒で知らせるかも調整できます。
動画はAI生成の顔を実際のWeb検知に入力したデモです。
音とバイブ、どっち派？

Web: https://inemuri.toriumis.com/
Android: https://play.google.com/store/apps/details?id=com.stop.sleeping
#個人開発 #居眠りガード

# 実画面紹介セット（2026-09-08）

- inemuri-real-ja.mp4 / inemuri-real-en.mp4: 24秒、1080×1920、30fps、H.264 / AAC。
- cover-ja.jpg / cover-en.jpg: 縦型サムネイル。冒頭0秒と同じ内容。
- thumbnail-wide-ja.jpg / thumbnail-wide-en.jpg: 横型1280×720。
- play-feature-ja.png / play-feature-en.png: Play用1024×500。既存ストア用スクリーンショットを使用。
- web-recording.webm: 公開Webアプリの画面収録。搭載の「起こし方を試す」ボタンを使用。実際の睡眠検知を撮影したものではない。
- android-recording.mp4: Android開発版のエミュレーター画面収録。閉眼時間スライダーの操作を収録。ストア公開版と画面が異なる場合あり。
- android-nap.png: 同じエミュレーターで撮影した実画面。
- 動画は実画面の録画と静止画を編集したもの。ライブの検知結果を合成していない。カメラに顔を映した検証動画ではない。
- 音声はオリジナルの合成効果音。字幕焼き込み、日本語・英語版あり。発報音そのものの録音ではない。

再生成: tools/capture_web_promo.cjs → tools/capture_android_promo.py → tools/render_real_promo.py。
収録スクリプトは専用の空のブラウザ環境とエミュレーターを使用し、ユーザーの個人データを収録しない。
raw/ は録画ライブラリが作る重複ファイルのためGitに含めない。

ストアの動画欄はYouTubeの公開または限定公開URLが必要。MP4ファイルをその欄へ直接登録することはできない。YouTubeへの投稿はこの作業では実施していない。

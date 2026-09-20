# Androidの日英対応 / Android localization

2026-09-21 / v1.9.0+14。主要な見張り操作を日英化した開発版であり、全画面の翻訳完了やストア公開を意味しない。

## 対応した範囲

- 初回の規約要点、カメラ開始、顔・目と音の確認、準備完了、停止。
- カメラ・マイク入力の状態、再接続、権限・音量・通知設定への案内。
- 感度、机／車、プレビュー、警告と手動停止、休憩案内。
- ナビゲーションと上部の状態、警告通知、通知の停止操作、時計の通知テスト。
- Androidのアプリ名、クイック設定タイル、監視サービス通知、カメラのエラー。
- 任意の音声停止は端末の認識器が提供する日英の言語IDを選択。「stop」「I'm awake」「I am awake」と従来の日本語に対応。「unstoppable」など単語の一部分では英語の停止語に一致しない。言語選択中に警告を止めた場合も、後から認識を開始しない。

端末の優先言語一覧で最初に見つかる日本語・英語を使い、両方なければ英語を使う。アプリ内の独立した言語設定はまだない。FlutterのLocale解決とサービスの文言は同じ規則。Androidリソースは標準の言語解決に従う。翻訳の切替でWidgetの状態や検知サービスを作り直さない。

初回のプライバシー説明も処理実態に合わせた。カメラ・呼吸音の検知と、任意の端末音声認識・広告・課金の通信を区別する。認識した言葉をデバッグログに出さない。音声認識の利用可否・認識精度は端末と提供元に依存する。

## 翻訳を変更する

Flutterは `lib/l10n/app_en.arb` と `app_ja.arb` を編集し、`flutter gen-l10n` を実行する。`lib/l10n/generated/` は生成物として追跡するが、直接編集しない。秒数などはARBのplaceholderを使い、翻訳文を文字列連結で組み立てない。

Androidは `android/app/src/main/res/values/strings.xml`（既定英語）と `values-ja/strings.xml` をそろえる。通知チャンネルID、通知アクションID、Intent、保存用キーは翻訳しない。

構成は [Flutter公式の国際化ガイド](https://docs.flutter.dev/ui/internationalization) に基づく。OSS公開を選ぶ場合もこの構成で翻訳を受け付けられるが、リポジトリの公開設定・ライセンスは今回変更していない。

## 検証

`flutter test`、`flutter analyze`、`flutter build apk --debug`。

結果: 自動テスト119件成功、静的解析指摘なし、v1.9.0+14 debug APKビルド成功。英語の主要操作は可読フォントを使った追加のWidgetプレビューでも確認した。実機は未接続であり、ストアへは未提出。

新しい回帰テストは、英語での初回準備と音の明示確認、入力停止からの再接続、停止、言語変更時の準備状態維持、320px幅と拡大文字、通知停止IDの維持、認識SDKへの英語言語IDの受渡し、言語取得中の停止を確認する。既存の日本語テストは明示的に日本語を指定する。

自動テストはカメラ・音・時計・実際の発話を検証するものではない。テストの画面画像はFlutterのテスト用フォントの場合があり、実機の表示確認に置き換えない。

## 続けて対応する範囲

- 設定の大部分、仮眠・記録・改善画面、購入説明、支援リンク、ポモドーロ・水分補給の通知本文、車両自動開始・呼出し通知。
- 過去に保存した日本語の記録。表示言語で永続データを上書きしない設計で整える。
- 英語プライバシーポリシー全文と日本語原文の実装照合。現行リンクには英語UIでJapaneseと付記。既存の英語利用規約URLはHTTP 200を確認した。
- 既に出た通知や予約済みの通知、通知チャンネル表示名の端末言語変更後の更新。今回の保証範囲は現在の言語で新しく生成する対応済み文言。
- 日本語・英語の実機で権限、通知、音声認識、Bluetooth音声出力、時計転送、バックグラウンド動作を確認。ストア提出と配信地域設定は別途。

## English summary

Version 1.9.0 adds Japanese/English localization for the main Android monitoring
flow: first-use setup, alerts, recovery, sensitivity and alarm notifications.
It follows device language preferences, falling back to English. Optional voice
control selects an available recognizer locale and accepts “stop” or “I'm awake”.
Speech may be processed by the device's speech provider, as explained in the UI.

Localization is incomplete: most settings, history, guidance, purchase text and
some secondary notifications remain in Japanese. This is a development build;
device validation, full privacy-policy translation and store release remain open.
Repository visibility and licensing are unchanged. No user-growth result is claimed.

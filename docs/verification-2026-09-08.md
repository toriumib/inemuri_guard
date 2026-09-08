# 2026-09-08 Android 検証

- 検知画面の build / post-frame callback で行っていた発報と記録を、センサーのリスナーと microtask に移した。画面フレームが停止していても Dart のイベント処理から実行する。
- 通知アクセス設定を開く経路は設定画面の明示的なボタンのみ。ユーザー報告の意図しない画面遷移は再現未確認。
- flutter analyze: 指摘なし。
- flutter test: 既存20件成功。これは実機のバックグラウンド発報を保証するものではない。
- flutter build apk --debug: 成功。生成物 build/app/outputs/flutter-apk/app-debug.apk。
- adb devices に端末なし。実機への更新、マイクのバックグラウンド入力、検知から音・振動までの実機確認は未実施。

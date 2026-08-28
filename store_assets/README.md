# ストア掲載素材

| ファイル | 用途 | 状態 |
|---|---|---|
| `play_icon_512.png` | Play アイコン 512x512 | ✅ `tools/gen_icons.py` で生成 |
| `feature_graphic_1024x500.png` | フィーチャーグラフィック | ✅ `tools/gen_feature_graphic.py` で生成 |
| `screenshots_play/` | **Play にアップロードするのはこちら** | ✅ 1200x2400・比2.00 |
| `screenshots/` | エミュレータの生キャプチャ（元データ） | 比2.22 のため**そのままでは使えない** |

## 注意

- **フィーチャーグラフィックには実際のアプリ画面を入れること。**
  以前のアプリで抽象イラストを使い、Play から「アプリ内体験を反映していない」
  と指摘された経緯がある。`gen_feature_graphic.py` は `screenshots/02_nap.png`
  を合成しているので、UI を変えたらスクショを撮り直してから再生成する。
- **スクリーンショットは 2:1 を超えると Play に拒否される。**
  最近の端末は 20:9 なので生キャプチャは 2.22:1。`tools/prep_screenshots.py`
  が左右にアプリの背景色を足して 2.00 に収める（切り取ると下部ナビが欠けるため）。
- スクショ撮影時は広告を消しておくこと。デバッグビルドのバナーは
  「テスト広告」と表示されるため。`adb shell run-as` で
  `flutter.ads_removed` を true にすると消せる。

## 撮り直し手順

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
# 広告を消す（run-as は debuggable ビルドでのみ可）
adb shell am force-stop com.toriumi.inemuri_guard
# → FlutterSharedPreferences.xml に flutter.ads_removed=true を書く
# 撮影後:
python tools/prep_screenshots.py
python tools/gen_feature_graphic.py
```

# 広告と同意の実装 / Ads and consent

更新: 2026-09-21 / v1.8.2+13

## 表示方針

広告は初回準備完了後、検知・マイク・仮眠・ポモドーロ・警告が停止しているときに本人が開いた「記録」タブのバナーだけ。検知画面、準備、権限の復旧、設定、時計、通知には広告を表示しない。全画面広告とその先読みは削除した。

監視開始、警告、タブ変更、Premium購入、同意情報の更新時にバナーを取り除く。アプリがinactive / hidden / pausedへ移行したら広告を破棄する。背景での読み込みや表示を収益に数える設計にしない。監視や警告が終わっただけでは再表示せず、本人が記録タブを開き直す必要がある。

同意情報は利用規約への同意後、HomeShellの初回表示で一度更新する。初回設定や自動検知は待たせない。広告SDKは同意状態と表示条件を満たす記録画面で初めて初期化する。条件確認前の先読みはしない。

## 同意操作

- UMPの情報を更新し、canRequestAdsを確認する。アプリ独自の保存値で同意を代用しない。
- 同意が必要な場合、設定タブの「広告のプライバシー設定」から本人の操作でフォームを開く。この操作をしなくても検知・警告は使える。
- 初回フォームの読み込みが遅れた場合、表示直前に前面・設定タブ・監視停止を再確認する。表示できなくなったフォームは破棄する。
- プライバシー選択の変更が必要な地域では、Premium購入後も設定への入口を残す。検知やタイマーが動作中なら停止後に変更できると案内する。
- 同意確認に失敗したときは広告を読み込まず、設定から再試行できる。広告の障害を検知側のエラーにしない。
- 設定の説明は端末言語に応じて日本語または英語。ただしAndroid全体の英語化は未完了。

## 検証範囲

自動テストでは実広告を取得せず、SDK境界を差し替えて広告のload / dispose呼び出しを確認する。検知・マイクの各状態、仮眠・集中タイマー、Premium、初回準備、タブ切替、背面移行、広告の読み込み失敗、遅延完了、同意変更、二重操作を検証する。

結果: 新規17件を含む全109件成功、flutter analyze指摘なし、v1.8.2+13 debug APKビルド成功。

実機が未接続のため、実際の広告ビュー、UMPの地域別フォーム、OSやメディエーションSDKの動作、購入・復元と広告停止の連携は未検証。ストアへの公開は別工程。

## 公開前の実機確認

1. AdMobのPrivacy & messagingで本アプリのメッセージ設定を確認する。コードの追加だけで管理画面の設定が完了したと扱わない。
2. テスト端末とテスト広告を使い、対象地域の同意が必要／不要、未選択、選択変更、フォームの通信失敗を確認する。UMPの地域強制設定やテスト端末IDを製品版へ入れない。
3. 設定・初回準備・検知開始で広告やフォームが割り込まないことを確認する。記録タブで監視を開始し、広告が消えることを確認する。
4. アプリ切替、画面ロック、復帰、回線切断、遅い通信で広告が背景に残らないことと、検知・警告・停止操作が使えることを確認する。
5. テスト購入と復元で広告が消えること、購入済みでも必要なプライバシー設定へ戻れることを確認する。

料金、商品内容、配信国、広告ユニットの管理画面設定は今回変更していない。広告表示機会は減るため、収益改善は未検証。継続利用、苦情、広告収益、買い切り購入の実測で判断する。

## English

Version 1.8.2 uses banners only on the History tab when setup is complete and all
monitoring, alarms and timers are stopped. Ads are removed when monitoring starts,
the user leaves History, the app becomes inactive, Premium is purchased, or consent
is being updated. Ending an alarm does not automatically restore an ad; the user
must revisit History. Interstitials and their preloading have been removed.

Consent information is refreshed after the terms gate without blocking setup or
monitoring. The advertising SDK is initialized lazily after UMP permits requests
and the placement is eligible. Required forms open only from an explicit settings
action. A form that finishes loading after the user leaves the idle settings screen
is disposed instead of appearing unexpectedly. Privacy choices remain accessible
for Premium users when required. Consent failures suppress ads, not monitoring.

Automated tests replace the SDK boundary and observe load/dispose calls; they do
not fetch real ads. AdMob messaging configuration and physical-device verification
are still required before release. Prices and distribution settings are unchanged.
No revenue or retention improvement has been measured.

## 公式資料

- [AdMob Flutter UMP](https://developers.google.com/admob/flutter/privacy)
- [AdMob interstitial placement rules](https://support.google.com/admob/answer/6201362?hl=en)
- [AdMob Flutter banners](https://developers.google.com/admob/flutter/banner)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/terms_gate.dart';
import '../services/alarm_service.dart';
import '../services/car_trigger.dart';
import '../services/drowsiness_detector.dart';
import '../services/notification_service.dart';
import '../services/nudge_service.dart';
import '../services/purchase_service.dart';
import '../services/stats_service.dart';
import '../services/support_service.dart';
import '../services/torch.dart';
import '../services/voice_stop.dart';
import '../theme/app_skin.dart';
import '../theme/app_theme.dart';
import '../widgets/breathing_card.dart';
import '../widgets/hydration_card.dart';
import '../widgets/tone_row.dart';
import '../widgets/quick_setup_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsService>();
    final purchases = context.watch<PurchaseService>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _DetectionSettingsCard(stats: stats),
        const QuickSetupCard(showShortcut: true),
        _WatchBridgeCard(stats: stats),
        const SizedBox(height: 16),
        if (CarTrigger.isSupported) ...[
          const _CarStartCard(),
          const SizedBox(height: 16),
        ],
        _PremiumCard(stats: stats, purchases: purchases),
        const SizedBox(height: 16),
        _SkinCard(stats: stats, purchases: purchases),
        const SizedBox(height: 16),
        const _NudgeCard(),
        const SizedBox(height: 16),
        const HydrationCard(),
        const SizedBox(height: 16),
        _BetaCard(stats: stats),
        const SizedBox(height: 16),
        const _SupportCard(),
        const SizedBox(height: 16),
        const _AboutCard(),
      ],
    );
  }
}

/// 検知まわりの、たまに触る設定。検知画面は「始める・止める・使う場所・秒数」
/// だけにして、残りはここに寄せる（だれでも使えるように、と本人の要望）。
class _DetectionSettingsCard extends StatelessWidget {
  final StatsService stats;
  const _DetectionSettingsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final alarm = context.read<AlarmService>();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('検知の設定', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('開いた瞬間から見張る'),
              subtitle: const Text('アプリを開くだけでカメラが始まります。'),
              value: stats.autoStartDetection,
              onChanged: (v) => stats.setAutoStartDetection(v),
            ),
            if (VoiceStop.isSupported)
              ListenableBuilder(
                listenable: VoiceStop.instance,
                builder: (context, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('声で止める'),
                  subtitle: Text(
                    VoiceStop.instance.unavailable
                        ? 'この端末では音声認識が使えませんでした。音・振動・ボタンで止められます。'
                        : '鳴っている間「起きた」「止めて」と言うと止まります。'
                              '端末の音声認識を使います（寝息検知を使っている間は声では止められません）。'
                              '${VoiceStop.instance.lastHeard.isEmpty ? '' : '\n直近に聞こえた言葉: 「${VoiceStop.instance.lastHeard}」'}',
                  ),
                  value: stats.voiceStop,
                  onChanged: (v) async {
                    await stats.setVoiceStop(v);
                    alarm.useVoice = v;
                    if (v) await VoiceStop.instance.prepare();
                  },
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('暗いところでは画面で照らす'),
              subtitle: const Text(
                '暗くて顔が見つからないとき、画面を白く明るくして顔を照らします。'
                '顔が見つかると元に戻ります。',
              ),
              value: stats.illuminateInDark,
              onChanged: (v) => stats.setIlluminateInDark(v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('アラーム中に画面を点滅させる'),
              subtitle: const Text('通常は音と振動で知らせます。点滅が苦手な方はオフのまま使えます。'),
              value: stats.flashAlarm,
              onChanged: (v) async {
                await stats.setFlashAlarm(v);
                alarm.useTorch = v && stats.useBackCamera && Torch.isSupported;
              },
            ),
            const Divider(height: 24),
            ToneRow(alarm: alarm),
          ],
        ),
      ),
    );
  }
}

/// 車に乗ったら始める。起動の手間を無くすための入口を 1 か所に集める。
class _CarStartCard extends StatelessWidget {
  const _CarStartCard();

  Future<void> _pickCar(BuildContext context) async {
    final car = context.read<CarTrigger>();
    final devices = await car.bondedDevices();
    if (!context.mounted) return;
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ペアリング済みの Bluetooth 機器が見つかりません。'
            '先に端末の設定で車とペアリングし、Bluetooth の許可を与えてください。',
          ),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<({String name, String address})?>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Text(
                '車のオーディオはどれ？',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final d in devices)
              ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(d.name),
                subtitle: Text(d.address),
                onTap: () => Navigator.pop(c, d),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await car.setCar(picked.address, picked.name);
  }

  @override
  Widget build(BuildContext context) {
    final car = context.watch<CarTrigger>();
    final c = AppColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('車に乗ったら始める', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              'アプリを開く手間を無くします。乗ったことを検知すると、画面がロック中なら'
              'そのまま開いて見張りが始まり、解除中なら通知が出て 1 タップで始まります。'
              '降りたら止まります。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bluetooth_audio, color: c.accentGood),
              title: const Text('車の Bluetooth につながったら'),
              subtitle: Text(
                car.btName == null
                    ? '車のオーディオを選んでください（位置情報は使いません）'
                    : '${car.btName} につながったら始めます',
              ),
              trailing: car.btName == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '解除',
                      onPressed: () => car.setCar(null, null),
                    ),
              onTap: () => _pickCar(context),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('運転を体で検知して始める（試験的）'),
              subtitle: const Text(
                '端末の身体活動認識で「乗り物に乗った」を受けます。バス・電車と区別できないので、'
                '通勤電車でも通知が出ます。位置情報は使いません。',
              ),
              value: car.startOnDrive,
              onChanged: (v) async {
                final ok = await car.setStartOnDrive(v);
                if (v && !ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('身体活動認識の許可が必要です。')),
                  );
                }
              },
            ),
            const SizedBox(height: 6),
            Text(
              'ほかの入口：クイック設定に「居眠りガード」タイルを追加すると、どの画面からでも 1 回で始まります。'
              'ホルダーに NFC タグ（URI: inemuri://start）を貼れば、置くだけで開きます。'
              '自動化アプリからは com.stop.sleeping.START で起動できます。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// 開発中の機能。使い道が限られる・まだ実機での検証が薄いものを、
/// 一般の画面から外してここに集める。開くまで見えない。
class _BetaCard extends StatelessWidget {
  final StatsService stats;
  const _BetaCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final detector = context.watch<DrowsinessDetector>();
    final alarm = context.read<AlarmService>();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        title: Text(
          '開発中の機能（β）',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          '試している機能。動かない端末・場面があります。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
        ),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('裏向きに置いて背面カメラで見張る'),
            subtitle: Text(
              '画面を外へ向けて置き、背面カメラで自分を見ます。'
              '${Torch.isSupported ? 'アラーム中は背面のライトも点滅します。' : ''}'
              '机では切ったままで。',
            ),
            value: stats.useBackCamera,
            onChanged: (v) async {
              await stats.setUseBackCamera(v);
              alarm.useTorch = v && stats.flashAlarm && Torch.isSupported;
              // 見張っている最中なら、カメラをその場で開き直す。
              await detector.setUseBackCamera(v);
            },
          ),
          const SizedBox(height: 10),
          const BreathingCard(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// 時計連携（β）。仕組みはスマホの通知をWear OSが自動で時計へ転送する
/// もので、専用の時計アプリは不要。オフにすると通知へ
/// FLAG_LOCAL_ONLY を付けて転送を止める。
class _WatchBridgeCard extends StatelessWidget {
  final StatsService stats;
  const _WatchBridgeCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final notifications = context.read<NotificationService>();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'スマートウォッチにも知らせる',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              '対応する時計へ警告通知を転送し、時計側の設定に応じて振動で知らせます。'
              'Wear OSでは専用の時計アプリは不要です。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: stats.watchBridge,
              onChanged: (v) {
                notifications.bridgeToWatch = v;
                stats.setWatchBridge(v);
              },
              title: const Text('時計へ転送する'),
              subtitle: const Text('オフにしてもスマホ側の振動・音は変わりません'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.watch_outlined),
              label: const Text('時計への通知を試す'),
              onPressed: !stats.watchBridge
                  ? null
                  : () async {
                      var sent = false;
                      try {
                        sent = await notifications.testWatchNotification();
                      } catch (_) {}
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            sent
                                ? 'テスト通知を出しました。時計が振動したか確認してください。スマホも振動する場合があります。'
                                : '通知を出せませんでした。スマホの通知許可を確認してください。',
                          ),
                        ),
                      );
                    },
            ),
            const Text(
              '届かない場合は、時計の管理アプリで「居眠りガード」の通知を許可し、'
              '時計の消音・おやすみモードと接続状態を確認してください。'
              'スマホ使用中も時計へ通知する設定が必要な機種があります。',
            ),
            const SizedBox(height: 6),
            const Text(
              '時計の接続・到達をこの画面で確認する機能はありません。'
              'Wear OS以外はメーカーの通知転送対応によります。'
              '時計に「止める」が表示される場合は警告を停止できます。'
              '通知を払い消すだけではアラームは止まりません。',
            ),
          ],
        ),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  final StatsService stats;
  final PurchaseService purchases;
  const _SkinCard({required this.stats, required this.purchases});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('テーマ', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              stats.isPremium
                  ? 'どのテーマも端末のライト／ダーク設定に合わせて切り替わります。'
                  : '有料のテーマはプレミアムに含まれます。'
                        'どのテーマも端末のライト／ダーク設定に合わせて切り替わります。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            for (final skin in AppSkin.values) ...[
              // 有料テーマは単品で売らない。押すとプレミアムの購入に進む。
              _SkinRow(
                skin: skin,
                owned: stats.ownsSkin(skin),
                selected: stats.selectedSkin == skin,
                price: skin.productId == null
                    ? null
                    : purchases.priceFor(PurchaseService.premiumId),
                busy:
                    skin.productId != null &&
                    purchases.pendingProductId == PurchaseService.premiumId,
                onSelect: () => stats.selectSkin(skin),
                onBuy: purchases.available && skin.productId != null
                    ? () => purchases.buy(PurchaseService.premiumId)
                    : null,
              ),
              if (skin != AppSkin.values.last)
                Divider(height: 18, color: c.border),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkinRow extends StatelessWidget {
  final AppSkin skin;
  final bool owned;
  final bool selected;
  final String? price;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback? onBuy;

  const _SkinRow({
    required this.skin,
    required this.owned,
    required this.selected,
    required this.price,
    required this.busy,
    required this.onSelect,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final preview = Theme.of(context).brightness == Brightness.dark
        ? skin.dark
        : skin.light;

    return Row(
      children: [
        // A live swatch of the skin's own palette, so the choice is visible
        // before buying rather than a name on a list.
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: preview.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Dot(preview.accentNap),
              const SizedBox(width: 3),
              _Dot(preview.accentAlert),
              const SizedBox(width: 3),
              _Dot(preview.accentGood),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                skin.label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontSize: 14),
              ),
              Text(
                skin.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 11.5, height: 1.35),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Fixed-width trailing slot so a long price or label can never push
        // the row past the card edge.
        SizedBox(
          width: 74,
          child: Align(
            alignment: Alignment.centerRight,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : owned
                ? (selected
                      ? Icon(Icons.check_circle, color: c.accentGood, size: 22)
                      : TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: onSelect,
                          child: const Text('使う'),
                        ))
                : (onBuy != null && price != null)
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accentNap,
                      foregroundColor: c.accentNapInk,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: onBuy,
                    child: Text(
                      price!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Text(
                    '準備中',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 11.5),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// プレミアム（買い切り 980円）。売る商品はこれ一つ。
/// 起こす機能は全部無料のまま。有料は「無くても困らないが、あると毎日
/// ちょっと良い」もの——広告なし・テーマ全部・通知の差出人フィルタ。
class _PremiumCard extends StatelessWidget {
  final StatsService stats;
  final PurchaseService purchases;
  const _PremiumCard({required this.stats, required this.purchases});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final price = purchases.priceFor(PurchaseService.premiumId);
    final busy = purchases.pendingProductId == PurchaseService.premiumId;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('プレミアム', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              stats.isPremium
                  ? '購入済みです。ありがとうございます。'
                  : '買い切り一回で、ずっと。起こす機能はこれからも全部無料です。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            for (final line in const [
              '広告が出なくなる（下のバナーと全画面）',
              'テーマが全部使える',
              '「呼ばれたら起こす」を差出人・件名で絞り込める',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      stats.isPremium
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      size: 18,
                      color: stats.isPremium ? c.accentGood : c.textDim,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if (stats.isPremium)
              (stats.premium
                  ? const SizedBox.shrink()
                  : Text(
                      // 旧「広告除去」「テーマ」を買った人。追加の支払いは無い。
                      '以前に広告除去やテーマを買った方は、そのままプレミアムです。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ))
            else if (busy)
              const Center(child: CircularProgressIndicator())
            else if (purchases.available && price != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accentAlert,
                    foregroundColor: c.accentAlertInk,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => purchases.buy(PurchaseService.premiumId),
                  child: Text('プレミアムにする　$price'),
                ),
              )
            else
              Text(
                // ストアに繋がっているのに値段が無い＝Play Console 側で
                // premium がまだ有効になっていない。接続失敗と混ぜない。
                purchases.storeReady
                    ? 'この商品は準備中です。'
                    : 'ストアに接続できませんでした。時間をおいて開き直してください。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: purchases.restore,
                child: const Text('購入を復元'),
              ),
            ),
            if (purchases.lastError != null)
              Text(
                '購入に失敗しました：${purchases.lastError}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: c.accentAlert),
              ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('応援する', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '広めてもらえると、開発を続ける力になります。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.star_outline,
              color: c.accentNap,
              label: 'レビューを書く',
              subtitle: 'Playストアで評価する',
              onTap: SupportService.openStoreListing,
            ),
            _ActionTile(
              icon: Icons.share_outlined,
              color: c.accentGood,
              label: 'アプリを共有',
              subtitle: 'LINEなどで友だちに送る',
              onTap: SupportService.shareApp,
            ),
            _ActionTile(
              icon: Icons.alternate_email,
              color: c.text,
              label: '𝕏 でポストする',
              subtitle: '感想をつぶやく',
              onTap: SupportService.shareOnX,
            ),
            _ActionTile(
              icon: Icons.coffee_outlined,
              color: c.accentAlert,
              label: '開発者にコーヒーをおごる ☕',
              subtitle: 'Buy Me a Coffee を開く',
              onTap: SupportService.openBuyMeACoffee,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14),
      ),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

/// 🛠 開発者モードの合言葉。動作確認と画面撮影のためのもの。
/// なまえがお（同じ開発者の別アプリ）と同じ仕組みで揃えてある。
const String _kDevPassphrase = 'Toriumi';

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  Future<void> _askDevPassword(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('開発者モード'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(labelText: '合言葉'),
          onSubmitted: (_) => Navigator.pop(c, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('有効にする'),
          ),
        ],
      ),
    );
    final input = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !context.mounted) return;
    if (input != _kDevPassphrase) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('合言葉が違います')));
      return;
    }
    // ⚠️ 動作確認・スクショ撮影中に広告が挟まらないようにするためだけの
    //    フラグ。課金の代わりにはならない（購入フローとは別経路）。
    await context.read<StatsService>().setAdsRemoved(true);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('開発者モードON：広告を消しました')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ⚠️ 一般ユーザーの目に触れない場所に置く。見出しの長押しで開く
            //    （なまえがおはボタン露出だが、こちらはボタン数を増やしたく
            //    ないので長押しにした）。
            GestureDetector(
              onLongPress: () => _askDevPassword(context),
              child: Text(
                'このアプリについて',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'カメラでまぶたと頭の傾きを見て、眠気の兆候が続いたら音・振動・画面・ライトで起こす道具です。'
              'まぶたと頭の解析は端末の中だけで行い、映像を送信・録画しません。マイクの音も録音しません。\n\n'
              '「声で止める」は端末の音声認識機能を使うため、鳴っている間の音声が端末外の認識サービスで'
              '処理されることがあります（設定で切れます）。\n\n'
              '補助の道具であり、睡眠の代わり・医療機器・安全装置ではありません。'
              '暗さ・眼鏡・サングラス・マスク・顔の向きなどで、見逃しや誤作動があります。'
              '強い眠気が続く場合は医療機関にご相談ください。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            // 車載機器と同じ水準の免責。用途としては残すが、責任の所在は
            // 運転者にあることを、ここと背面カメラの説明の両方で言う。
            Text(
              '運転・車内でのご利用について',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '本アプリは運転者の注意義務や安全確認を代替するものではなく、'
              '運転支援装置・安全装置でもありません。眠気の兆候を見逃すこと、'
              '眠っていないのに作動することがあります。本アプリの動作・不作動・表示に'
              '依拠して生じた事故・損害について、当運営者は一切の責任を負いません。'
              '運転中は端末を操作しないでください。端末は視界や操作の妨げにならない位置に'
              '確実に固定し、道路交通法など各地域の法令に従ってご利用ください。'
              '眠気を感じたら、アプリの反応にかかわらず安全な場所に停車して休んでください。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(TermsGate.url),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('利用規約'),
                ),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(TermsGate.privacyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('プライバシーポリシー'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Slack/Teams/メールの通知で起こす設定。
///
/// 通知アクセスは Android でもっとも強い権限のひとつなので、
/// **何を見ていて何を見ていないか**を画面に明記してある。
/// 許可はユーザーが設定画面で自分で与えるしかない（アプリからは開くだけ）。
class _NudgeCard extends StatefulWidget {
  const _NudgeCard();

  @override
  State<_NudgeCard> createState() => _NudgeCardState();
}

class _NudgeCardState extends State<_NudgeCard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 設定画面で許可して戻ってきたら、状態を取り直す。
    if (state == AppLifecycleState.resumed) {
      context.read<NudgeService>().refreshGranted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final nudge = context.watch<NudgeService>();
    if (!nudge.isSupported) return const SizedBox.shrink();

    // まだ一度も聞いていないなら、スイッチを探させるより先に問いを出す。
    // 「はい」を押した時点で有効になり、許可の画面まで開く。
    if (!nudge.asked) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'メールや電話、Slack、LINE などで連絡が来たとき、'
                'たたき起こす機能が欲しいですか？',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '仮眠中や集中しているあいだに呼ばれても気づけるようになります。'
                'あとから設定でいつでも切り替えられます。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              // 横並びにすると日本語のラベルが入りきらず見切れる（実機で確認）。
              // 縦に積んで全幅にしておけば、文字が伸びても崩れない。
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accentAlert,
                    foregroundColor: c.accentAlertInk,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => nudge.answer(true),
                  child: const Text('はい、起こしてほしい'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => nudge.answer(false),
                  child: const Text('いらない'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('呼ばれたら起こす', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              nudge.apps.isEmpty
                  ? 'Slack や Teams、メールの通知が届いたら起こします。'
                  : '${nudge.apps.join("・")} の通知が届いたら起こします。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Text(
                nudge.senderFilter.isEmpty
                    ? '見ているのは「どのアプリから来たか」だけです。'
                          '本文も件名も読んでいませんし、どこにも送らず保存もしません。'
                    : '差出人を登録しているあいだは、一致するかを調べるために'
                          '通知の件名と本文を端末の中だけで照合します。'
                          '読んだ内容はどこにも送らず、保存もログにも残しません。',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: nudge.enabled,
              onChanged: (v) => nudge.setEnabled(v),
              title: const Text('通知で起こす'),
              subtitle: Text(
                nudge.granted ? '通知へのアクセスは許可されています' : '通知へのアクセスがまだ許可されていません',
                style: TextStyle(
                  fontSize: 12,
                  color: nudge.granted ? c.textDim : c.accentAlert,
                ),
              ),
            ),
            if (nudge.enabled && !nudge.granted)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: nudge.openSettings,
                  child: const Text('通知へのアクセスを許可する'),
                ),
              ),
            if (nudge.enabled) ...[
              const Divider(height: 26),
              // 差出人の絞り込みはプレミアム。無料でもアプリ単位では起こせる。
              if (context.watch<StatsService>().isPremium)
                _SenderFilterField(nudge: nudge)
              else
                Text(
                  '差出人・件名で絞り込む（「上司からのメールだけ」など）は'
                  'プレミアムで使えます。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
            ],
            if (nudge.lastApp != null)
              Text(
                '直近: ${nudge.lastApp} の通知で起こしました',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

/// 差出人・件名の絞り込み。
///
/// 「上司のアドレスから来たときだけ起こしてほしい」に応えるための欄。
/// 空のままなら絞り込まない（対象アプリの通知すべてで起こす）ので、
/// 通知の中身を読む必要も無くなる。既定は空。
class _SenderFilterField extends StatefulWidget {
  final NudgeService nudge;
  const _SenderFilterField({required this.nudge});

  @override
  State<_SenderFilterField> createState() => _SenderFilterFieldState();
}

class _SenderFilterFieldState extends State<_SenderFilterField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.nudge.senderFilter.join(', '),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    // 半角カンマ・全角読点・改行のどれで区切っても受ける。
    widget.nudge.setSenderFilter(_controller.text.split(RegExp(r'[,、\n]')));
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _controller.text.trim().isEmpty
              ? '絞り込みを外しました。対象アプリの通知すべてで起こします。'
              : '登録しました。一致した通知だけで起こします。',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('この相手のときだけ起こす', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          'メールアドレスや名前を入れると、それを含む通知だけで起こします。'
          'カンマ区切りで複数登録できます。空にすると絞り込みません。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            hintText: 'bucho@example.com, 山田',
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: _save, child: const Text('登録')),
        ),
      ],
    );
  }
}

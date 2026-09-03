import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import '../services/stats_service.dart';
import '../services/support_service.dart';
import '../theme/app_skin.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsService>();
    final purchases = context.watch<PurchaseService>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SkinCard(stats: stats, purchases: purchases),
        const SizedBox(height: 16),
        _RemoveAdsCard(stats: stats, purchases: purchases),
        const SizedBox(height: 16),
        _WatchBridgeCard(stats: stats),
        const SizedBox(height: 16),
        const _SupportCard(),
        const SizedBox(height: 16),
        const _AboutCard(),
      ],
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
            Text('時計にも通知（β）', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '眠気を検知したとき、ペアリングしたWear OSの時計でも振動します。'
              'スマホの通知がそのまま時計へ転送される仕組みで、専用アプリは不要です。',
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
              'どのテーマも端末のライト／ダーク設定に合わせて切り替わります。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            for (final skin in AppSkin.values) ...[
              _SkinRow(
                skin: skin,
                owned: stats.ownsSkin(skin),
                selected: stats.selectedSkin == skin,
                price: skin.productId == null
                    ? null
                    : purchases.priceFor(skin.productId!),
                busy: purchases.pendingProductId == skin.productId,
                onSelect: () => stats.selectSkin(skin),
                onBuy: purchases.available && skin.productId != null
                    ? () => purchases.buy(skin.productId!)
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

class _RemoveAdsCard extends StatelessWidget {
  final StatsService stats;
  final PurchaseService purchases;
  const _RemoveAdsCard({required this.stats, required this.purchases});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final price = purchases.priceFor(PurchaseService.removeAdsId);
    final busy = purchases.pendingProductId == PurchaseService.removeAdsId;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('広告を消す', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              stats.adsRemoved
                  ? '購入済みです。ありがとうございます。'
                  : '買い切りで下部のバナー広告と全画面広告が出なくなります。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            if (stats.adsRemoved)
              Row(
                children: [
                  Icon(Icons.check_circle, color: c.accentGood, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '広告は無効になっています',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              )
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
                  onPressed: () => purchases.buy(PurchaseService.removeAdsId),
                  child: Text('広告を消す　$price'),
                ),
              )
            else
              Text(
                'ストアに接続できませんでした。時間をおいて開き直してください。',
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

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('このアプリについて', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'カメラ映像と音声はすべて端末内だけで処理され、外部に送信・保存されません。\n\n'
              '居眠り検知・仮眠タイマーは健康管理を補助する目的のもので、'
              '医療機器ではありません。睡眠に関する不調が続く場合は医療機関にご相談ください。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

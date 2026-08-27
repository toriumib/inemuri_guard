import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../theme/app_skin.dart';
import 'stats_service.dart';

/// 💳 Google Play billing for this app.
///
/// | Product ID       | Type          | What it unlocks            |
/// |------------------|---------------|----------------------------|
/// | `remove_ads`     | non-consumable| removes banner + interstitial |
/// | `skin_midnight`  | non-consumable| ミッドナイト theme         |
/// | `skin_forest`    | non-consumable| フォレスト theme           |
/// | `skin_sakura`    | non-consumable| サクラ theme               |
///
/// IMPORTANT (same trap as the nanimonjya/petaname setup): each ID must be
/// created and ACTIVATED in Play Console → 収益化 → アプリ内アイテム with
/// exactly these strings before anything resolves. Until then
/// `queryProductDetails` returns empty, [available] stays false, and the
/// purchase UI stays hidden — that's expected, not a bug. IDs cannot be
/// renamed after publishing.
///
/// Android purchases must be acknowledged within 3 days or Play auto-refunds
/// them; `completePurchase` does that, so it must run *after* the entitlement
/// is granted.
class PurchaseService extends ChangeNotifier {
  static const String removeAdsId = 'remove_ads';

  static Set<String> get allProductIds => {
    removeAdsId,
    ...AppSkin.paidProductIds,
  };

  final StatsService stats;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  final Map<String, ProductDetails> _products = {};
  bool storeReady = false;
  String? pendingProductId;
  String? lastError;

  PurchaseService(this.stats);

  /// True only when the store connected AND returned at least one product.
  /// The UI hides purchase cards while this is false rather than showing
  /// priceless buttons that fail on tap.
  bool get available => storeReady && _products.isNotEmpty;

  ProductDetails? productFor(String id) => _products[id];

  String? priceFor(String id) => _products[id]?.price;

  Future<void> init() async {
    final connected = await _iap.isAvailable();
    if (!connected) {
      notifyListeners();
      return;
    }
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) {
        lastError = e.toString();
        notifyListeners();
      },
    );
    final response = await _iap.queryProductDetails(allProductIds);
    for (final p in response.productDetails) {
      _products[p.id] = p;
    }
    storeReady = true;
    notifyListeners();
    // Re-apply anything already owned (new device, reinstall).
    await _iap.restorePurchases();
  }

  Future<void> buy(String productId) async {
    final product = _products[productId];
    if (product == null) return;
    pendingProductId = productId;
    lastError = null;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      pendingProductId = null;
      lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> restore() async {
    lastError = null;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grant(p.productID);
        case PurchaseStatus.error:
          lastError = p.error?.message;
        case PurchaseStatus.canceled:
          break;
        case PurchaseStatus.pending:
          continue;
      }
      if (p.productID == pendingProductId) pendingProductId = null;
      // Must run after the entitlement is granted, or Play refunds it.
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
    notifyListeners();
  }

  Future<void> _grant(String productId) async {
    if (productId == removeAdsId) {
      await stats.setAdsRemoved(true);
      return;
    }
    for (final skin in AppSkin.values) {
      if (skin.productId == productId) {
        await stats.grantSkin(skin);
        return;
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

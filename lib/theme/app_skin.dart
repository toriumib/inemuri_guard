import 'package:flutter/material.dart' show Color;

import 'app_theme.dart';

/// A purchasable look. Each skin supplies its own light and dark palette, so
/// switching skins never breaks theme-following — every skin still respects
/// the phone's light/dark setting.
///
/// [productId] is null for the free default skin. The others must be created
/// and activated in Play Console under exactly these IDs before they can be
/// bought (IDs are permanent once published).
enum AppSkin {
  paper(
    id: 'paper',
    label: 'ペーパー',
    description: '初期テーマ。紙とインクの落ち着いた配色',
    productId: null,
  ),
  midnight(
    id: 'midnight',
    label: 'ミッドナイト',
    description: '深夜の作業机。紫がかった暗い配色',
    productId: 'skin_midnight',
  ),
  forest(
    id: 'forest',
    label: 'フォレスト',
    description: '森の休憩所。緑を基調にした穏やかな配色',
    productId: 'skin_forest',
  ),
  sakura(
    id: 'sakura',
    label: 'サクラ',
    description: '春の昼下がり。淡いピンクの配色',
    productId: 'skin_sakura',
  );

  const AppSkin({
    required this.id,
    required this.label,
    required this.description,
    required this.productId,
  });

  final String id;
  final String label;
  final String description;
  final String? productId;

  bool get isFree => productId == null;

  static AppSkin fromId(String? id) =>
      AppSkin.values.firstWhere((s) => s.id == id, orElse: () => AppSkin.paper);

  /// Every paid skin's product id, for the store query.
  static Set<String> get paidProductIds =>
      AppSkin.values.map((s) => s.productId).whereType<String>().toSet();

  AppColors get light => switch (this) {
    AppSkin.paper => AppColors.light,
    AppSkin.midnight => _midnightLight,
    AppSkin.forest => _forestLight,
    AppSkin.sakura => _sakuraLight,
  };

  AppColors get dark => switch (this) {
    AppSkin.paper => AppColors.dark,
    AppSkin.midnight => _midnightDark,
    AppSkin.forest => _forestDark,
    AppSkin.sakura => _sakuraDark,
  };
}

// ── ミッドナイト ────────────────────────────────────────────────
const _midnightLight = AppColors(
  bg: Color(0xFFF2F0F7),
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFE8E4F2),
  border: Color(0x1F1B1630),
  text: Color(0xFF1E1930),
  textDim: Color(0xFF635C7D),
  accentAlert: Color(0xFFD8365F),
  accentAlertInk: Color(0xFFFFFFFF),
  accentNap: Color(0xFF7C5CD6),
  accentNapInk: Color(0xFFFFFFFF),
  accentGood: Color(0xFF2E7D6E),
);

const _midnightDark = AppColors(
  bg: Color(0xFF0D0A1A),
  surface: Color(0xFF171233),
  surface2: Color(0xFF211A45),
  border: Color(0x1AFFFFFF),
  text: Color(0xFFEDE9FA),
  textDim: Color(0xFF9C93C4),
  accentAlert: Color(0xFFFF5C86),
  accentAlertInk: Color(0xFF2B0512),
  accentNap: Color(0xFFAE8CFF),
  accentNapInk: Color(0xFF1A0B3D),
  accentGood: Color(0xFF4FDCC0),
);

// ── フォレスト ─────────────────────────────────────────────────
const _forestLight = AppColors(
  bg: Color(0xFFF1F4EE),
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFE3EADC),
  border: Color(0x1F16210F),
  text: Color(0xFF1B2415),
  textDim: Color(0xFF5C6B52),
  accentAlert: Color(0xFFC2521F),
  accentAlertInk: Color(0xFFFFFFFF),
  accentNap: Color(0xFF3F7D4E),
  accentNapInk: Color(0xFFFFFFFF),
  accentGood: Color(0xFF2F6B45),
);

const _forestDark = AppColors(
  bg: Color(0xFF0C1710),
  surface: Color(0xFF14251A),
  surface2: Color(0xFF1D3325),
  border: Color(0x1AFFFFFF),
  text: Color(0xFFE7F1E6),
  textDim: Color(0xFF93AC96),
  accentAlert: Color(0xFFFF8A4C),
  accentAlertInk: Color(0xFF2A1002),
  accentNap: Color(0xFF6FD08C),
  accentNapInk: Color(0xFF06240F),
  accentGood: Color(0xFF54D68A),
);

// ── サクラ ─────────────────────────────────────────────────────
const _sakuraLight = AppColors(
  bg: Color(0xFFFDF2F4),
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFF8E3E8),
  border: Color(0x1F2A1219),
  text: Color(0xFF2E1A20),
  textDim: Color(0xFF7A5C66),
  accentAlert: Color(0xFFD23A63),
  accentAlertInk: Color(0xFFFFFFFF),
  accentNap: Color(0xFFE07A9B),
  accentNapInk: Color(0xFFFFFFFF),
  accentGood: Color(0xFF4A8B72),
);

const _sakuraDark = AppColors(
  bg: Color(0xFF1C1015),
  surface: Color(0xFF2B1A21),
  surface2: Color(0xFF3A242D),
  border: Color(0x1AFFFFFF),
  text: Color(0xFFF7E8ED),
  textDim: Color(0xFFC0A0AB),
  accentAlert: Color(0xFFFF6E92),
  accentAlertInk: Color(0xFF2E040F),
  accentNap: Color(0xFFF7A8C0),
  accentNapInk: Color(0xFF33101D),
  accentGood: Color(0xFF64C9A5),
);

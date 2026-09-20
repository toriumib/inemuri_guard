import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 鳴っている間、画面の下半分を「起きた！」の大きなボタンにする。
///
/// 寝ぼけた手が小さなスヌーズを探すのは無理がある。押せる範囲を広く、
/// 文字を大きく。点滅（AlarmFlashOverlay）の上に載せ、まわりは透かして
/// 点滅が見えるようにしてある。
///
/// [onWake] が指定されたら手動で解除できる。自動解除を待つ必要はない。
class WakeUpOverlay extends StatelessWidget {
  final bool active;
  final String message;
  final VoidCallback? onWake;
  const WakeUpOverlay({
    super.key,
    required this.active,
    required this.message,
    required this.onWake,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    final c = AppColors.of(context);
    return SafeArea(
      child: Column(
        children: [
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (onWake != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accentAlert,
                    foregroundColor: c.accentAlertInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onPressed: onWake,
                  child: Text(
                    context.l10n.awakeStop,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Text(
                context.l10n.eyesOpenToStop,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/road_assist.dart';
import '../services/road_logic.dart';

/// 知らせの文（読み上げと画面で同じ文を使う）。
String roadEventText(AppLocalizations l, RoadEvent e) => switch (e) {
  RoadEvent.forwardCollision => l.roadForwardCollision,
  RoadEvent.tooClose => l.roadTooClose,
  RoadEvent.leadMoved => l.roadLeadMoved,
  RoadEvent.carBehind => l.roadCarBehind,
  RoadEvent.signalRed => l.roadSignalRed,
  RoadEvent.signalGo => l.roadSignalGo,
  RoadEvent.speedCamera => l.roadSpeedCamera,
  RoadEvent.overspeed => l.roadOverspeed,
  RoadEvent.laneDeparture => l.roadLaneDeparture,
  RoadEvent.driverUnresponsive => l.roadDriverUnresponsive,
};

/// プレビューの上に、見つけた物の枠を描く。注目している 1 台（前の車・信号）は太く。
class RoadOverlay extends StatelessWidget {
  const RoadOverlay({super.key, required this.assist});
  final RoadAssist assist;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: assist,
      builder: (context, _) => CustomPaint(
        painter: _BoxPainter(assist.objects, assist.lead),
        size: Size.infinite,
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(this.objects, this.focus);
  final List<RoadObject> objects;
  final RoadObject? focus;

  @override
  void paint(Canvas canvas, Size size) {
    for (final o in objects) {
      final isFocus = identical(o, focus);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFocus ? 4 : 1.5
        ..color = switch (o.kind) {
          RoadKind.person || RoadKind.bicycle => Colors.orangeAccent,
          RoadKind.trafficLight => Colors.lightGreenAccent,
          _ => isFocus ? Colors.redAccent : Colors.white70,
        };
      canvas.drawRect(
        Rect.fromLTRB(
          o.left * size.width,
          o.top * size.height,
          o.right * size.width,
          o.bottom * size.height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      old.objects != objects || old.focus != focus;
}

/// 直近の知らせを 6 秒だけ帯で出す。
class RoadEventBanner extends StatelessWidget {
  const RoadEventBanner({super.key, required this.assist});
  final RoadAssist assist;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: assist,
      builder: (context, _) {
        final e = assist.lastEvent, at = assist.lastEventAt;
        if (e == null ||
            at == null ||
            DateTime.now().difference(at) > const Duration(seconds: 6)) {
          return const SizedBox();
        }
        final urgent =
            e == RoadEvent.forwardCollision || e == RoadEvent.carBehind;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: urgent ? Colors.red : Colors.black87,
          child: Text(
            roadEventText(AppLocalizations.of(context), e),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

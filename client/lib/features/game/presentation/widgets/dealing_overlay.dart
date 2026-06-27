import 'package:flutter/material.dart';
import 'package:pusoy_tayo/features/game/domain/card_model.dart';
import 'package:pusoy_tayo/features/game/presentation/widgets/card_widget.dart';

/// A short card-distribution animation: face-down cards fly from a center deck
/// out to each player's seat, staggered. Calls [onDone] when finished.
class DealingOverlay extends StatefulWidget {
  final int playerCount;
  final VoidCallback onDone;

  const DealingOverlay({
    super.key,
    required this.playerCount,
    required this.onDone,
  });

  @override
  State<DealingOverlay> createState() => _DealingOverlayState();
}

class _DealingOverlayState extends State<DealingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const _card = PlayingCard(rank: 3, suit: 'S');

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Seat anchors as fractional offsets (0..1) of the available area.
  List<Offset> _seatAnchors(int n) {
    switch (n) {
      case 2:
        return const [Offset(0.5, 0.9), Offset(0.5, 0.1)];
      case 3:
        return const [Offset(0.5, 0.9), Offset(0.13, 0.13), Offset(0.87, 0.13)];
      default:
        return const [
          Offset(0.5, 0.9),
          Offset(0.1, 0.18),
          Offset(0.5, 0.07),
          Offset(0.9, 0.18),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final seats = _seatAnchors(widget.playerCount);
    const cardsPerSeat = 3;
    final total = seats.length * cardsPerSeat;

    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final center = Offset(w / 2, h / 2);
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final children = <Widget>[
                // Deck at the center.
                Positioned(
                  left: center.dx - 19,
                  top: center.dy - 26,
                  child: const CardWidget(
                    card: _card,
                    isFaceDown: true,
                    width: 38,
                    height: 52,
                  ),
                ),
              ];

              for (int i = 0; i < total; i++) {
                final seat = seats[i % seats.length];
                final target = Offset(seat.dx * w, seat.dy * h);
                final start = (i / total) * 0.55;
                final t = Curves.easeOut.transform(
                  ((_c.value - start) / 0.45).clamp(0.0, 1.0),
                );
                if (t <= 0) continue;
                final pos = Offset.lerp(center, target, t)!;
                final opacity = 1 - ((t - 0.85) / 0.15).clamp(0.0, 1.0);
                children.add(Positioned(
                  left: pos.dx - 16,
                  top: pos.dy - 22,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: (1 - t) * 0.6,
                      child: const CardWidget(
                        card: _card,
                        isFaceDown: true,
                        width: 32,
                        height: 44,
                      ),
                    ),
                  ),
                ));
              }

              children.add(
                Align(
                  alignment: const Alignment(0, -0.55),
                  child: Text(
                    'Dealing…',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              );

              return Stack(children: children);
            },
          );
        },
      ),
    );
  }
}

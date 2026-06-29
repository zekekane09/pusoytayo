import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/features/game/domain/card_model.dart';
import 'package:pusoy_tayo/features/game/logic/hand_comparator.dart';
import 'package:pusoy_tayo/features/game/logic/hand_evaluator.dart';
import 'package:pusoy_tayo/features/game/presentation/widgets/card_widget.dart';

/// One player's revealed hand: header (name + round/total score) and the three
/// rows of face-up cards with their hand types. Used in the reveal + history.
class PlayerRevealTile extends StatelessWidget {
  final String name;
  final PlayerArrangement arr;
  final int roundScore;
  final int total;
  final bool isYou;
  final bool isBanker;
  final bool isWinner;

  /// How many rows (top→middle→bottom) to reveal so far: 0–3. Used to stage the
  /// reveal animation; defaults to all three (history / instant view).
  final int visibleRows;

  /// Which rows this player won, for a winner highlight: [front, middle, back].
  final List<bool> wonRows;

  const PlayerRevealTile({
    super.key,
    required this.name,
    required this.arr,
    required this.roundScore,
    required this.total,
    this.isYou = false,
    this.isBanker = false,
    this.isWinner = false,
    this.visibleRows = 3,
    this.wonRows = const [false, false, false],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinner ? AppColors.success : AppColors.glassBorder,
          width: isWinner ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isBanker)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text('👑', style: TextStyle(fontSize: 14)),
                ),
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isYou ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (isYou)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('YOU',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              const Spacer(),
              Text(
                roundScore >= 0 ? '+$roundScore' : '$roundScore',
                style: TextStyle(
                  color: roundScore > 0
                      ? AppColors.success
                      : (roundScore < 0 ? AppColors.error : AppColors.textMuted),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${total >= 0 ? '+$total' : '$total'})',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (visibleRows >= 1) _row('F', arr.front, wonRows[0]),
          if (visibleRows >= 2) const SizedBox(height: 3),
          if (visibleRows >= 2) _row('M', arr.middle, wonRows[1]),
          if (visibleRows >= 3) const SizedBox(height: 3),
          if (visibleRows >= 3) _row('B', arr.back, wonRows[2]),
        ],
      ),
    );
  }

  Widget _row(String label, List<PlayingCard> cards, bool won) {
    final type =
        cards.isEmpty ? '' : HandEvaluator.evaluate(cards).type.displayName;
    return Container(
      decoration: won
          ? BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          for (final c in cards)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: CardWidget(card: c, width: 34, height: 48),
            ),
          const SizedBox(width: 6),
          if (won)
            const Padding(
              padding: EdgeInsets.only(right: 2),
              child: Text('🏆', style: TextStyle(fontSize: 11)),
            ),
          Expanded(
            child: Text(
              type,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ),
        ],
      ),
    ).animate(target: 1).fadeIn(duration: 280.ms).slideX(begin: 0.08, end: 0);
  }
}

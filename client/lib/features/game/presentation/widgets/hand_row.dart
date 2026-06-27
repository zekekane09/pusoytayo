import 'package:flutter/material.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/features/game/domain/card_model.dart';
import 'package:pusoy_tayo/features/game/domain/hand_type.dart';
import 'package:pusoy_tayo/features/game/logic/hand_evaluator.dart';
import 'package:pusoy_tayo/features/game/presentation/widgets/card_widget.dart';

class HandRow extends StatelessWidget {
  final String label;
  final int maxCards;
  final List<PlayingCard> cards;
  final void Function(PlayingCard card)? onRemoveCard;
  final Color labelColor;

  const HandRow({
    super.key,
    required this.label,
    required this.maxCards,
    required this.cards,
    this.onRemoveCard,
    this.labelColor = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final handResult = cards.isNotEmpty ? HandEvaluator.evaluate(cards) : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$label (${cards.length}/$maxCards)',
                style: TextStyle(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (handResult != null && handResult.type != HandType.highCard)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    handResult.type.displayName,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 64,
            child: cards.isEmpty
                ? _buildEmptySlots()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: cards.map((card) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: CardWidget(
                          card: card,
                          width: 42,
                          height: 60,
                          onTap: onRemoveCard != null
                              ? () => onRemoveCard!(card)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        maxCards,
        (i) => Container(
          width: 42,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.glassBorder,
              style: BorderStyle.solid,
            ),
            color: AppColors.surfaceLight.withValues(alpha: 0.3),
          ),
          child: const Center(
            child: Icon(
              Icons.add,
              color: AppColors.textMuted,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

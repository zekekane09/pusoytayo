import 'package:flutter/material.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/features/game/domain/card_model.dart';

class CardWidget extends StatelessWidget {
  final PlayingCard card;
  final bool isSelected;
  final bool isFaceDown;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool isHighlighted;

  const CardWidget({
    super.key,
    required this.card,
    this.isSelected = false,
    this.isFaceDown = false,
    this.width = 60,
    this.height = 84,
    this.onTap,
    this.isHighlighted = false,
  });

  Color get _suitColor {
    // Classic two-colour deck: hearts & diamonds red, spades & clubs black.
    return (card.suit == 'H' || card.suit == 'D')
        ? const Color(0xFFD81E2C)
        : const Color(0xFF14171C);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        transform: Matrix4.translationValues(0, isSelected ? -12 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isHighlighted
                    ? AppColors.accent
                    : AppColors.glassBorder,
            width: isSelected || isHighlighted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.3),
              blurRadius: isSelected ? 12 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: isFaceDown ? _buildBack() : _buildFront(),
        ),
      ),
    );
  }

  Widget _buildFront() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(width * 0.05),
      child: Stack(
        children: [
          // Big, bold rank in the top-left corner with its suit beneath it.
          Align(
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.rankDisplay,
                  style: TextStyle(
                    fontSize: height * 0.34,
                    fontWeight: FontWeight.w900,
                    color: _suitColor,
                    height: 1,
                  ),
                ),
                Text(
                  card.suitSymbol,
                  style: TextStyle(
                    fontSize: height * 0.22,
                    color: _suitColor,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          // Large suit pip in the bottom-right corner.
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              card.suitSymbol,
              style: TextStyle(
                fontSize: width * 0.46,
                color: _suitColor,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
        ),
      ),
      child: Center(
        child: Container(
          width: width * 0.7,
          height: height * 0.75,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.5),
                AppColors.secondary.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.style_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: width * 0.35,
            ),
          ),
        ),
      ),
    );
  }
}

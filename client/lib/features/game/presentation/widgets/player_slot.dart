import 'package:flutter/material.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/features/game/domain/game_state_model.dart';

class PlayerSlot extends StatelessWidget {
  final GamePlayer? player;
  final int seatIndex;
  final bool isCurrentPlayer;
  final bool isCurrentTurn;

  const PlayerSlot({
    super.key,
    this.player,
    required this.seatIndex,
    this.isCurrentPlayer = false,
    this.isCurrentTurn = false,
  });

  @override
  Widget build(BuildContext context) {
    if (player == null) return _buildEmptySlot();
    return _buildPlayerSlot();
  }

  Widget _buildEmptySlot() {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.glassBorder,
          style: BorderStyle.solid,
        ),
        color: AppColors.glassBackground,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceLight,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(
              Icons.person_add_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Empty',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerSlot() {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentTurn
              ? AppColors.accent
              : isCurrentPlayer
                  ? AppColors.primary
                  : AppColors.glassBorder,
          width: isCurrentTurn ? 2 : 1,
        ),
        color: isCurrentPlayer
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.glassBackground,
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                backgroundImage: player!.avatarUrl != null
                    ? NetworkImage(player!.avatarUrl!)
                    : null,
                child: player!.avatarUrl == null
                    ? Text(
                        player!.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              if (player!.isReady)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: const Icon(Icons.check, size: 8, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            player!.displayName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (player!.hasArranged)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Ready',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

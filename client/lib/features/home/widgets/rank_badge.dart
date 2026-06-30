import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/core/theme/glass_container.dart';
import 'package:pusoy_tayo/features/rankings/rankings_screen.dart';

class RankBadge extends ConsumerWidget {
  const RankBadge({super.key});

  Color _tierColor(String tier) {
    switch (tier) {
      case 'Silver':
        return AppColors.silver;
      case 'Gold':
        return AppColors.gold;
      case 'Platinum':
      case 'Diamond':
        return AppColors.accent;
      case 'Legend':
        return AppColors.primary;
      default:
        return AppColors.bronze;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(myRankingProvider).valueOrNull;
    final tier = (r?['rankTier'] ?? 'Bronze').toString();
    final points = (r?['rankPoints'] as num?)?.toInt() ?? 0;
    final wagered =
        r?['totalWagered'] == null ? 0 : int.tryParse('${r!['totalWagered']}') ?? 0;

    // Find current + next tier thresholds for the progress bar.
    var floor = 0;
    int? ceil;
    String nextName = 'Max';
    for (var i = 0; i < rankTiers.length; i++) {
      if (points >= rankTiers[i].$2) {
        floor = rankTiers[i].$2;
        if (i + 1 < rankTiers.length) {
          ceil = rankTiers[i + 1].$2;
          nextName = rankTiers[i + 1].$1;
        } else {
          ceil = null;
          nextName = 'Max';
        }
      }
    }
    final progress = ceil == null
        ? 1.0
        : ((points - floor) / (ceil - floor)).clamp(0.0, 1.0);
    final color = _tierColor(tier);

    return GestureDetector(
      onTap: () => context.push('/rankings'),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.6)],
                ),
              ),
              child: const Icon(Icons.military_tech_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(tier,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: color)),
                      const Spacer(),
                      Text(
                        ceil == null ? '$points RP' : '$points / $ceil RP',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Wagered 🪙$wagered — bet to rank up',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                      Text('Next: $nextName',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.silver)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

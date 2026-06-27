import 'package:flutter/material.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';

/// A poker/card-table backdrop: a dark room gradient with a centered elliptical
/// green felt "table" surface. Wraps the game body.
class TableBackground extends StatelessWidget {
  final Widget child;
  const TableBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.3,
          colors: [Color(0xFF0D2818), Color(0xFF0A1A10), AppColors.background],
        ),
      ),
      child: Stack(
        children: [
          // Felt table surface (rounded "stadium" shape reads as an oval table).
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.94,
              heightFactor: 0.84,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(220),
                  gradient: const RadialGradient(
                    center: Alignment.center,
                    radius: 0.85,
                    colors: [
                      Color(0xFF135234),
                      Color(0xFF0C3A22),
                      Color(0xFF09291A),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                  border: Border.all(color: const Color(0xFF1F6B43), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

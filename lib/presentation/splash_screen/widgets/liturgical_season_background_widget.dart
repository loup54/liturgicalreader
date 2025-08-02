import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../theme/app_theme.dart';

class LiturgicalSeasonBackgroundWidget extends StatelessWidget {
  const LiturgicalSeasonBackgroundWidget({super.key});

  Color _getCurrentSeasonColor() {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    // Advent (late November - December 24)
    if ((month == 11 && day >= 27) || (month == 12 && day <= 24)) {
      return const Color(0xFF6A4C93); // Purple
    }

    // Christmas (December 25 - January 13)
    if ((month == 12 && day >= 25) || (month == 1 && day <= 13)) {
      return const Color(0xFFFFD700); // Gold
    }

    // Lent (varies, but roughly February-March)
    if (month == 2 || (month == 3 && day <= 20)) {
      return const Color(0xFF6A4C93); // Purple
    }

    // Easter (varies, but roughly March-May)
    if ((month == 3 && day > 20) || month == 4 || (month == 5 && day <= 15)) {
      return const Color(0xFFFFFFFF); // White
    }

    // Ordinary Time (default)
    return const Color(0xFF228B22); // Green
  }

  @override
  Widget build(BuildContext context) {
    final seasonColor = _getCurrentSeasonColor();

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            seasonColor.withValues(alpha: 0.1),
            seasonColor.withValues(alpha: 0.05),
            AppTheme.lightTheme.colorScheme.surface,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Colors.transparent,
              seasonColor.withValues(alpha: 0.03),
            ],
          ),
        ),
      ),
    );
  }
}

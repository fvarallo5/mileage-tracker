import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../theme/app_theme.dart';

class SourceBadge extends StatelessWidget {
  final String source;

  const SourceBadge({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    if (source == 'manual') return const SizedBox.shrink();

    final trip = Trip(date: '', miles: 0, source: source);
    final color = AppColors.sourceColor(source);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        trip.sourceLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: color == AppColors.surface3 ? AppColors.accent : color,
        ),
      ),
    );
  }
}
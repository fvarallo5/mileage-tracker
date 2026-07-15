import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StatEmphasis { featured, normal, muted }

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;
  final IconData? icon;
  final StatEmphasis emphasis;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
    this.icon,
    this.emphasis = StatEmphasis.normal,
  });

  @override
  Widget build(BuildContext context) {
    final accent = valueColor ?? AppColors.text;
    final isFeatured = emphasis == StatEmphasis.featured;
    final isMuted = emphasis == StatEmphasis.muted;

    return Container(
      padding: EdgeInsets.all(isFeatured ? 18 : isMuted ? 10 : AppSpacing.card),
      decoration: BoxDecoration(
        color: isFeatured
            ? accent.withValues(alpha: 0.08)
            : isMuted
                ? AppColors.surface.withValues(alpha: 0.6)
                : AppColors.surface2,
        borderRadius: BorderRadius.circular(isFeatured ? AppRadii.lg : AppRadii.md),
        border: Border.all(
          color: isFeatured ? accent.withValues(alpha: 0.45) : AppColors.border,
          width: isFeatured ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: isFeatured ? 18 : isMuted ? 12 : 14,
                  color: accent.withValues(alpha: isMuted ? 0.5 : 0.85),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: isFeatured ? 11 : isMuted ? 9 : 10,
                        color: isMuted ? AppColors.textMuted.withValues(alpha: 0.7) : null,
                      ),
                ),
              ),
            ],
          ),
          SizedBox(height: isFeatured ? 10 : isMuted ? 4 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isFeatured ? 28 : isMuted ? 15 : 20,
              fontWeight: isFeatured ? FontWeight.w800 : FontWeight.w700,
              letterSpacing: isFeatured ? -0.8 : -0.3,
              color: isMuted ? AppColors.textMuted : accent,
            ),
          ),
          if (subtitle case final sub?) ...[
            const SizedBox(height: 4),
            Text(
              sub,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: isMuted ? 10 : 11,
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
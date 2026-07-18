import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Segmented Business / Personal control.
class PurposeToggle extends StatelessWidget {
  final bool isBusiness;
  final ValueChanged<bool>? onChanged;
  final bool compact;

  const PurposeToggle({
    super.key,
    required this.isBusiness,
    this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onChanged != null;

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback? onTap,
    }) {
      return Expanded(
        child: Material(
          color: selected
              ? (label == 'Business'
                  ? AppColors.green.withValues(alpha: 0.18)
                  : p.surface3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: compact ? 6 : 10,
                horizontal: 8,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? (label == 'Business' ? AppColors.green : p.text)
                      : p.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: p.surface3,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: p.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          chip(
            label: 'Business',
            selected: isBusiness,
            onTap: enabled && !isBusiness ? () => onChanged!(true) : null,
          ),
          chip(
            label: 'Personal',
            selected: !isBusiness,
            onTap: enabled && isBusiness ? () => onChanged!(false) : null,
          ),
        ],
      ),
    );
  }
}

/// Small pill for list rows — tap to flip purpose.
class PurposeBadge extends StatelessWidget {
  final bool isBusiness;
  final VoidCallback? onTap;

  const PurposeBadge({
    super.key,
    required this.isBusiness,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = isBusiness ? AppColors.green : p.textMuted;

    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            isBusiness ? 'Business' : 'Personal',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

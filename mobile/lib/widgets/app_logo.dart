import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// TrekTrack brand mark (car + gauge). Use instead of [Icons.route] for branding.
class AppLogo extends StatelessWidget {
  /// Outer box size (width = height).
  final double size;

  /// When true, uses the compact mark without the wordmark (best under ~48px).
  final bool markOnly;

  /// Optional corner radius; defaults to medium app radius.
  final double? borderRadius;

  /// Draws a thin border for light surfaces.
  final bool bordered;

  const AppLogo({
    super.key,
    this.size = 40,
    this.markOnly = true,
    this.borderRadius,
    this.bordered = true,
  });

  /// Compact mark for app bars / auth hero.
  const AppLogo.mark({
    super.key,
    this.size = 40,
    this.borderRadius,
    this.bordered = true,
  }) : markOnly = true;

  /// Full brand lockup (prefer size ≥ 72).
  const AppLogo.full({
    super.key,
    this.size = 88,
    this.borderRadius,
    this.bordered = true,
  }) : markOnly = false;

  static const markAsset = 'assets/icon/app_mark.png';
  static const fullAsset = 'assets/icon/app_icon.png';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = borderRadius ?? (size >= 56 ? AppRadii.lg : AppRadii.md);
    final asset = markOnly ? markAsset : fullAsset;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.isLight ? Colors.white : p.surface3,
        borderRadius: BorderRadius.circular(radius),
        border: bordered
            ? Border.all(color: p.border.withValues(alpha: p.isLight ? 1 : 0.8))
            : null,
        boxShadow: p.isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => ColoredBox(
          color: AppColors.accent,
          child: Icon(
            Icons.route,
            color: Colors.white,
            size: size * 0.45,
          ),
        ),
      ),
    );
  }
}

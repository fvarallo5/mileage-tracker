import 'package:flutter/material.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class TrackingHero extends StatefulWidget {
  final AppState state;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const TrackingHero({
    super.key,
    required this.state,
    required this.onStart,
    required this.onStop,
  });

  @override
  State<TrackingHero> createState() => _TrackingHeroState();
}

class _TrackingHeroState extends State<TrackingHero> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tracking = widget.state.tracking;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tracking
              ? [
                  AppColors.green.withValues(alpha: p.isLight ? 0.12 : 0.25),
                  p.surface,
                ]
              : [p.surface, p.surface],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: tracking ? AppColors.green.withValues(alpha: 0.4) : p.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (tracking)
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) => Transform.scale(
                        scale: 1.0 + _pulse.value * 0.08,
                        child: child,
                      ),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.green.withValues(alpha: 0.3 + _pulse.value * 0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.surface3,
                      border: Border.all(color: p.border),
                    ),
                    child: Icon(
                      tracking ? Icons.gps_fixed : Icons.gps_not_fixed,
                      size: 40,
                      color: tracking ? AppColors.green : p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (tracking) ...[
              if (widget.state.trackingIsAuto || widget.state.trackingInBackground)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      if (widget.state.trackingIsAuto)
                        const _TrackingBadge(label: 'Auto-detect', color: AppColors.amber),
                      if (widget.state.trackingInBackground)
                        const _TrackingBadge(label: 'Background', color: AppColors.accent),
                    ],
                  ),
                ),
              Text(
                widget.state.liveMiles.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                  color: AppColors.accent,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'miles driven',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: widget.onStop,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop & Save'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.red,
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ] else ...[
              Text(
                'Ready to drive',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: p.text),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'GPS tracks your mileage automatically.\nAdd tips when you finish.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: widget.state.connected ? widget.onStart : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Trip'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  minimumSize: const Size(double.infinity, 52),
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackingBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TrackingBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

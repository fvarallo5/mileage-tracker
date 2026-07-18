import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';

enum LocationPermissionReason {
  backgroundTracking,
  autoDetect,
}

/// Store-review-friendly disclosure shown before the OS location permission prompt.
Future<bool> showLocationPermissionExplainer(
  BuildContext context, {
  required LocationPermissionReason reason,
}) async {
  final result = await showAppBottomSheet<bool>(
    context,
    _LocationPermissionSheet(reason: reason),
  );
  return result == true;
}

class _LocationPermissionSheet extends StatelessWidget {
  final LocationPermissionReason reason;

  const _LocationPermissionSheet({required this.reason});

  @override
  Widget build(BuildContext context) {
    final isAutoDetect = reason == LocationPermissionReason.autoDetect;

    return AppBottomSheet(
      title: isAutoDetect ? 'Auto-detect needs background location' : 'Background tracking needs location access',
      subtitle: 'We only use your location for mileage logging — never for ads or resale.',
      children: [
        Builder(
          builder: (ctx) {
            final p = ThemePalette.of(ctx);
            return Container(
              padding: const EdgeInsets.all(AppSpacing.card),
              decoration: BoxDecoration(
                color: p.surface3,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: p.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.accent, size: 36),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    isAutoDetect
                        ? 'Auto-detect watches for driving and logs trips hands-free.'
                        : 'Pro keeps GPS running while you use Uber, DoorDash, or Maps.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                          color: p.textMuted,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        const _ExplainerRow(
          icon: Icons.trip_origin,
          text: 'Location is collected only during active trips or while auto-detect monitoring is on.',
        ),
        const SizedBox(height: AppSpacing.md),
        const _ExplainerRow(
          icon: Icons.visibility_outlined,
          text: 'You will see a system indicator (and on Android, a notification) while tracking runs.',
        ),
        const SizedBox(height: AppSpacing.md),
        const _ExplainerRow(
          icon: Icons.block_outlined,
          text: 'We do not sell your location data. Trips are saved to your account for reports.',
        ),
        const SizedBox(height: AppSpacing.md),
        const _ExplainerRow(
          icon: Icons.settings_suggest_outlined,
          text: 'You can turn off auto-detect or revoke access anytime in Settings.',
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () => _openPrivacyPolicy(),
          child: const Text('Read our Privacy Policy'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          isAutoDetect
              ? 'Next, allow "Always" / "Allow all the time" so trips can be detected in the background.'
              : 'Next, allow "Always" / "Allow all the time" so mileage keeps logging in the background.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
        ),
      ],
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(AppConfig.privacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ExplainerRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ExplainerRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: ThemePalette.of(context).text,
            ),
          ),
        ),
      ],
    );
  }
}
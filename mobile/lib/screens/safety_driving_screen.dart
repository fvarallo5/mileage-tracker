import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// Shown after sign-in (and legal acceptance) on each cold start.
/// Reminds drivers not to interact with the phone while driving.
class SafetyDrivingScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const SafetyDrivingScreen({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              const Center(child: AppLogo.mark(size: 72)),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Drive safely',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: p.text,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.card),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: p.isLight ? 0.12 : 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.amber,
                      size: 36,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Do not use your phone or ${AppConfig.appName} while driving.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Start or stop trips before you move or after you park. '
                      'Auto-detect is designed to run in the background so you '
                      'can keep your eyes on the road.\n\n'
                      'Always follow local laws and never interact with the '
                      'screen while the vehicle is in motion.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: p.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('I understand — continue'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'By continuing you confirm you will only use the app when it is '
                'safe and legal to do so.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: p.textMuted, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

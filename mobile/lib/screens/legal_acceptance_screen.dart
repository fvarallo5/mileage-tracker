import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/legal_acceptance_service.dart';
import '../theme/app_theme.dart';
import '../utils/open_url.dart';

/// Full-screen gate: must accept Terms + Privacy before using the app.
class LegalAcceptanceScreen extends StatefulWidget {
  const LegalAcceptanceScreen({super.key});

  @override
  State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  bool _agreed = false;
  bool _busy = false;

  Future<void> _continue() async {
    if (!_agreed || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<LegalAcceptanceService>().acceptCurrent();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final linkStyle = TextStyle(
      color: AppColors.accent,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.accent.withValues(alpha: 0.6),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentDark],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Icon(Icons.route, color: Colors.white, size: 28),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Before you continue',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: p.text,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'TrekTrack helps you log mileage. It is not tax, legal, or accounting advice. '
                'Please review our Terms and Privacy Policy.',
                style: TextStyle(color: p.textMuted, height: 1.45, fontSize: 15),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.card),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bullet(
                      icon: Icons.gavel_outlined,
                      text: 'Terms of Service (v${AppConfig.legalTermsVersion})',
                      onTap: openTermsOfService,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Bullet(
                      icon: Icons.privacy_tip_outlined,
                      text: 'Privacy Policy (v${AppConfig.legalPrivacyVersion})',
                      onTap: openPrivacyPolicy,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Operated by ${AppConfig.legalEntityName} · ${AppConfig.legalEntityState}',
                      style: TextStyle(fontSize: 12, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              InkWell(
                onTap: () => setState(() => _agreed = !_agreed),
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: p.text,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(text: 'I have read and agree to the '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: linkStyle,
                              recognizer: TapGestureRecognizer()
                                ..onTap = openTermsOfService,
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: linkStyle,
                              recognizer: TapGestureRecognizer()
                                ..onTap = openPrivacyPolicy,
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: _agreed && !_busy ? _continue : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You can review these anytime in Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _Bullet({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: p.text,
                fontSize: 15,
              ),
            ),
          ),
          Icon(Icons.open_in_new, size: 16, color: p.textMuted),
        ],
      ),
    );
  }
}

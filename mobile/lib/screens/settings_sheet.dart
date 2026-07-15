import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../config/app_config.dart';
import '../providers/app_state.dart';
import '../screens/premium_sheet.dart';
import '../theme/app_theme.dart';
import '../utils/premium_permission_flow.dart';
import '../widgets/app_bottom_sheet.dart';

Future<void> showSettingsSheet(BuildContext context) async {
  final state = context.read<AppState>();
  final apiController = TextEditingController(text: state.apiUrl);
  final rateController = TextEditingController(text: state.mileageRate.toStringAsFixed(2));
  final packageInfo = await PackageInfo.fromPlatform();

  if (!context.mounted) return;

  await showAppBottomSheet(
    context,
    AppBottomSheet(
      title: 'Settings',
      subtitle: state.connected ? 'Connected to API' : 'API not reachable',
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.card),
          decoration: BoxDecoration(
            color: (state.connected ? AppColors.green : AppColors.red).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: (state.connected ? AppColors.green : AppColors.red).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                state.connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: state.connected ? AppColors.green : AppColors.red,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  state.connected ? 'API connected' : 'Check server & URL',
                  style: TextStyle(
                    color: state.connected ? AppColors.green : AppColors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (ApiConfig.allowCustomApiUrl) ...[
          TextField(
            controller: apiController,
            decoration: const InputDecoration(
              labelText: 'API Base URL (dev only)',
              hintText: 'http://192.168.1.10:3001/api',
              helperText: 'Hidden in App Store builds',
              prefixIcon: Icon(Icons.link, size: 20),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        TextField(
          controller: rateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Mileage rate (\$/mi)',
            helperText: 'IRS standard mileage rate for expense calc',
            prefixIcon: Icon(Icons.attach_money, size: 20),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () async {
            if (ApiConfig.allowCustomApiUrl) {
              await state.setApiUrl(apiController.text.trim());
            }
            final rate = double.tryParse(rateController.text);
            if (rate != null && rate > 0) {
              await state.setMileageRate(rate);
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save Settings'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            state.isPremium ? Icons.workspace_premium_rounded : Icons.workspace_premium_outlined,
            color: AppColors.amber,
          ),
          title: Text(state.isPremium ? 'Premium active' : 'Upgrade to Premium'),
          subtitle: Text(
            state.isPremium
                ? 'Background GPS + auto-detect enabled'
                : 'Background tracking and auto-detect trips',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: state.isPremium
              ? null
              : const Icon(Icons.chevron_right, color: AppColors.textMuted),
          onTap: state.isPremium ? null : () => showPremiumSheet(context),
        ),
        if (state.isPremium) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-detect trips'),
            subtitle: const Text('Shows a privacy disclosure before background access', style: TextStyle(fontSize: 12)),
            value: state.autoDetectEnabled,
            onChanged: (enabled) => PremiumPermissionFlow.setAutoDetect(context, state, enabled),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore, color: AppColors.textMuted, size: 20),
            title: const Text('Restore purchases'),
            onTap: () async {
              final message = await state.restorePurchases();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.manage_accounts_outlined, color: AppColors.textMuted, size: 20),
            title: const Text('Manage subscription'),
            trailing: const Icon(Icons.open_in_new, size: 16, color: AppColors.textMuted),
            onTap: () => _openUrl(Platform.isIOS
                ? 'https://apps.apple.com/account/subscriptions'
                : 'https://play.google.com/store/account/subscriptions'),
          ),
        ] else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore, color: AppColors.textMuted, size: 20),
            title: const Text('Restore purchases'),
            onTap: () async {
              final message = await state.restorePurchases();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
            },
          ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const Icon(Icons.mic_none_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text('Voice commands', style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.card),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Platform.isIOS) ...[
                const Text('Hey Siri', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('"Start trip with Mileage Tracker"'),
                const Text('"Stop trip with Mileage Tracker"'),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Enable Siri for each shortcut in the Shortcuts app.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ] else if (Platform.isAndroid) ...[
                const Text('Hey Google', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('"Start trip on Mileage Tracker"'),
                const Text('"Stop trip on Mileage Tracker"'),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Voice shortcuts appear after you use them once or pin them in Google Assistant.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ] else
                Text(
                  'Voice commands are available on iOS and Android builds.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.accent),
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.open_in_new, size: 16, color: AppColors.textMuted),
          onTap: () => _openUrl(AppConfig.privacyPolicyUrl),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.email_outlined, color: AppColors.textMuted),
          title: const Text('Support'),
          subtitle: Text(AppConfig.supportEmail, style: const TextStyle(fontSize: 12)),
          onTap: () => _openUrl('mailto:${AppConfig.supportEmail}'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${AppConfig.appName} v${packageInfo.version} (${packageInfo.buildNumber})',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
        ),
      ],
    ),
  );
}

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
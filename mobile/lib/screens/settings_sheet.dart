import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/app_state.dart';
import '../providers/auth_state.dart';
import '../screens/premium_sheet.dart';
import '../services/battery_mode.dart';
import '../services/irs_mileage_rate.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../utils/open_url.dart';
import '../utils/premium_permission_flow.dart';
import '../widgets/app_bottom_sheet.dart';

Future<void> showSettingsSheet(BuildContext context) async {
  final state = context.read<AppState>();
  final auth = context.read<AuthState>();
  final themeService = context.read<ThemeService>();
  final packageInfo = await PackageInfo.fromPlatform();

  if (!context.mounted) return;

  await showAppBottomSheet(
    context,
    _SettingsSheetBody(
      state: state,
      auth: auth,
      themeService: themeService,
      packageInfo: packageInfo,
    ),
  );
}

class _SettingsSheetBody extends StatelessWidget {
  final AppState state;
  final AuthState auth;
  final ThemeService themeService;
  final PackageInfo packageInfo;

  const _SettingsSheetBody({
    required this.state,
    required this.auth,
    required this.themeService,
    required this.packageInfo,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([state, themeService]),
      builder: (context, _) {
        final p = context.palette;
        final irs = IrsMileageRate.current;

        return AppBottomSheet(
          title: 'Settings',
          children: [
            // —— IRS rate (auto) ——
            _SectionLabel('Mileage rate'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.card),
              decoration: BoxDecoration(
                color: p.surface3,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: const Icon(Icons.account_balance_outlined,
                        color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          IrsMileageRate.currentLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: p.text,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Auto-updates each tax year from the IRS standard business rate. '
                          'Reports use the rate for each trip’s year.',
                          style: TextStyle(fontSize: 12, color: p.textMuted, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$${irs.toStringAsFixed(3)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            _SectionLabel('Appearance'),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Auto'),
                  icon: Icon(Icons.brightness_auto, size: 16),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined, size: 16),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined, size: 16),
                ),
              ],
              selected: {themeService.mode},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) themeService.setMode(set.first);
              },
            ),

            const SizedBox(height: AppSpacing.lg),
            _SectionLabel('Tracking'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lock screen controls'),
              subtitle: Text(
                'Live banner with Start / Stop and mile updates on the lock screen and notification shade',
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
              value: state.lockScreenControlsEnabled,
              onChanged: (v) => state.setLockScreenControlsEnabled(v),
            ),
            SegmentedButton<BatteryMode>(
              segments: [
                for (final mode in BatteryMode.values)
                  ButtonSegment(
                    value: mode,
                    label: Text(
                      mode.label.split(' ').first,
                      style: const TextStyle(fontSize: 11),
                    ),
                    icon: Icon(mode.icon, size: 16),
                    tooltip: mode.description,
                  ),
              ],
              selected: {state.batteryMode},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) state.setBatteryMode(set.first);
              },
            ),
            const SizedBox(height: 6),
            Text(
              state.batteryMode.description,
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-detect trips'),
              subtitle: Text(
                state.isPremium
                    ? 'Unlimited · background GPS'
                    : '${state.usage.remainingFreeAutoTrips} free auto trips left this month',
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
              value: state.autoDetectEnabled,
              onChanged: (enabled) =>
                  PremiumPermissionFlow.setAutoDetect(context, state, enabled),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Only with car Bluetooth'),
              subtitle: Text(
                state.carBluetoothGateEnabled
                    ? state.carBluetooth.statusLabel
                    : 'Sleep GPS until the car stereo connects — big battery save. '
                        'Earbuds may also count as Bluetooth audio.',
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
              value: state.carBluetoothGateEnabled,
              onChanged: state.autoDetectEnabled
                  ? (v) => state.setCarBluetoothGate(v)
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Only when in a vehicle'),
              subtitle: Text(
                state.activityGateEnabled
                    ? state.activityRecognition.statusLabel
                    : 'Use phone motion sensors to sleep GPS until you\'re driving '
                        '(or cycling). Works without car Bluetooth.',
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
              value: state.activityGateEnabled,
              onChanged: state.autoDetectEnabled
                  ? (v) => state.setActivityGate(v)
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Snap miles to roads'),
              subtitle: Text(
                'After each trip, refine distance on the road network (more accurate in cities). '
                'Uses a routing service; falls back to GPS if offline.',
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
              value: state.mapMatchEnabled,
              onChanged: (v) => state.setMapMatchEnabled(v),
            ),

            const SizedBox(height: AppSpacing.md),
            _SectionLabel('Account'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                auth.isAnonymous ? Icons.person_outline : Icons.person,
                color: AppColors.accent,
              ),
              title: Text(auth.isAnonymous ? 'Guest' : 'Signed in'),
              subtitle: Text(
                auth.isAnonymous
                    ? 'Create an account to sync across devices'
                    : (auth.userEmail ?? ''),
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
            ),
            if (auth.isAnonymous)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.login, color: p.textMuted, size: 20),
                title: const Text('Create account / Sign in'),
                trailing: Icon(Icons.chevron_right, color: p.textMuted),
                onTap: () async {
                  Navigator.pop(context);
                  await auth.signOut();
                },
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout, color: p.textMuted, size: 20),
                title: const Text('Sign out'),
                onTap: () async {
                  Navigator.pop(context);
                  await auth.signOut();
                },
              ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                state.isPremium
                    ? Icons.workspace_premium_rounded
                    : Icons.workspace_premium_outlined,
                color: AppColors.amber,
              ),
              title: Text(state.isPremium ? 'Pro active' : 'Upgrade to Pro'),
              subtitle: Text(
                state.isPremium
                    ? 'Unlimited auto-detect + background GPS'
                    : 'Unlimited auto trips beyond free ${AppConfig.freeAutoTripsPerMonth}/month',
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
              trailing: state.isPremium
                  ? null
                  : Icon(Icons.chevron_right, color: p.textMuted),
              onTap: state.isPremium ? null : () => showPremiumSheet(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.restore, color: p.textMuted, size: 20),
              title: const Text('Restore purchases'),
              onTap: () async {
                final message = await state.restorePurchases();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              },
            ),
            if (state.isPremium)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.manage_accounts_outlined, color: p.textMuted, size: 20),
                title: const Text('Manage subscription'),
                trailing: Icon(Icons.open_in_new, size: 16, color: p.textMuted),
                onTap: () => openUrl(
                  Platform.isIOS
                      ? 'https://apps.apple.com/account/subscriptions'
                      : 'https://play.google.com/store/account/subscriptions',
                ),
              ),

            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
                leading: const Icon(Icons.mic_none_rounded, color: AppColors.accent),
                title: const Text('Voice commands'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (Platform.isIOS) ...[
                          Text('"Start trip with TrekTrack"',
                              style: TextStyle(color: p.text, fontSize: 13)),
                          Text('"Stop trip with TrekTrack"',
                              style: TextStyle(color: p.text, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            'Enable Siri for each shortcut in the Shortcuts app.',
                            style: TextStyle(fontSize: 12, color: p.textMuted),
                          ),
                        ] else if (Platform.isAndroid) ...[
                          Text('"Start trip on TrekTrack"',
                              style: TextStyle(color: p.text, fontSize: 13)),
                          Text('"Stop trip on TrekTrack"',
                              style: TextStyle(color: p.text, fontSize: 13)),
                        ] else
                          Text(
                            'Available on iOS and Android.',
                            style: TextStyle(fontSize: 12, color: p.textMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.accent),
              title: const Text('Privacy Policy'),
              trailing: Icon(Icons.open_in_new, size: 16, color: p.textMuted),
              onTap: openPrivacyPolicy,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.email_outlined, color: p.textMuted),
              title: const Text('Support'),
              subtitle: Text(AppConfig.supportEmail, style: TextStyle(fontSize: 12, color: p.textMuted)),
              onTap: openSupportEmail,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${AppConfig.appName} v${packageInfo.version}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    color: p.textMuted,
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.8,
              color: context.palette.textMuted,
            ),
      ),
    );
  }
}


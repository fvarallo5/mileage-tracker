import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/app_state.dart';
import '../providers/auth_state.dart';
import '../theme/app_theme.dart';
import '../utils/open_url.dart';
import '../widgets/app_bottom_sheet.dart';

Future<void> showDataControlsSheet(BuildContext context) async {
  await showAppBottomSheet(
    context,
    const _DataControlsBody(),
  );
}

class _DataControlsBody extends StatefulWidget {
  const _DataControlsBody();

  @override
  State<_DataControlsBody> createState() => _DataControlsBodyState();
}

class _DataControlsBodyState extends State<_DataControlsBody> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final tripCount = state.trips.length;

    return AppBottomSheet(
      title: 'Your data',
      subtitle:
          'Download, erase trips, or delete your account. We don’t sell your data.',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.card),
          decoration: BoxDecoration(
            color: p.surface3,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: p.border),
          ),
          child: Text(
            'What we store: trips (miles, purpose, optional GPS points), settings, '
            'and Pro entitlement status. Location is only used for tracking you enable. '
            'Tax packages are separate under Reports.',
            style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.4),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download_outlined, color: AppColors.accent),
          title: const Text('Download all trips'),
          subtitle: Text(
            tripCount == 0
                ? 'No trips to export'
                : 'CSV of $tripCount trip${tripCount == 1 ? '' : 's'} (business + personal)',
            style: TextStyle(fontSize: 12, color: p.textMuted),
          ),
          enabled: !_busy && tripCount > 0,
          onTap: _busy || tripCount == 0 ? null : () => _download(context, state),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_sweep_outlined, color: p.textMuted),
          title: const Text('Delete all trips'),
          subtitle: Text(
            'Removes every trip. Keeps your account and settings.',
            style: TextStyle(fontSize: 12, color: p.textMuted),
          ),
          enabled: !_busy && tripCount > 0,
          onTap: _busy || tripCount == 0
              ? null
              : () => _deleteAllTrips(context, state),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_off_outlined, color: AppColors.red),
          title: const Text('Delete account'),
          subtitle: Text(
            'Permanently erase cloud trips, settings, and this login on this app.',
            style: TextStyle(fontSize: 12, color: p.textMuted),
          ),
          enabled: !_busy,
          onTap: _busy ? null : () => _deleteAccount(context, state),
        ),
        const SizedBox(height: AppSpacing.md),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.gavel_outlined, color: p.textMuted, size: 20),
          title: const Text('Terms of Service'),
          trailing: Icon(Icons.open_in_new, size: 16, color: p.textMuted),
          onTap: () => openUrl(AppConfig.termsOfServiceUrl),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.privacy_tip_outlined, color: p.textMuted, size: 20),
          title: const Text('Privacy policy'),
          trailing: Icon(Icons.open_in_new, size: 16, color: p.textMuted),
          onTap: () => openUrl(AppConfig.privacyPolicyUrl),
        ),
        if (_busy) ...[
          const SizedBox(height: AppSpacing.md),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Future<void> _download(BuildContext context, AppState state) async {
    setState(() => _busy = true);
    try {
      await state.exportAllTrips();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export ready — choose where to save or share')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAllTrips(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all trips?'),
        content: Text(
          'This removes all ${state.trips.length} trips from your account. '
          'This cannot be undone. Your login and settings stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete all trips'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    setState(() => _busy = true);
    try {
      final n = await state.deleteAllTrips();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(n == 0 ? 'No trips to delete' : 'Deleted $n trips')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete trips: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your trips, settings, and Pro status '
          'stored for this login. You will be signed out.\n\n'
          'Subscriptions are managed in the App Store or Play Store — '
          'cancel there separately if needed.\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    // Second confirm for safety.
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text(
          'All cloud trip history for this account will be erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Yes, delete everything'),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;

    setState(() => _busy = true);
    final auth = context.read<AuthState>();
    try {
      await state.deleteAccountData();
      await auth.signOutLocal();
      if (!context.mounted) return;
      // Close data sheet + settings if open.
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not fully delete account: $e\n'
            'If this continues, email ${AppConfig.supportEmail}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

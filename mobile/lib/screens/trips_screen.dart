import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/trip.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import '../widgets/trip_tile.dart';
import 'import_screen.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: state.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: state.connected ? () => _showTripForm(context) : null,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Log Trip'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.connected
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ImportScreen()),
                              )
                          : null,
                      icon: const Icon(Icons.upload_rounded),
                      label: const Text('Import'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(
                title: 'Recent Trips',
                subtitle: '${state.trips.length} logged',
              ),
              if (state.trips.isEmpty)
                EmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'No trips yet',
                  message: 'Log a trip manually, start GPS tracking, or import from Uber or DoorDash.',
                  action: FilledButton.icon(
                    onPressed: state.connected ? () => _showTripForm(context) : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Log first trip'),
                  ),
                )
              else
                ...state.trips.map(
                  (trip) => TripTile(
                    trip: trip,
                    onTap: () => _showTripForm(context, trip: trip),
                    onDelete: () => _delete(context, state, trip),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showTripForm(BuildContext context, {Trip? trip}) async {
    final state = context.read<AppState>();
    final dateController = TextEditingController(
      text: trip?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final milesController = TextEditingController(text: trip?.miles.toString() ?? '');
    final tipsController = TextEditingController(text: trip?.tips.toString() ?? '');
    final notesController = TextEditingController(text: trip?.notes ?? '');

    final saved = await showAppBottomSheet<bool>(
      context,
      AppBottomSheet(
        title: trip == null ? 'New Trip' : 'Edit Trip',
        children: [
          TextField(
            controller: dateController,
            decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: milesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Miles'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: tipsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tips / Earnings (\$)'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () async {
              final miles = double.tryParse(milesController.text);
              if (miles == null || miles <= 0) return;
              final tips = double.tryParse(tipsController.text) ?? 0;
              await state.saveTrip(
                id: trip?.id,
                date: dateController.text,
                miles: miles,
                tips: tips,
                notes: notesController.text,
              );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: Text(trip == null ? 'Save Trip' : 'Update Trip'),
          ),
        ],
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trip == null ? 'Trip saved' : 'Trip updated')),
      );
    }
  }

  Future<void> _delete(BuildContext context, AppState state, Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && trip.id != null) {
      await state.deleteTrip(trip.id!);
    }
  }
}
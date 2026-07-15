import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';
import '../theme/app_theme.dart';
import 'source_badge.dart';

final _currency = NumberFormat.currency(symbol: '\$');
final _dateFmt = DateFormat.yMMMd();

class TripTile extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TripTile({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onDelete,
  });

  IconData _sourceIcon() => switch (trip.source) {
        'uber' => Icons.local_taxi,
        'doordash' => Icons.delivery_dining,
        'lyft' => Icons.directions_car,
        'instacart' => Icons.shopping_bag,
        'gps' => Icons.gps_fixed,
        _ => Icons.edit_road,
      };

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.tryParse(trip.date);
    final iconColor = AppColors.sourceColor(trip.source);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          onTap: onTap,
          onLongPress: onDelete,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.card),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(_sourceIcon(), color: iconColor == AppColors.surface3 ? AppColors.accent : iconColor, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              parsedDate != null ? _dateFmt.format(parsedDate) : trip.date,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
                            ),
                          ),
                          SourceBadge(source: trip.source),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trip.notes.isEmpty ? 'No notes' : trip.notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${trip.miles.toStringAsFixed(1)} mi',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      _currency.format(trip.tips),
                      style: const TextStyle(color: AppColors.green, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
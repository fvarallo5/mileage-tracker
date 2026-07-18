import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';
import '../theme/app_theme.dart';
import 'purpose_toggle.dart';
import 'source_badge.dart';

final _currency = NumberFormat.currency(symbol: '\$');
final _dateFmt = DateFormat.yMMMd();

class TripTile extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool>? onPurposeChanged;

  const TripTile({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onDelete,
    this.onPurposeChanged,
  });

  IconData _sourceIcon() => switch (trip.source) {
        'uber' => Icons.local_taxi,
        'doordash' => Icons.delivery_dining,
        'lyft' => Icons.directions_car,
        'instacart' => Icons.shopping_bag,
        'gps' => Icons.gps_fixed,
        'autodetect' => Icons.radar_rounded,
        _ => Icons.edit_road,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final parsedDate = DateTime.tryParse(trip.date);
    final iconColor = AppColors.sourceColor(trip.source);
    final personal = !trip.isBusiness;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          onTap: onTap,
          onLongPress: onDelete,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.card),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: personal ? p.border.withValues(alpha: 0.7) : p.border,
              ),
            ),
            child: Row(
              children: [
                Opacity(
                  opacity: personal ? 0.55 : 1,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Icon(
                      _sourceIcon(),
                      color: iconColor == AppColors.surface3 ? AppColors.accent : iconColor,
                      size: 22,
                    ),
                  ),
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
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 15,
                                    color: personal ? p.textMuted : p.text,
                                  ),
                            ),
                          ),
                          SourceBadge(source: trip.source),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          PurposeBadge(
                            isBusiness: trip.isBusiness,
                            onTap: trip.id != null && onPurposeChanged != null
                                ? () => onPurposeChanged!(!trip.isBusiness)
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              trip.notes.isEmpty
                                  ? (trip.hasMapGeometry ? 'Route on map' : 'No notes')
                                  : trip.notes,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                    color: p.textMuted,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Opacity(
                  opacity: personal ? 0.55 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${trip.miles.toStringAsFixed(1)} mi',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: p.text,
                          decoration: personal ? TextDecoration.lineThrough : null,
                          decorationColor: p.textMuted,
                        ),
                      ),
                      Text(
                        personal ? 'Not deductible' : _currency.format(trip.tips),
                        style: TextStyle(
                          color: personal ? p.textMuted : AppColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

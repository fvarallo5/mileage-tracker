import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';
import '../theme/app_theme.dart';
import 'purpose_toggle.dart';
import 'source_badge.dart';

final _currency = NumberFormat.currency(symbol: '\$');
final _dateFmt = DateFormat.yMMMd();
final _timeFmt = DateFormat.jm();

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

  String _titleLine() {
    final day = DateTime.tryParse(trip.date);
    final dateLabel = day != null ? _dateFmt.format(day) : trip.date;
    final time = _timeRangeLabel(trip);
    if (time == null) return dateLabel;
    return '$dateLabel · $time';
  }

  /// e.g. "2:14–2:41 PM" or "2:14 PM" when only one clock time is known.
  static String? _timeRangeLabel(Trip trip) {
    final start = trip.displayStart?.toLocal();
    final end = trip.displayEnd?.toLocal();
    if (start == null && end == null) return null;
    if (start != null && end != null) {
      final sameMeridiem = start.hour < 12 == end.hour < 12;
      if (sameMeridiem) {
        final startPart = DateFormat('h:mm').format(start);
        final endPart = _timeFmt.format(end);
        return '$startPart–$endPart';
      }
      return '${_timeFmt.format(start)} – ${_timeFmt.format(end)}';
    }
    final only = start ?? end!;
    return _timeFmt.format(only);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
                      AppColors.sourceIcon(trip.source),
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
                              _titleLine(),
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

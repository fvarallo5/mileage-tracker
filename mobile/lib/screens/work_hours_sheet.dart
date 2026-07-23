import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/work_hours_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';

Future<void> showWorkHoursSheet(BuildContext context) async {
  await showAppBottomSheet(
    context,
    const _WorkHoursSheetBody(),
  );
}

class _WorkHoursSheetBody extends StatelessWidget {
  const _WorkHoursSheetBody();

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final wh = state.workHours;
        final p = context.palette;

        return AppBottomSheet(
          title: 'Work hours',
          subtitle:
              'Only run auto-detect during your shift. Manual trips always work.',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Limit auto-detect to schedule'),
              subtitle: Text(
                wh.enabled ? wh.summaryLabel : 'Off — watch any time',
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
              value: wh.enabled,
              onChanged: (v) => state.setWorkHoursEnabled(v),
            ),
            if (wh.enabled) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Days',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: p.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      label: Text(_dayLabels[i]),
                      selected: wh.daysActive[i],
                      onSelected: (v) => state.setWorkHoursDay(i, v),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start'),
                trailing: Text(
                  WorkHoursService.formatMinutes(wh.startMinutes),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => _pickTime(
                  context,
                  state,
                  initial: wh.startMinutes,
                  isStart: true,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End'),
                trailing: Text(
                  WorkHoursService.formatMinutes(wh.endMinutes),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => _pickTime(
                  context,
                  state,
                  initial: wh.endMinutes,
                  isStart: false,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                wh.startMinutes > wh.endMinutes
                    ? 'Overnight shift supported (e.g. 10 PM–6 AM).'
                    : 'Outside this window, auto-detect sleeps to skip personal miles.',
                style: TextStyle(fontSize: 12, color: p.textMuted, height: 1.35),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    AppState state, {
    required int initial,
    required bool isStart,
  }) async {
    final tod = TimeOfDay(hour: initial ~/ 60, minute: initial % 60);
    final picked = await showTimePicker(context: context, initialTime: tod);
    if (picked == null) return;
    final mins = WorkHoursService.timeOfDayToMinutes(picked.hour, picked.minute);
    if (isStart) {
      await state.setWorkHoursStart(mins);
    } else {
      await state.setWorkHoursEnd(mins);
    }
  }
}

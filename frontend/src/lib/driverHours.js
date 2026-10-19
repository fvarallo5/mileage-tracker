import { WEEKDAYS } from './quote.js';
import { hoursLabel, isAllDayHours } from './planMonth.js';

export const ALL_START = '00:00';
export const ALL_END = '23:30';

export function emptyWeek() {
  const next = {};
  for (const day of WEEKDAYS) next[day.id] = { start: '', end: '' };
  return next;
}

export function weekFromRows(rows, userId) {
  const next = emptyWeek();
  for (const row of rows || []) {
    if (row.user_id !== userId) continue;
    const start = String(row.start_time || '').slice(0, 5);
    let end = String(row.end_time || '').slice(0, 5);
    if (end === '23:59' || end === '24:00') end = ALL_END;
    next[Number(row.weekday)] = { start, end };
  }
  return next;
}

export function weekDaysPayload(week) {
  return WEEKDAYS.map((day) => ({
    weekday: day.id,
    start_time: week[day.id]?.start || '',
    end_time: week[day.id]?.end || '',
  }));
}

export function weekSummary(week) {
  const bits = WEEKDAYS
    .filter((day) => week[day.id]?.start && week[day.id]?.end)
    .map((day) => `${day.label} ${hoursLabel({ start_time: week[day.id].start, end_time: week[day.id].end })}`);
  return bits.length ? bits.join(' · ') : 'Off every day';
}

export function dayHoursLabel(week, dayId) {
  const start = week[dayId]?.start || '';
  const end = week[dayId]?.end || '';
  if (!start || !end) return 'Off';
  if (isAllDayHours({ start_time: start, end_time: end })) return 'All day';
  return hoursLabel({ start_time: start, end_time: end });
}

export function isoDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function formatMdY(iso) {
  const raw = String(iso || '').slice(0, 10);
  const d = new Date(`${raw}T12:00:00`);
  if (Number.isNaN(d.getTime())) return String(iso || '');
  const mon = d.toLocaleString('en-US', { month: 'short' });
  return `${mon} ${d.getDate()} ${d.getFullYear()}`;
}

export function formatRangeMdY(start, end) {
  const from = formatMdY(start);
  const to = formatMdY(end);
  if (!start || from === to) return from;
  return `${from} to ${to}`;
}

export function periodRange(key, now = new Date()) {
  const end = isoDate(now);
  if (key === 'day') {
    return { key, start: end, end, label: 'Today' };
  }
  if (key === 'week') {
    const start = new Date(now);
    const weekday = (now.getDay() + 6) % 7;
    start.setDate(now.getDate() - weekday);
    return { key, start: isoDate(start), end, label: 'This week' };
  }
  if (key === 'quarter') {
    const q = Math.floor(now.getMonth() / 3);
    const start = new Date(now.getFullYear(), q * 3, 1);
    return { key, start: isoDate(start), end, label: `Q${q + 1} ${now.getFullYear()}` };
  }
  if (key === 'year') {
    return { key, start: `${now.getFullYear()}-01-01`, end, label: 'This year' };
  }
  return {
    key: 'month',
    start: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`,
    end,
    label: 'This month',
  };
}

export function weekContaining(iso, now = new Date()) {
  const day = iso
    ? new Date(`${String(iso).slice(0, 10)}T12:00:00`)
    : now;
  const basis = Number.isNaN(day.getTime()) ? now : day;
  const weekday = (basis.getDay() + 6) % 7;
  const start = new Date(basis);
  start.setDate(basis.getDate() - weekday);
  const end = new Date(start);
  end.setDate(start.getDate() + 6);
  return {
    key: 'week',
    start: isoDate(start),
    end: isoDate(end),
    label: 'This week',
  };
}

export const PERIODS = [
  ['day', 'Day'],
  ['week', 'Week'],
  ['month', 'Month'],
  ['quarter', 'Quarter'],
  ['year', 'Year'],
];

export function isoDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
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

export const PERIODS = [
  ['day', 'Day'],
  ['week', 'Week'],
  ['month', 'Month'],
  ['quarter', 'Quarter'],
  ['year', 'Year'],
];

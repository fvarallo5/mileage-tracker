export const milesFmt = new Intl.NumberFormat('en-US', { maximumFractionDigits: 1 });
export const moneyFmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

export function costLabel(category) {
  switch (category) {
    case 'fuel':
      return 'Gas';
    case 'parking':
      return 'Parking';
    case 'tolls':
      return 'Tolls';
    case 'meals':
      return 'Client meals';
    case 'supplies':
      return 'Supplies';
    case 'maintenance':
      return 'Maintenance';
    case 'car_wash':
      return 'Car wash';
    case 'phone':
      return 'Phone / data';
    case 'uniforms':
      return 'Uniforms';
    case 'office':
      return 'Office';
    case 'software':
      return 'Software';
    case 'insurance':
      return 'Insurance';
    default:
      return 'Other';
  }
}

const ACTIVE_MS = 2 * 60 * 1000;

export function isDriverActive(lastSeenAt, now = Date.now()) {
  if (!lastSeenAt) return false;
  const t = new Date(lastSeenAt).getTime();
  return Number.isFinite(t) && now - t < ACTIVE_MS;
}

export function presenceLabel(lastSeenAt, now = Date.now()) {
  if (!lastSeenAt) return '';
  if (isDriverActive(lastSeenAt, now)) return 'Active';
  const t = new Date(lastSeenAt).getTime();
  if (!Number.isFinite(t)) return '';
  const mins = Math.round((now - t) / 60000);
  if (mins < 60) return `Seen ${mins}m ago`;
  const hours = Math.round(mins / 60);
  if (hours < 24) return `Seen ${hours}h ago`;
  const days = Math.round(hours / 24);
  return `Seen ${days}d ago`;
}

export function splitName(nickname) {
  const s = String(nickname || '').trim();
  if (!s) return { first: '', last: '' };
  const i = s.indexOf(' ');
  if (i < 0) return { first: s, last: '' };
  return { first: s.slice(0, i), last: s.slice(i + 1).trim() };
}

export function fullName(profile, fallback = '') {
  const first = String(profile?.first_name || '').trim();
  const last = String(profile?.last_name || '').trim();
  const joined = [first, last].filter(Boolean).join(' ');
  if (joined) return joined;
  const nick = String(profile?.nickname || fallback || '').trim();
  return nick || 'Driver';
}

export function driverHeadline(driverNumber, name, openCount) {
  const jobs = `${openCount} open`;
  const num = String(driverNumber || '').trim();
  const label = name || 'Driver';
  return num ? `${num} - ${label} - ${jobs}` : `${label} - ${jobs}`;
}

export { roleLabel } from '../../lib/roles.js';

export function formatShortDate(iso) {
  if (!iso) return '—';
  const d = new Date(`${String(iso).slice(0, 10)}T12:00:00`);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export function csvEscape(value) {
  const s = String(value ?? '');
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

export function downloadCsv(name, rows) {
  const body = rows.map((row) => row.map(csvEscape).join(',')).join('\n');
  const blob = new Blob([`\uFEFF${body}`], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  a.click();
  URL.revokeObjectURL(url);
}

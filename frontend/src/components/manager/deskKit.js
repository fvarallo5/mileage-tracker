import { isActiveJob } from '../../lib/jobStatus.js';
import { isoDate } from '../../lib/period.js';
import { isDriverActive } from './format.js';

export const AVATAR_COLORS = ['#34d399', '#3b9eff', '#fbbf24', '#8fd3ff', '#7ee8c0', '#c5d2e5'];

export function initials(name) {
  return String(name || 'TT')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0].toUpperCase())
    .join('');
}

export function avatarStyle(seed) {
  const i = Math.abs(hash(seed)) % AVATAR_COLORS.length;
  const c = AVATAR_COLORS[i];
  return {
    background: `linear-gradient(180deg, color-mix(in oklab, ${c} 45%, white), ${c} 55%, color-mix(in oklab, ${c} 70%, black))`,
  };
}

function hash(s) {
  return String(s || '').split('').reduce((n, ch) => n + ch.charCodeAt(0), 0);
}

export function tripDate(trip) {
  return String(trip?.trip_date || trip?.date || '').slice(0, 10);
}

export function driverPresence(driver, jobs = [], today = isoDate(new Date())) {
  const mine = jobs.filter((j) => j.assigned_user_id === driver.user_id && j.job_date === today);
  if (mine.some((j) => j.status === 'picked_up')) return { id: 'on', label: 'On route' };
  if (isDriverActive(driver.lastSeenAt) || mine.some((j) => isActiveJob(j.status))) {
    return { id: 'idle', label: 'Idle' };
  }
  return { id: 'off', label: 'Off shift' };
}

export function sparkPath(values, w = 200, h = 34) {
  if (!values.length) {
    return { line: `M2,${h - 6} L${w - 2},${h - 6}`, area: `M2,${h - 6} L${w - 2},${h - 6} L${w - 2},${h} L2,${h} Z` };
  }
  const max = Math.max(...values, 1);
  const n = values.length;
  const step = n === 1 ? 0 : (w - 4) / (n - 1);
  const pts = values.map((v, i) => {
    const x = 2 + i * step;
    const y = h - 6 - (v / max) * (h - 12);
    return [x, y];
  });
  const line = pts.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(' ');
  const last = pts[pts.length - 1];
  const area = `${line} L${last[0].toFixed(1)},${h} L2,${h} Z`;
  return { line, area };
}

export function daysInRange(start, end) {
  const out = [];
  const d = new Date(`${start}T12:00:00`);
  const last = new Date(`${end}T12:00:00`);
  if (Number.isNaN(d.getTime()) || Number.isNaN(last.getTime())) return out;
  while (d <= last) {
    out.push(isoDate(d));
    d.setDate(d.getDate() + 1);
  }
  return out;
}

export function dailySeries(trips, start, end, pick) {
  const days = daysInRange(start, end);
  const byDay = {};
  for (const iso of days) byDay[iso] = 0;
  for (const trip of trips || []) {
    const iso = tripDate(trip);
    if (iso in byDay) byDay[iso] += pick(trip);
  }
  return days.map((iso) => byDay[iso]);
}

export function donutDash(values, r = 62) {
  const circ = 2 * Math.PI * r;
  const total = values.reduce((s, v) => s + v, 0) || 1;
  let offset = 0;
  return values.map((v) => {
    const len = (v / total) * circ;
    const row = { len, offset, circ };
    offset += len;
    return row;
  });
}

import { jobQuote } from './jobReport.js';
import { isoDate } from './period.js';

export const BOARD_DATE_KEY = 'trektrack-board-date';
export const CAL_DOW = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export function weekdayIndex(iso) {
  const d = new Date(`${String(iso).slice(0, 10)}T12:00:00`);
  return Number.isNaN(d.getTime()) ? 0 : d.getDay();
}

export function shiftMonth(year, month, delta) {
  const d = new Date(year, month + delta, 1);
  return { year: d.getFullYear(), month: d.getMonth() };
}

export function monthTitle(year, month) {
  return new Date(year, month, 1).toLocaleString('en-US', { month: 'long', year: 'numeric' });
}

export function monthGrid(year, month) {
  const first = new Date(year, month, 1);
  const start = new Date(first);
  start.setDate(1 - first.getDay());
  const cells = [];
  for (let i = 0; i < 42; i += 1) {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    cells.push({
      iso: isoDate(d),
      day: d.getDate(),
      inMonth: d.getMonth() === month,
      weekday: d.getDay(),
    });
  }
  return cells;
}

export function hoursByUserMap(rows) {
  const map = new Map();
  for (const row of rows || []) {
    map.set(`${row.user_id}:${Number(row.weekday)}`, row);
  }
  return map;
}

function clock(value) {
  const raw = String(value || '');
  return raw.length >= 5 ? raw.slice(0, 5) : raw;
}

export function clock12From24(hhmm) {
  const raw = clock(hhmm);
  if (!raw) return { clock: '', meridiem: '' };
  const [hStr, mStr] = raw.split(':');
  let h = Number(hStr);
  if (!Number.isFinite(h)) return { clock: '', meridiem: '' };
  const meridiem = h >= 12 ? 'PM' : 'AM';
  h %= 12;
  if (h === 0) h = 12;
  return { clock: `${h}:${(mStr || '00').padStart(2, '0')}`, meridiem };
}

export function clock24From12(clock12, meridiem) {
  if (!clock12) return '';
  const [hStr, mStr] = String(clock12).split(':');
  let h = Number(hStr);
  if (!Number.isFinite(h)) return '';
  const mm = (mStr || '00').padStart(2, '0');
  if (meridiem === 'PM') {
    if (h !== 12) h += 12;
  } else if (h === 12) {
    h = 0;
  }
  return `${String(h).padStart(2, '0')}:${mm}`;
}

export function formatTime12(value) {
  const parts = clock12From24(value);
  if (!parts.clock) return '';
  return `${parts.clock} ${parts.meridiem}`;
}

export function isAllDayHours(row) {
  if (!row) return false;
  const end = clock(row.end_time);
  return clock(row.start_time) === '00:00' && (end === '23:30' || end === '23:59' || end === '24:00');
}

export function hoursLabel(row) {
  if (!row) return 'Off';
  if (isAllDayHours(row)) return 'All day';
  const start = formatTime12(row.start_time);
  const end = formatTime12(row.end_time);
  if (!start || !end) return 'Off';
  return `${start} – ${end}`;
}

export function cellStats(iso, { jobs, hoursMap, drivers }) {
  const dayJobs = [];
  for (const job of jobs || []) {
    if (job.job_date === iso) dayJobs.push(job);
  }
  const weekday = weekdayIndex(iso);
  const roster = [];
  const seen = new Set();
  for (const driver of drivers || []) {
    const hours = hoursMap?.get(`${driver.user_id}:${weekday}`);
    if (!hours) continue;
    seen.add(driver.user_id);
    roster.push({
      user_id: driver.user_id,
      label: driver.label,
      driverNumber: driver.driverNumber,
      hours,
      fromHours: true,
      jobCount: 0,
      firstTime: '',
      lastTime: '',
    });
  }
  for (const job of dayJobs) {
    const id = job.assigned_user_id;
    if (!id) continue;
    let row = roster.find((item) => item.user_id === id);
    if (!row) {
      const driver = (drivers || []).find((item) => item.user_id === id);
      row = {
        user_id: id,
        label: driver?.label || 'Driver',
        driverNumber: driver?.driverNumber,
        hours: hoursMap?.get(`${id}:${weekday}`) || null,
        fromHours: false,
        jobCount: 0,
        firstTime: '',
        lastTime: '',
      };
      roster.push(row);
    }
    row.jobCount += 1;
    const t = String(job.pickup_time || job.job_time || '').slice(0, 5);
    if (t) {
      if (!row.firstTime || t < row.firstTime) row.firstTime = t;
      if (!row.lastTime || t > row.lastTime) row.lastTime = t;
    }
  }
  let quoted = 0;
  let unassigned = 0;
  for (const job of dayJobs) {
    quoted += jobQuote(job);
    if (!job.assigned_user_id) unassigned += 1;
  }
  const scheduled = roster.filter((row) => row.fromHours).length;
  const weekend = weekday === 0 || weekday === 6;
  return {
    iso,
    jobs: dayJobs.length,
    drivers: scheduled,
    quoted: Math.round((quoted + Number.EPSILON) * 100) / 100,
    unassigned,
    uncovered: dayJobs.length > 0 && scheduled === 0,
    idle: scheduled > 0 && dayJobs.length === 0,
    weekend,
    dayJobs,
    roster,
  };
}

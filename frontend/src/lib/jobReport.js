import { trim } from './address.js';
import { statusMatches } from './jobStatus.js';
import { serviceLevelLabel } from './quote.js';

export function jobTown(job, prefix) {
  const city = trim(job?.[`${prefix}_city`]);
  if (city) return city;
  const addr = trim(job?.[`${prefix}_address`]);
  if (!addr) return '—';
  const parts = addr.split(',').map((part) => part.trim()).filter(Boolean);
  if (parts.length >= 2) {
    const last = parts[parts.length - 1];
    if (/^[A-Za-z]{2}\b/.test(last) || /\d{5}/.test(last)) {
      return parts[parts.length - 2] || '—';
    }
    return parts[1];
  }
  return addr;
}

export function jobQuote(job) {
  const n = Number(job?.quoted_amount ?? job?.estimated_cost);
  return Number.isFinite(n) ? n : 0;
}

export function jobPay(job) {
  const n = Number(job?.driver_pay);
  if (Number.isFinite(n)) return n;
  return jobQuote(job);
}

export function jobDurationHours(job) {
  const parse = (raw) => {
    if (!raw) return null;
    const parts = String(raw).split(':');
    const h = Number(parts[0]);
    const m = Number(parts[1] ?? 0);
    if (!Number.isFinite(h)) return null;
    return h * 60 + m;
  };
  const a = parse(job?.pickup_time || job?.job_time);
  const b = parse(job?.dropoff_time);
  if (a == null || b == null || b <= a) return 0;
  return (b - a) / 60;
}

export function jobTake(job) {
  const n = Number(job?.company_take);
  if (Number.isFinite(n)) return n;
  return Math.max(0, jobQuote(job) - jobPay(job));
}

export function jobsForReport(jobs, { start, end, driverId, status = 'done' } = {}) {
  const rows = [];
  for (const job of jobs || []) {
    if (start && job.job_date < start) continue;
    if (end && job.job_date > end) continue;
    if (!statusMatches(job.status, status)) continue;
    if (driverId && job.assigned_user_id !== driverId) continue;
    rows.push(job);
  }
  rows.sort((a, b) => {
    const date = String(a.job_date).localeCompare(String(b.job_date));
    if (date) return date;
    return String(a.job_number || '').localeCompare(String(b.job_number || ''), undefined, { numeric: true });
  });
  return rows;
}

export function jobRateTags(job) {
  const tags = [];
  const level = serviceLevelLabel(job?.service_level);
  if (level) tags.push(level);
  if (job?.quote_weekend) tags.push('Weekend');
  if (job?.quote_after_hours) tags.push('After hours');
  return tags;
}

export function totalsForJobs(jobs) {
  let pay = 0;
  let quote = 0;
  let take = 0;
  for (const job of jobs || []) {
    pay += jobPay(job);
    quote += jobQuote(job);
    take += jobTake(job);
  }
  return { pay, quote, take, count: (jobs || []).length };
}

export function settleByDriver(jobs, drivers) {
  const groups = new Map();
  for (const driver of drivers || []) {
    groups.set(driver.user_id, {
      userId: driver.user_id,
      label: driver.driverNumber ? `${driver.driverNumber} - ${driver.label}` : driver.label,
      jobs: [],
    });
  }
  const extras = [];
  for (const job of jobs || []) {
    let group = groups.get(job.assigned_user_id);
    if (!group) {
      group = {
        userId: job.assigned_user_id || '',
        label: job.assigned_user_id ? 'Driver' : 'Unassigned',
        jobs: [],
      };
      groups.set(job.assigned_user_id, group);
      extras.push(group);
    }
    group.jobs.push(job);
  }
  const ordered = [
    ...extras.filter((group) => !group.userId),
    ...(drivers || []).map((driver) => groups.get(driver.user_id)),
    ...extras.filter((group) => group.userId),
  ].filter((group) => group && group.jobs.length);
  return ordered.map((group) => ({
    ...group,
    ...totalsForJobs(group.jobs),
  }));
}

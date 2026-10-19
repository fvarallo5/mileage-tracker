import { isDelivered } from './jobStatus.js';
import { jobTown } from './jobReport.js';

export function jobMatchesQuery(job, query, { customers, drivers } = {}) {
  const q = String(query || '').trim().toLowerCase();
  if (!q) return true;
  const account = (customers || []).find((row) => row.id === job.customer_id)?.name || '';
  const driver = (drivers || []).find((row) => row.user_id === job.assigned_user_id)?.label || '';
  const hay = [
    job.job_number,
    job.pickup_name,
    job.dropoff_name,
    job.pickup_city,
    job.dropoff_city,
    job.pickup_address,
    job.dropoff_address,
    job.pickup_line1,
    job.dropoff_line1,
    account,
    driver,
  ].join(' ').toLowerCase();
  return hay.includes(q);
}

export function dayPulse(jobs, boardDate) {
  const counts = {
    open: 0,
    picked_up: 0,
    delivered: 0,
    unassigned: 0,
    failed: 0,
  };
  for (const job of jobs || []) {
    if (job.job_date !== boardDate) continue;
    if (job.status === 'open') counts.open += 1;
    if (job.status === 'picked_up') counts.picked_up += 1;
    if (isDelivered(job.status)) counts.delivered += 1;
    if (job.status === 'failed') counts.failed += 1;
    if (!job.assigned_user_id && job.status !== 'cancelled') counts.unassigned += 1;
  }
  return counts;
}

export function dayExceptions(jobs, boardDate, mode) {
  const rows = [];
  const failedLabel = mode === 'driving_school'
    ? 'No-show'
    : mode === 'service'
      ? "Couldn't complete"
      : "Couldn't deliver";
  for (const job of jobs || []) {
    if (job.job_date !== boardDate) continue;
    if (job.status === 'failed') {
      rows.push({ job, kind: 'failed', label: failedLabel });
    } else if (!job.assigned_user_id && job.status !== 'cancelled' && !isDelivered(job.status)) {
      rows.push({ job, kind: 'unassigned', label: 'Unassigned' });
    } else if (isDelivered(job.status) && !job.customer_id) {
      rows.push({ job, kind: 'account', label: 'No account' });
    }
  }
  return rows;
}

export function accountPeriodStats(customers, jobs, { start, end } = {}) {
  return (customers || []).map((customer) => {
    const theirs = (jobs || []).filter((job) => job.customer_id === customer.id);
    const inPeriod = theirs.filter((job) => {
      const date = job.job_date || '';
      if (start && date < start) return false;
      if (end && date > end) return false;
      return true;
    });
    const last = [...theirs].sort((a, b) => String(b.job_date).localeCompare(String(a.job_date)))[0];
    return {
      ...customer,
      periodJobs: inPeriod.length,
      lastJobDate: last?.job_date || '',
      lastTown: last ? `${jobTown(last, 'pickup')} → ${jobTown(last, 'dropoff')}` : '',
    };
  });
}

export function jobsWithProof(jobs) {
  return (jobs || []).filter((job) => job.pod_photo_path || job.pod_signature_path);
}

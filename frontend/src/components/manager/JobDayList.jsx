import { boardRank, isActiveJob, statusLabel } from '../../lib/jobStatus.js';
import { milesFmt, moneyFmt } from './format.js';

export function formatJobTime(t) {
  if (!t) return '';
  const parts = String(t).split(':');
  const h = Number(parts[0]);
  const m = Number(parts[1] ?? 0);
  if (!Number.isFinite(h)) return String(t);
  return new Date(2020, 0, 1, h, m).toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
  });
}

export function stopLine(job, prefix) {
  const city = String(job[`${prefix}_city`] || '').trim();
  const name = String(job[`${prefix}_name`] || '').trim();
  const line1 = String(job[`${prefix}_line1`] || '').trim();
  const address = String(job[`${prefix}_address`] || '').trim();
  if (name && city) return `${name} · ${city}`;
  return name || city || line1 || address || '';
}

export function sortDayJobs(list) {
  return [...list].sort((a, b) => {
    const rank = boardRank(a.status) - boardRank(b.status);
    if (rank) return rank;
    const unassigned = Number(Boolean(a.assigned_user_id)) - Number(Boolean(b.assigned_user_id));
    if (unassigned) return unassigned;
    const orderA = Number(a.stop_order);
    const orderB = Number(b.stop_order);
    if (Number.isFinite(orderA) && Number.isFinite(orderB) && orderA !== orderB) return orderA - orderB;
    return String(a.pickup_time || a.job_time || '99').localeCompare(String(b.pickup_time || b.job_time || '99'));
  });
}

export function jobsOnDate(jobs, iso, { hideDone = false } = {}) {
  const list = [];
  for (const job of jobs || []) {
    if (job.job_date !== iso) continue;
    if (hideDone && !isActiveJob(job.status)) continue;
    list.push(job);
  }
  return sortDayJobs(list);
}

export default function JobDayList({
  jobs,
  editingId,
  onPick,
  driverName,
  etas = {},
  officeClosesJobs = false,
  onMarkDelivered,
  mode = 'courier',
  serviceStyle = false,
  showMoney = true,
}) {
  if (!jobs.length) return null;
  return (
    <div className="job-list">
      {jobs.map((job) => (
        <div key={job.id} className="job-row-wrap">
        <button
          type="button"
          className={`job-row status-${job.status} ${editingId === job.id ? 'active' : ''}`}
          onClick={() => onPick(job)}
        >
          <div className="job-row-top">
            <strong>{job.job_number}</strong>
            <span>
              {(() => {
                const pickup = formatJobTime(job.pickup_time || job.job_time);
                const drop = formatJobTime(job.dropoff_time);
                if (pickup && drop) return `${pickup}–${drop}`;
                return pickup || '—';
              })()}
            </span>
          </div>
          <div className="muted-row">{driverName(job.assigned_user_id)}</div>
          {stopLine(job, 'pickup') ? <div className="job-tile-stop">{stopLine(job, 'pickup')}</div> : null}
          {serviceStyle ? null : (stopLine(job, 'dropoff') ? <div className="job-tile-stop muted">{stopLine(job, 'dropoff')}</div> : null)}
          <div className="job-row-meta">
            {job.estimated_miles != null ? <span>{milesFmt.format(Number(job.estimated_miles))} mi</span> : null}
            {showMoney && (job.quoted_amount != null || job.estimated_cost != null) ? (
              <span>{moneyFmt.format(Number(job.quoted_amount ?? job.estimated_cost))}</span>
            ) : null}
            {showMoney && job.driver_pay != null ? <span>{moneyFmt.format(Number(job.driver_pay))} pay</span> : null}
            {job.status === 'picked_up' && etas[job.id] != null ? (
              <span>About {etas[job.id]} min</span>
            ) : null}
            {job.status !== 'open' ? <span className="job-tile-status">{statusLabel(job.status, mode)}</span> : null}
          </div>
        </button>
            {officeClosesJobs && onMarkDelivered && (job.status === 'open' || job.status === 'picked_up') ? (
              <button
                type="button"
                className="btn btn-secondary settings-copy job-close-btn"
                onClick={() => onMarkDelivered(job)}
              >
                {statusLabel('delivered', mode)}
              </button>
            ) : null}
        </div>
      ))}
    </div>
  );
}

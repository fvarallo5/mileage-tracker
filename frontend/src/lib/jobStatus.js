export const JOB_STATUSES = [
  { id: 'open', label: 'Open' },
  { id: 'picked_up', label: 'Picked up' },
  { id: 'delivered', label: 'Delivered' },
  { id: 'failed', label: "Couldn't deliver" },
  { id: 'cancelled', label: 'Cancelled' },
];

export function isDelivered(status) {
  return status === 'delivered' || status === 'done';
}

export function isActiveJob(status) {
  return status === 'open' || status === 'picked_up' || status === 'failed';
}

export function statusesForMode(mode) {
  const type = String(mode || '').toLowerCase();
  if (type === 'driving_school') {
    return [
      { id: 'open', label: 'Scheduled' },
      { id: 'picked_up', label: 'In lesson' },
      { id: 'delivered', label: 'Done' },
      { id: 'failed', label: 'No-show' },
      { id: 'cancelled', label: 'Cancelled' },
    ];
  }
  if (type === 'service') {
    return [
      { id: 'open', label: 'Open' },
      { id: 'picked_up', label: 'On site' },
      { id: 'delivered', label: 'Done' },
      { id: 'failed', label: "Couldn't complete" },
      { id: 'cancelled', label: 'Cancelled' },
    ];
  }
  return JOB_STATUSES;
}

export function statusLabel(status, mode) {
  const row = statusesForMode(mode).find((item) => item.id === status);
  if (row) return row.label;
  if (isDelivered(status)) return mode === 'driving_school' || mode === 'service' ? 'Done' : 'Delivered';
  return status || '';
}

export function boardRank(status) {
  if (status === 'failed') return 0;
  if (status === 'open') return 1;
  if (status === 'picked_up') return 2;
  if (isDelivered(status)) return 3;
  return 4;
}

export function statusMatches(jobStatus, filter) {
  if (!filter || filter === 'all') return true;
  if (filter === 'delivered' || filter === 'done') return isDelivered(jobStatus);
  return jobStatus === filter;
}

import { trim } from './address.js';
import { supabase } from '../supabase.js';

export function jobNotifyEmails(job, customer) {
  const emails = [];
  for (const raw of [job?.pickup_email, job?.dropoff_email, customer?.billing_email]) {
    const email = trim(raw).toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) continue;
    if (!emails.includes(email)) emails.push(email);
  }
  return emails;
}

export function shouldNotifyJob({ isCreate = false, prevStatus, nextStatus } = {}) {
  const status = nextStatus || 'open';
  if (isCreate) return ['open', 'picked_up', 'delivered', 'failed'].includes(status);
  if (!nextStatus || nextStatus === prevStatus) return false;
  return ['open', 'picked_up', 'delivered', 'failed'].includes(nextStatus);
}

export async function notifyJob(jobId) {
  if (!supabase || jobId == null) return;
  try {
    await supabase.functions.invoke('notify-job', { body: { job_id: jobId } });
  } catch {
    /* function not deployed yet */
  }
}

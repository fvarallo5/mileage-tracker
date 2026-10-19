import { rememberLastCustomer } from './accountMatch.js';
import { copyJobNumber } from './books.js';
import { payloadFromForm, withQuote } from './jobForm.js';
import { notifyJob, shouldNotifyJob } from './jobNotify.js';
import { isWeekend, weekdayDates } from './quote.js';
import { orgApi } from '../orgApi.js';

export function jobSaveHint(message) {
  const text = message || '';
  if (/charge_number|item_count|weight_value|weight_unit|038_/i.test(text)) {
    return ' Paste 038_account_stops_weight.sql in the SQL editor, then hard-refresh.';
  }
  if (/pickup_email|dropoff_email|service_level|service_addon|pod_signature|036_/i.test(text)) {
    return ' Paste 036_job_notify_signature.sql in the Supabase SQL editor, then hard-refresh.';
  }
  if (/pickup_line1|dropoff_line1|schema cache/i.test(text)) {
    return ' Run 023_org_job_addresses.sql in the Supabase SQL editor.';
  }
  if (/customer_id|failure_reason|attempt_fee|cod_|stop_order|pod_note|org_jobs_status_check|032_/i.test(text)) {
    return ' Run 032_customers_books.sql in the Supabase SQL editor.';
  }
  if (/quoted_amount|driver_pay|pickup_time|030_/i.test(text)) {
    return ' Run 030_job_quotes_schedule.sql in the Supabase SQL editor.';
  }
  if (/estimated_/i.test(text)) {
    return ' Run 026_dispatch_home.sql in the Supabase SQL editor.';
  }
  return '';
}

export function assertJobPayload(body) {
  if (!body.job_number) throw new Error('Job number is required.');
  if (!body.pickup_address) throw new Error('Pickup address is required.');
  if (!body.dropoff_address) throw new Error('Delivery address is required.');
}

export async function saveJobForm({ form, editingId, orgId, jobs, ratesFor }) {
  const body = payloadFromForm(form);
  assertJobPayload(body);
  if (editingId) {
    const prev = (jobs || []).find((job) => job.id === editingId);
    await orgApi.updateJob(editingId, body);
    if (shouldNotifyJob({ prevStatus: prev?.status, nextStatus: body.status })) {
      await notifyJob(editingId);
    }
  } else {
    const dates = form.weekdays.length
      ? weekdayDates(body.job_date, form.weekdays, 8)
      : [body.job_date];
    const seriesId = dates.length > 1 ? crypto.randomUUID() : null;
    const rows = dates.map((date) => {
      const priced = withQuote({ ...form, job_date: date, quote_weekend: isWeekend(date) }, ratesFor(form));
      return {
        ...payloadFromForm(priced),
        job_date: date,
        series_id: seriesId,
      };
    });
    if (rows.length === 1) {
      const created = await orgApi.createJob(orgId, rows[0]);
      if (shouldNotifyJob({ isCreate: true, nextStatus: created?.status || rows[0].status })) {
        await notifyJob(created?.id);
      }
    } else {
      const created = await orgApi.createJobs(orgId, rows);
      await Promise.all((created || []).map((row) => notifyJob(row.id)));
    }
  }
  if (body.customer_id) rememberLastCustomer(orgId, body.customer_id);
  return { boardDate: body.job_date };
}

export async function duplicateJobForm({ form, orgId, jobDate }) {
  const body = payloadFromForm(form);
  body.job_number = copyJobNumber(body.job_number);
  body.job_date = jobDate || body.job_date;
  body.status = 'open';
  body.failure_reason = '';
  body.pod_note = '';
  body.attempt_fee = null;
  body.cod_collected = false;
  const created = await orgApi.createJob(orgId, body);
  if (created?.id) await notifyJob(created.id);
  if (body.customer_id) rememberLastCustomer(orgId, body.customer_id);
  return { boardDate: body.job_date };
}

export async function deleteJobById(id) {
  await orgApi.deleteJob(id);
}

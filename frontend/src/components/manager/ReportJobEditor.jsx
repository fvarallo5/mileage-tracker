import { useEffect, useState } from 'react';
import { useTeam } from '../../context/TeamContext.jsx';
import { nextChargeNumber } from '../../lib/accountForm.js';
import { customerFromPickup, rememberLastCustomer } from '../../lib/accountMatch.js';
import { recentJobStops, US_STATES } from '../../lib/address.js';
import { copyJobNumber } from '../../lib/books.js';
import { applyFormChange, formFromJob, payloadFromForm, ratesForAccount, withSuggestedAccount } from '../../lib/jobForm.js';
import { jobNotifyEmails } from '../../lib/jobNotify.js';
import { SERVICE_LEVELS } from '../../lib/quote.js';
import { isServiceJobStyle } from '../../lib/company.js';
import { statusLabel } from '../../lib/jobStatus.js';
import { deskSkin } from '../../lib/layout.js';
import { orgApi } from '../../orgApi.js';
import { moneyFmt } from './format.js';
import AddressSuggest from './AddressSuggest.jsx';
import PodPhoto from './PodPhoto.jsx';
import TrackLinkButtons from './TrackLinkButtons.jsx';
import JobBookFields, { StatusSelect } from './JobBookFields.jsx';
import TimeSelect from './TimeSelect.jsx';

export default function ReportJobEditor({
  job,
  drivers,
  rates,
  jobs,
  customers,
  sample,
  gpsMiles,
  busy,
  onSave,
  onDelete,
  onDuplicate,
  onClose,
}) {
  const team = useTeam();
  const skin = deskSkin(team.membership?.operatingMode);
  const mode = team.membership?.operatingMode;
  const serviceStyle = isServiceJobStyle(mode);
  const takePct = Math.round((rates?.companyTakePct ?? 0.3) * 100);
  const [form, setForm] = useState(() => (job ? formFromJob(job, { takePct, customers }) : null));
  const [savingAccount, setSavingAccount] = useState(false);
  const recents = recentJobStops(jobs);

  useEffect(() => {
    setForm(job ? formFromJob(job, { takePct, customers }) : null);
  }, [job?.id, takePct, customers]);

  if (!job || !form) {
    return (
      <aside className="dispatch-form report-editor">
        <div className="drawer-head">
          <h2>{skin.jobWord}</h2>
        </div>
        <p className="empty">Select a {skin.jobWord.toLowerCase()} to edit or delete it.</p>
      </aside>
    );
  }

  function ratesFor(current) {
    const customer = (customers || []).find((row) => row.id === current.customer_id);
    return ratesForAccount(rates, customer);
  }

  function setField(key, value) {
    setForm((prev) => {
      const nextForm = key === 'customer_id' ? { ...prev, customer_id: value } : prev;
      const nextRates = ratesFor(nextForm);
      const base = key === 'customer_id' && !prev.quote_manual
        ? { ...prev, company_take_pct: String(Math.round((nextRates.companyTakePct ?? 0.3) * 100)) }
        : prev;
      const changed = applyFormChange(base, key, value, nextRates, customers);
      if (key === 'pickup_name' || key === 'pickup_email') {
        return withSuggestedAccount(changed, customers, rates);
      }
      return changed;
    });
  }

  async function handleSaveAccount() {
    const fields = customerFromPickup(form, { terms: team.membership?.defaultTerms });
    if (!fields.charge_number) fields.charge_number = nextChargeNumber(customers);
    if (!fields.name || !team.membership?.orgId || sample) return;
    setSavingAccount(true);
    team.setError(null);
    try {
      const row = await orgApi.saveCustomer(team.membership.orgId, fields);
      rememberLastCustomer(team.membership.orgId, row.id);
      setField('customer_id', row.id);
      await team.reload();
    } catch (err) {
      team.setError(err.message);
    } finally {
      setSavingAccount(false);
    }
  }

  function setAddr(side, patch) {
    setForm((prev) => {
      const next = { ...prev, [side]: { ...prev[side], ...patch } };
      return applyFormChange(next, side, next[side], ratesFor(next));
    });
  }

  function chooseStop(side, hit) {
    setAddr(side, {
      line1: hit.line1 || '',
      city: hit.city || '',
      state: hit.state || '',
      zip: hit.zip || '',
    });
    if (hit.business && !form[`${side}_name`]) setField(`${side}_name`, hit.business);
  }

  async function handleSubmit(e) {
    e.preventDefault();
    const body = payloadFromForm(form);
    if (body.customer_id && team.membership?.orgId) {
      rememberLastCustomer(team.membership.orgId, body.customer_id);
    }
    await onSave(job, body);
  }

  return (
    <aside className="dispatch-form report-editor">
      <div className="drawer-head">
        <h2>{skin.jobWord} {form.job_number || ''}</h2>
        <button type="button" className="btn-ghost btn-sm" onClick={onClose}>
          Close
        </button>
      </div>
      {sample ? <p className="field-hint">Sample job · edits stay on this preview.</p> : null}
      {job.pod_photo_path || job.pod_signature_path ? (
        <div className="pod-pair">
          {job.pod_photo_path ? <PodPhoto path={job.pod_photo_path} alt="Delivery photo" /> : null}
          {job.pod_signature_path ? <PodPhoto path={job.pod_signature_path} alt="Signature" className="pod-photo pod-sig" /> : null}
        </div>
      ) : null}
      {job.failure_reason ? <p className="field-hint">{statusLabel('failed', mode)}: {job.failure_reason}</p> : null}
      {job.pod_note ? <p className="field-hint">{skin.showCourierQuotes ? 'Delivery note' : 'Note'}: {job.pod_note}</p> : null}
      {gpsMiles != null ? (
        <p className="field-hint">
          GPS {Number(gpsMiles).toFixed(1)} mi
          {job.estimated_miles != null ? ` · estimate ${Number(job.estimated_miles).toFixed(1)} mi` : ''}. The invoice still uses the quote.
        </p>
      ) : null}
      <form onSubmit={handleSubmit} className="drawer-form">
        <div className="drawer-form-body">
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="rep-job-number">{skin.jobWord} #</label>
              <input id="rep-job-number" value={form.job_number} onChange={(e) => setField('job_number', e.target.value)} required maxLength={40} />
            </div>
            <div className="form-group">
              <label htmlFor="rep-job-date">Date</label>
              <input id="rep-job-date" type="date" value={form.job_date} onChange={(e) => setField('job_date', e.target.value)} required />
            </div>
          </div>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="rep-pickup-time">{serviceStyle ? 'Start' : 'Pickup'}</label>
              <TimeSelect
                id="rep-pickup-time"
                value={form.pickup_time}
                onChange={(value) => setField('pickup_time', value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="rep-dropoff-time">{serviceStyle ? 'End' : 'Dropoff'}</label>
              <TimeSelect
                id="rep-dropoff-time"
                value={form.dropoff_time}
                onChange={(value) => setField('dropoff_time', value)}
              />
            </div>
          </div>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="rep-driver">{skin.worker}</label>
              <select id="rep-driver" value={form.assigned_user_id} onChange={(e) => setField('assigned_user_id', e.target.value)}>
                <option value="">Unassigned</option>
                {drivers.map((d) => (
                  <option key={d.user_id} value={d.user_id}>
                    {d.driverNumber ? `${d.driverNumber} - ${d.label}` : d.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="rep-status">Status</label>
              <StatusSelect id="rep-status" value={form.status} onChange={(e) => setField('status', e.target.value)} mode={mode} />
            </div>
          </div>
          <JobBookFields
            idPrefix="rep"
            form={form}
            setField={setField}
            customers={customers}
            onSaveAccount={sample ? undefined : handleSaveAccount}
            savingAccount={savingAccount}
            weightUnit={team.weightUnit}
            useCod={team.membership?.useCod}
            courierExtras={skin.showCourierQuotes}
            failedLabel={statusLabel('failed', mode)}
            noteLabel={skin.showCourierQuotes ? 'Delivery note' : 'Note'}
          />
          <fieldset className="address-block">
            <legend>{skin.siteTitle}</legend>
            <div className="form-group">
              <label htmlFor="rep-pick-line1">Address</label>
              <AddressSuggest
                id="rep-pick-line1"
                value={form.pickup.line1}
                recents={recents}
                onChange={(line1) => setAddr('pickup', { line1 })}
                onSelect={(hit) => chooseStop('pickup', hit)}
              />
            </div>
            <div className="form-row">
              <div className="form-group">
                <label htmlFor="rep-pick-city">Town</label>
                <input id="rep-pick-city" value={form.pickup.city} onChange={(e) => setAddr('pickup', { city: e.target.value })} />
              </div>
              <div className="form-group">
                <label htmlFor="rep-pick-state">ST</label>
                <input id="rep-pick-state" value={form.pickup.state} onChange={(e) => setAddr('pickup', { state: e.target.value })} maxLength={2} list="rep-states" />
              </div>
            </div>
            <div className="form-group">
              <label htmlFor="rep-pick-email">Email</label>
              <input id="rep-pick-email" type="email" value={form.pickup_email} onChange={(e) => setField('pickup_email', e.target.value)} />
            </div>
          </fieldset>
          {serviceStyle ? null : (
          <fieldset className="address-block">
            <legend>Drop-off</legend>
            <div className="form-group">
              <label htmlFor="rep-drop-line1">Address</label>
              <AddressSuggest
                id="rep-drop-line1"
                value={form.dropoff.line1}
                recents={recents}
                onChange={(line1) => setAddr('dropoff', { line1 })}
                onSelect={(hit) => chooseStop('dropoff', hit)}
              />
            </div>
            <div className="form-row">
              <div className="form-group">
                <label htmlFor="rep-drop-city">Town</label>
                <input id="rep-drop-city" value={form.dropoff.city} onChange={(e) => setAddr('dropoff', { city: e.target.value })} />
              </div>
              <div className="form-group">
                <label htmlFor="rep-drop-state">ST</label>
                <input id="rep-drop-state" value={form.dropoff.state} onChange={(e) => setAddr('dropoff', { state: e.target.value })} maxLength={2} list="rep-states" />
              </div>
            </div>
            <div className="form-group">
              <label htmlFor="rep-drop-email">Email</label>
              <input id="rep-drop-email" type="email" value={form.dropoff_email} onChange={(e) => setField('dropoff_email', e.target.value)} />
            </div>
          </fieldset>
          )}
          <datalist id="rep-states">
            {US_STATES.map((st) => (
              <option key={st} value={st} />
            ))}
          </datalist>
          {skin.showCourierQuotes ? (
          <>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="rep-service">Service</label>
              <select id="rep-service" value={form.service_level} onChange={(e) => setField('service_level', e.target.value)}>
                {SERVICE_LEVELS.map((row) => (
                  <option key={row.id || 'standard'} value={row.id}>{row.label}</option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="rep-addon">Add-on $</label>
              <input id="rep-addon" inputMode="decimal" value={form.service_addon} onChange={(e) => setField('service_addon', e.target.value)} />
            </div>
          </div>
          <div className="form-row quote-split">
            <div className="form-group">
              <label htmlFor="rep-quote">Quote</label>
              <input id="rep-quote" inputMode="decimal" value={form.quoted_amount} onChange={(e) => setField('quoted_amount', e.target.value)} />
            </div>
            <div className="form-group">
              <label htmlFor="rep-take">Take %</label>
              <input id="rep-take" inputMode="decimal" value={form.company_take_pct} onChange={(e) => setField('company_take_pct', e.target.value)} />
            </div>
            <div className="form-group">
              <label htmlFor="rep-pay">Driver pay</label>
              <input id="rep-pay" value={form.driver_pay} readOnly />
            </div>
          </div>
          <div className="quote-flags">
            <label>
              <input type="checkbox" checked={form.quote_manual} onChange={(e) => setField('quote_manual', e.target.checked)} />
              Manual quote
            </label>
            <label>
              <input type="checkbox" checked={form.quote_weekend} onChange={(e) => setField('quote_weekend', e.target.checked)} />
              Weekend
            </label>
            <label>
              <input type="checkbox" checked={form.quote_after_hours} onChange={(e) => setField('quote_after_hours', e.target.checked)} />
              After hours
            </label>
          </div>
          <p className="field-hint">
            Pay {moneyFmt.format(Number(form.driver_pay) || 0)}. Quote {moneyFmt.format(Number(form.quoted_amount) || 0)}.
          </p>
          </>
          ) : null}
          <div className="form-group">
            <label htmlFor="rep-notes">Notes</label>
            <textarea id="rep-notes" rows={2} value={form.details} onChange={(e) => setField('details', e.target.value)} />
          </div>
        </div>
        {skin.showCourierQuotes ? (
        <TrackLinkButtons
          token={job.tracking_token}
          phone={form.dropoff_phone}
          emails={jobNotifyEmails(form, (customers || []).find((row) => row.id === form.customer_id))}
          jobNumber={form.job_number}
          status={form.status}
        />
        ) : null}
        <div className="drawer-actions">
          <button type="submit" className="btn btn-primary" disabled={busy}>
            {busy ? 'Saving…' : `Save ${skin.jobWord.toLowerCase()}`}
          </button>
          {onDuplicate ? (
            <button
              type="button"
              className="btn btn-secondary"
              disabled={busy}
              onClick={() => onDuplicate(job, {
                ...payloadFromForm(form),
                job_number: copyJobNumber(form.job_number),
                status: 'open',
                failure_reason: '',
                pod_note: '',
                attempt_fee: null,
                cod_collected: false,
              })}
            >
              Duplicate
            </button>
          ) : null}
          <button
            type="button"
            className="btn-danger"
            disabled={busy}
            onClick={() => onDelete(job)}
          >
            Delete
          </button>
        </div>
      </form>
    </aside>
  );
}

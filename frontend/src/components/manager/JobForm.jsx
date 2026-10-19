import { useEffect } from 'react';
import { composeAddress, trim, US_STATES } from '../../lib/address.js';
import { drivingEstimate } from '../../lib/geo.js';
import { jobNotifyEmails } from '../../lib/jobNotify.js';
import { withQuote } from '../../lib/jobForm.js';
import { statusLabel } from '../../lib/jobStatus.js';
import { SERVICE_LEVELS, WEEKDAYS } from '../../lib/quote.js';
import { moneyFmt } from './format.js';
import AddressSuggest from './AddressSuggest.jsx';
import JobBookFields, { StatusSelect } from './JobBookFields.jsx';
import TimeSelect from './TimeSelect.jsx';
import TrackLinkButtons from './TrackLinkButtons.jsx';

function addressReady(addr) {
  return Boolean(trim(addr?.line1) && trim(addr?.city));
}

function AddressFields({ id, title, name, setName, phone, setPhone, email, setEmail, address, setAddress, recents, nameLabel = 'Business name' }) {
  function set(key, value) {
    setAddress({ ...address, [key]: value });
  }
  return (
    <fieldset className="address-block">
      <legend>{title}</legend>
      <div className="form-group">
        <label htmlFor={`${id}-name`}>{nameLabel}</label>
        <input id={`${id}-name`} value={name} onChange={(e) => setName(e.target.value)} />
      </div>
      <div className="form-group">
        <label htmlFor={`${id}-line1`}>Address line 1</label>
        <AddressSuggest
          id={`${id}-line1`}
          value={address.line1}
          recents={recents}
          onChange={(line1) => set('line1', line1)}
          onSelect={(hit) => {
            setAddress({
              line1: hit.line1 || '',
              line2: hit.line2 || address.line2,
              city: hit.city || '',
              state: hit.state || '',
              zip: hit.zip || '',
            });
            if (hit.business) setName(hit.business);
          }}
        />
      </div>
      <div className="form-group">
        <label htmlFor={`${id}-line2`}>Address line 2</label>
        <input
          id={`${id}-line2`}
          value={address.line2}
          onChange={(e) => set('line2', e.target.value)}
          placeholder="Apt, unit"
          autoComplete="address-line2"
        />
      </div>
      <div className="form-row address-city-row">
        <div className="form-group">
          <label htmlFor={`${id}-city`}>City</label>
          <input id={`${id}-city`} value={address.city} onChange={(e) => set('city', e.target.value)} autoComplete="address-level2" />
        </div>
        <div className="form-group">
          <label htmlFor={`${id}-state`}>State</label>
          <select id={`${id}-state`} value={address.state} onChange={(e) => set('state', e.target.value)}>
            <option value="">—</option>
            {US_STATES.map((st) => (
              <option key={st} value={st}>{st}</option>
            ))}
          </select>
        </div>
        <div className="form-group">
          <label htmlFor={`${id}-zip`}>ZIP</label>
          <input id={`${id}-zip`} value={address.zip} onChange={(e) => set('zip', e.target.value)} inputMode="numeric" autoComplete="postal-code" />
        </div>
      </div>
      <div className="form-group">
        <label htmlFor={`${id}-phone`}>Phone</label>
        <input id={`${id}-phone`} type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} />
      </div>
      <div className="form-group">
        <label htmlFor={`${id}-email`}>Email</label>
        <input id={`${id}-email`} type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" />
      </div>
    </fieldset>
  );
}

export default function JobForm({
  form,
  setField,
  patchForm,
  toggleWeekday,
  editingId,
  drivers,
  customers,
  recents,
  busy,
  estimating,
  savingAccount,
  onSubmit,
  onEstimate,
  onDuplicate,
  onDelete,
  onSaveAccount,
  onClose,
  ratesFor,
  trackingToken,
  idPrefix = 'job',
  className = 'dispatch-form',
  weightUnit = 'lb',
  officeClosesJobs = false,
  useCod = false,
  serviceStyle = false,
  courierQuotes = true,
  operatingMode = 'courier',
  workerLabel = 'Driver',
  siteTitle = 'Pickup',
  jobWord = 'Job',
}) {
  useEffect(() => {
    if (serviceStyle) return undefined;
    const pickup = composeAddress(form.pickup);
    const dropoff = composeAddress(form.dropoff);
    if (!addressReady(form.pickup) || !addressReady(form.dropoff) || form.milesDirty || !patchForm) return undefined;
    const timer = window.setTimeout(async () => {
      try {
        const { miles } = await drivingEstimate(pickup, dropoff);
        patchForm((prev) => {
          if (prev.milesDirty) return prev;
          if (composeAddress(prev.pickup) !== pickup || composeAddress(prev.dropoff) !== dropoff) return prev;
          return withQuote({ ...prev, estimated_miles: miles.toFixed(1) }, ratesFor(prev));
        });
      } catch {
        /* Estimate from map still reports a failure */
      }
    }, 600);
    return () => window.clearTimeout(timer);
  }, [form.pickup, form.dropoff, form.milesDirty, patchForm]);

  const rates = ratesFor(form);

  return (
    <aside className={className} aria-labelledby={`${idPrefix}-form-title`}>
      <div className="drawer-head">
        <h2 id={`${idPrefix}-form-title`}>{editingId ? `${jobWord} ${form.job_number || ''}` : `New ${jobWord.toLowerCase()}`}</h2>
        {editingId && onClose ? (
          <button type="button" className="btn-ghost btn-sm" onClick={onClose}>
            New
          </button>
        ) : null}
      </div>
      <form onSubmit={onSubmit} className="drawer-form">
        <div className="drawer-form-body">
          <div className="form-row">
            <div className="form-group">
              <label htmlFor={`${idPrefix}-number`}>{jobWord} #</label>
              <input id={`${idPrefix}-number`} value={form.job_number} onChange={(e) => setField('job_number', e.target.value)} required maxLength={40} />
            </div>
            <div className="form-group">
              <label htmlFor={`${idPrefix}-date`}>Date</label>
              <input id={`${idPrefix}-date`} type="date" value={form.job_date} onChange={(e) => setField('job_date', e.target.value)} required />
            </div>
          </div>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor={`${idPrefix}-pickup-time`}>{serviceStyle ? 'Start' : 'Pickup'}</label>
              <TimeSelect
                id={`${idPrefix}-pickup-time`}
                value={form.pickup_time}
                onChange={(value) => setField('pickup_time', value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor={`${idPrefix}-dropoff-time`}>{serviceStyle ? 'End' : 'Dropoff'}</label>
              <TimeSelect
                id={`${idPrefix}-dropoff-time`}
                value={form.dropoff_time}
                onChange={(value) => setField('dropoff_time', value)}
              />
            </div>
          </div>
          <div className="form-row address-assign-row">
            <div className="form-group">
              <label htmlFor={`${idPrefix}-driver`}>{workerLabel}</label>
              <select id={`${idPrefix}-driver`} value={form.assigned_user_id} onChange={(e) => setField('assigned_user_id', e.target.value)}>
                <option value="">Unassigned</option>
                {drivers.map((m) => (
                  <option key={m.user_id} value={m.user_id}>{m.label}</option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label htmlFor={`${idPrefix}-status`}>Status</label>
              <StatusSelect
                id={`${idPrefix}-status`}
                value={form.status}
                onChange={(e) => setField('status', e.target.value)}
                mode={operatingMode}
              />
              {officeClosesJobs ? (
                <p className="field-hint">
                  Office closes this {jobWord.toLowerCase()}. {workerLabel}s can mark {statusLabel('picked_up', operatingMode).toLowerCase()} on the phone.
                </p>
              ) : null}
            </div>
          </div>
          <JobBookFields
            idPrefix={idPrefix}
            form={form}
            setField={setField}
            customers={customers}
            onSaveAccount={onSaveAccount}
            savingAccount={savingAccount}
            weightUnit={weightUnit}
            useCod={useCod}
            courierExtras={courierQuotes}
            failedLabel={statusLabel('failed', operatingMode)}
            noteLabel={courierQuotes ? 'Delivery note' : 'Note'}
          />
          <div className={serviceStyle ? '' : 'address-pair'}>
            <AddressFields
              id={`${idPrefix}-pickup`}
              title={operatingMode === 'driving_school' ? 'Student / meet' : siteTitle}
              name={form.pickup_name}
              setName={(v) => setField('pickup_name', v)}
              phone={form.pickup_phone}
              setPhone={(v) => setField('pickup_phone', v)}
              email={form.pickup_email}
              setEmail={(v) => setField('pickup_email', v)}
              address={form.pickup}
              setAddress={(v) => setField('pickup', v)}
              recents={recents}
              nameLabel={operatingMode === 'driving_school' ? 'Student name' : (serviceStyle ? 'Customer name' : 'Business name')}
            />
            {serviceStyle ? null : (
            <AddressFields
              id={`${idPrefix}-dropoff`}
              title="Delivery"
              name={form.dropoff_name}
              setName={(v) => setField('dropoff_name', v)}
              phone={form.dropoff_phone}
              setPhone={(v) => setField('dropoff_phone', v)}
              email={form.dropoff_email}
              setEmail={(v) => setField('dropoff_email', v)}
              address={form.dropoff}
              setAddress={(v) => setField('dropoff', v)}
              recents={recents}
            />
            )}
          </div>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor={`${idPrefix}-est-miles`}>Est. miles</label>
              <input
                id={`${idPrefix}-est-miles`}
                inputMode="decimal"
                value={form.estimated_miles}
                onChange={(e) => setField('estimated_miles', e.target.value)}
              />
            </div>
            {serviceStyle ? null : (
            <div className="form-group" style={{ justifyContent: 'flex-end' }}>
              <label htmlFor={`${idPrefix}-estimate-btn`}>&nbsp;</label>
              <button id={`${idPrefix}-estimate-btn`} type="button" className="btn btn-secondary" onClick={onEstimate} disabled={estimating}>
                {estimating ? 'Estimating…' : 'Estimate from map'}
              </button>
            </div>
            )}
          </div>
          {courierQuotes ? (
          <div className="form-row">
            <div className="form-group">
              <label htmlFor={`${idPrefix}-service`}>Service</label>
              <select id={`${idPrefix}-service`} value={form.service_level} onChange={(e) => setField('service_level', e.target.value)}>
                {SERVICE_LEVELS.map((row) => (
                  <option key={row.id || 'standard'} value={row.id}>{row.label}</option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label htmlFor={`${idPrefix}-addon`}>Add-on $</label>
              <input
                id={`${idPrefix}-addon`}
                inputMode="decimal"
                value={form.service_addon}
                onChange={(e) => setField('service_addon', e.target.value)}
              />
            </div>
          </div>
          ) : null}
          {courierQuotes ? (
          <>
          <div className="form-row quote-split">
            <div className="form-group">
              <label htmlFor={`${idPrefix}-quote`}>Quote</label>
              <input
                id={`${idPrefix}-quote`}
                inputMode="decimal"
                value={form.quoted_amount}
                onChange={(e) => setField('quoted_amount', e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor={`${idPrefix}-take`}>Take %</label>
              <input
                id={`${idPrefix}-take`}
                inputMode="decimal"
                value={form.company_take_pct}
                onChange={(e) => setField('company_take_pct', e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor={`${idPrefix}-pay`}>Driver pay</label>
              <input id={`${idPrefix}-pay`} value={form.driver_pay} readOnly />
            </div>
          </div>
          <div className="quote-flags">
            <label>
              <input
                type="checkbox"
                checked={form.quote_manual}
                onChange={(e) => setField('quote_manual', e.target.checked)}
              />
              Manual quote
            </label>
            <label>
              <input
                type="checkbox"
                checked={form.quote_weekend}
                onChange={(e) => setField('quote_weekend', e.target.checked)}
              />
              Weekend
            </label>
            <label>
              <input
                type="checkbox"
                checked={form.quote_after_hours}
                onChange={(e) => setField('quote_after_hours', e.target.checked)}
              />
              After hours
            </label>
          </div>
          <p className="field-hint">
            {form.quote_manual
              ? 'Typed quote. Driver pay is quote minus company take. The add-on is already in that number.'
              : `Road miles. max(min ${moneyFmt.format(rates.quoteMinimum)}, miles × ${moneyFmt.format(rates.quotePerMile)})${form.quote_weekend ? ` × ${rates.weekendMult} weekend` : ''}${form.quote_after_hours ? ` × ${rates.afterHoursMult} after hours` : ''}${Number(form.service_addon) > 0 ? ` + ${moneyFmt.format(Number(form.service_addon))}` : ''}.`}
          </p>
          </>
          ) : null}
          {editingId ? null : (
            <fieldset className="weekday-set">
              <legend>Repeat weekdays</legend>
              <div className="weekday-row">
                {WEEKDAYS.map((day) => (
                  <label key={day.id} className={form.weekdays.includes(day.id) ? 'on' : ''}>
                    <input
                      type="checkbox"
                      checked={form.weekdays.includes(day.id)}
                      onChange={() => toggleWeekday(day.id)}
                    />
                    {day.label}
                  </label>
                ))}
              </div>
              {form.weekdays.length ? (
                <p className="field-hint">Creates the next 8 weeks of matching days for this run.</p>
              ) : null}
            </fieldset>
          )}
          <div className="form-group">
            <label htmlFor={`${idPrefix}-details`}>Notes</label>
            <textarea id={`${idPrefix}-details`} rows={2} value={form.details} onChange={(e) => setField('details', e.target.value)} />
          </div>
        </div>
        {editingId && courierQuotes ? (
          <TrackLinkButtons
            token={trackingToken}
            phone={form.dropoff_phone}
            emails={jobNotifyEmails(form, (customers || []).find((row) => row.id === form.customer_id))}
            jobNumber={form.job_number}
            status={form.status}
          />
        ) : null}
        <div className="drawer-actions">
          <button type="submit" className="btn btn-primary" disabled={busy}>
            {busy ? 'Saving…' : editingId ? `Save ${jobWord.toLowerCase()}` : `Create ${jobWord.toLowerCase()}`}
          </button>
          {editingId ? (
            <button type="button" className="btn btn-secondary" onClick={onDuplicate} disabled={busy}>
              Duplicate
            </button>
          ) : null}
          {editingId ? (
            <button type="button" className="btn-danger" onClick={onDelete} disabled={busy}>
              Delete
            </button>
          ) : null}
        </div>
      </form>
    </aside>
  );
}

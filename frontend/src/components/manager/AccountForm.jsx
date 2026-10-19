import { US_STATES } from '../../lib/address.js';
import { digitsOnly } from '../../lib/accountForm.js';

function StopFields({ prefix, title, form, set, idPrefix }) {
  return (
    <fieldset className="address-block">
      <legend>{title}</legend>
      <div className="form-group">
        <label htmlFor={`${idPrefix}-${prefix}-name`}>Business name</label>
        <input
          id={`${idPrefix}-${prefix}-name`}
          value={form[`${prefix}_name`]}
          onChange={(e) => set(`${prefix}_name`, e.target.value)}
        />
      </div>
      <div className="form-group">
        <label htmlFor={`${idPrefix}-${prefix}-line1`}>Address line 1</label>
        <input
          id={`${idPrefix}-${prefix}-line1`}
          value={form[`${prefix}_line1`]}
          onChange={(e) => set(`${prefix}_line1`, e.target.value)}
        />
      </div>
      <div className="form-group">
        <label htmlFor={`${idPrefix}-${prefix}-line2`}>Address line 2</label>
        <input
          id={`${idPrefix}-${prefix}-line2`}
          value={form[`${prefix}_line2`]}
          onChange={(e) => set(`${prefix}_line2`, e.target.value)}
        />
      </div>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor={`${idPrefix}-${prefix}-city`}>City</label>
          <input
            id={`${idPrefix}-${prefix}-city`}
            value={form[`${prefix}_city`]}
            onChange={(e) => set(`${prefix}_city`, e.target.value)}
          />
        </div>
        <div className="form-group">
          <label htmlFor={`${idPrefix}-${prefix}-state`}>State</label>
          <select
            id={`${idPrefix}-${prefix}-state`}
            value={form[`${prefix}_state`]}
            onChange={(e) => set(`${prefix}_state`, e.target.value)}
          >
            <option value="">—</option>
            {US_STATES.map((code) => (
              <option key={code} value={code}>{code}</option>
            ))}
          </select>
        </div>
        <div className="form-group">
          <label htmlFor={`${idPrefix}-${prefix}-zip`}>ZIP</label>
          <input
            id={`${idPrefix}-${prefix}-zip`}
            value={form[`${prefix}_zip`]}
            onChange={(e) => set(`${prefix}_zip`, e.target.value)}
          />
        </div>
      </div>
      <div className="form-group">
        <label htmlFor={`${idPrefix}-${prefix}-phone`}>Phone</label>
        <input
          id={`${idPrefix}-${prefix}-phone`}
          value={form[`${prefix}_phone`]}
          onChange={(e) => set(`${prefix}_phone`, e.target.value)}
        />
      </div>
    </fieldset>
  );
}

export default function AccountForm({
  form,
  set,
  idPrefix = 'acct',
  busy,
  editingId,
  onSubmit,
  onDelete,
  onClose,
}) {
  return (
    <form onSubmit={onSubmit} className="stack-form">
      <div className="form-row">
        <div className="form-group">
          <label htmlFor={`${idPrefix}-name`}>Name</label>
          <input id={`${idPrefix}-name`} value={form.name} onChange={(e) => set('name', e.target.value)} required />
        </div>
        <div className="form-group">
          <label htmlFor={`${idPrefix}-charge`}>Charge #</label>
          <input
            id={`${idPrefix}-charge`}
            inputMode="numeric"
            value={form.charge_number}
            onChange={(e) => set('charge_number', digitsOnly(e.target.value, 5))}
            required
            minLength={4}
            maxLength={5}
            pattern="[0-9]{4,5}"
            title="4 or 5 digits"
          />
        </div>
      </div>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor={`${idPrefix}-email`}>Billing email</label>
          <input id={`${idPrefix}-email`} type="email" value={form.billing_email} onChange={(e) => set('billing_email', e.target.value)} />
        </div>
        <div className="form-group">
          <label htmlFor={`${idPrefix}-phone`}>Phone</label>
          <input id={`${idPrefix}-phone`} value={form.phone} onChange={(e) => set('phone', e.target.value)} />
        </div>
        <div className="form-group">
          <label htmlFor={`${idPrefix}-terms`}>Terms</label>
          <input id={`${idPrefix}-terms`} value={form.terms} onChange={(e) => set('terms', e.target.value)} placeholder="Net 30" />
        </div>
      </div>
      <div className="address-pair">
        <StopFields prefix="pickup" title="Pickup (optional)" form={form} set={set} idPrefix={idPrefix} />
        <StopFields prefix="dropoff" title="Delivery (optional)" form={form} set={set} idPrefix={idPrefix} />
      </div>
      <p className="field-hint">Saved stops fill the job form when you pick this account or type the charge number.</p>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor={`${idPrefix}-mile`}>Per mile</label>
          <input id={`${idPrefix}-mile`} inputMode="decimal" value={form.quote_per_mile} onChange={(e) => set('quote_per_mile', e.target.value)} />
        </div>
        <div className="form-group">
          <label htmlFor={`${idPrefix}-min`}>Minimum</label>
          <input id={`${idPrefix}-min`} inputMode="decimal" value={form.quote_minimum} onChange={(e) => set('quote_minimum', e.target.value)} />
        </div>
        <div className="form-group">
          <label htmlFor={`${idPrefix}-take`}>Take %</label>
          <input id={`${idPrefix}-take`} inputMode="decimal" value={form.company_take_pct} onChange={(e) => set('company_take_pct', e.target.value)} />
        </div>
      </div>
      <div className="drawer-actions">
        <button type="submit" className="btn btn-primary" disabled={busy}>Save account</button>
        {editingId && onDelete ? (
          <button type="button" className="btn-danger" onClick={onDelete} disabled={busy}>Delete</button>
        ) : null}
        {onClose ? (
          <button type="button" className="btn-ghost btn-sm" onClick={onClose}>Close</button>
        ) : null}
      </div>
    </form>
  );
}

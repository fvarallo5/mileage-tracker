import { accountLabel, digitsOnly, weightLabel } from '../../lib/accountForm.js';
import { trim } from '../../lib/address.js';
import { statusesForMode } from '../../lib/jobStatus.js';

export function StatusSelect({ id, value, onChange, mode }) {
  const rows = statusesForMode(mode);
  return (
    <select id={id} value={value} onChange={onChange}>
      {rows.map((row) => (
        <option key={row.id} value={row.id}>{row.label}</option>
      ))}
    </select>
  );
}

export default function JobBookFields({
  idPrefix,
  form,
  setField,
  customers,
  onSaveAccount,
  savingAccount,
  weightUnit = 'lb',
  useCod = false,
  courierExtras = true,
  failedLabel = "Couldn't deliver",
  noteLabel = 'Delivery note',
}) {
  const canSaveAccount = Boolean(onSaveAccount && !form.customer_id && trim(form.pickup_name));
  const unit = form.weight_unit === 'kg' || form.weight_unit === 'lb' ? form.weight_unit : weightUnit;
  return (
    <>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor={`${idPrefix}-account`}>Account</label>
          <select
            id={`${idPrefix}-account`}
            value={form.customer_id || ''}
            onChange={(e) => setField('customer_id', e.target.value)}
          >
            <option value="">No account yet</option>
            {(customers || []).map((customer) => (
              <option key={customer.id} value={customer.id}>{accountLabel(customer)}</option>
            ))}
          </select>
          {canSaveAccount ? (
            <button
              type="button"
              className="btn-ghost btn-sm account-save"
              onClick={onSaveAccount}
              disabled={savingAccount}
            >
              {savingAccount ? 'Saving…' : 'Save as account'}
            </button>
          ) : null}
        </div>
        <div className="form-group">
          <label htmlFor={`${idPrefix}-charge`}>Charge #</label>
          <input
            id={`${idPrefix}-charge`}
            inputMode="numeric"
            value={form.charge_number || ''}
            onChange={(e) => setField('charge_number', digitsOnly(e.target.value, 5))}
            maxLength={5}
            placeholder="4–5 digits"
          />
        </div>
      </div>
      {courierExtras ? (
      <div className="form-row">
        <div className="form-group">
          <label htmlFor={`${idPrefix}-items`}>Item count</label>
          <input
            id={`${idPrefix}-items`}
            inputMode="numeric"
            value={form.item_count}
            onChange={(e) => setField('item_count', e.target.value)}
          />
        </div>
        <div className="form-group">
          <label htmlFor={`${idPrefix}-weight`}>Weight ({weightLabel(unit)})</label>
          <input
            id={`${idPrefix}-weight`}
            inputMode="decimal"
            value={form.weight_value}
            onChange={(e) => setField('weight_value', e.target.value)}
          />
        </div>
        <div className="form-group">
          <label htmlFor={`${idPrefix}-stop`}>Stop order</label>
          <input
            id={`${idPrefix}-stop`}
            inputMode="numeric"
            value={form.stop_order}
            onChange={(e) => setField('stop_order', e.target.value)}
          />
        </div>
      </div>
      ) : null}
      {form.status === 'failed' ? (
        <div className="form-row">
          <div className="form-group">
            <label htmlFor={`${idPrefix}-reason`}>{failedLabel}</label>
            <input
              id={`${idPrefix}-reason`}
              value={form.failure_reason}
              onChange={(e) => setField('failure_reason', e.target.value)}
              placeholder={courierExtras ? 'Not home, refused, wrong address' : ''}
            />
          </div>
          {courierExtras ? (
          <div className="form-group">
            <label htmlFor={`${idPrefix}-fee`}>Attempt fee</label>
            <input
              id={`${idPrefix}-fee`}
              inputMode="decimal"
              value={form.attempt_fee}
              onChange={(e) => setField('attempt_fee', e.target.value)}
            />
          </div>
          ) : null}
        </div>
      ) : null}
      {form.status === 'delivered' ? (
        <div className="form-group">
          <label htmlFor={`${idPrefix}-pod`}>{noteLabel}</label>
          <input
            id={`${idPrefix}-pod`}
            value={form.pod_note}
            onChange={(e) => setField('pod_note', e.target.value)}
            placeholder={courierExtras ? 'Left at door, signed by…' : 'Notes for the file'}
          />
        </div>
      ) : null}
      {courierExtras && useCod ? (
        <>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor={`${idPrefix}-cod`}>Cash on delivery</label>
              <input
                id={`${idPrefix}-cod`}
                inputMode="decimal"
                value={form.cod_amount}
                onChange={(e) => setField('cod_amount', e.target.value)}
              />
            </div>
            <label className="hide-done">
              <input
                type="checkbox"
                checked={Boolean(form.cod_collected)}
                onChange={(e) => setField('cod_collected', e.target.checked)}
              />
              Cash collected
            </label>
          </div>
          <p className="field-hint">Cash on delivery is not added to the quote or the invoice.</p>
        </>
      ) : null}
    </>
  );
}

import { useState } from 'react';
import { EMPTY_ACCOUNT, formFromCustomer } from '../../lib/accountForm.js';
import { accountPeriodStats } from '../../lib/jobSearch.js';
import { orgApi } from '../../orgApi.js';
import { useTeam } from '../../context/TeamContext.jsx';
import AccountForm from './AccountForm.jsx';
import Module from './Module.jsx';

export default function Accounts() {
  const team = useTeam();
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState(EMPTY_ACCOUNT);
  const [open, setOpen] = useState(false);

  function begin(customer) {
    setEditingId(customer?.id || null);
    setForm(formFromCustomer(customer, { terms: team.membership?.defaultTerms }));
    setOpen(true);
  }

  function set(key, value) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    team.setError(null);
    try {
      await orgApi.saveCustomer(team.membership.orgId, { ...form, id: editingId });
      setOpen(false);
      setEditingId(null);
      setForm(EMPTY_ACCOUNT);
      await team.reload();
    } catch (err) {
      team.setError(err.message);
    }
  }

  async function handleDelete() {
    if (!editingId) return;
    if (!confirm(`Delete ${form.name}? Jobs stay, and they drop off that account.`)) return;
    team.setError(null);
    try {
      await orgApi.deleteCustomer(editingId);
      setOpen(false);
      setEditingId(null);
      await team.reload();
    } catch (err) {
      team.setError(err.message);
    }
  }

  const rows = accountPeriodStats(team.customers, team.jobs, {
    start: team.range?.start,
    end: team.range?.end,
  });

  return (
    <Module
      className="people-accounts"
      title="Accounts"
      actions={
        <button type="button" className="btn btn-secondary btn-sm" onClick={() => begin(null)}>
          New account
        </button>
      }
    >
      <p className="field-hint">The name here is the QuickBooks customer. Charge # is 4 or 5 digits.</p>
      {rows.length === 0 ? (
        <p className="empty">No accounts yet.</p>
      ) : (
        <div className="job-list">
          {rows.map((customer) => (
            <button key={customer.id} type="button" className="job-row" onClick={() => begin(customer)}>
              <div className="job-row-top">
                <strong>{customer.charge_number ? `${customer.charge_number} · ${customer.name}` : customer.name}</strong>
                <span>{customer.terms || 'Net 30'}</span>
              </div>
              <div className="muted-row">{customer.billing_email || customer.phone || 'No billing contact'}</div>
              <div className="muted-row">
                {customer.periodJobs} {customer.periodJobs === 1 ? 'job' : 'jobs'} this period
                {customer.lastJobDate ? ` · last ${customer.lastJobDate}` : ''}
              </div>
            </button>
          ))}
        </div>
      )}
      {open ? (
        <AccountForm
          form={form}
          set={set}
          busy={team.busy}
          editingId={editingId}
          onSubmit={handleSubmit}
          onDelete={handleDelete}
          onClose={() => setOpen(false)}
        />
      ) : null}
    </Module>
  );
}

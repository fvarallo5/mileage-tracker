import { useState } from 'react';
import { useTeam } from '../context/TeamContext.jsx';
import { addressFromJob, composeAddress, trim, US_STATES } from '../lib/address.js';
import { isoDate } from '../lib/period.js';
import { orgApi } from '../orgApi.js';
import { formatShortDate } from './manager/format.js';

function emptyAddress() {
  return { line1: '', line2: '', city: '', state: '', zip: '' };
}

function emptyForm(assignedUserId = '') {
  return {
    job_number: '',
    job_date: isoDate(new Date()),
    job_time: '',
    pickup_name: '',
    pickup: emptyAddress(),
    pickup_phone: '',
    dropoff_name: '',
    dropoff: emptyAddress(),
    dropoff_phone: '',
    details: '',
    notes: '',
    assigned_user_id: assignedUserId,
    status: 'open',
  };
}

function payloadFromForm(form) {
  const pickup = {
    line1: trim(form.pickup.line1),
    line2: trim(form.pickup.line2),
    city: trim(form.pickup.city),
    state: trim(form.pickup.state).toUpperCase(),
    zip: trim(form.pickup.zip),
  };
  const dropoff = {
    line1: trim(form.dropoff.line1),
    line2: trim(form.dropoff.line2),
    city: trim(form.dropoff.city),
    state: trim(form.dropoff.state).toUpperCase(),
    zip: trim(form.dropoff.zip),
  };
  return {
    job_number: trim(form.job_number),
    job_date: form.job_date,
    job_time: trim(form.job_time) || null,
    pickup_name: trim(form.pickup_name),
    pickup_line1: pickup.line1,
    pickup_line2: pickup.line2,
    pickup_city: pickup.city,
    pickup_state: pickup.state,
    pickup_zip: pickup.zip,
    pickup_address: composeAddress(pickup),
    pickup_phone: trim(form.pickup_phone),
    dropoff_name: trim(form.dropoff_name),
    dropoff_line1: dropoff.line1,
    dropoff_line2: dropoff.line2,
    dropoff_city: dropoff.city,
    dropoff_state: dropoff.state,
    dropoff_zip: dropoff.zip,
    dropoff_address: composeAddress(dropoff),
    dropoff_phone: trim(form.dropoff_phone),
    details: trim(form.details),
    notes: trim(form.notes),
    assigned_user_id: form.assigned_user_id,
    status: form.status || 'open',
  };
}

function formatTime(t) {
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

function driverLabel(member) {
  return member.nickname || member.email || member.user_id;
}

function AddressFields({ id, title, name, setName, phone, setPhone, address, setAddress }) {
  function set(key, value) {
    setAddress({ ...address, [key]: value });
  }
  return (
    <fieldset className="address-block">
      <legend>{title}</legend>
      <div className="form-group">
        <label htmlFor={`${id}-name`}>Business name</label>
        <input id={`${id}-name`} value={name} onChange={(e) => setName(e.target.value)} />
      </div>
      <div className="form-group">
        <label htmlFor={`${id}-line1`}>Address line 1</label>
        <input id={`${id}-line1`} value={address.line1} onChange={(e) => set('line1', e.target.value)} autoComplete="address-line1" />
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
    </fieldset>
  );
}

export default function Jobs() {
  const team = useTeam();
  const [form, setForm] = useState(() => emptyForm(team.roster[0]?.user_id ?? ''));
  const [editingId, setEditingId] = useState(null);
  const [busy, setBusy] = useState(false);
  const [showDone, setShowDone] = useState(false);

  function setField(key, value) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  function startEdit(job) {
    setEditingId(job.id);
    setForm({
      job_number: job.job_number ?? '',
      job_date: job.job_date ?? isoDate(new Date()),
      job_time: job.job_time ? String(job.job_time).slice(0, 5) : '',
      pickup_name: job.pickup_name ?? '',
      pickup: addressFromJob(job, 'pickup'),
      pickup_phone: job.pickup_phone ?? '',
      dropoff_name: job.dropoff_name ?? '',
      dropoff: addressFromJob(job, 'dropoff'),
      dropoff_phone: job.dropoff_phone ?? '',
      details: job.details ?? '',
      notes: job.notes ?? '',
      assigned_user_id: job.assigned_user_id ?? '',
      status: job.status ?? 'open',
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function resetForm() {
    setEditingId(null);
    setForm(emptyForm(team.roster[0]?.user_id ?? ''));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    const body = payloadFromForm(form);
    if (!body.job_number) {
      team.setError('Job number is required.');
      return;
    }
    if (!body.assigned_user_id) {
      team.setError('Assign a driver.');
      return;
    }
    setBusy(true);
    team.setError(null);
    try {
      if (editingId) await orgApi.updateJob(editingId, body);
      else await orgApi.createJob(team.membership.orgId, body);
      resetForm();
      await team.reload();
    } catch (err) {
      const hint = /pickup_line1|dropoff_line1|schema cache/i.test(err.message)
        ? ' Run 023_org_job_addresses.sql in the Supabase SQL editor.'
        : '';
      team.setError(`${err.message}${hint}`);
    } finally {
      setBusy(false);
    }
  }

  async function handleDelete(id) {
    if (!confirm('Delete this job?')) return;
    setBusy(true);
    team.setError(null);
    try {
      await orgApi.deleteJob(id);
      if (editingId === id) resetForm();
      await team.reload();
    } catch (err) {
      team.setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  const rosterById = Object.fromEntries(team.roster.map((m) => [m.user_id, driverLabel(m)]));
  const visible = team.jobs.filter((j) => (showDone ? true : j.status === 'open'));

  return (
    <div className="mgr-page">
      <div className="page-toolbar">
        <div>
          <h1>{editingId ? 'Edit job' : 'Jobs'}</h1>
          <p className="page-sub">Assigned drivers see the stop on their phone.</p>
        </div>
      </div>

      <section className="panel">
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="job-number">Job #</label>
              <input id="job-number" value={form.job_number} onChange={(e) => setField('job_number', e.target.value)} required maxLength={40} />
            </div>
            <div className="form-group">
              <label htmlFor="job-date">Date</label>
              <input id="job-date" type="date" value={form.job_date} onChange={(e) => setField('job_date', e.target.value)} required />
            </div>
            <div className="form-group">
              <label htmlFor="job-time">Time</label>
              <input id="job-time" type="time" value={form.job_time} onChange={(e) => setField('job_time', e.target.value)} />
            </div>
          </div>
          <div className="form-row address-assign-row">
            <div className="form-group">
              <label htmlFor="job-driver">Assigned driver</label>
              <select id="job-driver" value={form.assigned_user_id} onChange={(e) => setField('assigned_user_id', e.target.value)} required>
                <option value="">Select driver</option>
                {team.roster.map((m) => (
                  <option key={m.user_id} value={m.user_id}>{driverLabel(m)}</option>
                ))}
              </select>
            </div>
            {editingId ? (
              <div className="form-group">
                <label htmlFor="job-status">Status</label>
                <select id="job-status" value={form.status} onChange={(e) => setField('status', e.target.value)}>
                  <option value="open">Open</option>
                  <option value="done">Done</option>
                  <option value="cancelled">Cancelled</option>
                </select>
              </div>
            ) : null}
          </div>

          <div className="address-grid">
            <AddressFields
              id="pickup"
              title="Pickup"
              name={form.pickup_name}
              setName={(v) => setField('pickup_name', v)}
              phone={form.pickup_phone}
              setPhone={(v) => setField('pickup_phone', v)}
              address={form.pickup}
              setAddress={(v) => setField('pickup', v)}
            />
            <AddressFields
              id="dropoff"
              title="Delivery"
              name={form.dropoff_name}
              setName={(v) => setField('dropoff_name', v)}
              phone={form.dropoff_phone}
              setPhone={(v) => setField('dropoff_phone', v)}
              address={form.dropoff}
              setAddress={(v) => setField('dropoff', v)}
            />
          </div>

          <div className="form-row" style={{ gridTemplateColumns: '1fr 1fr' }}>
            <div className="form-group">
              <label htmlFor="job-details">Details</label>
              <textarea id="job-details" rows={3} value={form.details} onChange={(e) => setField('details', e.target.value)} />
            </div>
            <div className="form-group">
              <label htmlFor="job-notes">Notes</label>
              <textarea id="job-notes" rows={3} value={form.notes} onChange={(e) => setField('notes', e.target.value)} />
            </div>
          </div>

          <div className="header-actions">
            <button type="submit" className="btn btn-primary" disabled={busy}>
              {busy ? 'Saving…' : editingId ? 'Save job' : 'Create job'}
            </button>
            {editingId ? (
              <button type="button" className="btn btn-ghost btn-sm" onClick={resetForm}>
                Cancel
              </button>
            ) : null}
          </div>
        </form>
      </section>

      <section className="panel">
        <div className="panel-head">
          <h2>Dispatched</h2>
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => setShowDone((v) => !v)}>
            {showDone ? 'Hide done' : 'Show done'}
          </button>
        </div>
        {visible.length === 0 ? (
          <p className="empty">No jobs yet.</p>
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Job</th>
                  <th>When</th>
                  <th>Driver</th>
                  <th>Pickup</th>
                  <th>Delivery</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {visible.map((job) => (
                  <tr key={job.id}>
                    <td>
                      <button type="button" className="linkish" onClick={() => startEdit(job)}>
                        {job.job_number}
                      </button>
                    </td>
                    <td>
                      {formatShortDate(job.job_date)}
                      {job.job_time ? <div className="muted-row">{formatTime(job.job_time)}</div> : null}
                    </td>
                    <td>{rosterById[job.assigned_user_id] || '—'}</td>
                    <td className="clip">{job.pickup_address || '—'}</td>
                    <td className="clip">{job.dropoff_address || '—'}</td>
                    <td>{job.status}</td>
                    <td className="num">
                      <button type="button" className="btn-danger" onClick={() => handleDelete(job.id)} disabled={busy}>
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}

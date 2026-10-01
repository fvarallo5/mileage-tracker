import { useCallback, useEffect, useState } from 'react';
import { orgApi } from '../orgApi.js';

function isoDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function emptyForm(assignedUserId = '') {
  return {
    job_number: '',
    job_date: isoDate(new Date()),
    job_time: '',
    pickup_name: '',
    pickup_address: '',
    pickup_phone: '',
    dropoff_name: '',
    dropoff_address: '',
    dropoff_phone: '',
    details: '',
    notes: '',
    assigned_user_id: assignedUserId,
    status: 'open',
  };
}

function trimOrEmpty(v) {
  return String(v ?? '').trim();
}

function payloadFromForm(form) {
  return {
    job_number: trimOrEmpty(form.job_number),
    job_date: form.job_date,
    job_time: trimOrEmpty(form.job_time) || null,
    pickup_name: trimOrEmpty(form.pickup_name),
    pickup_address: trimOrEmpty(form.pickup_address),
    pickup_phone: trimOrEmpty(form.pickup_phone),
    dropoff_name: trimOrEmpty(form.dropoff_name),
    dropoff_address: trimOrEmpty(form.dropoff_address),
    dropoff_phone: trimOrEmpty(form.dropoff_phone),
    details: trimOrEmpty(form.details),
    notes: trimOrEmpty(form.notes),
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
  const d = new Date(2020, 0, 1, h, m);
  return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
}

function formatDate(iso) {
  if (!iso) return '';
  const d = new Date(`${iso}T12:00:00`);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function mapsHref(address) {
  return `https://maps.apple.com/?q=${encodeURIComponent(address)}`;
}

function driverLabel(member) {
  return member.nickname || member.email || member.user_id;
}

function JobSummaryCard({ job, driver, onEdit }) {
  const time = formatTime(job.job_time);
  const Tag = onEdit ? 'button' : 'div';
  return (
    <Tag
      type={onEdit ? 'button' : undefined}
      className="job-card"
      onClick={onEdit}
    >
      <div className="job-card-grid">
        <div className="job-number">{job.job_number}</div>
        <div className="job-when">
          <div>{formatDate(job.job_date)}</div>
          {time ? <div className="muted">{time}</div> : null}
        </div>
        <div className="job-addr">
          {job.pickup_address ? <div>{job.pickup_address}</div> : null}
          {job.dropoff_address ? <div className="muted">{job.dropoff_address}</div> : null}
        </div>
      </div>
      {driver ? <div className="job-driver">{driver}</div> : null}
    </Tag>
  );
}

export default function Jobs({ auth }) {
  const [membership, setMembership] = useState(null);
  const [roster, setRoster] = useState([]);
  const [jobs, setJobs] = useState([]);
  const [form, setForm] = useState(emptyForm());
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [showDone, setShowDone] = useState(false);

  const load = useCallback(async () => {
    setError(null);
    try {
      const mem = await orgApi.getMembership();
      setMembership(mem);
      if (!mem) {
        setRoster([]);
        setJobs([]);
        return;
      }
      const list = await orgApi.listJobs(mem.orgId);
      setJobs(list);
      if (mem.isManager) {
        const people = await orgApi.roster(mem.orgId);
        setRoster(people);
        setForm((prev) =>
          prev.assigned_user_id
            ? prev
            : emptyForm(people[0]?.user_id ?? ''),
        );
      } else {
        setRoster([]);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

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
      pickup_address: job.pickup_address ?? '',
      pickup_phone: job.pickup_phone ?? '',
      dropoff_name: job.dropoff_name ?? '',
      dropoff_address: job.dropoff_address ?? '',
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
    setForm(emptyForm(roster[0]?.user_id ?? ''));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!membership?.isManager) return;
    const body = payloadFromForm(form);
    if (!body.job_number) {
      setError('Job number is required.');
      return;
    }
    if (!body.assigned_user_id) {
      setError('Assign a driver.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      if (editingId) {
        await orgApi.updateJob(editingId, body);
      } else {
        await orgApi.createJob(membership.orgId, body);
      }
      resetForm();
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleDelete(id) {
    if (!confirm('Delete this job?')) return;
    setBusy(true);
    setError(null);
    try {
      await orgApi.deleteJob(id);
      if (editingId === id) resetForm();
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  if (auth.isAnonymous) {
    return (
      <div className="card">
        <div className="card-title">Jobs</div>
        <p className="empty" style={{ padding: '1.5rem 0' }}>
          Create an account to dispatch jobs to drivers.
        </p>
      </div>
    );
  }

  if (loading) {
    return <div className="loading">Loading jobs…</div>;
  }

  if (!membership) {
    return (
      <div className="card">
        <div className="card-title">Jobs</div>
        <p className="empty" style={{ padding: '1.5rem 0' }}>
          Create or join a team first. Jobs are assigned to drivers from this
          dashboard.
        </p>
      </div>
    );
  }

  const visible = jobs.filter((j) => (showDone ? true : j.status === 'open'));
  const rosterById = Object.fromEntries(
    roster.map((m) => [m.user_id, driverLabel(m)]),
  );

  return (
    <div className="grid-2">
      {error && (
        <div className="error-banner" style={{ gridColumn: '1 / -1' }}>
          {error}
        </div>
      )}

      {membership.isManager && (
        <div className="card">
          <div className="card-title">{editingId ? 'Edit job' : 'New job'}</div>
          <form onSubmit={handleSubmit}>
            <div className="form-row">
              <div className="form-group">
                <label htmlFor="job-number">Job #</label>
                <input
                  id="job-number"
                  value={form.job_number}
                  onChange={(e) => setField('job_number', e.target.value)}
                  required
                  maxLength={40}
                />
              </div>
              <div className="form-group">
                <label htmlFor="job-date">Date</label>
                <input
                  id="job-date"
                  type="date"
                  value={form.job_date}
                  onChange={(e) => setField('job_date', e.target.value)}
                  required
                />
              </div>
              <div className="form-group">
                <label htmlFor="job-time">Time</label>
                <input
                  id="job-time"
                  type="time"
                  value={form.job_time}
                  onChange={(e) => setField('job_time', e.target.value)}
                />
              </div>
            </div>

            <div className="form-group">
              <label htmlFor="job-driver">Assigned driver</label>
              <select
                id="job-driver"
                value={form.assigned_user_id}
                onChange={(e) => setField('assigned_user_id', e.target.value)}
                required
              >
                <option value="">Select driver</option>
                {roster.map((m) => (
                  <option key={m.user_id} value={m.user_id}>
                    {driverLabel(m)}
                  </option>
                ))}
              </select>
            </div>

            <div className="form-row" style={{ gridTemplateColumns: '1fr 1fr' }}>
              <div>
                <div className="form-group">
                  <label htmlFor="pickup-name">Pickup bus. name</label>
                  <input
                    id="pickup-name"
                    value={form.pickup_name}
                    onChange={(e) => setField('pickup_name', e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label htmlFor="pickup-address">Pickup address</label>
                  <input
                    id="pickup-address"
                    value={form.pickup_address}
                    onChange={(e) => setField('pickup_address', e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label htmlFor="pickup-phone">Pickup phone</label>
                  <input
                    id="pickup-phone"
                    type="tel"
                    value={form.pickup_phone}
                    onChange={(e) => setField('pickup_phone', e.target.value)}
                  />
                </div>
              </div>
              <div>
                <div className="form-group">
                  <label htmlFor="dropoff-name">Delivery bus. name</label>
                  <input
                    id="dropoff-name"
                    value={form.dropoff_name}
                    onChange={(e) => setField('dropoff_name', e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label htmlFor="dropoff-address">Delivery address</label>
                  <input
                    id="dropoff-address"
                    value={form.dropoff_address}
                    onChange={(e) => setField('dropoff_address', e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label htmlFor="dropoff-phone">Delivery phone</label>
                  <input
                    id="dropoff-phone"
                    type="tel"
                    value={form.dropoff_phone}
                    onChange={(e) => setField('dropoff_phone', e.target.value)}
                  />
                </div>
              </div>
            </div>

            <div className="form-group">
              <label htmlFor="job-details">Details</label>
              <textarea
                id="job-details"
                rows={3}
                value={form.details}
                onChange={(e) => setField('details', e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="job-notes">Notes</label>
              <textarea
                id="job-notes"
                rows={2}
                value={form.notes}
                onChange={(e) => setField('notes', e.target.value)}
              />
            </div>

            {editingId ? (
              <div className="form-group">
                <label htmlFor="job-status">Status</label>
                <select
                  id="job-status"
                  value={form.status}
                  onChange={(e) => setField('status', e.target.value)}
                >
                  <option value="open">Open</option>
                  <option value="done">Done</option>
                  <option value="cancelled">Cancelled</option>
                </select>
              </div>
            ) : null}

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
        </div>
      )}

      <div className="card" style={{ gridColumn: membership.isManager ? undefined : '1 / -1' }}>
        <div className="card-title" style={{ display: 'flex', justifyContent: 'space-between', gap: '0.75rem' }}>
          <span>{membership.isManager ? 'Dispatched jobs' : 'Your jobs'}</span>
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            onClick={() => setShowDone((v) => !v)}
          >
            {showDone ? 'Hide done' : 'Show done'}
          </button>
        </div>
        {visible.length === 0 ? (
          <p className="empty" style={{ padding: '1rem 0' }}>
            {membership.isManager
              ? 'No jobs yet. Create one and assign a driver — it shows on their Track tab.'
              : 'No jobs assigned to you yet.'}
          </p>
        ) : (
          <div className="job-list">
            {visible.map((job) => (
              <div key={job.id} className="job-list-item">
                <JobSummaryCard
                  job={job}
                  driver={membership.isManager ? rosterById[job.assigned_user_id] : null}
                  onEdit={
                    membership.isManager
                      ? () => startEdit(job)
                      : undefined
                  }
                />
                <JobFullFields job={job} />
                {membership.isManager ? (
                  <button
                    type="button"
                    className="btn-danger"
                    onClick={() => handleDelete(job.id)}
                    disabled={busy}
                  >
                    Delete
                  </button>
                ) : null}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function Field({ label, children }) {
  const text = typeof children === 'string' ? children.trim() : children;
  if (!text) return null;
  return (
    <div className="job-field">
      <div className="muted">{label}</div>
      <div>{text}</div>
    </div>
  );
}

function JobFullFields({ job }) {
  return (
    <div className="job-full">
      <Field label="Pickup">{job.pickup_name}</Field>
      {job.pickup_address ? (
        <Field label="Pickup address">
          <a href={mapsHref(job.pickup_address)} target="_blank" rel="noreferrer">
            {job.pickup_address}
          </a>
        </Field>
      ) : null}
      {job.pickup_phone ? (
        <Field label="Pickup phone">
          <a href={`tel:${job.pickup_phone}`}>{job.pickup_phone}</a>
        </Field>
      ) : null}
      <Field label="Delivery">{job.dropoff_name}</Field>
      {job.dropoff_address ? (
        <Field label="Delivery address">
          <a href={mapsHref(job.dropoff_address)} target="_blank" rel="noreferrer">
            {job.dropoff_address}
          </a>
        </Field>
      ) : null}
      {job.dropoff_phone ? (
        <Field label="Delivery phone">
          <a href={`tel:${job.dropoff_phone}`}>{job.dropoff_phone}</a>
        </Field>
      ) : null}
      <Field label="Details">{job.details}</Field>
      <Field label="Notes">{job.notes}</Field>
    </div>
  );
}

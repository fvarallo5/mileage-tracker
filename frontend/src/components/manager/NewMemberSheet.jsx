import { useState } from 'react';
import { payTypeLabel } from '../../lib/company.js';
import { looksLikeEmail, looksLikePhone, toE164 } from '../../lib/phone.js';
import { defaultAccess, inviteRoles, roleLabel } from '../../lib/roles.js';
import AccessFields from './AccessFields.jsx';

const empty = {
  first_name: '',
  last_name: '',
  phone: '',
  email: '',
  driver_number: '',
  password: '',
  password2: '',
};

export default function NewMemberSheet({
  fleet,
  companyType,
  actorRole,
  defaultPayType = 'contractor',
  busy,
  onClose,
  onCreate,
}) {
  const [form, setForm] = useState(empty);
  const [role, setRole] = useState('driver');
  const [access, setAccess] = useState(() => defaultAccess('driver'));
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);
  const roles = inviteRoles(actorRole);
  const blocked = busy || saving;

  function set(key, value) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError(null);
    const email = form.email.trim().toLowerCase();
    const phoneRaw = form.phone.trim();
    if (!email && !phoneRaw) {
      setError('Enter an email or a phone number.');
      return;
    }
    if (email && !looksLikeEmail(email)) {
      setError('Enter a valid email.');
      return;
    }
    if (phoneRaw && !looksLikePhone(phoneRaw)) {
      setError('Enter a valid phone number.');
      return;
    }
    if (form.password && form.password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }
    if (form.password && form.password !== form.password2) {
      setError('Passwords do not match.');
      return;
    }
    setSaving(true);
    try {
      await onCreate({
        first_name: form.first_name.trim(),
        last_name: form.last_name.trim(),
        email: email || null,
        phone: phoneRaw ? toE164(phoneRaw) : null,
        driver_number: form.driver_number.trim() || null,
        role,
        access,
        password: form.password,
      });
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="plan-modal-wrap people-sheet-wrap">
      <button type="button" className="plan-modal-scrim" aria-label="Close new member" onClick={onClose} />
      <div className="plan-modal people-sheet member-create-sheet" role="dialog" aria-labelledby="new-member-title">
        <div className="drawer-head">
          <div>
            <h2 id="new-member-title">New member</h2>
            <p className="page-sub">Email or phone. Add a password to open the account now, or leave it blank for a join link.</p>
          </div>
          <button type="button" className="btn-ghost btn-sm" onClick={onClose}>Close</button>
        </div>
        {error ? <div className="error-banner">{error}</div> : null}
        <form id="new-member" className="stack-form member-create-form" onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="mem-first">First name</label>
              <input id="mem-first" value={form.first_name} onChange={(e) => set('first_name', e.target.value)} maxLength={40} autoComplete="given-name" />
            </div>
            <div className="form-group">
              <label htmlFor="mem-last">Last name</label>
              <input id="mem-last" value={form.last_name} onChange={(e) => set('last_name', e.target.value)} maxLength={40} autoComplete="family-name" />
            </div>
          </div>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="mem-phone">Phone</label>
              <input id="mem-phone" type="tel" value={form.phone} onChange={(e) => set('phone', e.target.value)} autoComplete="tel" placeholder="(555) 010-0100" />
            </div>
            <div className="form-group">
              <label htmlFor="mem-email">Email</label>
              <input id="mem-email" type="email" value={form.email} onChange={(e) => set('email', e.target.value)} autoComplete="email" placeholder="driver@company.com" />
            </div>
          </div>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="mem-number">Driver #</label>
              <input id="mem-number" value={form.driver_number} onChange={(e) => set('driver_number', e.target.value)} maxLength={12} />
            </div>
            <div className="form-group">
              <label htmlFor="mem-role">Role</label>
              <select
                id="mem-role"
                value={role}
                onChange={(e) => {
                  const next = e.target.value;
                  setRole(next);
                  setAccess(defaultAccess(next));
                }}
              >
                {roles.map((id) => (
                  <option key={id} value={id}>{roleLabel(id, { fleet, companyType })}</option>
                ))}
              </select>
            </div>
          </div>
          <div className="form-group">
            <span className="access-label">Access</span>
            <AccessFields role={role} access={access} onChange={setAccess} idPrefix="mem-access" />
          </div>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="mem-pass">Password</label>
              <input id="mem-pass" type="password" value={form.password} onChange={(e) => set('password', e.target.value)} minLength={6} autoComplete="new-password" />
            </div>
            <div className="form-group">
              <label htmlFor="mem-pass2">Confirm</label>
              <input id="mem-pass2" type="password" value={form.password2} onChange={(e) => set('password2', e.target.value)} minLength={6} autoComplete="new-password" />
            </div>
          </div>
          <p className="field-hint">
            Default pay is {payTypeLabel(defaultPayType)}. Change role and pay on their card after they join.
          </p>
        </form>
        <div className="drawer-actions">
          <button type="submit" form="new-member" className="btn btn-primary" disabled={blocked}>
            {blocked ? 'Working…' : form.password ? 'Create account' : 'Create join link'}
          </button>
          <button type="button" className="btn-ghost" onClick={onClose} disabled={blocked}>Cancel</button>
        </div>
      </div>
    </div>
  );
}

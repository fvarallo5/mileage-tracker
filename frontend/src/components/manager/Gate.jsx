import { useState } from 'react';
import { useTeam } from '../../context/TeamContext.jsx';
import { jobStyleForMode, orgModeLabel, payTypeForMode, normalizeOperatingMode } from '../../lib/company.js';
import ThemeToggle from './ThemeToggle.jsx';

function BrandHeader({ onSignOut, children }) {
  return (
    <div className="gate">
      <header className="mgr-brand gate-brand">
        <img src="/icon-192.png" alt="" width="40" height="40" />
        <strong>TrekTrack</strong>
        <ThemeToggle />
        <button type="button" className="btn-ghost btn-sm" onClick={onSignOut}>
          Sign out
        </button>
      </header>
      <div className="gate-card">{children}</div>
    </div>
  );
}

export function CreateTeam({ onSignOut, defaults = {} }) {
  const { createOrg, busy, error } = useTeam();
  const [name, setName] = useState('');
  const operatingMode = normalizeOperatingMode(defaults.operating_mode);
  const jobStyle = defaults.job_style || jobStyleForMode(operatingMode);
  const companyKind = defaults.company_kind || 'other';
  const defaultPayType = defaults.default_pay_type || payTypeForMode(operatingMode);

  async function handleCreate(e) {
    e.preventDefault();
    try {
      await createOrg(name.trim(), { jobStyle, companyKind, defaultPayType, operatingMode });
      setName('');
    } catch {
      /* error is on context */
    }
  }

  const styleHint = `${orgModeLabel(operatingMode)}. ${
    operatingMode === 'reimbursement'
      ? 'Employee miles, receipts, and tolls.'
      : operatingMode === 'service'
        ? 'One site per visit. Shop-to-site miles come from GPS.'
        : operatingMode === 'driving_school'
          ? 'Lessons, hours, and GPS miles.'
          : 'Pickup and delivery jobs on Today.'
  }`;

  return (
    <BrandHeader onSignOut={onSignOut}>
      <h1>Create a team</h1>
      <p className="page-sub">
        You become the owner. Workers keep the phone app. {styleHint}
      </p>
      {error ? <div className="error-banner">{error}</div> : null}
      <form onSubmit={handleCreate}>
        <div className="form-group">
          <label htmlFor="org-name">Team name</label>
          <input
            id="org-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            maxLength={80}
            required
            placeholder="Acme Heating"
          />
        </div>
        <button type="submit" className="btn btn-primary" disabled={busy || !name.trim()}>
          {busy ? 'Creating…' : 'Create team'}
        </button>
      </form>
    </BrandHeader>
  );
}

export function DriverHome({ onSignOut }) {
  const { membership, leaveOrg, busy, error } = useTeam();

  return (
    <BrandHeader onSignOut={onSignOut}>
      <h1>Your work stays in the app</h1>
      <p>
        You are on <strong>{membership?.name}</strong>. Jobs and tracking are in the TrekTrack phone app.
        This site is for dispatchers and managers.
      </p>
      {error ? <div className="error-banner">{error}</div> : null}
      <button type="button" className="btn-danger" onClick={() => leaveOrg()} disabled={busy}>
        Leave team
      </button>
    </BrandHeader>
  );
}

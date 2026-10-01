import { useState } from 'react';
import { useTeam } from '../../context/TeamContext.jsx';

function BrandHeader({ onSignOut, children }) {
  return (
    <div className="gate">
      <header className="mgr-brand gate-brand">
        <img src="/icon-192.png" alt="" width="40" height="40" />
        <strong>TrekTrack</strong>
        <button type="button" className="btn-ghost btn-sm" onClick={onSignOut}>
          Sign out
        </button>
      </header>
      <div className="gate-card">{children}</div>
    </div>
  );
}

export function CreateTeam({ onSignOut }) {
  const { createOrg, busy, error } = useTeam();
  const [name, setName] = useState('');

  async function handleCreate(e) {
    e.preventDefault();
    try {
      await createOrg(name.trim());
      setName('');
    } catch {
      /* error is on context */
    }
  }

  return (
    <BrandHeader onSignOut={onSignOut}>
      <h1>Create a team</h1>
      <p className="page-sub">
        You become the owner. Drivers keep logging in the phone app. This site is where you read the crew.
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
            placeholder="Acme Delivery"
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
      <h1>Your trips stay in the app</h1>
      <p>
        You are a driver on <strong>{membership?.name}</strong>. TrekTrack on the phone is where you log miles.
        This site is the manager dashboard.
      </p>
      {error ? <div className="error-banner">{error}</div> : null}
      <button type="button" className="btn-danger" onClick={() => leaveOrg()} disabled={busy}>
        Leave team
      </button>
    </BrandHeader>
  );
}

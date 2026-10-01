import { useState } from 'react';
import { supabase } from '../../supabase.js';
import { COMPANY_KINDS, PAY_TYPES, jobStyleForKind } from '../../lib/company.js';
import ThemeToggle from './ThemeToggle.jsx';

export default function CompanySetup({ onSignOut, onDone }) {
  const [kind, setKind] = useState('hvac');
  const [pay, setPay] = useState('hourly');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const jobStyle = jobStyleForKind(kind);
      const { error: err } = await supabase.auth.updateUser({
        data: {
          company_kind: kind,
          job_style: jobStyle,
          default_pay_type: pay,
        },
      });
      if (err) throw err;
      onDone({ companyKind: kind, jobStyle, defaultPayType: pay });
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

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
      <div className="gate-card">
        <h1>Set up your company</h1>
        <p className="page-sub">
          This picks the job card: one site for trades, pickup and delivery for couriers.
          You can change a person’s pay later.
        </p>
        {error ? <div className="error-banner">{error}</div> : null}
        <form onSubmit={handleSubmit}>
          <fieldset className="choice-set">
            <legend>What kind of company?</legend>
            <div className="choice-grid">
              {COMPANY_KINDS.map((opt) => (
                <label key={opt.id} className={`choice${kind === opt.id ? ' on' : ''}`}>
                  <input
                    type="radio"
                    name="company-kind"
                    value={opt.id}
                    checked={kind === opt.id}
                    onChange={() => setKind(opt.id)}
                  />
                  {opt.label}
                </label>
              ))}
            </div>
          </fieldset>
          <fieldset className="choice-set">
            <legend>How do field workers get paid?</legend>
            <p className="field-hint">Default for people you add. Each person can be different.</p>
            <div className="choice-grid">
              {PAY_TYPES.map((opt) => (
                <label key={opt.id} className={`choice${pay === opt.id ? ' on' : ''}`}>
                  <input
                    type="radio"
                    name="pay-type"
                    value={opt.id}
                    checked={pay === opt.id}
                    onChange={() => setPay(opt.id)}
                  />
                  {opt.label}
                </label>
              ))}
            </div>
          </fieldset>
          <button type="submit" className="btn btn-primary" disabled={busy}>
            {busy ? 'Saving…' : 'Continue'}
          </button>
        </form>
      </div>
    </div>
  );
}

import { useState } from 'react';

export default function Auth({ onSignIn, onSignUp, onGuest }) {
  const [mode, setMode] = useState('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(e) {
    e.preventDefault();
    setError(null);

    if (!email.includes('@')) {
      setError('Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }

    setBusy(true);
    try {
      if (mode === 'signup') {
        await onSignUp(email.trim(), password);
      } else {
        await onSignIn(email.trim(), password);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleGuest() {
    setError(null);
    setBusy(true);
    try {
      await onGuest();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <div className="auth-logo">🛣️</div>
        <h1>TrekTrack</h1>
        <p className="auth-subtitle">
          {mode === 'signup'
            ? 'Create an account to sync audit-ready mileage across devices.'
            : 'Audit-ready mileage. Built for the road.'}
        </p>

        <div className="auth-tabs">
          <button
            type="button"
            className={mode === 'signin' ? 'active' : ''}
            onClick={() => setMode('signin')}
          >
            Sign In
          </button>
          <button
            type="button"
            className={mode === 'signup' ? 'active' : ''}
            onClick={() => setMode('signup')}
          >
            Sign Up
          </button>
        </div>

        {error && <div className="error-banner">{error}</div>}

        <form onSubmit={handleSubmit} className="auth-form">
          <label>
            Email
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
              required
            />
          </label>
          <label>
            Password
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete={mode === 'signup' ? 'new-password' : 'current-password'}
              minLength={6}
              required
            />
          </label>
          <button type="submit" className="btn-primary" disabled={busy}>
            {busy ? 'Please wait…' : mode === 'signup' ? 'Create Account' : 'Sign In'}
          </button>
        </form>

        <button type="button" className="btn-ghost" onClick={handleGuest} disabled={busy}>
          Continue without account
        </button>

        <p className="auth-footnote">
          Guest mode keeps data on this browser only. Create an account to sync across devices.
          <br />
          <a
            href="https://cdn.jsdelivr.net/gh/fvarallo5/mileage-tracker@main/static/privacy.html"
            target="_blank"
            rel="noopener noreferrer"
          >
            Privacy Policy
          </a>
        </p>
      </div>
    </div>
  );
}
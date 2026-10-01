import { useState } from 'react';
import { inviteTokenFromUrl } from '../orgApi';

export default function Auth({
  onSignIn,
  onSignUp,
  onGuest,
  onForgotPassword,
  onUpdatePassword,
  needsPasswordUpdate = false,
  linkError = null,
}) {
  const hasInvite = Boolean(inviteTokenFromUrl());
  const [mode, setMode] = useState(
    needsPasswordUpdate ? 'update' : hasInvite ? 'signup' : 'signin',
  );
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [password2, setPassword2] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(linkError);
  const [notice, setNotice] = useState(null);

  const showUpdate = needsPasswordUpdate || mode === 'update';
  const showForgot = !showUpdate && mode === 'forgot';

  async function handleSubmit(e) {
    e.preventDefault();
    setError(null);
    setNotice(null);

    if (showUpdate) {
      if (password.length < 6) {
        setError('Password must be at least 6 characters.');
        return;
      }
      if (password !== password2) {
        setError('Passwords do not match.');
        return;
      }
      setBusy(true);
      try {
        await onUpdatePassword(password);
      } catch (err) {
        setError(err.message);
      } finally {
        setBusy(false);
      }
      return;
    }

    if (showForgot) {
      if (!email.includes('@')) {
        setError('Enter a valid email address.');
        return;
      }
      setBusy(true);
      try {
        await onForgotPassword(email.trim());
        setNotice(
          'If that email has an account, a reset link is on the way. Open it on this same computer.',
        );
      } catch (err) {
        setError(err.message);
      } finally {
        setBusy(false);
      }
      return;
    }

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

  let subtitle = 'Audit-ready mileage. Built for the road.';
  if (hasInvite && !showUpdate && !showForgot) {
    subtitle =
      'Sign in with the invited email to join the team. Use the same account as the phone app.';
  } else if (showUpdate) {
    subtitle = 'Choose a new password for TrekTrack. This also unlocks the phone app.';
  } else if (showForgot) {
    subtitle = 'We’ll email a reset link. Open it on this computer, not the phone.';
  } else if (mode === 'signup') {
    subtitle = 'Create an account to sync audit-ready mileage across devices.';
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <img className="auth-logo" src="/icon-192.png" alt="" width="64" height="64" />
        <h1>TrekTrack</h1>
        <p className="auth-subtitle">{subtitle}</p>

        {!showUpdate && !showForgot && (
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
        )}

        {error && <div className="error-banner">{error}</div>}
        {notice && <div className="notice-banner">{notice}</div>}

        <form onSubmit={handleSubmit} className="auth-form">
          {!showUpdate && (
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
          )}
          {!showForgot && (
            <label>
              {showUpdate ? 'New password' : 'Password'}
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete={showUpdate || mode === 'signup' ? 'new-password' : 'current-password'}
                minLength={6}
                required
              />
            </label>
          )}
          {showUpdate && (
            <label>
              Confirm password
              <input
                type="password"
                value={password2}
                onChange={(e) => setPassword2(e.target.value)}
                autoComplete="new-password"
                minLength={6}
                required
              />
            </label>
          )}
          <button type="submit" className="btn-primary" disabled={busy}>
            {busy
              ? 'Please wait…'
              : showUpdate
                ? 'Save new password'
                : showForgot
                  ? 'Send reset link'
                  : mode === 'signup'
                    ? 'Create Account'
                    : 'Sign In'}
          </button>
        </form>

        {mode === 'signin' && !showUpdate && !showForgot && (
          <button
            type="button"
            className="btn-ghost"
            onClick={() => {
              setError(null);
              setNotice(null);
              setMode('forgot');
            }}
            disabled={busy}
          >
            Forgot password?
          </button>
        )}

        {(showForgot || (showUpdate && !needsPasswordUpdate)) && (
          <button
            type="button"
            className="btn-ghost"
            onClick={() => {
              setError(null);
              setNotice(null);
              setMode('signin');
            }}
            disabled={busy}
          >
            Back to sign in
          </button>
        )}

        {!hasInvite && !showUpdate && !showForgot && (
          <button type="button" className="btn-ghost" onClick={handleGuest} disabled={busy}>
            Continue without account
          </button>
        )}

        <p className="auth-footnote">
          {showForgot
            ? 'Check spam if it is not in the inbox within a couple of minutes.'
            : 'Guest mode keeps data on this browser only. Create an account to sync across devices.'}
          <br />
          <a
            href="https://trektrack.pro/privacy.html"
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

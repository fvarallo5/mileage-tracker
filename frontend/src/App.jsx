import { useState } from 'react';
import { useAuth } from './auth';
import Auth from './components/Auth';
import { CreateTeam, DriverHome } from './components/manager/Gate';
import { ProfileSetup } from './components/manager/Profile';
import ThemeToggle from './components/manager/ThemeToggle';
import Shell from './components/manager/Shell';
import { TeamProvider, useTeam } from './context/TeamContext';
import { inviteTokenFromUrl } from './orgApi';
import TrackPage from './components/TrackPage';
import { trackTokenFromUrl } from './lib/tracking';

function Workspace({ onSignOut, user }) {
  const { loading, membership, ownProfile } = useTeam();
  const [setup, setSetup] = useState(null);
  const [profileOk, setProfileOk] = useState(false);

  if (loading) {
    return (
      <div className="app">
        <div className="loading">Loading…</div>
      </div>
    );
  }

  const meta = { ...(user?.user_metadata || {}), ...(setup || {}) };
  const joining = Boolean(inviteTokenFromUrl());
  const hasMode = Boolean(meta.operating_mode || meta.company_kind);

  if (!membership && !joining && !hasMode) {
    return (
      <ProfileSetup
        onSignOut={onSignOut}
        includeMode
        onDone={(answers) =>
          setSetup({
            operating_mode: answers.operatingMode,
            company_kind: answers.companyKind,
            job_style: answers.jobStyle,
            default_pay_type: answers.defaultPayType,
          })
        }
      />
    );
  }

  if (!membership) return <CreateTeam onSignOut={onSignOut} defaults={meta} />;
  if (!membership.isDesk) return <DriverHome onSignOut={onSignOut} />;
  const hasName = Boolean((ownProfile?.nickname || '').trim()) || profileOk;
  if (!hasName) {
    return <ProfileSetup onSignOut={onSignOut} onDone={() => setProfileOk(true)} />;
  }
  return <Shell onSignOut={onSignOut} />;
}

export default function App() {
  const trackToken = trackTokenFromUrl();
  if (trackToken) return <TrackPage token={trackToken} />;
  return <Desk />;
}

function Desk() {
  const auth = useAuth();

  if (auth.loading) {
    return (
      <div className="app">
        <div className="loading">Loading…</div>
      </div>
    );
  }

  if (!auth.isSignedIn || auth.needsPasswordUpdate) {
    return (
      <Auth
        onSignIn={auth.signIn}
        onSignUp={auth.signUp}
        onGuest={auth.signInAnonymously}
        onForgotPassword={auth.requestPasswordReset}
        onUpdatePassword={auth.updatePassword}
        needsPasswordUpdate={auth.needsPasswordUpdate}
        linkError={auth.linkError}
      />
    );
  }

  if (auth.isAnonymous) {
    return (
      <div className="gate">
        <header className="mgr-brand gate-brand">
          <img src="/icon-192.png" alt="" width="40" height="40" />
          <strong>TrekTrack</strong>
          <ThemeToggle />
          <button type="button" className="btn-ghost btn-sm" onClick={auth.signOut}>
            Sign out
          </button>
        </header>
        <div className="gate-card">
          <h1>Create an account</h1>
          <p>This dashboard is for team managers. Sign out of guest mode and create the account you use in the phone app.</p>
        </div>
      </div>
    );
  }

  return (
    <TeamProvider key={auth.user?.id}>
      <Workspace onSignOut={auth.signOut} user={auth.user} />
    </TeamProvider>
  );
}

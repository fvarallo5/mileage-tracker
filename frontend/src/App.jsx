import { useAuth } from './auth';
import Auth from './components/Auth';
import { CreateTeam, DriverHome } from './components/manager/Gate';
import Shell from './components/manager/Shell';
import { TeamProvider, useTeam } from './context/TeamContext';

function Workspace({ onSignOut }) {
  const { loading, membership } = useTeam();

  if (loading) {
    return (
      <div className="app">
        <div className="loading">Loading…</div>
      </div>
    );
  }

  if (!membership) return <CreateTeam onSignOut={onSignOut} />;
  if (!membership.isManager) return <DriverHome onSignOut={onSignOut} />;
  return <Shell onSignOut={onSignOut} />;
}

export default function App() {
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
      <Workspace onSignOut={auth.signOut} />
    </TeamProvider>
  );
}

import { useCallback, useEffect, useState } from 'react';
import { api } from './api';
import { useAuth } from './auth';
import Auth from './components/Auth';
import ImportTrips from './components/ImportTrips';
import TripForm from './components/TripForm';
import TripList from './components/TripList';
import Reports from './components/Reports';
import ReportStats from './components/ReportStats';

const fmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

function MainApp({ auth, onSignOut }) {
  const [tab, setTab] = useState('trips');
  const [trips, setTrips] = useState([]);
  const [summary, setSummary] = useState(null);
  const [mileageRate, setMileageRate] = useState('0.725');
  const [editing, setEditing] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const loadData = useCallback(async () => {
    setError(null);
    try {
      await api.init();
      const [tripsData, summaryData, settings] = await Promise.all([
        api.getTrips({ limit: 50 }),
        api.getReportSummary(),
        api.getSettings(),
      ]);
      setTrips(tripsData);
      setSummary(summaryData);
      setMileageRate(String(settings.mileage_rate ?? '0.725'));
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  async function handleCreateTrip(data) {
    if (editing) {
      await api.updateTrip(editing.id, data);
      setEditing(null);
    } else {
      await api.createTrip(data);
    }
    await loadData();
  }

  async function handleDelete(id) {
    if (!confirm('Delete this trip?')) return;
    await api.deleteTrip(id);
    await loadData();
  }

  async function handleTogglePurpose(trip) {
    await api.updateTrip(trip.id, {
      date: trip.date,
      miles: trip.miles,
      tips: trip.tips,
      notes: trip.notes,
      is_business: trip.is_business === false,
    });
    await loadData();
  }

  if (loading) {
    return (
      <div className="app">
        <div className="loading">Loading…</div>
      </div>
    );
  }

  return (
    <div className="app">
      <header className="header">
        <div>
          <h1>TrekTrack</h1>
          <p>
            {auth.isAnonymous
              ? 'Guest mode — create an account to sync'
              : `Signed in as ${auth.userEmail}`}
          </p>
        </div>
        <div className="header-actions">
          <button type="button" className="btn-ghost btn-sm" onClick={onSignOut}>
            Sign out
          </button>
          <div className="rate-badge" title="IRS standard business mileage rate (auto)">
            <span>IRS rate</span>
            <strong>${Number(mileageRate).toFixed(3).replace(/0$/, '')}/mi</strong>
          </div>
        </div>
      </header>

      {error && <div className="error-banner">{error}</div>}

      {summary && (
        <div className="stats-grid" style={{ marginBottom: '2rem' }}>
          <div className="stat-card">
            <div className="label">This Week</div>
            <div className="value accent">{summary.weekly.total_miles.toFixed(1)} mi</div>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
              {fmt.format(summary.weekly.earnings_per_mile)}/mi
            </div>
          </div>
          <div className="stat-card">
            <div className="label">This Month</div>
            <div className="value green">{fmt.format(summary.monthly.total_tips)}</div>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
              {fmt.format(summary.monthly.mileage_expense)} expense
            </div>
          </div>
          <div className="stat-card">
            <div className="label">Year to Date</div>
            <div className="value amber">{summary.annual.total_miles.toFixed(1)} mi</div>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
              {fmt.format(summary.annual.mileage_expense)} expense
            </div>
          </div>
        </div>
      )}

      <nav className="tabs">
        <button className={`tab ${tab === 'trips' ? 'active' : ''}`} onClick={() => setTab('trips')}>
          Log Trips
        </button>
        <button className={`tab ${tab === 'reports' ? 'active' : ''}`} onClick={() => setTab('reports')}>
          Reports
        </button>
      </nav>

      {tab === 'trips' && (
        <div className="grid-2">
          <div className="card" style={{ gridColumn: '1 / -1' }}>
            <ImportTrips onImported={loadData} />
          </div>
          <div className="card">
            <div className="card-title">{editing ? 'Edit Trip' : 'New Trip'}</div>
            <TripForm
              key={editing?.id ?? 'new'}
              editing={editing}
              onSubmit={handleCreateTrip}
              onCancel={() => setEditing(null)}
            />
          </div>
          <div className="card">
            <div className="card-title">Quick Stats (This Week)</div>
            {summary && <ReportStats report={summary.weekly} />}
          </div>
          <div className="card" style={{ gridColumn: '1 / -1' }}>
            <div className="card-title">Recent Trips</div>
            <TripList
              trips={trips}
              onEdit={(trip) => {
                setEditing(trip);
                window.scrollTo({ top: 0, behavior: 'smooth' });
              }}
              onDelete={handleDelete}
              onTogglePurpose={handleTogglePurpose}
            />
          </div>
        </div>
      )}

      {tab === 'reports' && <Reports />}

      <footer className="app-footer">
        <a
          href="https://cdn.jsdelivr.net/gh/fvarallo5/mileage-tracker@main/static/privacy.html"
          target="_blank"
          rel="noopener noreferrer"
        >
          Privacy Policy
        </a>
        <span aria-hidden="true">·</span>
        <a href="mailto:support@trektrack.app">support@trektrack.app</a>
      </footer>
    </div>
  );
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

  if (!auth.isSignedIn) {
    return (
      <Auth
        onSignIn={auth.signIn}
        onSignUp={auth.signUp}
        onGuest={auth.signInAnonymously}
      />
    );
  }

  return (
    <MainApp
      key={auth.user?.id}
      auth={auth}
      onSignOut={auth.signOut}
    />
  );
}
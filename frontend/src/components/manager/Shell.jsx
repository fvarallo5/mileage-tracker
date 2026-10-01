import { useState } from 'react';
import { useTeam } from '../../context/TeamContext.jsx';
import Jobs from '../Jobs.jsx';
import Overview from './Overview.jsx';
import People from './People.jsx';
import DriverTable from './DriverTable.jsx';

const NAV = [
  ['overview', 'Overview'],
  ['drivers', 'Drivers'],
  ['jobs', 'Jobs'],
  ['people', 'People'],
];

export default function Shell({ onSignOut }) {
  const { membership, error, notice, drivers, range } = useTeam();
  const [page, setPage] = useState('overview');

  return (
    <div className="mgr">
      <aside className="mgr-side">
        <div className="mgr-brand">
          <img src="/icon-192.png" alt="" width="36" height="36" />
          <div>
            <strong>TrekTrack</strong>
            <div className="muted-row">{membership?.name}</div>
          </div>
        </div>
        <nav className="mgr-nav">
          {NAV.map(([id, label]) => (
            <button
              key={id}
              type="button"
              className={page === id ? 'active' : ''}
              onClick={() => setPage(id)}
            >
              {label}
            </button>
          ))}
        </nav>
        <div className="mgr-side-foot">
          <button type="button" className="btn-ghost btn-sm" onClick={onSignOut}>
            Sign out
          </button>
        </div>
      </aside>
      <main className="mgr-main">
        {error ? <div className="error-banner">{error}</div> : null}
        {notice ? <div className="notice-banner">{notice}</div> : null}
        {page === 'overview' && <Overview />}
        {page === 'drivers' && (
          <div className="mgr-page">
            <div className="page-toolbar">
              <div>
                <h1>Drivers</h1>
                <p className="page-sub">{range.label}. Same period as Overview.</p>
              </div>
            </div>
            <DriverTable drivers={drivers} rangeLabel={range.label} heading="" />
          </div>
        )}
        {page === 'jobs' && <Jobs />}
        {page === 'people' && <People />}
      </main>
    </div>
  );
}

import { useEffect, useMemo, useRef, useState } from 'react';
import { DeskNav } from '../../context/DeskNav.jsx';
import { useTeam } from '../../context/TeamContext.jsx';
import { layoutFor } from '../../lib/layout.js';
import { pageNav, roleLabel } from '../../lib/roles.js';
import Jobs from '../Jobs.jsx';
import Books from './Books.jsx';
import DeskOverview from './DeskOverview.jsx';
import DriversPage from './DriversPage.jsx';
import ExpensesPage from './ExpensesPage.jsx';
import Overview from './Overview.jsx';
import People from './People.jsx';
import Plan from './Plan.jsx';
import Profile from './Profile.jsx';
import ReimbursementHome from './ReimbursementHome.jsx';
import ThemeToggle from './ThemeToggle.jsx';
import TripsPage from './TripsPage.jsx';
import { initials } from './deskKit.js';
import { ICO, NAV_ICONS } from './icons.jsx';

const PAGE_KEY = 'trektrack-page';
const RAIL_KEY = 'trektrack-rail';

function readSavedPage(nav, fallback) {
  try {
    const saved = sessionStorage.getItem(PAGE_KEY);
    if (saved && nav.some(([id]) => id === saved)) return saved;
  } catch {
    /* private mode */
  }
  if (nav.some(([id]) => id === fallback)) return fallback;
  return nav[0]?.[0];
}

function readCollapsed() {
  try {
    return localStorage.getItem(RAIL_KEY) === '1';
  } catch {
    return false;
  }
}

export default function Shell({ onSignOut }) {
  const { membership, error, notice, ownProfile, kpis, drivers, jobs } = useTeam();
  const layout = layoutFor({ companyType: membership?.operatingMode, onTeam: true, role: membership?.role });
  const nav = pageNav(layout.deskNav, membership);
  const fallback = layout.deskFallback;
  const [page, setPageState] = useState(() => readSavedPage(nav, fallback));
  const [collapsed, setCollapsed] = useState(readCollapsed);
  const [header, setHeader] = useState(null);
  const [rail, setRail] = useState(null);
  const [mini, setMini] = useState(null);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const [paletteQ, setPaletteQ] = useState('');
  const paletteRef = useRef(null);

  function setPage(id) {
    setPageState(id);
    try {
      sessionStorage.setItem(PAGE_KEY, id);
    } catch {
      /* private mode */
    }
  }

  function toggleRail() {
    setCollapsed((on) => {
      const next = !on;
      try {
        localStorage.setItem(RAIL_KEY, next ? '1' : '0');
      } catch {
        /* private mode */
      }
      return next;
    });
  }

  useEffect(() => {
    function onKey(e) {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setPaletteOpen(true);
        setPaletteQ('');
        return;
      }
      if (e.key !== '[' || e.metaKey || e.ctrlKey || e.altKey) return;
      const el = e.target;
      if (el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT' || el.isContentEditable)) return;
      e.preventDefault();
      toggleRail();
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  useEffect(() => {
    if (paletteOpen) paletteRef.current?.focus();
  }, [paletteOpen]);

  const current = nav.some(([id]) => id === page) ? page : nav[0]?.[0];
  const orgName = membership?.name || 'TrekTrack';
  const person = (ownProfile?.nickname || '').trim() || 'You';
  const role = roleLabel(membership?.role, { companyType: membership?.operatingMode });
  const labels = Object.fromEntries(nav);
  const hits = useMemo(() => {
    const q = paletteQ.trim().toLowerCase();
    return nav.filter(([, label]) => !q || label.toLowerCase().includes(q));
  }, [nav, paletteQ]);

  const badges = {
    drivers: drivers.length || null,
    home: drivers.length || null,
    jobs: jobs.length || null,
    trips: kpis.unclassified || null,
  };

  return (
    <DeskNav.Provider value={{ page: current, setPage, setHeader, setRail, setMini }}>
    <div className={`mgr${collapsed ? ' is-collapsed' : ''}`}>
      <aside className="mgr-rail" aria-label="Primary">
        <div className="mgr-brand">
          <img src="/icon-192.png" alt="" width="34" height="34" />
          <div>
            <strong>TrekTrack</strong>
            <small>Audit-ready mileage</small>
          </div>
          <button type="button" className="mgr-collapse" onClick={toggleRail} title="Collapse rail ([)">
            {ICO.collapse}
          </button>
        </div>

        <div className="mgr-org metal">
          <span className="av fill-blue">{initials(orgName)}</span>
          <div>
            <strong>{orgName}</strong>
            <span>Team · {drivers.length} {drivers.length === 1 ? 'driver' : 'drivers'}</span>
          </div>
        </div>

        <button type="button" className="mgr-cmdk well" onClick={() => { setPaletteOpen(true); setPaletteQ(''); }}>
          {ICO.search}
          <span>Search or jump to…</span>
          <kbd>⌘K</kbd>
        </button>

        <div className="mgr-section">Workspace</div>
        <nav className="mgr-nav">
          {nav.map(([id, label]) => {
            const alert = id === 'trips' && badges.trips;
            const soft = badges[id] && id !== 'trips' ? badges[id] : null;
            return (
              <button
                key={id}
                type="button"
                className={current === id ? 'active' : ''}
                onClick={() => setPage(id)}
                title={label}
                aria-current={current === id ? 'page' : undefined}
              >
                {NAV_ICONS[id] || NAV_ICONS.jobs}
                <span>{label}</span>
                {alert ? <em className="badge alert">{alert}</em> : null}
                {soft ? <em className="badge soft">{soft}</em> : null}
                {alert ? <i className="dot-badge show" /> : null}
              </button>
            );
          })}
        </nav>

        {rail || mini ? <div className="mgr-section hide-c">Controls</div> : null}
        {rail}
        {mini}

        <div className="mgr-rail-foot">
          <ThemeToggle />
          <div className="mgr-me metal">
            <span className="avatar">{initials(person)}</span>
            <div>
              <b>{person}</b>
              <span>{role}</span>
            </div>
            <button type="button" className="mgr-signout" onClick={onSignOut} title="Sign out">
              {ICO.signout}
            </button>
          </div>
        </div>
      </aside>
      <main className="mgr-main">
        {error ? <div className="error-banner">{error}</div> : null}
        {notice ? <div className="notice-banner">{notice}</div> : null}
        {header ? (
          <header className="mgr-topbar">
            <div>
              <div className="mgr-crumb">{header.crumb || `${orgName} › ${labels[current] || ''}`}</div>
              <h1>{header.title}</h1>
              {header.sub ? <div className="mgr-sub">{header.sub}</div> : null}
            </div>
            {header.right ? <div className="right">{header.right}</div> : null}
          </header>
        ) : null}
        {current === 'overview' && <DeskOverview />}
        {current === 'drivers' && <DriversPage />}
        {current === 'jobs' && <Jobs />}
        {current === 'plan' && <Plan />}
        {current === 'trips' && <TripsPage />}
        {current === 'expenses' && <ExpensesPage />}
        {current === 'home' && <ReimbursementHome />}
        {current === 'review' && <Overview />}
        {current === 'books' && <Books />}
        {current === 'people' && <People />}
        {current === 'profile' && <Profile />}
      </main>
    </div>
    {paletteOpen ? (
      <dialog className="palette-pop metal" open onClose={() => setPaletteOpen(false)}>
        <div className="search well" style={{ width: 'auto', marginBottom: 8 }}>
          {ICO.search}
          <input
            ref={paletteRef}
            value={paletteQ}
            onChange={(e) => setPaletteQ(e.target.value)}
            placeholder="Jump to a page…"
            aria-label="Jump to a page"
            style={{ flex: 1, border: 0, background: 'transparent', color: 'inherit', font: 'inherit', outline: 'none' }}
            onKeyDown={(e) => {
              if (e.key === 'Escape') setPaletteOpen(false);
              if (e.key === 'Enter' && hits[0]) {
                setPage(hits[0][0]);
                setPaletteOpen(false);
              }
            }}
          />
        </div>
        <div className="palette-list">
          {hits.map(([id, label]) => (
            <button
              key={id}
              type="button"
              className={id === current ? 'active' : ''}
              onClick={() => { setPage(id); setPaletteOpen(false); }}
            >
              {NAV_ICONS[id] || NAV_ICONS.jobs}
              {label}
            </button>
          ))}
        </div>
        <form method="dialog" style={{ display: 'none' }}><button type="submit">close</button></form>
        <button type="button" className="btn fill-steel btn-xs" style={{ marginTop: 8 }} onClick={() => setPaletteOpen(false)}>Close</button>
      </dialog>
    ) : null}
    </DeskNav.Provider>
  );
}

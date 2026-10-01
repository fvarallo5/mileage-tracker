import { useCallback, useEffect, useMemo, useState } from 'react';
import { inviteLink, orgApi } from '../orgApi.js';

const milesFmt = new Intl.NumberFormat('en-US', { maximumFractionDigits: 1 });
const moneyFmt = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
});

function isoDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function periodRange(key) {
  const now = new Date();
  const end = isoDate(now);
  if (key === 'week') {
    const start = new Date(now);
    const weekday = (now.getDay() + 6) % 7;
    start.setDate(now.getDate() - weekday);
    return { start: isoDate(start), end, label: 'This week' };
  }
  if (key === 'year') {
    return { start: `${now.getFullYear()}-01-01`, end, label: 'This year' };
  }
  return {
    start: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`,
    end,
    label: 'This month',
  };
}

function csvEscape(value) {
  const s = String(value ?? '');
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

function downloadCsv(name, rows) {
  const body = rows.map((row) => row.map(csvEscape).join(',')).join('\n');
  const blob = new Blob([`\uFEFF${body}`], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  a.click();
  URL.revokeObjectURL(url);
}

function roleLabel(role) {
  if (role === 'owner') return 'Owner';
  if (role === 'admin') return 'Admin';
  return 'Driver';
}

function costBucket(category) {
  if (category === 'tolls') return 'tolls';
  if (category === 'parking') return 'parking';
  if (category === 'fuel') return 'gas';
  return 'misc';
}

function costLabel(category) {
  switch (category) {
    case 'fuel':
      return 'Gas';
    case 'parking':
      return 'Parking';
    case 'tolls':
      return 'Tolls';
    case 'meals':
      return 'Client meals';
    case 'supplies':
      return 'Supplies';
    case 'maintenance':
      return 'Maintenance';
    case 'car_wash':
      return 'Car wash';
    case 'phone':
      return 'Phone / data';
    case 'uniforms':
      return 'Uniforms';
    case 'office':
      return 'Office';
    case 'software':
      return 'Software';
    case 'insurance':
      return 'Insurance';
    default:
      return 'Other';
  }
}

export default function Team({ auth }) {
  const [membership, setMembership] = useState(null);
  const [roster, setRoster] = useState([]);
  const [unclassified, setUnclassified] = useState([]);
  const [invites, setInvites] = useState([]);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('driver');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [copied, setCopied] = useState(null);
  const [period, setPeriod] = useState('month');
  const [driverId, setDriverId] = useState(null);
  const [periodTrips, setPeriodTrips] = useState([]);
  const [periodExpenses, setPeriodExpenses] = useState([]);
  const range = useMemo(() => periodRange(period), [period]);

  const load = useCallback(async () => {
    setError(null);
    try {
      const mem = await orgApi.getMembership();
      setMembership(mem);
      if (mem?.isManager) {
        const [rows, trips, pending, allTrips, costs] = await Promise.all([
          orgApi.rosterForPeriod(mem.orgId, range.start, range.end),
          orgApi.unclassified(mem.orgId),
          orgApi.pendingInvites(mem.orgId),
          orgApi.periodTrips(mem.orgId, range.start, range.end),
          orgApi.periodExpenses(mem.orgId, range.start, range.end),
        ]);
        setRoster(rows);
        setUnclassified(trips);
        setInvites(pending);
        setPeriodTrips(allTrips);
        setPeriodExpenses(costs);
      } else {
        setRoster([]);
        setUnclassified([]);
        setInvites([]);
        setPeriodTrips([]);
        setPeriodExpenses([]);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [range.start, range.end]);

  useEffect(() => {
    load();
  }, [load]);

  const totals = useMemo(() => {
    const drivers = roster.length;
    const unclassifiedCount = roster.reduce(
      (sum, row) =>
        sum + Number(row.unclassified_this_period ?? row.unclassified_this_month ?? 0),
      0,
    );
    const businessMiles = roster.reduce(
      (sum, row) =>
        sum + Number(row.business_miles_this_period ?? row.business_miles_this_month ?? 0),
      0,
    );
    return { drivers, unclassifiedCount, businessMiles };
  }, [roster]);

  const costTotals = useMemo(() => {
    const buckets = { tolls: 0, parking: 0, gas: 0, misc: 0 };
    for (const row of periodExpenses) {
      buckets[costBucket(row.category)] += Number(row.amount ?? 0);
    }
    return buckets;
  }, [periodExpenses]);

  async function handleCreate(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await orgApi.createOrg(name);
      setName('');
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleInvite(e) {
    e.preventDefault();
    if (!membership?.orgId) return;
    setBusy(true);
    setError(null);
    setCopied(null);
    try {
      const token = await orgApi.invite(membership.orgId, email, role);
      setEmail('');
      await load();
      const link = inviteLink(token);
      try {
        await navigator.clipboard.writeText(link);
        setCopied(link);
      } catch {
        setCopied(link);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleRevoke(id) {
    if (!confirm('Revoke this invite?')) return;
    setBusy(true);
    setError(null);
    try {
      await orgApi.revokeInvite(id);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleRemove(userId, label) {
    if (!confirm(`Remove ${label} from the team?`)) return;
    setBusy(true);
    setError(null);
    try {
      await orgApi.removeMember(membership.orgId, userId);
      if (driverId === userId) setDriverId(null);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleLeave() {
    if (!confirm('Leave this team?')) return;
    setBusy(true);
    setError(null);
    try {
      await orgApi.leaveOrg();
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  function handleExport() {
    const safe = range.label.replace(/\s+/g, '_');
    const mileage = [
      ['Date', 'Driver', 'Class', 'Miles', 'Earnings (USD)', 'Notes'],
      ...periodTrips.map((trip) => [
        trip.trip_date,
        trip.nickname || trip.email,
        trip.is_business === true
          ? 'Business'
          : trip.is_business === false
            ? 'Personal'
            : 'Unclassified',
        Number(trip.miles).toFixed(2),
        Number(trip.tips ?? 0).toFixed(2),
        trip.notes || '',
      ]),
    ];
    const costs = [
      ['Date', 'Driver', 'Category', 'Merchant', 'Amount (USD)', 'Receipt', 'Notes'],
      ...periodExpenses.map((row) => [
        row.expense_date,
        row.nickname || row.email,
        costLabel(row.category),
        row.merchant || '',
        Number(row.amount ?? 0).toFixed(2),
        row.has_receipt ? 'Yes' : '',
        row.notes || '',
      ]),
      [
        'Total',
        '',
        '',
        '',
        (
          costTotals.tolls +
          costTotals.parking +
          costTotals.gas +
          costTotals.misc
        ).toFixed(2),
        '',
        '',
      ],
    ];
    downloadCsv(`TrekTrack_Team_Mileage_${safe}.csv`, mileage);
    downloadCsv(`TrekTrack_Team_FieldCosts_${safe}.csv`, costs);
  }

  if (auth.isAnonymous) {
    return (
      <div className="card">
        <div className="card-title">Team</div>
        <p className="empty" style={{ padding: '1.5rem 0' }}>
          Create an account to start a team. Drivers keep logging on the phone; this
          dashboard is for the roster and unclassified trips.
        </p>
      </div>
    );
  }

  if (loading) {
    return <div className="loading">Loading team…</div>;
  }

  if (!membership) {
    return (
      <div className="card team-create">
        <div className="card-title">Create a team</div>
        {error && <div className="error-banner">{error}</div>}
        <p className="field-hint" style={{ marginBottom: '1rem' }}>
          You become the owner. Invite drivers by email — they sign in here (same
          account as the app) and join. Phone stays the logger.
        </p>
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
      </div>
    );
  }

  if (!membership.isManager) {
    return (
      <div className="card">
        <div className="card-title">Your team</div>
        {error && <div className="error-banner">{error}</div>}
        <p>
          You&apos;re a {roleLabel(membership.role).toLowerCase()} on{' '}
          <strong>{membership.name}</strong>. Keep logging on the phone. Your manager
          can see roster miles and unclassified trips — they cannot edit your trips.
        </p>
        <button type="button" className="btn-danger" onClick={handleLeave} disabled={busy}>
          Leave team
        </button>
      </div>
    );
  }

  return (
    <div className="team-dashboard">
      {error && <div className="error-banner">{error}</div>}

      <div className="report-period-tabs" style={{ marginBottom: '1rem' }}>
        {[
          ['week', 'This week'],
          ['month', 'This month'],
          ['year', 'This year'],
        ].map(([key, label]) => (
          <button
            key={key}
            type="button"
            className={`period-btn ${period === key ? 'active' : ''}`}
            onClick={() => setPeriod(key)}
          >
            {label}
          </button>
        ))}
        <button type="button" className="btn btn-secondary btn-sm" onClick={handleExport} disabled={busy}>
          Export CSV
        </button>
        <button type="button" className="btn-danger" onClick={handleLeave} disabled={busy}>
          Leave team
        </button>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="label">Team</div>
          <div className="value">{membership.name}</div>
        </div>
        <div className="stat-card">
          <div className="label">Drivers</div>
          <div className="value accent">{totals.drivers}</div>
        </div>
        <div className="stat-card">
          <div className="label">Business miles ({range.label.toLowerCase()})</div>
          <div className="value green">{milesFmt.format(totals.businessMiles)}</div>
        </div>
        <div className="stat-card">
          <div className="label">Unclassified (month)</div>
          <div className={`value ${totals.unclassifiedCount ? 'amber' : ''}`}>
            {totals.unclassifiedCount}
          </div>
        </div>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="label">Tolls</div>
          <div className="value">{moneyFmt.format(costTotals.tolls)}</div>
        </div>
        <div className="stat-card">
          <div className="label">Parking</div>
          <div className="value">{moneyFmt.format(costTotals.parking)}</div>
        </div>
        <div className="stat-card">
          <div className="label">Gas</div>
          <div className="value">{moneyFmt.format(costTotals.gas)}</div>
        </div>
        <div className="stat-card">
          <div className="label">Misc</div>
          <div className="value">{moneyFmt.format(costTotals.misc)}</div>
        </div>
      </div>

      <div className="grid-2">
        <div className="card">
          <div className="card-title">Invite a driver</div>
          <form onSubmit={handleInvite}>
            <div className="form-group">
              <label htmlFor="invite-email">Email</label>
              <input
                id="invite-email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                placeholder="driver@company.com"
              />
            </div>
            <div className="form-group">
              <label htmlFor="invite-role">Role</label>
              <select
                id="invite-role"
                value={role}
                onChange={(e) => setRole(e.target.value)}
              >
                <option value="driver">Driver</option>
                <option value="admin">Admin</option>
              </select>
            </div>
            <button type="submit" className="btn btn-primary" disabled={busy}>
              {busy ? 'Inviting…' : 'Create invite link'}
            </button>
          </form>
          {copied && (
            <p className="invite-copied">
              Invite link copied. Send it to the driver — they sign in with that
              email and join automatically.
              <br />
              <code>{copied}</code>
            </p>
          )}
          <p className="field-hint">
            No email blast yet. Copy the link. Same TrekTrack account as the phone.
          </p>
        </div>

        <div className="card">
          <div className="card-title">Pending invites</div>
          {invites.length === 0 ? (
            <p className="empty" style={{ padding: '1rem 0' }}>None waiting.</p>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Email</th>
                    <th>Role</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {invites.map((inv) => (
                    <tr key={inv.id}>
                      <td>{inv.email}</td>
                      <td>{roleLabel(inv.role)}</td>
                      <td>
                        <button
                          type="button"
                          className="btn-danger"
                          onClick={() => handleRevoke(inv.id)}
                          disabled={busy}
                        >
                          Revoke
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      <div className="card">
        <div className="card-title">Roster · {range.label}</div>
        {roster.length === 0 ? (
          <p className="empty">No members yet.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Driver</th>
                  <th>Role</th>
                  <th>Last trip</th>
                  <th>Trips</th>
                  <th>Unclassified</th>
                  <th>Business mi</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {roster.map((row) => (
                  <tr key={row.user_id}>
                    <td>
                      <button
                        type="button"
                        className="btn-ghost"
                        onClick={() => setDriverId(row.user_id)}
                      >
                        {row.nickname || row.email}
                      </button>
                      {row.nickname ? (
                        <div className="muted-row">{row.email}</div>
                      ) : null}
                    </td>
                    <td>{roleLabel(row.role)}</td>
                    <td>{row.last_trip_date ?? '—'}</td>
                    <td>{row.trips_this_period ?? row.trips_this_month}</td>
                    <td className={(row.unclassified_this_period ?? row.unclassified_this_month) ? 'warn-cell' : ''}>
                      {row.unclassified_this_period ?? row.unclassified_this_month}
                    </td>
                    <td>{milesFmt.format(Number(row.business_miles_this_period ?? row.business_miles_this_month ?? 0))}</td>
                    <td>
                      {row.role !== 'owner' ? (
                        <button
                          type="button"
                          className="btn-danger"
                          onClick={() => handleRemove(row.user_id, row.nickname || row.email)}
                          disabled={busy}
                        >
                          Remove
                        </button>
                      ) : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="card">
        <div className="card-title">Unclassified trips this month</div>
        {unclassified.length === 0 ? (
          <p className="empty">All trips classified. Drivers swipe Business / Personal on the phone.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Driver</th>
                  <th>Miles</th>
                  <th>Notes</th>
                </tr>
              </thead>
              <tbody>
                {unclassified.map((trip) => (
                  <tr key={trip.trip_id}>
                    <td>{trip.trip_date}</td>
                    <td>{trip.nickname || trip.email}</td>
                    <td>{milesFmt.format(Number(trip.miles))}</td>
                    <td>{trip.notes || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="card">
        <div className="card-title">Field costs · {range.label}</div>
        {periodExpenses.length === 0 ? (
          <p className="empty">No parking, tolls, gas, or misc costs in this period.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Driver</th>
                  <th>Category</th>
                  <th>Merchant</th>
                  <th>Amount</th>
                  <th>Receipt</th>
                  <th>Notes</th>
                </tr>
              </thead>
              <tbody>
                {periodExpenses.map((row) => (
                  <tr key={row.expense_id}>
                    <td>{row.expense_date}</td>
                    <td>{row.nickname || row.email}</td>
                    <td>{costLabel(row.category)}</td>
                    <td>{row.merchant || '—'}</td>
                    <td>{moneyFmt.format(Number(row.amount ?? 0))}</td>
                    <td>{row.has_receipt ? 'Yes' : ''}</td>
                    <td>{row.notes || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {driverId ? (
        <div className="card">
          <div className="card-title">
            Driver trips · {range.label}
            <button type="button" className="btn-ghost btn-sm" onClick={() => setDriverId(null)}>
              Close
            </button>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Class</th>
                  <th>Miles</th>
                  <th>Earnings</th>
                  <th>Notes</th>
                </tr>
              </thead>
              <tbody>
                {periodTrips
                  .filter((t) => t.user_id === driverId)
                  .map((trip) => (
                    <tr key={trip.trip_id}>
                      <td>{trip.trip_date}</td>
                      <td>
                        {trip.is_business === true
                          ? 'Business'
                          : trip.is_business === false
                            ? 'Personal'
                            : 'Unclassified'}
                      </td>
                      <td>{milesFmt.format(Number(trip.miles))}</td>
                      <td>{moneyFmt.format(Number(trip.tips ?? 0))}</td>
                      <td>{trip.notes || '—'}</td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
          <div className="card-title" style={{ marginTop: '1.25rem' }}>
            Field costs
          </div>
          {periodExpenses.filter((e) => e.user_id === driverId).length === 0 ? (
            <p className="empty" style={{ padding: '1rem 0' }}>No field costs for this driver.</p>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Category</th>
                    <th>Merchant</th>
                    <th>Amount</th>
                    <th>Notes</th>
                  </tr>
                </thead>
                <tbody>
                  {periodExpenses
                    .filter((e) => e.user_id === driverId)
                    .map((row) => (
                      <tr key={row.expense_id}>
                        <td>{row.expense_date}</td>
                        <td>{costLabel(row.category)}</td>
                        <td>{row.merchant || '—'}</td>
                        <td>{moneyFmt.format(Number(row.amount ?? 0))}</td>
                        <td>{row.notes || '—'}</td>
                      </tr>
                    ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      ) : null}
    </div>
  );
}

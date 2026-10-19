import { useMemo, useState } from 'react';
import { useDeskChrome, useDeskNav } from '../../context/DeskNav.jsx';
import { useTeam } from '../../context/TeamContext.jsx';
import { formatRangeMdY, isoDate } from '../../lib/period.js';
import { api } from '../../api.js';
import { downloadCsv, formatShortDate, milesFmt, moneyFmt } from './format.js';
import { ICO } from './icons.jsx';
import PeriodRail, { PeriodMini } from './PeriodRail.jsx';
import { Avatar, EmptyHint, SearchWell } from './DeskWidgets.jsx';
import { driverPresence, tripDate } from './deskKit.js';
import DriverRoster from './DriverRoster.jsx';

export default function DriversPage() {
  const team = useTeam();
  const desk = useDeskNav();
  const { drivers, jobs, period, setPeriod, range, mileageRate, membership } = team;
  const org = membership?.name || 'TrekTrack';
  const today = isoDate(new Date());
  const [query, setQuery] = useState('');
  const [chip, setChip] = useState('all');
  const [selectedId, setSelectedId] = useState(drivers[0]?.user_id || null);

  const counts = useMemo(() => {
    const rows = { all: drivers.length, on: 0, idle: 0, off: 0, unclassified: 0 };
    for (const d of drivers) {
      rows[driverPresence(d, jobs, today).id] += 1;
      if (d.unclassified) rows.unclassified += 1;
    }
    return rows;
  }, [drivers, jobs, today]);

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    return drivers.filter((d) => {
      if (chip === 'on' || chip === 'idle' || chip === 'off') {
        if (driverPresence(d, jobs, today).id !== chip) return false;
      }
      if (chip === 'unclassified' && !d.unclassified) return false;
      if (q && !`${d.label} ${d.email || ''} ${d.phone || ''}`.toLowerCase().includes(q)) return false;
      return true;
    });
  }, [drivers, jobs, today, chip, query]);

  const selected = visible.find((d) => d.user_id === selectedId) || visible[0] || null;

  function exportCsv() {
    downloadCsv(`TrekTrack_Drivers_${range.start}_${range.end}.csv`, [
      ['Driver', 'Email', 'Business mi', 'Deduction', 'Trips', 'Unclassified', 'Field costs', 'Open jobs', 'Last trip'],
      ...visible.map((d) => [
        d.label, d.email || '', milesFmt.format(d.businessMiles), moneyFmt.format(d.deduction),
        d.tripCount, d.unclassified, moneyFmt.format(d.field), d.openJobs, d.last_trip_date || '',
      ]),
    ]);
  }

  useDeskChrome(() => ({
    header: {
      title: 'Drivers',
      crumb: `${org} › Drivers`,
      sub: (
        <>
          {range.label}
          <span className="sep">·</span>
          same period as Overview
          <span className="sep">·</span>
          <span className="num">{drivers.length} drivers</span>
        </>
      ),
      right: membership?.isAdmin ? (
        <button type="button" className="btn fill-blue" onClick={() => desk?.setPage('people')}>
          {ICO.mail}Invite driver
        </button>
      ) : null,
    },
    rail: (
      <PeriodRail
        period={period}
        setPeriod={setPeriod}
        range={range}
        mileageRate={mileageRate}
        onExport={exportCsv}
        primaryLabel="Add driver"
        onPrimary={membership?.isAdmin ? () => desk?.setPage('people') : undefined}
      />
    ),
    mini: <PeriodMini period={period} onExport={exportCsv} onPrimary={membership?.isAdmin ? () => desk?.setPage('people') : undefined} />,
  }), [org, range.label, drivers.length, period, mileageRate, membership?.isAdmin]);

  return (
    <div className="desk-page">
      <div className="grid">
        <section className="card metal s12">
          <div className="toolbar">
            <SearchWell value={query} onChange={setQuery} placeholder="Find a driver" />
            <div className="chips">
              {[
                ['all', 'All', counts.all],
                ['on', 'On route', counts.on],
                ['idle', 'Idle', counts.idle],
                ['off', 'Off shift', counts.off],
                ['unclassified', 'Has unclassified', counts.unclassified],
              ].map(([id, label, n]) => (
                <button key={id} type="button" className="fchip" aria-pressed={chip === id} onClick={() => setChip(id)}>
                  {label} <span className="n">{n}</span>
                </button>
              ))}
            </div>
            <div style={{ marginLeft: 'auto', display: 'flex', gap: 8 }}>
              <button type="button" className="btn fill-steel btn-xs" style={{ height: 34 }} onClick={exportCsv}>
                {ICO.export}CSV
              </button>
            </div>
          </div>
          <DriverRoster
            drivers={visible}
            jobs={jobs}
            selectedId={selected?.user_id}
            onSelect={(d) => setSelectedId(d.user_id)}
            showCheck
          />
        </section>
        {selected ? <DriverDetail driver={selected} mileageRate={mileageRate} onReload={team.reload} /> : null}
      </div>
    </div>
  );
}

function DriverDetail({ driver, mileageRate, onReload }) {
  const todayTrips = driver.tripRows.filter((t) => tripDate(t) === isoDate(new Date()));
  const rows = (todayTrips.length ? todayTrips : driver.tripRows).slice(0, 12);

  async function classify(trip, isBusiness) {
    if (!trip.id) return;
    await api.updateTrip(trip.id, {
      date: tripDate(trip),
      miles: Number(trip.miles || 0),
      tips: Number(trip.tips || 0),
      notes: trip.notes || '',
      is_business: isBusiness,
    });
    await onReload();
  }

  return (
    <>
      <section className="card metal chrome-edge s7">
        <div className="card-h">
          <div className="who">
            <Avatar name={driver.label} status={driverPresence(driver).id} seed={driver.user_id} />
            <div>
              <b style={{ fontSize: 15 }}>{driver.label} · trip log</b>
              <span>
                {formatRangeMdYSafe(driver)} {rows.length} trips
                {driver.unclassified ? <> · <span className="alert-t">{driver.unclassified} unclassified</span></> : null}
              </span>
            </div>
          </div>
        </div>
        <div className="grid" style={{ gridTemplateColumns: 'repeat(4,1fr)', gap: 10, marginBottom: 14 }}>
          <Stat label="Business mi" value={milesFmt.format(driver.businessMiles)} tone="pos-t" />
          <Stat label="Deduction" value={moneyFmt.format(driver.deduction)} tone="money-t" />
          <Stat label="Trips" value={String(driver.tripCount)} />
          <Stat label="Field costs" value={moneyFmt.format(driver.field)} tone="money-t" />
        </div>
        {rows.length === 0 ? (
          <EmptyHint>No trips in this period.</EmptyHint>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Notes</th>
                  <th className="r">Miles</th>
                  <th className="r">Deduction</th>
                  <th className="r">Purpose</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((trip) => {
                  const biz = trip.is_business;
                  const miles = Number(trip.miles || 0);
                  return (
                    <tr key={trip.id || `${tripDate(trip)}-${miles}`}>
                      <td className="mono">{formatShortDate(tripDate(trip))}</td>
                      <td>{trip.notes || trip.start_address || '—'}</td>
                      <td className="r num">{milesFmt.format(miles)}</td>
                      <td className="r money-t num">{biz === true ? moneyFmt.format(miles * mileageRate) : '—'}</td>
                      <td className="r">
                        {biz === true ? <span className="status on">Business</span> : null}
                        {biz === false ? <span className="status off">Personal</span> : null}
                        {biz == null ? (
                          <div style={{ display: 'inline-flex', gap: 6 }}>
                            <button type="button" className="btn btn-xs fill-green" onClick={() => classify(trip, true)}>Business</button>
                            <button type="button" className="btn btn-xs fill-steel" onClick={() => classify(trip, false)}>Personal</button>
                          </div>
                        ) : null}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>
      <section className="card metal s5">
        <div className="card-h">
          <div>
            <h2>Today’s route</h2>
            <p>{driver.vehicle || 'No vehicle on file'}</p>
          </div>
        </div>
        <div className="map" style={{ display: 'grid', placeItems: 'center', color: 'var(--text-subtle)', fontSize: 13, height: 300 }}>
          Route map uses the Jobs board Map view when this driver has stops today.
        </div>
      </section>
    </>
  );
}

function Stat({ label, value, tone }) {
  return (
    <div className="card well" style={{ padding: '12px 14px', borderRadius: 12 }}>
      <div className="muted" style={{ fontSize: 11.5 }}>{label}</div>
      <div className={`num ${tone || ''}`} style={{ fontSize: 19, fontWeight: 620, letterSpacing: '-.02em' }}>{value}</div>
    </div>
  );
}

function formatRangeMdYSafe() {
  return '';
}

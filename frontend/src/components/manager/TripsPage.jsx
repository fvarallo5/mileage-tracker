import { useMemo, useState } from 'react';
import { useDeskChrome, useDeskNav } from '../../context/DeskNav.jsx';
import { useTeam } from '../../context/TeamContext.jsx';
import { api } from '../../api.js';
import { formatRangeMdY } from '../../lib/period.js';
import { downloadCsv, formatShortDate, milesFmt, moneyFmt } from './format.js';
import PeriodRail, { PeriodMini } from './PeriodRail.jsx';
import { EmptyHint, SearchWell } from './DeskWidgets.jsx';
import { tripDate } from './deskKit.js';

export default function TripsPage() {
  const team = useTeam();
  const desk = useDeskNav();
  const { trips, drivers, period, setPeriod, range, mileageRate, membership, kpis } = team;
  const org = membership?.name || 'TrekTrack';
  const [query, setQuery] = useState('');
  const [chip, setChip] = useState('all');

  const nameOf = useMemo(() => {
    const m = new Map(drivers.map((d) => [d.user_id, d.label]));
    return (id) => m.get(id) || 'Driver';
  }, [drivers]);

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase();
    return (trips || []).filter((t) => {
      if (chip === 'business' && t.is_business !== true) return false;
      if (chip === 'personal' && t.is_business !== false) return false;
      if (chip === 'unclassified' && t.is_business != null) return false;
      if (q && !`${nameOf(t.user_id)} ${t.notes || ''} ${tripDate(t)}`.toLowerCase().includes(q)) return false;
      return true;
    });
  }, [trips, chip, query, nameOf]);

  const counts = {
    all: trips.length,
    business: trips.filter((t) => t.is_business === true).length,
    personal: trips.filter((t) => t.is_business === false).length,
    unclassified: trips.filter((t) => t.is_business == null).length,
  };

  function exportCsv() {
    downloadCsv(`TrekTrack_Trips_${range.start}_${range.end}.csv`, [
      ['Date', 'Driver', 'Class', 'Miles', 'Notes'],
      ...rows.map((t) => [
        tripDate(t),
        nameOf(t.user_id),
        t.is_business === true ? 'Business' : t.is_business === false ? 'Personal' : 'Unclassified',
        milesFmt.format(Number(t.miles || 0)),
        t.notes || '',
      ]),
    ]);
  }

  async function classify(trip, isBusiness) {
    if (!trip.id) return;
    await api.updateTrip(trip.id, {
      date: tripDate(trip),
      miles: Number(trip.miles || 0),
      tips: Number(trip.tips || 0),
      notes: trip.notes || '',
      is_business: isBusiness,
    });
    await team.reload();
  }

  useDeskChrome(() => ({
    header: {
      title: 'Trips',
      crumb: `${org} › Trips`,
      sub: (
        <>
          {range.label}
          <span className="sep">·</span>
          <span className="num">{formatRangeMdY(range.start, range.end)}</span>
          <span className="sep">·</span>
          <span className="num">{trips.length} trips</span>
        </>
      ),
      right: kpis.unclassified ? (
        <span className="pill well"><b className="num alert-t">{kpis.unclassified}</b> unclassified</span>
      ) : null,
    },
    rail: (
      <PeriodRail
        period={period}
        setPeriod={setPeriod}
        range={range}
        mileageRate={mileageRate}
        onExport={exportCsv}
        primaryLabel="Drivers"
        onPrimary={() => desk?.setPage('drivers')}
      />
    ),
    mini: <PeriodMini period={period} onExport={exportCsv} />,
  }), [org, range.label, range.start, range.end, trips.length, kpis.unclassified, period, mileageRate]);

  return (
    <div className="desk-page">
      <div className="grid">
        <section className="card metal s12">
          <div className="toolbar">
            <SearchWell value={query} onChange={setQuery} placeholder="Find a trip" shortcut="" />
            <div className="chips">
              {[
                ['all', 'All', counts.all],
                ['business', 'Business', counts.business],
                ['personal', 'Personal', counts.personal],
                ['unclassified', 'Unclassified', counts.unclassified],
              ].map(([id, label, n]) => (
                <button key={id} type="button" className="fchip" aria-pressed={chip === id} onClick={() => setChip(id)}>
                  {label} <span className="n">{n}</span>
                </button>
              ))}
            </div>
            <div style={{ marginLeft: 'auto' }}>
              <button type="button" className="btn fill-steel btn-xs" style={{ height: 34 }} onClick={exportCsv}>CSV</button>
            </div>
          </div>
          {rows.length === 0 ? (
            <EmptyHint>No trips in this period. Drivers classify trips in the TrekTrack phone app.</EmptyHint>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Driver</th>
                    <th>Notes</th>
                    <th className="r">Miles</th>
                    <th className="r">Deduction</th>
                    <th className="r">Purpose</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((t) => {
                    const miles = Number(t.miles || 0);
                    return (
                      <tr key={t.id || `${t.user_id}-${tripDate(t)}-${miles}`}>
                        <td className="mono">{formatShortDate(tripDate(t))}</td>
                        <td>{nameOf(t.user_id)}</td>
                        <td>{t.notes || '—'}</td>
                        <td className="r num">{milesFmt.format(miles)}</td>
                        <td className="r money-t num">{t.is_business === true ? moneyFmt.format(miles * mileageRate) : '—'}</td>
                        <td className="r">
                          {t.is_business === true ? <span className="status on">Business</span> : null}
                          {t.is_business === false ? <span className="status off">Personal</span> : null}
                          {t.is_business == null ? (
                            <div style={{ display: 'inline-flex', gap: 6 }}>
                              <button type="button" className="btn btn-xs fill-green" onClick={() => classify(t, true)}>Business</button>
                              <button type="button" className="btn btn-xs fill-steel" onClick={() => classify(t, false)}>Personal</button>
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
      </div>
    </div>
  );
}

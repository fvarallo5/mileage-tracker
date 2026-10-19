import { useMemo } from 'react';
import { useDeskChrome, useDeskNav } from '../../context/DeskNav.jsx';
import { useTeam } from '../../context/TeamContext.jsx';
import { formatRangeMdY } from '../../lib/period.js';
import { isoDate } from '../../lib/period.js';
import { downloadCsv, milesFmt, moneyFmt } from './format.js';
import { ICO } from './icons.jsx';
import PeriodRail, { PeriodMini } from './PeriodRail.jsx';
import { EmptyHint, KpiCard } from './DeskWidgets.jsx';
import { dailySeries, donutDash, driverPresence } from './deskKit.js';
import DriverRoster from './DriverRoster.jsx';

export default function DeskOverview() {
  const team = useTeam();
  const desk = useDeskNav();
  const { kpis, drivers, trips, expenses, jobs, period, setPeriod, range, mileageRate, membership } = team;
  const org = membership?.name || 'TrekTrack';
  const today = isoDate(new Date());
  const onRoute = drivers.filter((d) => driverPresence(d, jobs, today).id === 'on').length;

  const mileSpark = useMemo(
    () => dailySeries(trips, range.start, range.end, (t) => (t.is_business === true ? Number(t.miles || 0) : 0)),
    [trips, range.start, range.end],
  );
  const tripSpark = useMemo(
    () => dailySeries(trips, range.start, range.end, () => 1),
    [trips, range.start, range.end],
  );
  const unclassSpark = useMemo(
    () => dailySeries(trips, range.start, range.end, (t) => (t.is_business == null ? 1 : 0)),
    [trips, range.start, range.end],
  );
  const costSpark = useMemo(
    () => dailySeries(expenses, range.start, range.end, (e) => Number(e.amount || 0)),
    [expenses, range.start, range.end],
  );
  const deductSpark = useMemo(() => mileSpark.map((v) => v * mileageRate), [mileSpark, mileageRate]);

  function exportCsv() {
    downloadCsv(`TrekTrack_Overview_${range.start}_${range.end}.csv`, [
      ['Driver', 'Business mi', 'Deduction', 'Trips', 'Unclassified', 'Field costs', 'Open jobs'],
      ...drivers.map((d) => [
        d.label,
        milesFmt.format(d.businessMiles),
        moneyFmt.format(d.deduction),
        d.tripCount,
        d.unclassified,
        moneyFmt.format(d.field),
        d.openJobs,
      ]),
    ]);
  }

  useDeskChrome(() => ({
    header: {
      title: 'Overview',
      crumb: `${org} › Overview`,
      sub: (
        <>
          {range.label}
          <span className="sep">·</span>
          <span className="num">{formatRangeMdY(range.start, range.end)}</span>
          <span className="sep">·</span>
          IRS <span className="num">{moneyFmt.format(mileageRate)}/mi</span>
        </>
      ),
      right: (
        <span className="pill well">
          <span className="live-dot" />
          <b>{onRoute}</b> {onRoute === 1 ? 'driver' : 'drivers'} on route
        </span>
      ),
    },
    rail: (
      <PeriodRail
        period={period}
        setPeriod={setPeriod}
        range={range}
        mileageRate={mileageRate}
        onExport={exportCsv}
        primaryLabel="New job"
        onPrimary={membership?.operatingMode === 'reimbursement' ? undefined : () => desk?.setPage('jobs')}
      />
    ),
    mini: (
      <PeriodMini
        period={period}
        onExport={exportCsv}
        onPrimary={membership?.operatingMode === 'reimbursement' ? undefined : () => desk?.setPage('jobs')}
      />
    ),
  }), [org, range.label, range.start, range.end, period, mileageRate, onRoute, membership?.operatingMode]);

  const buckets = kpis.buckets;
  const donutVals = [buckets.tolls, buckets.gas, buckets.parking, buckets.misc];
  const donut = donutDash(donutVals);
  const colors = ['#fbbf24', '#3b9eff', '#34d399', '#a3b1c6'];
  const labels = ['Tolls', 'Gas', 'Parking', 'Misc'];
  const fieldTotal = kpis.field || 1;
  const unclassifiedDrivers = drivers.filter((d) => d.unclassified > 0);

  return (
    <div className="desk-page">
      <div className="grid">
        <KpiCard
          lit
          icon={ICO.miles}
          tone="pos"
          label="Business miles"
          value={milesFmt.format(kpis.miles)}
          unit="mi"
          spark={mileSpark}
          sparkId="sp-mi"
          foot={<><span className="delta up">{drivers.length} drivers</span><span className="ctx">this period</span></>}
        />
        <KpiCard
          icon={ICO.money}
          tone="money"
          label="Est. deduction"
          value={moneyFmt.format(kpis.deduction)}
          spark={deductSpark}
          sparkId="sp-ded"
          foot={<><span className="delta money">@ {moneyFmt.format(mileageRate)}/mi</span><span className="ctx">IRS</span></>}
        />
        <KpiCard
          icon={ICO.trips}
          tone="pri"
          label="Trips"
          value={String(kpis.trips)}
          spark={tripSpark}
          sparkId="sp-tr"
          foot={<span className="ctx">{kpis.trips ? `${(kpis.trips / Math.max(daysCount(range), 1)).toFixed(1)} / day` : 'No trips yet'}</span>}
        />
        <KpiCard
          icon={ICO.alert}
          tone="alert"
          label="Unclassified"
          value={String(kpis.unclassified)}
          unit="trips"
          spark={unclassSpark}
          sparkId="sp-un"
          foot={kpis.unclassified ? <><span className="delta warn">Needs review</span><span className="ctx">{unclassifiedDrivers.length} drivers</span></> : <span className="ctx">All classified</span>}
        />
        <KpiCard
          icon={ICO.costs}
          tone="money"
          label="Field costs"
          value={moneyFmt.format(kpis.field)}
          spark={costSpark}
          sparkId="sp-co"
          foot={<span className="ctx">4 categories</span>}
        />
        <KpiCard
          icon={ICO.jobs}
          tone="pri"
          label="Open jobs"
          value={String(kpis.jobs)}
          sparkId="sp-jo"
          spark={[]}
          foot={<span className="ctx">active on the board</span>}
        />

        <section className="card metal s8">
          <div className="card-h">
            <div>
              <h2>Business miles over time</h2>
              <p>Daily, {formatRangeMdY(range.start, range.end)} · tooltip shows deduction at {moneyFmt.format(mileageRate)}/mi</p>
            </div>
          </div>
          {kpis.miles === 0 ? (
            <EmptyHint>No business miles in this period. Drivers log trips in the TrekTrack phone app.</EmptyHint>
          ) : (
            <MilesChart values={mileSpark} days={dayLabels(range)} />
          )}
        </section>

        <section className="card metal s4">
          <div className="card-h">
            <div>
              <h2>Field costs</h2>
              <p>Tolls, parking, gas, misc</p>
            </div>
          </div>
          {kpis.field === 0 ? (
            <EmptyHint>No field costs this period.</EmptyHint>
          ) : (
            <div className="donut-wrap">
              <svg viewBox="0 0 170 170" width="170" height="170" role="img" aria-label="Field costs breakdown">
                <circle r="62" cx="85" cy="85" fill="none" stroke="var(--surface-sunken)" strokeWidth="24" />
                {donut.map((seg, i) => (
                  <circle
                    key={labels[i]}
                    r="62"
                    cx="85"
                    cy="85"
                    fill="none"
                    stroke={colors[i]}
                    strokeWidth="20"
                    strokeDasharray={`${seg.len} ${seg.circ}`}
                    strokeDashoffset={-seg.offset}
                    transform="rotate(-90 85 85)"
                  />
                ))}
                <circle r="49" cx="85" cy="85" fill="var(--surface)" stroke="var(--line-strong)" />
                <text x="85" y="81" textAnchor="middle" fontSize="18" fontWeight="650" fill="var(--text)">{moneyFmt.format(kpis.field)}</text>
                <text x="85" y="99" textAnchor="middle" fontSize="11" fill="var(--text-subtle)">field costs</text>
              </svg>
              <div className="donut-legend">
                {labels.map((name, i) => (
                  <div className="row" key={name}>
                    <i style={{ background: colors[i] }} />
                    <span>{name}</span>
                    <b>
                      {moneyFmt.format(donutVals[i])}
                      <em>{Math.round((donutVals[i] / fieldTotal) * 100)}%</em>
                    </b>
                  </div>
                ))}
              </div>
            </div>
          )}
        </section>

        <section className="card metal s7">
          <div className="card-h">
            <div>
              <h2>Live fleet</h2>
              <p>
                {onRoute} on route · {drivers.filter((d) => driverPresence(d, jobs, today).id === 'idle').length} idle ·{' '}
                {drivers.filter((d) => driverPresence(d, jobs, today).id === 'off').length} off shift
              </p>
            </div>
            <div className="right">
              <span className="pill well"><span className="live-dot" /><b>Live</b></span>
            </div>
          </div>
          <div className="map" style={{ display: 'grid', placeItems: 'center', color: 'var(--text-subtle)', fontSize: 13 }}>
            {drivers.length === 0
              ? 'Invite drivers on People to see the fleet.'
              : 'Driver pings show here once phones share a last location. Open Jobs → Map for the day board.'}
          </div>
        </section>

        <section className="card metal s5">
          <div className="card-h">
            <div>
              <h2>Needs attention</h2>
              <p>Keep the log audit-ready</p>
            </div>
            <div className="right">
              {kpis.unclassified ? <span className="badge alert">{kpis.unclassified}</span> : null}
            </div>
          </div>
          <div className="list">
            <div className="item">
              <span className="tile alert">{ICO.alert}</span>
              <div>
                <div className="t">{kpis.unclassified} unclassified trips</div>
                <div className="m">
                  {unclassifiedDrivers.length
                    ? unclassifiedDrivers.slice(0, 3).map((d) => `${d.label} (${d.unclassified})`).join(' · ')
                    : 'None waiting'}
                </div>
              </div>
              <button type="button" className="btn btn-xs fill-red" onClick={() => desk?.setPage('trips')}>Review</button>
            </div>
            <div className="item">
              <span className="tile money">{ICO.costs}</span>
              <div>
                <div className="t">Field costs this period</div>
                <div className="m">{moneyFmt.format(kpis.field)} across {expenses.length} receipts</div>
              </div>
              <button type="button" className="btn btn-xs fill-steel" onClick={() => desk?.setPage('expenses')}>Open</button>
            </div>
            <div className="item">
              <span className="tile pri">{ICO.jobs}</span>
              <div>
                <div className="t">{kpis.jobs} open jobs</div>
                <div className="m">Active on the dispatch board</div>
              </div>
              <button type="button" className="btn btn-xs fill-steel" onClick={() => desk?.setPage('jobs')}>Board</button>
            </div>
          </div>
        </section>

        <section className="card metal s12">
          <div className="card-h">
            <div>
              <h2>Drivers</h2>
              <p>{range.label} · select a row for trips and costs</p>
            </div>
            <div className="right">
              <button type="button" className="btn fill-steel btn-xs" style={{ height: 34 }} onClick={() => desk?.setPage('drivers')}>
                Open drivers
              </button>
            </div>
          </div>
          <DriverRoster drivers={drivers} jobs={jobs} compact />
        </section>
      </div>
    </div>
  );
}

function daysCount(range) {
  const a = new Date(`${range.start}T12:00:00`);
  const b = new Date(`${range.end}T12:00:00`);
  return Math.max(1, Math.round((b - a) / 86400000) + 1);
}

function dayLabels(range) {
  const a = new Date(`${range.start}T12:00:00`);
  const b = new Date(`${range.end}T12:00:00`);
  const out = [];
  const d = new Date(a);
  while (d <= b) {
    out.push(`${d.toLocaleString('en-US', { month: 'short' })} ${d.getDate()}`);
    d.setDate(d.getDate() + 1);
  }
  return out;
}

function MilesChart({ values, days }) {
  const w = 820;
  const h = 300;
  const padL = 44;
  const padB = 28;
  const padT = 14;
  const max = Math.max(...values, 1);
  const nice = Math.ceil(max / 5) * 5 || 100;
  const innerW = w - padL - 10;
  const innerH = h - padT - padB;
  const step = values.length > 1 ? innerW / (values.length - 1) : innerW;
  const pts = values.map((v, i) => {
    const x = padL + i * step;
    const y = padT + innerH - (v / nice) * innerH;
    return [x, y];
  });
  const line = pts.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(' ');
  const area = `${line} L${pts[pts.length - 1][0].toFixed(1)},${padT + innerH} L${padL},${padT + innerH} Z`;
  const ticks = [0, 1, 2, 3, 4, 5].map((i) => nice - (nice / 5) * i);
  return (
    <svg className="chart" viewBox={`0 0 ${w} ${h}`} role="img" aria-label="Business miles per day">
      <g className="axis">
        {ticks.map((t, i) => {
          const y = padT + (innerH / 5) * i;
          return (
            <g key={t}>
              <line x1={padL} x2={w - 10} y1={y} y2={y} strokeDasharray={i === ticks.length - 1 ? '' : '2 4'} />
              <text x={padL - 10} y={y + 4} textAnchor="end">{t}</text>
            </g>
          );
        })}
        {days.filter((_, i) => i === 0 || i === days.length - 1 || i % Math.ceil(days.length / 6) === 0).map((label) => {
          const i = days.indexOf(label);
          const x = padL + i * step;
          return <text key={label + i} x={x} y={h - 8} textAnchor={i === 0 ? 'start' : i === days.length - 1 ? 'end' : 'middle'}>{label}</text>;
        })}
      </g>
      <path d={area} fill="color-mix(in oklab, #34d399 22%, transparent)" />
      <path d={line} fill="none" stroke="#34d399" strokeWidth="2.4" strokeLinecap="round" />
    </svg>
  );
}



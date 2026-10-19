import { isoDate } from '../../lib/period.js';
import { formatShortDate, milesFmt, moneyFmt } from './format.js';
import { ICO } from './icons.jsx';
import { Avatar } from './DeskWidgets.jsx';
import { driverPresence } from './deskKit.js';

export default function DriverRoster({
  drivers,
  jobs = [],
  selectedId,
  onSelect,
  compact = false,
  showCheck = false,
}) {
  const today = isoDate(new Date());
  const maxMiles = Math.max(...drivers.map((d) => d.businessMiles), 1);
  const maxField = Math.max(...drivers.map((d) => d.field), 1);
  const totals = drivers.reduce(
    (s, d) => ({
      miles: s.miles + d.businessMiles,
      deduction: s.deduction + d.deduction,
      trips: s.trips + d.tripCount,
      unclassified: s.unclassified + d.unclassified,
      field: s.field + d.field,
      jobs: s.jobs + d.openJobs,
    }),
    { miles: 0, deduction: 0, trips: 0, unclassified: 0, field: 0, jobs: 0 },
  );

  if (!drivers.length) {
    return <p className="empty" style={{ padding: 16 }}>No drivers in this view. Invite people on People.</p>;
  }

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            {showCheck ? <th /> : null}
            <th>Driver</th>
            <th>Status</th>
            <th className="r">Business mi</th>
            <th className="r">Deduction</th>
            <th className="r">Trips</th>
            <th className="r">Unclassified</th>
            <th className="r">Field costs</th>
            {compact ? null : <th className="r">Open jobs</th>}
            <th>Last trip</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {drivers.map((d) => {
            const st = driverPresence(d, jobs, today);
            const sel = selectedId === d.user_id;
            return (
              <tr
                key={d.user_id}
                className={sel ? 'sel' : ''}
                onClick={() => onSelect?.(d)}
                style={onSelect ? { cursor: 'pointer' } : undefined}
              >
                {showCheck ? (
                  <td style={{ width: 28, paddingRight: 0 }}>
                    <input type="checkbox" className="chk" checked={sel} readOnly />
                  </td>
                ) : null}
                <td>
                  <div className="who">
                    <Avatar name={d.label} status={st.id} seed={d.user_id} />
                    <div>
                      <b>{d.label}</b>
                      <span>{d.email || d.phone || '—'}</span>
                    </div>
                  </div>
                </td>
                <td><span className={`status ${st.id}`}>{st.label}</span></td>
                <td className="r">
                  <span className="bar" style={{ '--w': `${Math.round((d.businessMiles / maxMiles) * 100)}%`, '--c': 'var(--brand-green)' }}>
                    <i />
                    <span className="num">{milesFmt.format(d.businessMiles)}</span>
                  </span>
                </td>
                <td className="r money-t num">{moneyFmt.format(d.deduction)}</td>
                <td className="r num">{d.tripCount}</td>
                <td className="r num">
                  {d.unclassified ? <span className="status alert">{d.unclassified}</span> : <span className="zero">0</span>}
                </td>
                <td className="r">
                  <span className="bar" style={{ '--w': `${Math.round((d.field / maxField) * 100)}%`, '--c': 'var(--brand-amber)' }}>
                    <i />
                    <span className="num">{moneyFmt.format(d.field)}</span>
                  </span>
                </td>
                {compact ? null : <td className="r num">{d.openJobs}</td>}
                <td className="muted">{formatShortDate(d.last_trip_date)}</td>
                <td style={{ width: 30 }}>{ICO.chev}</td>
              </tr>
            );
          })}
          <tr style={{ background: 'color-mix(in oklab, var(--surface-2) 50%, transparent)' }}>
            {showCheck ? <td /> : null}
            <td><b style={{ fontWeight: 600 }}>Team total</b></td>
            <td />
            <td className="r num" style={{ fontWeight: 600 }}>{milesFmt.format(totals.miles)}</td>
            <td className="r money-t num" style={{ fontWeight: 600 }}>{moneyFmt.format(totals.deduction)}</td>
            <td className="r num" style={{ fontWeight: 600 }}>{totals.trips}</td>
            <td className={`r num${totals.unclassified ? ' alert-t' : ''}`}>{totals.unclassified}</td>
            <td className="r num" style={{ fontWeight: 600 }}>{moneyFmt.format(totals.field)}</td>
            {compact ? null : <td className="r num" style={{ fontWeight: 600 }}>{totals.jobs}</td>}
            <td />
            <td />
          </tr>
        </tbody>
      </table>
    </div>
  );
}

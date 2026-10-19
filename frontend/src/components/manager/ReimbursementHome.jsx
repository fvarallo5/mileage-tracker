import { PERIODS } from '../../lib/period.js';
import { useTeam } from '../../context/TeamContext.jsx';
import { milesFmt, moneyFmt } from './format.js';
import Module from './Module.jsx';
import DeskTitle from './DeskTitle.jsx';

export default function ReimbursementHome() {
  const { period, setPeriod, range, drivers, kpis } = useTeam();

  return (
    <div className="desk-page">
    <DeskTitle title="Employees" sub={`${range.label} · Business miles, receipts, and tolls.`} />
    <div className="mgr-page">
      <div className="page-toolbar">
        <div>
          <h1>Employees</h1>
          <p className="page-sub">
            {range.label} · Business miles, receipts, and tolls by employee. Job dispatch is off in reimbursement mode.
          </p>
        </div>
        <div className="toolbar-actions">
          <div className="period-pills" role="tablist" aria-label="Period">
            {PERIODS.map(([key, label]) => (
              <button
                key={key}
                type="button"
                className={period === key ? 'active' : ''}
                onClick={() => setPeriod(key)}
              >
                {label}
              </button>
            ))}
          </div>
        </div>
      </div>

      <Module title="Totals">
      <div className="kpi-row">
        <div className="kpi"><div className="label">Business miles</div><div className="kpi-value">{milesFmt.format(kpis.miles)}</div></div>
        <div className={`kpi${kpis.unclassified > 0 ? ' warn' : ''}`}><div className="label">Unclassified</div><div className="kpi-value">{kpis.unclassified}</div></div>
        <div className="kpi"><div className="label">Tolls</div><div className="kpi-value">{moneyFmt.format(kpis.buckets.tolls)}</div></div>
        <div className="kpi"><div className="label">Field costs</div><div className="kpi-value">{moneyFmt.format(kpis.field)}</div></div>
      </div>
      </Module>

      <Module title="Employees" fill>
        <p className="field-hint" style={{ marginBottom: '0.85rem' }}>
          Employees log miles and receipts in the TrekTrack phone app. A dedicated accountant upload and packet comes next.
        </p>
        {drivers.length === 0 ? (
          <p className="empty">Invite employees on People.</p>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>Employee</th>
                <th>Phone</th>
                <th className="num">Business mi</th>
                <th className="num">Trips</th>
                <th className="num">Unclassified</th>
                <th className="num">Tolls</th>
                <th className="num">Parking</th>
                <th className="num">Gas</th>
                <th className="num">Misc</th>
              </tr>
            </thead>
            <tbody>
              {drivers.map((row) => (
                <tr key={row.user_id}>
                  <td>
                    <div>{row.label}</div>
                    <div className="muted-row">{row.email}</div>
                  </td>
                  <td>{row.phone || '—'}</td>
                  <td className="num">{milesFmt.format(row.businessMiles)}</td>
                  <td className="num">{row.tripCount}</td>
                  <td className="num">{row.unclassified}</td>
                  <td className="num">{moneyFmt.format(row.buckets.tolls)}</td>
                  <td className="num">{moneyFmt.format(row.buckets.parking)}</td>
                  <td className="num">{moneyFmt.format(row.buckets.gas)}</td>
                  <td className="num">{moneyFmt.format(row.buckets.misc)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Module>
    </div>
    </div>
  );
}

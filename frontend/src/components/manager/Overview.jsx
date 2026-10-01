import { PERIODS } from '../../lib/period.js';
import { useTeam } from '../../context/TeamContext.jsx';
import DriverTable from './DriverTable.jsx';
import { costLabel, downloadCsv, milesFmt, moneyFmt } from './format.js';

export default function Overview() {
  const { period, setPeriod, range, kpis, drivers, trips, expenses, mileageRate } = useTeam();

  function handleExport() {
    const safe = range.label.replace(/\s+/g, '_');
    downloadCsv(`TrekTrack_Team_Mileage_${safe}.csv`, [
      ['Date', 'Driver', 'Class', 'Miles', 'Earnings (USD)', 'Notes'],
      ...trips.map((trip) => [
        trip.trip_date,
        trip.nickname || trip.email,
        trip.is_business === true ? 'Business' : trip.is_business === false ? 'Personal' : 'Unclassified',
        Number(trip.miles).toFixed(2),
        Number(trip.tips ?? 0).toFixed(2),
        trip.notes || '',
      ]),
    ]);
    const total = kpis.buckets.tolls + kpis.buckets.parking + kpis.buckets.gas + kpis.buckets.misc;
    downloadCsv(`TrekTrack_Team_FieldCosts_${safe}.csv`, [
      ['Date', 'Driver', 'Category', 'Merchant', 'Amount (USD)', 'Receipt', 'Notes'],
      ...expenses.map((row) => [
        row.expense_date,
        row.nickname || row.email,
        costLabel(row.category),
        row.merchant || '',
        Number(row.amount ?? 0).toFixed(2),
        row.has_receipt ? 'Yes' : '',
        row.notes || '',
      ]),
      ['Total', '', '', '', total.toFixed(2), '', ''],
    ]);
  }

  return (
    <div className="mgr-page">
      <div className="page-toolbar">
        <div>
          <h1>Overview</h1>
          <p className="page-sub">
            {range.label} · {range.start} to {range.end} · IRS {moneyFmt.format(mileageRate)}/mi
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
          <button type="button" className="btn btn-secondary btn-sm" onClick={handleExport}>
            Export
          </button>
        </div>
      </div>

      <div className="kpi-row">
        <Kpi label="Business miles" value={milesFmt.format(kpis.miles)} />
        <Kpi label="Est. deduction" value={moneyFmt.format(kpis.deduction)} />
        <Kpi label="Trips" value={String(kpis.trips)} />
        <Kpi label="Unclassified" value={String(kpis.unclassified)} warn={kpis.unclassified > 0} />
        <Kpi label="Field costs" value={moneyFmt.format(kpis.field)} />
        <Kpi label="Open jobs" value={String(kpis.jobs)} />
      </div>

      <div className="bucket-row">
        <span>Tolls {moneyFmt.format(kpis.buckets.tolls)}</span>
        <span>Parking {moneyFmt.format(kpis.buckets.parking)}</span>
        <span>Gas {moneyFmt.format(kpis.buckets.gas)}</span>
        <span>Misc {moneyFmt.format(kpis.buckets.misc)}</span>
      </div>

      <DriverTable drivers={drivers} rangeLabel={range.label} />
    </div>
  );
}

function Kpi({ label, value, warn = false }) {
  return (
    <div className={`kpi${warn ? ' warn' : ''}`}>
      <div className="label">{label}</div>
      <div className="kpi-value">{value}</div>
    </div>
  );
}

import { useMemo, useState } from 'react';
import { costLabel, formatShortDate, milesFmt, moneyFmt } from './format.js';

function Disclosure({ title, meta, children }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="disclosure">
      <button type="button" className="disclosure-btn" onClick={() => setOpen((v) => !v)}>
        <span className="disclosure-caret" aria-hidden="true">{open ? '▾' : '▸'}</span>
        {title}
        {meta ? <span className="disclosure-meta">{meta}</span> : null}
      </button>
      {open ? <div className="disclosure-body">{children}</div> : null}
    </div>
  );
}

function classLabel(trip) {
  if (trip.is_business === true) return 'Business';
  if (trip.is_business === false) return 'Personal';
  return 'Unclassified';
}

export default function DriverTable({ drivers, rangeLabel, heading = 'Drivers' }) {
  const [openId, setOpenId] = useState(null);
  const [query, setQuery] = useState('');

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return drivers;
    return drivers.filter((d) =>
      `${d.label} ${d.email || ''}`.toLowerCase().includes(q),
    );
  }, [drivers, query]);

  return (
    <section className="panel">
      <div className="panel-head">
        <div>
          {heading ? <h2>{heading}</h2> : null}
          <p>{rangeLabel}. Select a row for trips and costs.</p>
        </div>
        <input
          className="filter-input"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Find a driver"
          aria-label="Find a driver"
        />
      </div>
      {visible.length === 0 ? (
        <p className="empty">No drivers in this view.</p>
      ) : (
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>Driver</th>
                <th className="num">Business mi</th>
                <th className="num">Deduction</th>
                <th className="num">Trips</th>
                <th className="num">Unclassified</th>
                <th className="num">Field costs</th>
                <th className="num">Open jobs</th>
                <th>Last trip</th>
              </tr>
            </thead>
            <tbody>
              {visible.map((driver) => {
                const open = openId === driver.user_id;
                return (
                  <DriverBlock
                    key={driver.user_id}
                    driver={driver}
                    open={open}
                    onToggle={() => setOpenId(open ? null : driver.user_id)}
                  />
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

function DriverBlock({ driver, open, onToggle }) {
  const unclassifiedTrips = driver.tripRows.filter((t) => t.is_business == null);
  return (
    <>
      <tr className={`crew-row${open ? ' open' : ''}`} onClick={onToggle}>
        <td>
          <div className="crew-name">{driver.label}</div>
          {driver.nickname ? <div className="muted-row">{driver.email}</div> : null}
        </td>
        <td className="num">{milesFmt.format(driver.businessMiles)}</td>
        <td className="num">{moneyFmt.format(driver.deduction)}</td>
        <td className="num">{driver.tripCount}</td>
        <td className={`num${driver.unclassified ? ' warn-cell' : ''}`}>{driver.unclassified}</td>
        <td className="num">{moneyFmt.format(driver.field)}</td>
        <td className="num">{driver.openJobs}</td>
        <td>{formatShortDate(driver.last_trip_date)}</td>
      </tr>
      {open ? (
        <tr className="expand-row">
          <td colSpan={8}>
            <div className="expand-panel">
              <div className="expand-stats">
                <Stat label="Personal mi" value={milesFmt.format(driver.personalMiles)} />
                <Stat label="Tips" value={moneyFmt.format(driver.tips)} />
                <Stat label="Tolls" value={moneyFmt.format(driver.buckets.tolls)} />
                <Stat label="Parking" value={moneyFmt.format(driver.buckets.parking)} />
                <Stat label="Gas" value={moneyFmt.format(driver.buckets.gas)} />
                <Stat label="Misc" value={moneyFmt.format(driver.buckets.misc)} />
              </div>
              <Disclosure title="Trips" meta={String(driver.tripRows.length)}>
                <MiniTable
                  columns={['Date', 'Class', 'Miles', 'Tips', 'Notes']}
                  rows={driver.tripRows.map((trip) => [
                    formatShortDate(trip.trip_date),
                    classLabel(trip),
                    milesFmt.format(Number(trip.miles)),
                    moneyFmt.format(Number(trip.tips ?? 0)),
                    trip.notes || '—',
                  ])}
                  empty="No trips in this period."
                />
              </Disclosure>
              <Disclosure title="Field costs" meta={moneyFmt.format(driver.field)}>
                <MiniTable
                  columns={['Date', 'Category', 'Merchant', 'Amount', 'Receipt', 'Notes']}
                  rows={driver.costs.map((row) => [
                    formatShortDate(row.expense_date),
                    costLabel(row.category),
                    row.merchant || '—',
                    moneyFmt.format(Number(row.amount ?? 0)),
                    row.has_receipt ? 'Yes' : '—',
                    row.notes || '—',
                  ])}
                  empty="No field costs in this period."
                />
              </Disclosure>
              {unclassifiedTrips.length > 0 ? (
                <Disclosure title="Unclassified" meta={String(unclassifiedTrips.length)}>
                  <MiniTable
                    columns={['Date', 'Miles', 'Notes']}
                    rows={unclassifiedTrips.map((trip) => [
                      formatShortDate(trip.trip_date),
                      milesFmt.format(Number(trip.miles)),
                      trip.notes || '—',
                    ])}
                    empty=""
                  />
                </Disclosure>
              ) : null}
            </div>
          </td>
        </tr>
      ) : null}
    </>
  );
}

function Stat({ label, value }) {
  return (
    <div className="expand-stat">
      <div className="label">{label}</div>
      <div>{value}</div>
    </div>
  );
}

function MiniTable({ columns, rows, empty }) {
  if (rows.length === 0) return <p className="empty">{empty}</p>;
  return (
    <table className="data-table compact">
      <thead>
        <tr>
          {columns.map((col) => (
            <th key={col}>{col}</th>
          ))}
        </tr>
      </thead>
      <tbody>
        {rows.map((row, i) => (
          <tr key={i}>
            {row.map((cell, j) => (
              <td key={j}>{cell}</td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}

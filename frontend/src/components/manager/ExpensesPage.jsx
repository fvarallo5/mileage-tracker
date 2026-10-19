import { useMemo, useState } from 'react';
import { useDeskChrome } from '../../context/DeskNav.jsx';
import { useTeam } from '../../context/TeamContext.jsx';
import { formatRangeMdY } from '../../lib/period.js';
import { costLabel, downloadCsv, formatShortDate, moneyFmt } from './format.js';
import PeriodRail, { PeriodMini } from './PeriodRail.jsx';
import { EmptyHint, SearchWell } from './DeskWidgets.jsx';
import { donutDash } from './deskKit.js';

export default function ExpensesPage() {
  const team = useTeam();
  const { expenses, drivers, period, setPeriod, range, mileageRate, membership, kpis } = team;
  const org = membership?.name || 'TrekTrack';
  const [query, setQuery] = useState('');
  const [chip, setChip] = useState('all');

  const nameOf = useMemo(() => {
    const m = new Map(drivers.map((d) => [d.user_id, d.label]));
    return (id) => m.get(id) || 'Driver';
  }, [drivers]);

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase();
    return (expenses || []).filter((e) => {
      const bucket = bucketOf(e.category);
      if (chip !== 'all' && bucket !== chip) return false;
      if (q && !`${nameOf(e.user_id)} ${e.merchant || ''} ${costLabel(e.category)}`.toLowerCase().includes(q)) return false;
      return true;
    });
  }, [expenses, chip, query, nameOf]);

  const buckets = kpis.buckets;
  const donutVals = [buckets.tolls, buckets.gas, buckets.parking, buckets.misc];
  const donut = donutDash(donutVals);
  const colors = ['#fbbf24', '#3b9eff', '#34d399', '#a3b1c6'];
  const labels = [
    ['tolls', 'Tolls', buckets.tolls],
    ['gas', 'Gas', buckets.gas],
    ['parking', 'Parking', buckets.parking],
    ['misc', 'Misc', buckets.misc],
  ];

  function exportCsv() {
    downloadCsv(`TrekTrack_FieldCosts_${range.start}_${range.end}.csv`, [
      ['Date', 'Driver', 'Category', 'Merchant', 'Amount', 'Receipt', 'Notes'],
      ...rows.map((e) => [
        e.expense_date || '',
        nameOf(e.user_id),
        costLabel(e.category),
        e.merchant || '',
        moneyFmt.format(Number(e.amount || 0)),
        e.has_receipt ? 'Yes' : '',
        e.notes || '',
      ]),
      ['', '', '', 'Total', moneyFmt.format(rows.reduce((s, e) => s + Number(e.amount || 0), 0)), '', ''],
    ]);
  }

  useDeskChrome(() => ({
    header: {
      title: 'Expenses',
      crumb: `${org} › Expenses`,
      sub: (
        <>
          {range.label}
          <span className="sep">·</span>
          <span className="num">{formatRangeMdY(range.start, range.end)}</span>
          <span className="sep">·</span>
          <span className="num">{moneyFmt.format(kpis.field)}</span> field costs
        </>
      ),
    },
    rail: (
      <PeriodRail
        period={period}
        setPeriod={setPeriod}
        range={range}
        mileageRate={mileageRate}
        onExport={exportCsv}
        primaryLabel={undefined}
        onPrimary={undefined}
      />
    ),
    mini: <PeriodMini period={period} onExport={exportCsv} />,
  }), [org, range.label, range.start, range.end, kpis.field, period, mileageRate]);

  const fieldTotal = kpis.field || 1;

  return (
    <div className="desk-page">
      <div className="grid">
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
              <svg viewBox="0 0 170 170" width="170" height="170" role="img" aria-label="Field costs">
                <circle r="62" cx="85" cy="85" fill="none" stroke="var(--surface-sunken)" strokeWidth="24" />
                {donut.map((seg, i) => (
                  <circle
                    key={i}
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
                {labels.map((row, i) => (
                  <div className="row" key={row[0]}>
                    <i style={{ background: colors[i] }} />
                    <span>{row[1]}</span>
                    <b>{moneyFmt.format(row[2])}<em>{Math.round((row[2] / fieldTotal) * 100)}%</em></b>
                  </div>
                ))}
              </div>
            </div>
          )}
        </section>
        <section className="card metal s8">
          <div className="toolbar">
            <SearchWell value={query} onChange={setQuery} placeholder="Find a cost" shortcut="" />
            <div className="chips">
              <button type="button" className="fchip" aria-pressed={chip === 'all'} onClick={() => setChip('all')}>
                All <span className="n">{expenses.length}</span>
              </button>
              {labels.map(([id, label, n]) => (
                <button key={id} type="button" className="fchip" aria-pressed={chip === id} onClick={() => setChip(id)}>
                  {label} <span className="n">{moneyFmt.format(n)}</span>
                </button>
              ))}
            </div>
          </div>
          {rows.length === 0 ? (
            <EmptyHint>No expenses in this view. Drivers add receipts on the phone.</EmptyHint>
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Driver</th>
                    <th>Category</th>
                    <th>Merchant</th>
                    <th className="r">Amount</th>
                    <th>Receipt</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((e) => (
                    <tr key={e.id || `${e.user_id}-${e.expense_date}-${e.amount}`}>
                      <td className="mono">{formatShortDate(e.expense_date)}</td>
                      <td>{nameOf(e.user_id)}</td>
                      <td>{costLabel(e.category)}</td>
                      <td>{e.merchant || '—'}</td>
                      <td className="r money-t num">{moneyFmt.format(Number(e.amount || 0))}</td>
                      <td className="muted">{e.has_receipt ? 'Yes' : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </div>
  );
}

function bucketOf(category) {
  if (category === 'tolls') return 'tolls';
  if (category === 'parking') return 'parking';
  if (category === 'fuel') return 'gas';
  return 'misc';
}

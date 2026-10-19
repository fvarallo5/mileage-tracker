import { PERIODS, formatRangeMdY } from '../../lib/period.js';
import { ICO } from './icons.jsx';
import { milesFmt, moneyFmt } from './format.js';

export default function PeriodRail({
  period,
  setPeriod,
  range,
  mileageRate,
  onExport,
  primaryLabel = 'New job',
  onPrimary,
  exportLabel = 'Export',
}) {
  return (
    <>
      <section className="mgr-controls metal" aria-label="Period and actions">
        <div className="seg well" role="group" aria-label="Period">
          {PERIODS.map(([key, label]) => (
            <button
              key={key}
              type="button"
              aria-pressed={period === key}
              className={period === key ? 'fill-blue' : ''}
              onClick={() => setPeriod(key)}
            >
              {label}
            </button>
          ))}
        </div>
        <div className="range">
          <span className="step fill-steel" aria-hidden="true">{ICO.prev}</span>
          <div className="lbl num">
            {formatRangeMdY(range.start, range.end)}
            <small>IRS rate {moneyFmt.format(mileageRate)}/mi</small>
          </div>
          <span className="step fill-steel" aria-hidden="true">{ICO.next}</span>
        </div>
        <div className="btn-row">
          <button type="button" className="btn fill-steel" onClick={onExport}>
            {ICO.export}
            {exportLabel}
          </button>
          {onPrimary ? (
            <button type="button" className="btn fill-blue" onClick={onPrimary}>
              {ICO.plus}
              {primaryLabel}
            </button>
          ) : (
            <span />
          )}
        </div>
      </section>
    </>
  );
}

export function PeriodMini({ period, onExport, onPrimary }) {
  const letter = (period || 'month')[0].toUpperCase();
  return (
    <section className="mgr-controls c-mini metal">
      <button type="button" className="icon-btn fill-blue" title={`Period: ${period}`}>
        {letter}
      </button>
      {onExport ? (
        <button type="button" className="icon-btn fill-steel" title="Export" onClick={onExport}>
          {ICO.export}
        </button>
      ) : null}
      {onPrimary ? (
        <button type="button" className="icon-btn fill-blue" title={primaryLabelSafe(onPrimary)} onClick={onPrimary}>
          {ICO.plus}
        </button>
      ) : null}
    </section>
  );
}

function primaryLabelSafe() {
  return 'Add';
}

export function rateLine(mileageRate) {
  return `IRS rate ${moneyFmt.format(mileageRate)}/mi`;
}

export { milesFmt, moneyFmt };

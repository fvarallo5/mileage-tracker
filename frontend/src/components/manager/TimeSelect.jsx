import { formatTime12 } from '../../lib/planMonth.js';

const STEP_MIN = 30;

function padTime(mins) {
  const h = String(Math.floor(mins / 60)).padStart(2, '0');
  const m = String(mins % 60).padStart(2, '0');
  return `${h}:${m}`;
}

function buildTimes() {
  const times = [];
  for (let mins = 0; mins < 24 * 60; mins += STEP_MIN) times.push(padTime(mins));
  return times;
}

const TIMES = buildTimes();

export default function TimeSelect({ id, value, onChange, emptyLabel = '—' }) {
  const raw = String(value || '').slice(0, 5);
  const options = raw && !TIMES.includes(raw) ? [raw, ...TIMES] : TIMES;
  return (
    <select id={id} value={raw} onChange={(e) => onChange(e.target.value)}>
      <option value="">{emptyLabel}</option>
      {options.map((time) => (
        <option key={time} value={time}>{formatTime12(time)}</option>
      ))}
    </select>
  );
}

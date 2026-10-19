import { ICO } from './icons.jsx';
import { avatarStyle, initials, sparkPath } from './deskKit.js';
import { milesFmt, moneyFmt } from './format.js';

export function Spark({ values, color, id }) {
  const { line, area } = sparkPath(values);
  return (
    <svg className="spark" viewBox="0 0 200 34" preserveAspectRatio="none" aria-hidden="true">
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={color} stopOpacity=".35" />
          <stop offset="1" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={area} fill={`url(#${id})`} />
      <path d={line} fill="none" stroke={color} strokeWidth="1.6" vectorEffect="non-scaling-stroke" strokeLinejoin="round" />
    </svg>
  );
}

export function KpiCard({ icon, tone, label, value, unit, spark, sparkId, foot, lit = false }) {
  const color = tone === 'pos' ? '#34d399' : tone === 'money' ? '#fbbf24' : tone === 'alert' ? '#f87171' : '#3b9eff';
  return (
    <article className={`card kpi metal chrome-edge sheen${lit ? ' is-lit' : ''} s2`}>
      <div className="kpi-top">
        <span className={`kpi-ico tile ${tone}`}>{icon}</span>
        {label}
      </div>
      <div className="kpi-value metal-text num">
        {value}
        {unit ? <small>{unit}</small> : null}
      </div>
      {spark ? <Spark values={spark} color={color} id={sparkId} /> : null}
      {foot ? <div className="kpi-foot">{foot}</div> : null}
    </article>
  );
}

export function Avatar({ name, status, seed }) {
  return (
    <span className="avatar" style={avatarStyle(seed || name)}>
      {initials(name)}
      {status ? <i className={`st ${status}`} /> : null}
    </span>
  );
}

export function EmptyHint({ children }) {
  return <p className="empty" style={{ padding: '12px 4px' }}>{children}</p>;
}

export function SearchWell({ value, onChange, placeholder, shortcut = '/' }) {
  return (
    <label className="search well">
      {ICO.search}
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        aria-label={placeholder}
        style={{ flex: 1, border: 0, background: 'transparent', color: 'inherit', font: 'inherit', outline: 'none', minWidth: 0 }}
      />
      {shortcut ? <kbd style={{ marginLeft: 'auto' }}>{shortcut}</kbd> : null}
    </label>
  );
}

export { milesFmt, moneyFmt };

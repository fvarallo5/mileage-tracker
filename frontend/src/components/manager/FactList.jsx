function dash(value) {
  const text = String(value || '').trim();
  return text || '—';
}

export default function FactList({ rows, className = '' }) {
  return (
    <dl className={`settings-facts${className ? ` ${className}` : ''}`}>
      {(rows || []).map((row) => (
        <div key={row.label} className="settings-fact">
          <dt>{row.label}</dt>
          <dd>{dash(row.value)}</dd>
        </div>
      ))}
    </dl>
  );
}

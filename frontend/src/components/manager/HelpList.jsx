export default function HelpList({ items, footer }) {
  return (
    <div className="help-list">
      {(items || []).map((row) => (
        <details key={row.title} className="help-item">
          <summary>{row.title}</summary>
          <p>{row.body}</p>
        </details>
      ))}
      {footer ? <p className="field-hint help-foot">{footer}</p> : null}
    </div>
  );
}

import { DESK_PAGES, accessLabel, defaultAccess, isAdminRole } from '../../lib/roles.js';

export function AccessSummary({ role, access }) {
  return <p className="access-summary">{accessLabel(role, access)}</p>;
}

export default function AccessFields({ role, access, onChange, idPrefix = 'access' }) {
  if (isAdminRole(role)) {
    return <p className="field-hint">Full desk. Can invite and edit people.</p>;
  }
  if (role !== 'dispatcher') {
    return <p className="field-hint">Work stays in the TrekTrack phone app.</p>;
  }
  const current = { ...defaultAccess('dispatcher'), ...access };
  return (
    <div className="access-grid">
      {DESK_PAGES.map((page) => (
        <label key={page.id} className="access-opt">
          <input
            id={`${idPrefix}-${page.id}`}
            type="checkbox"
            checked={Boolean(current[page.id])}
            onChange={(e) => onChange({ ...current, [page.id]: e.target.checked })}
          />
          {page.label}
        </label>
      ))}
    </div>
  );
}

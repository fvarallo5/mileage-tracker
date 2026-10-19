export function Icon({ d, children, className = 'i' }) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden="true">
      {children || (Array.isArray(d) ? d.map((p) => <path key={p} d={p} />) : <path d={d} />)}
    </svg>
  );
}

export const NAV_ICONS = {
  overview: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="3" width="7" height="9" rx="1.5" />
      <rect x="14" y="3" width="7" height="5" rx="1.5" />
      <rect x="14" y="12" width="7" height="9" rx="1.5" />
      <rect x="3" y="16" width="7" height="5" rx="1.5" />
    </svg>
  ),
  drivers: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
      <circle cx="12" cy="12" r="2.5" />
      <path d="M12 14.5V21M9.6 11.2 3.4 9.8M14.4 11.2l6.2-1.4" />
    </svg>
  ),
  home: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
      <circle cx="12" cy="12" r="2.5" />
      <path d="M12 14.5V21M9.6 11.2 3.4 9.8M14.4 11.2l6.2-1.4" />
    </svg>
  ),
  jobs: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="4" width="5" height="16" rx="1.5" />
      <rect x="10" y="4" width="5" height="11" rx="1.5" />
      <rect x="17" y="4" width="4" height="7" rx="1.5" />
    </svg>
  ),
  plan: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M8 3v4M16 3v4M3 10h18" />
    </svg>
  ),
  trips: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="6" cy="19" r="2.5" />
      <circle cx="18" cy="5" r="2.5" />
      <path d="M8.5 19H16a3.5 3.5 0 0 0 0-7H8a3.5 3.5 0 0 1 0-7h7.5" />
    </svg>
  ),
  expenses: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M5 3h14v18l-3-2-2 2-2-2-2 2-2-2-3 2z" />
      <path d="M9 8h6M9 12h6M9 16h3" />
    </svg>
  ),
  review: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M4 20V10M10 20V4M16 20v-7M22 20H2" />
    </svg>
  ),
  books: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="6" width="18" height="13" rx="2" />
      <path d="M3 10h18M8 6V4h8v2" />
    </svg>
  ),
  people: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="9" cy="8" r="3.5" />
      <path d="M2.5 20a6.5 6.5 0 0 1 13 0" />
      <path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 14a6 6 0 0 1 3.5 6" />
    </svg>
  ),
  profile: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M20 18h0" />
      <circle cx="16" cy="6" r="2" />
      <circle cx="10" cy="12" r="2" />
      <circle cx="18" cy="18" r="2" />
    </svg>
  ),
};

export const ICO = {
  search: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" />
    </svg>
  ),
  plus: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 5v14M5 12h14" />
    </svg>
  ),
  export: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 4v11M7 10l5 5 5-5M5 20h14" />
    </svg>
  ),
  chev: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="m10 6 6 6-6 6" />
    </svg>
  ),
  prev: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="m14 6-6 6 6 6" />
    </svg>
  ),
  next: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="m10 6 6 6-6 6" />
    </svg>
  ),
  bolt: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M13 2 4 14h7l-1 8 9-12h-7z" />
    </svg>
  ),
  mail: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <path d="m3 7 9 6 9-6" />
    </svg>
  ),
  board: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="4" width="5" height="16" rx="1.5" />
      <rect x="10" y="4" width="5" height="11" rx="1.5" />
      <rect x="17" y="4" width="4" height="7" rx="1.5" />
    </svg>
  ),
  list: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01" />
    </svg>
  ),
  map: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="m9 4-6 2v14l6-2 6 2 6-2V4l-6 2z" />
      <path d="M9 4v14M15 6v14" />
    </svg>
  ),
  signout: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 17l5-5-5-5M15 12H3" />
    </svg>
  ),
  collapse: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="4" width="18" height="16" rx="2.5" />
      <path d="M9 4v16M15 10l-2 2 2 2" />
    </svg>
  ),
  miles: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M4 18a8 8 0 1 1 16 0" />
      <path d="m12 18 4-6" />
    </svg>
  ),
  money: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 3v18M16.5 7.5c-.8-1.3-2.5-2-4.5-2-2.5 0-4 1.2-4 3s1.5 2.6 4 3.2 4.5 1.4 4.5 3.3-1.8 3.2-4.5 3.2c-2.2 0-4-.8-4.8-2.2" />
    </svg>
  ),
  trips: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M3 17l6-6 4 4 8-8" />
      <path d="M15 7h6v6" />
    </svg>
  ),
  alert: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 3 2 20h20z" />
      <path d="M12 10v4M12 17.5v.01" />
    </svg>
  ),
  costs: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M4 7h16v10H4z" />
      <circle cx="12" cy="12" r="2.5" />
      <path d="M7 7v10M17 7v10" opacity=".4" />
    </svg>
  ),
  jobs: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="7" width="18" height="13" rx="2" />
      <path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18" />
    </svg>
  ),
  camera: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M4 8h3l2-3h6l2 3h3v11H4z" />
      <circle cx="12" cy="13" r="3.5" />
    </svg>
  ),
  pod: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="m12 3 8 4.5v9L12 21l-8-4.5v-9z" />
      <path d="m4 7.5 8 4.5 8-4.5M12 12v9" />
    </svg>
  ),
};

import { useEffect, useState } from 'react';

function storedTheme() {
  try {
    return localStorage.getItem('trektrack-theme') || 'dark';
  } catch {
    return 'dark';
  }
}

function applyTheme(next) {
  try {
    localStorage.setItem('trektrack-theme', next);
  } catch {
    /* ignore */
  }
  if (next === 'system') {
    document.documentElement.removeAttribute('data-theme');
  } else {
    document.documentElement.setAttribute('data-theme', next);
  }
  window.dispatchEvent(new Event('trektrack-theme'));
}

const ICONS = {
  light: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
    </svg>
  ),
  dark: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z" />
    </svg>
  ),
  system: (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="4" width="18" height="12" rx="2" />
      <path d="M8 20h8M12 16v4" />
    </svg>
  ),
};

export default function ThemeToggle() {
  const [theme, setTheme] = useState(storedTheme);

  useEffect(() => {
    function sync() {
      setTheme(storedTheme());
    }
    window.addEventListener('trektrack-theme', sync);
    return () => window.removeEventListener('trektrack-theme', sync);
  }, []);

  function pick(next) {
    applyTheme(next);
    setTheme(next);
  }

  return (
    <div className="theme-seg well" role="group" aria-label="Theme">
      {[
        ['light', 'Light'],
        ['dark', 'Dark'],
        ['system', 'System'],
      ].map(([id, label]) => (
        <button
          key={id}
          type="button"
          aria-pressed={theme === id}
          title={label}
          className={theme === id ? 'fill-steel' : ''}
          onClick={() => pick(id)}
        >
          {ICONS[id]}
        </button>
      ))}
    </div>
  );
}

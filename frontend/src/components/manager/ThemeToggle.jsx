import { useState } from 'react';

function currentTheme() {
  if (typeof document === 'undefined') return 'light';
  return document.documentElement.getAttribute('data-theme') || 'light';
}

export default function ThemeToggle() {
  const [theme, setTheme] = useState(currentTheme);

  function toggle() {
    const next = theme === 'light' ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', next);
    try {
      localStorage.setItem('trektrack-theme', next);
    } catch {
      /* ignore */
    }
    setTheme(next);
  }

  return (
    <button type="button" className="btn-ghost btn-sm" onClick={toggle}>
      {theme === 'light' ? 'Dark mode' : 'Light mode'}
    </button>
  );
}

import { useEffect, useId, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { suggestAddresses } from '../../lib/geo.js';

function filterRecents(recents, query) {
  const q = query.trim().toLowerCase();
  if (q.length < 2) return recents.slice(0, 6);
  return recents.filter((row) => row.label.toLowerCase().includes(q)).slice(0, 6);
}

export default function AddressSuggest({ id, value, onChange, onSelect, recents = [] }) {
  const listId = useId();
  const inputRef = useRef(null);
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState([]);
  const [active, setActive] = useState(0);
  const [box, setBox] = useState(null);

  function place() {
    const el = inputRef.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    setBox({
      top: r.bottom + 4,
      left: r.left,
      width: Math.max(r.width, 220),
    });
  }

  useEffect(() => {
    if (!open) return undefined;
    place();
    function onWin() {
      place();
    }
    window.addEventListener('resize', onWin);
    window.addEventListener('scroll', onWin, true);
    return () => {
      window.removeEventListener('resize', onWin);
      window.removeEventListener('scroll', onWin, true);
    };
  }, [open]);

  useEffect(() => {
    const q = value.trim();
    const local = filterRecents(recents, q);
    if (q.length < 3) {
      setItems(local);
      setActive(0);
      return undefined;
    }
    let cancelled = false;
    const t = window.setTimeout(async () => {
      try {
        const remote = await suggestAddresses(q);
        if (cancelled) return;
        const seen = new Set(local.map((row) => row.label.toLowerCase()));
        const merged = [...local];
        for (const row of remote) {
          const idKey = row.label.toLowerCase();
          if (seen.has(idKey)) continue;
          seen.add(idKey);
          merged.push(row);
        }
        setItems(merged.slice(0, 8));
        setActive(0);
      } catch {
        if (!cancelled) setItems(local);
      }
    }, 280);
    return () => {
      cancelled = true;
      window.clearTimeout(t);
    };
  }, [value, recents]);

  function choose(row) {
    onSelect(row);
    setOpen(false);
  }

  function onKeyDown(e) {
    if (!open && (e.key === 'ArrowDown' || e.key === 'ArrowUp')) {
      setOpen(true);
      return;
    }
    if (!open || items.length === 0) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive((i) => (i + 1) % items.length);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActive((i) => (i - 1 + items.length) % items.length);
    } else if (e.key === 'Enter' && items[active]) {
      e.preventDefault();
      choose(items[active]);
    } else if (e.key === 'Escape') {
      setOpen(false);
    }
  }

  const showList = open && items.length > 0 && box;

  return (
    <>
      <input
        ref={inputRef}
        id={id}
        value={value}
        autoComplete="off"
        role="combobox"
        aria-expanded={showList}
        aria-controls={listId}
        aria-autocomplete="list"
        onChange={(e) => {
          onChange(e.target.value);
          setOpen(true);
        }}
        onFocus={() => {
          place();
          setOpen(true);
        }}
        onBlur={() => {
          window.setTimeout(() => setOpen(false), 160);
        }}
        onKeyDown={onKeyDown}
      />
      {showList
        ? createPortal(
            <ul
              id={listId}
              className="addr-suggest-list"
              role="listbox"
              style={{ top: box.top, left: box.left, width: box.width }}
            >
              {items.map((row, i) => (
                <li key={`${row.source}-${row.label}-${i}`} role="presentation">
                  <button
                    type="button"
                    role="option"
                    aria-selected={i === active}
                    className={i === active ? 'on' : ''}
                    onMouseDown={(e) => e.preventDefault()}
                    onClick={() => choose(row)}
                  >
                    <span>{row.label}</span>
                    {row.source === 'recent' ? <span className="addr-suggest-meta">Recent</span> : null}
                  </button>
                </li>
              ))}
            </ul>,
            document.body,
          )
        : null}
    </>
  );
}

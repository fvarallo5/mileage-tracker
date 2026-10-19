import { createContext, useContext, useEffect } from 'react';

export const DeskNav = createContext(null);

export function useDeskNav() {
  return useContext(DeskNav);
}

/** Pass a factory that returns { header, rail, mini }. Re-runs when `deps` change. */
export function useDeskChrome(factory, deps) {
  const nav = useDeskNav();
  useEffect(() => {
    if (!nav) return undefined;
    const next = factory() || {};
    nav.setHeader?.(next.header ?? null);
    nav.setRail?.(next.rail ?? null);
    nav.setMini?.(next.mini ?? null);
    return () => {
      nav.setHeader?.(null);
      nav.setRail?.(null);
      nav.setMini?.(null);
    };
    // factory is recreated each render; deps are the real inputs
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
}

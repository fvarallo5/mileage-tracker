function toRad(n) {
  return (n * Math.PI) / 180;
}

export function milesBetween(a, b) {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h = Math.sin(dLat / 2) ** 2
    + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 3958.8 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

// Earliest pickup starts the run. Each next stop is the nearest remaining pickup.
export function nearestOrder(stops) {
  const located = [];
  const rest = [];
  for (const stop of stops || []) {
    if (Number.isFinite(stop.lat) && Number.isFinite(stop.lng)) located.push(stop);
    else rest.push(stop);
  }
  located.sort((a, b) => String(a.time || '99:99').localeCompare(String(b.time || '99:99')));
  const ordered = [];
  const pool = [...located];
  if (pool.length) ordered.push(pool.shift());
  while (pool.length) {
    const current = ordered[ordered.length - 1];
    let best = 0;
    let bestMiles = Infinity;
    pool.forEach((stop, index) => {
      const miles = milesBetween(current, stop);
      if (miles < bestMiles) {
        bestMiles = miles;
        best = index;
      }
    });
    ordered.push(pool.splice(best, 1)[0]);
  }
  return [...ordered, ...rest].map((stop) => stop.id);
}

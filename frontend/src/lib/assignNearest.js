import { milesBetween } from './routeOrder.js';

function coords(ping) {
  if (ping?.lat == null || ping?.lng == null || ping.lat === '' || ping.lng === '') return null;
  const lat = Number(ping.lat);
  const lng = Number(ping.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  return { lat, lng };
}

export function pingOnDay(ping, day) {
  const seen = String(ping?.seen_at || '').slice(0, 10);
  return seen === day && coords(ping) != null;
}

// Closest ping wins. An equal distance keeps the earlier ping.
export function nearestPing(point, pings) {
  let best = null;
  let bestMiles = Infinity;
  for (const ping of pings || []) {
    const at = coords(ping);
    if (!at) continue;
    const miles = milesBetween(point, at);
    if (miles < bestMiles) {
      bestMiles = miles;
      best = ping;
    }
  }
  return best;
}

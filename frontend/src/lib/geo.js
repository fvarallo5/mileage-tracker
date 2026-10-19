import { composeAddress, toStateCode, trim } from './address.js';

const NOMINATIM = 'https://nominatim.openstreetmap.org/search';
const PHOTON = 'https://photon.komoot.io/api/';
const OSRM = 'https://router.project-osrm.org/route/v1/driving';

function cacheGet(key) {
  try {
    const raw = sessionStorage.getItem(key);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function cacheSet(key, value) {
  try {
    sessionStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* quota */
  }
}

export function jobAddress(job, prefix) {
  const composed = composeAddress({
    line1: job[`${prefix}_line1`] || '',
    line2: job[`${prefix}_line2`] || '',
    city: job[`${prefix}_city`] || '',
    state: job[`${prefix}_state`] || '',
    zip: job[`${prefix}_zip`] || '',
  });
  return composed || trim(job[`${prefix}_address`]);
}

export function houseNumberFromQuery(query) {
  const m = trim(query).match(/^(\d+[A-Za-z]?)\b/);
  return m ? m[1] : '';
}

function finishHit({ line1, city, state, zip, business = '', source }) {
  const hit = {
    line1: trim(line1),
    line2: '',
    city: trim(city),
    state: toStateCode(state),
    zip: trim(zip),
    business: trim(business),
    source,
  };
  if (!hit.line1 && !hit.city) return null;
  hit.label = [hit.business, composeAddress(hit)].filter(Boolean).join(' · ');
  return hit;
}

function attachHouse(hit, typedHouse) {
  if (!hit || !typedHouse) return hit;
  if (houseNumberFromQuery(hit.line1)) return hit;
  return finishHit({
    ...hit,
    line1: `${typedHouse} ${hit.line1}`.replace(/\s+/g, ' ').trim(),
    source: hit.source,
  });
}

function parsePhotonFeature(feature) {
  const p = feature?.properties || {};
  const cc = String(p.countrycode || '').toLowerCase();
  if (cc && cc !== 'us') return null;
  const street = trim(p.street);
  const number = trim(p.housenumber);
  const line1 = [number, street].filter(Boolean).join(' ') || trim(p.name);
  const city = trim(p.city || p.town || p.village || p.locality || p.district);
  const poi = p.osm_key === 'amenity' || p.osm_key === 'shop' || p.osm_key === 'tourism' || p.osm_key === 'office';
  return finishHit({
    line1,
    city,
    state: p.state,
    zip: p.postcode,
    business: poi ? trim(p.name) : '',
    source: 'map',
  });
}

function parseNominatimRow(row) {
  const a = row?.address || {};
  const line1 = [trim(a.house_number), trim(a.road || a.pedestrian || a.residential || a.street)]
    .filter(Boolean)
    .join(' ') || trim(String(row.display_name || '').split(',')[0]);
  const city = trim(a.city || a.town || a.village || a.hamlet || a.township || a.municipality);
  const poi = trim(a.amenity || a.shop || a.building || a.office);
  return finishHit({
    line1,
    city,
    state: a.state,
    zip: a.postcode,
    business: poi,
    source: 'map',
  });
}

async function suggestPhoton(q) {
  const url = `${PHOTON}?q=${encodeURIComponent(q)}&limit=8&lang=en`;
  const res = await fetch(url, { headers: { Accept: 'application/json' } });
  if (!res.ok) return [];
  const data = await res.json();
  return (data.features || []).map(parsePhotonFeature).filter(Boolean);
}

async function suggestNominatim(q) {
  const url = `${NOMINATIM}?format=jsonv2&addressdetails=1&limit=5&countrycodes=us&q=${encodeURIComponent(q)}`;
  const res = await fetch(url, { headers: { Accept: 'application/json' } });
  if (!res.ok) return [];
  const data = await res.json();
  return (Array.isArray(data) ? data : []).map(parseNominatimRow).filter(Boolean);
}

function suggestionScore(hit, typedHouse) {
  const house = houseNumberFromQuery(hit.line1);
  if (typedHouse && house.toLowerCase() === typedHouse.toLowerCase()) return 0;
  if (typedHouse && !house) return 2;
  if (typedHouse && house) return 6;
  if (house) return 1;
  return 3;
}

export async function suggestAddresses(query) {
  const q = trim(query);
  if (q.length < 3) return [];
  const key = `sug3:${q.toLowerCase()}`;
  const cached = cacheGet(key);
  if (Array.isArray(cached)) return cached;

  const typedHouse = houseNumberFromQuery(q);
  const [nominatim, photon] = await Promise.all([
    suggestNominatim(q).catch(() => []),
    suggestPhoton(q).catch(() => []),
  ]);

  const seen = new Set();
  const rows = [];
  for (const raw of [...nominatim, ...photon]) {
    const hit = attachHouse(raw, typedHouse);
    if (!hit) continue;
    const id = hit.label.toLowerCase();
    if (seen.has(id)) continue;
    seen.add(id);
    rows.push(hit);
  }

  rows.sort((a, b) => suggestionScore(a, typedHouse) - suggestionScore(b, typedHouse));
  const matched = typedHouse
    ? rows.filter((row) => houseNumberFromQuery(row.line1).toLowerCase() === typedHouse.toLowerCase())
    : rows;
  const out = (matched.length ? matched : rows).slice(0, 8);
  cacheSet(key, out);
  return out;
}

export async function geocodeAddress(query) {
  const q = trim(query);
  if (!q) return null;
  const key = `geo:${q.toLowerCase()}`;
  const hit = cacheGet(key);
  if (hit) return hit;
  const url = `${NOMINATIM}?format=json&limit=1&q=${encodeURIComponent(q)}`;
  const res = await fetch(url, {
    headers: { Accept: 'application/json' },
  });
  if (!res.ok) return null;
  const rows = await res.json();
  const row = rows?.[0];
  if (!row) return null;
  const point = { lat: Number(row.lat), lng: Number(row.lon) };
  if (!Number.isFinite(point.lat) || !Number.isFinite(point.lng)) return null;
  cacheSet(key, point);
  return point;
}

function routeKey(from, to) {
  const r = (n) => Number(n).toFixed(4);
  return `route:${r(from.lat)},${r(from.lng)}:${r(to.lat)},${r(to.lng)}`;
}

// Road route from the public OSRM server. Miles follow streets, not a straight line.
export async function drivingRoute(from, to) {
  if (!from || !to) return null;
  const key = routeKey(from, to);
  const cached = cacheGet(key);
  if (cached?.miles) return cached;
  const url = `${OSRM}/${from.lng},${from.lat};${to.lng},${to.lat}?overview=simplified&geometries=geojson`;
  const res = await fetch(url);
  if (!res.ok) return null;
  const data = await res.json();
  const route = data?.routes?.[0];
  const meters = route?.distance;
  if (!Number.isFinite(meters)) return null;
  const coordinates = Array.isArray(route?.geometry?.coordinates)
    ? route.geometry.coordinates
      .map(([lng, lat]) => [lat, lng])
      .filter(([lat, lng]) => Number.isFinite(lat) && Number.isFinite(lng))
    : [];
  const out = {
    miles: meters / 1609.344,
    minutes: Number.isFinite(route.duration) ? Math.max(1, Math.round(route.duration / 60)) : null,
    coordinates,
  };
  cacheSet(key, out);
  return out;
}

export async function drivingMinutes(from, to) {
  const route = await drivingRoute(from, to);
  return route?.minutes ?? null;
}

export async function drivingEstimate(fromQuery, toQuery) {
  const from = await geocodeAddress(fromQuery);
  const to = await geocodeAddress(toQuery);
  if (!from || !to) {
    throw new Error('Could not find one of the addresses on the map.');
  }
  const route = await drivingRoute(from, to);
  if (!route) throw new Error('Could not estimate the drive.');
  return { miles: route.miles, minutes: route.minutes, from, to, coordinates: route.coordinates };
}

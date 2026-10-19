import { isoDate } from './period.js';

export const DEFAULT_QUOTE_RATES = {
  quotePerMile: 3,
  quoteMinimum: 35,
  weekendMult: 1.25,
  afterHoursMult: 1.25,
  afterHoursStart: '18:00',
  afterHoursEnd: '06:00',
  companyTakePct: 0.3,
};

export const SERVICE_LEVELS = [
  { id: '', label: 'Standard' },
  { id: 'same_day', label: 'Same day' },
  { id: 'rush', label: 'Rush' },
  { id: 'wait', label: 'Wait time' },
  { id: 'extra_piece', label: 'Extra piece' },
];

export function serviceLevelLabel(id) {
  return SERVICE_LEVELS.find((row) => row.id === id)?.label || '';
}

export const WEEKDAYS = [
  { id: 1, label: 'Mon' },
  { id: 2, label: 'Tue' },
  { id: 3, label: 'Wed' },
  { id: 4, label: 'Thu' },
  { id: 5, label: 'Fri' },
  { id: 6, label: 'Sat' },
  { id: 0, label: 'Sun' },
];

export function ratesFromOrg(org = {}) {
  const n = (v, fallback) => {
    const x = Number(v);
    return Number.isFinite(x) ? x : fallback;
  };
  const t = (v, fallback) => {
    const s = String(v ?? '').slice(0, 5);
    return /^\d{2}:\d{2}$/.test(s) ? s : fallback;
  };
  return {
    quotePerMile: n(org.quotePerMile ?? org.quote_per_mile, DEFAULT_QUOTE_RATES.quotePerMile),
    quoteMinimum: n(org.quoteMinimum ?? org.quote_minimum, DEFAULT_QUOTE_RATES.quoteMinimum),
    weekendMult: n(org.weekendMult ?? org.quote_weekend_mult, DEFAULT_QUOTE_RATES.weekendMult),
    afterHoursMult: n(org.afterHoursMult ?? org.quote_after_hours_mult, DEFAULT_QUOTE_RATES.afterHoursMult),
    afterHoursStart: t(org.afterHoursStart ?? org.quote_after_hours_start, DEFAULT_QUOTE_RATES.afterHoursStart),
    afterHoursEnd: t(org.afterHoursEnd ?? org.quote_after_hours_end, DEFAULT_QUOTE_RATES.afterHoursEnd),
    companyTakePct: n(org.companyTakePct ?? org.company_take_pct, DEFAULT_QUOTE_RATES.companyTakePct),
  };
}

export function minutesFromTime(value) {
  if (!value) return null;
  const parts = String(value).split(':');
  const h = Number(parts[0]);
  const m = Number(parts[1] ?? 0);
  if (!Number.isFinite(h) || !Number.isFinite(m)) return null;
  return h * 60 + m;
}

export function addHours(time, hours) {
  const mins = minutesFromTime(time);
  if (mins == null) return '';
  const next = ((mins + Math.round(Number(hours) * 60)) % (24 * 60) + 24 * 60) % (24 * 60);
  const h = Math.floor(next / 60);
  const m = next % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

export function isWeekend(iso) {
  if (!iso) return false;
  const d = new Date(`${iso}T12:00:00`);
  if (Number.isNaN(d.getTime())) return false;
  const day = d.getDay();
  return day === 0 || day === 6;
}

export function isAfterHours(time, start = DEFAULT_QUOTE_RATES.afterHoursStart, end = DEFAULT_QUOTE_RATES.afterHoursEnd) {
  const t = minutesFromTime(time);
  const s = minutesFromTime(start);
  const e = minutesFromTime(end);
  if (t == null || s == null || e == null) return false;
  if (s === e) return false;
  if (s < e) return t >= s && t < e;
  return t >= s || t < e;
}

export function weekdayDates(startIso, weekdays, weeks = 8) {
  const wanted = new Set((weekdays || []).map(Number));
  if (!wanted.size) return [startIso];
  const start = new Date(`${startIso}T12:00:00`);
  if (Number.isNaN(start.getTime())) return [startIso];
  const end = new Date(start);
  end.setDate(end.getDate() + weeks * 7 - 1);
  const out = [];
  for (const d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    if (wanted.has(d.getDay())) out.push(isoDate(d));
  }
  return out.length ? out : [startIso];
}

function roundMoney(n) {
  return Math.round((Number(n) + Number.EPSILON) * 100) / 100;
}

function clamp(n, min, max) {
  return Math.min(max, Math.max(min, n));
}

export function computeQuote({
  miles,
  date,
  pickupTime,
  rates,
  weekendOverride,
  afterHoursOverride,
  quotedAmount,
  quoteManual = false,
  takePct,
  serviceAddon,
} = {}) {
  const r = { ...DEFAULT_QUOTE_RATES, ...rates };
  const weekend = weekendOverride == null ? isWeekend(date) : Boolean(weekendOverride);
  const afterHours = afterHoursOverride == null
    ? isAfterHours(pickupTime, r.afterHoursStart, r.afterHoursEnd)
    : Boolean(afterHoursOverride);
  const take = clamp(Number(takePct ?? r.companyTakePct) || 0, 0, 0.9);

  let quote;
  if (quoteManual && quotedAmount !== '' && quotedAmount != null && Number.isFinite(Number(quotedAmount))) {
    quote = Number(quotedAmount);
  } else {
    const mi = Number(miles);
    const base = Math.max(r.quoteMinimum, (Number.isFinite(mi) ? mi : 0) * r.quotePerMile);
    quote = base;
    if (weekend) quote *= r.weekendMult;
    if (afterHours) quote *= r.afterHoursMult;
    const addon = Number(serviceAddon);
    if (Number.isFinite(addon) && addon > 0) quote += addon;
  }

  quote = roundMoney(quote);
  const companyTake = roundMoney(quote * take);
  const driverPay = roundMoney(quote - companyTake);
  return {
    quotedAmount: quote,
    driverPay,
    companyTake,
    takePct: take,
    weekend,
    afterHours,
  };
}

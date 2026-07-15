import { Router } from 'express';
import db from '../db.js';

const router = Router();

function getMileageRate() {
  const row = db.prepare('SELECT value FROM settings WHERE key = ?').get('mileage_rate');
  return Number(row?.value ?? 0.7);
}

function buildPeriodReport(periodKey, label, startDate, endDate, rate) {
  const stats = db
    .prepare(
      `SELECT
        COUNT(*) as trip_count,
        COALESCE(SUM(miles), 0) as total_miles,
        COALESCE(SUM(tips), 0) as total_tips
      FROM trips
      WHERE date >= ? AND date <= ?`
    )
    .get(startDate, endDate);

  const totalMiles = stats.total_miles;
  const totalTips = stats.total_tips;
  const mileageExpense = totalMiles * rate;
  const earningsPerMile = totalMiles > 0 ? totalTips / totalMiles : 0;
  const netEarnings = totalTips - mileageExpense;

  return {
    period: periodKey,
    label,
    start_date: startDate,
    end_date: endDate,
    trip_count: stats.trip_count,
    total_miles: round2(totalMiles),
    total_tips: round2(totalTips),
    mileage_rate: rate,
    mileage_expense: round2(mileageExpense),
    earnings_per_mile: round2(earningsPerMile),
    net_earnings: round2(netEarnings),
  };
}

function round2(n) {
  return Math.round(n * 100) / 100;
}

function getISOWeekStart(date) {
  const d = new Date(date);
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  return formatDate(d);
}

function getISOWeekEnd(date) {
  const start = new Date(getISOWeekStart(date));
  start.setDate(start.getDate() + 6);
  return formatDate(start);
}

function getMonthStart(date) {
  const d = new Date(date);
  return formatDate(new Date(d.getFullYear(), d.getMonth(), 1));
}

function getMonthEnd(date) {
  const d = new Date(date);
  return formatDate(new Date(d.getFullYear(), d.getMonth() + 1, 0));
}

function getYearStart(date) {
  const d = new Date(date);
  return formatDate(new Date(d.getFullYear(), 0, 1));
}

function getYearEnd(year) {
  return `${year}-12-31`;
}

function getYtdLabel(date) {
  const d = new Date(date + 'T12:00:00');
  return `YTD ${d.getFullYear()}`;
}

function formatDate(d) {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function getWeekLabel(start, end) {
  const s = new Date(start + 'T12:00:00');
  const e = new Date(end + 'T12:00:00');
  const opts = { month: 'short', day: 'numeric' };
  return `Week of ${s.toLocaleDateString('en-US', opts)} – ${e.toLocaleDateString('en-US', opts)}`;
}

function getMonthLabel(date) {
  const d = new Date(date + 'T12:00:00');
  return d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
}



router.get('/summary', (req, res) => {
  const rate = getMileageRate();
  const referenceDate = req.query.date || formatDate(new Date());

  const weekly = buildPeriodReport(
    'weekly',
    getWeekLabel(getISOWeekStart(referenceDate), getISOWeekEnd(referenceDate)),
    getISOWeekStart(referenceDate),
    getISOWeekEnd(referenceDate),
    rate
  );

  const monthly = buildPeriodReport(
    'monthly',
    getMonthLabel(referenceDate),
    getMonthStart(referenceDate),
    getMonthEnd(referenceDate),
    rate
  );

  const annual = buildPeriodReport(
    'annual',
    getYtdLabel(referenceDate),
    getYearStart(referenceDate),
    referenceDate,
    rate
  );

  res.json({ reference_date: referenceDate, weekly, monthly, annual });
});

router.get('/:period', (req, res) => {
  const { period } = req.params;
  const rate = getMileageRate();
  const count = Math.min(Number(req.query.count) || 6, 52);
  const referenceDate = req.query.date || formatDate(new Date());

  const reports = [];

  for (let i = 0; i < count; i++) {
    let refDate;
    let start;
    let end;
    let label;
    let key;

    if (period === 'weekly') {
      const d = new Date(referenceDate + 'T12:00:00');
      d.setDate(d.getDate() - i * 7);
      const dateStr = formatDate(d);
      start = getISOWeekStart(dateStr);
      end = getISOWeekEnd(dateStr);
      label = getWeekLabel(start, end);
      key = `week-${start}`;
    } else if (period === 'monthly') {
      const d = new Date(referenceDate + 'T12:00:00');
      d.setMonth(d.getMonth() - i);
      const dateStr = formatDate(d);
      start = getMonthStart(dateStr);
      end = getMonthEnd(dateStr);
      label = getMonthLabel(dateStr);
      key = `month-${start.slice(0, 7)}`;
    } else if (period === 'annual') {
      const refYear = new Date(referenceDate + 'T12:00:00').getFullYear();
      if (i === 0) {
        start = getYearStart(referenceDate);
        end = referenceDate;
        label = getYtdLabel(referenceDate);
        key = `ytd-${refYear}`;
      } else {
        const year = refYear - i;
        start = `${year}-01-01`;
        end = getYearEnd(year);
        label = String(year);
        key = `year-${year}`;
      }
    } else {
      return res.status(400).json({ error: 'period must be weekly, monthly, or annual' });
    }

    reports.push(buildPeriodReport(key, label, start, end, rate));
  }

  res.json({ period, reports });
});

export default router;
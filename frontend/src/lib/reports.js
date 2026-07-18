function round2(n) {
  return Math.round(n * 100) / 100;
}

function formatDate(d) {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function isoWeekStart(date) {
  const d = new Date(date + 'T12:00:00');
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  return formatDate(d);
}

function isoWeekEnd(date) {
  const start = new Date(isoWeekStart(date) + 'T12:00:00');
  start.setDate(start.getDate() + 6);
  return formatDate(start);
}

function monthStart(date) {
  const d = new Date(date + 'T12:00:00');
  return formatDate(new Date(d.getFullYear(), d.getMonth(), 1));
}

function monthEnd(date) {
  const d = new Date(date + 'T12:00:00');
  return formatDate(new Date(d.getFullYear(), d.getMonth() + 1, 0));
}

function yearStart(date) {
  const d = new Date(date + 'T12:00:00');
  return formatDate(new Date(d.getFullYear(), 0, 1));
}

function ytdLabel(date) {
  const year = new Date(date + 'T12:00:00').getFullYear();
  return `YTD ${year}`;
}

function weekLabel(start, end) {
  const opts = { month: 'short', day: 'numeric' };
  const s = new Date(start + 'T12:00:00');
  const e = new Date(end + 'T12:00:00');
  return `Week of ${s.toLocaleDateString('en-US', opts)} – ${e.toLocaleDateString('en-US', opts)}`;
}

function monthLabel(date) {
  const d = new Date(date + 'T12:00:00');
  return d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
}

function buildPeriodReport(trips, rate, periodKey, label, startDate, endDate) {
  // Business trips only — personal miles are not deductible.
  const inRange = trips.filter(
    (t) => t.is_business !== false && t.date >= startDate && t.date <= endDate,
  );
  const totalMiles = inRange.reduce((sum, t) => sum + t.miles, 0);
  const totalTips = inRange.reduce((sum, t) => sum + t.tips, 0);
  const mileageExpense = totalMiles * rate;
  const earningsPerMile = totalMiles > 0 ? totalTips / totalMiles : 0;

  return {
    period: periodKey,
    label,
    start_date: startDate,
    end_date: endDate,
    trip_count: inRange.length,
    total_miles: round2(totalMiles),
    total_tips: round2(totalTips),
    mileage_rate: rate,
    mileage_expense: round2(mileageExpense),
    earnings_per_mile: round2(earningsPerMile),
    net_earnings: round2(totalTips - mileageExpense),
  };
}

export function buildReportSummary(trips, mileageRate, referenceDate = formatDate(new Date())) {
  return {
    reference_date: referenceDate,
    weekly: buildPeriodReport(
      trips,
      mileageRate,
      'weekly',
      weekLabel(isoWeekStart(referenceDate), isoWeekEnd(referenceDate)),
      isoWeekStart(referenceDate),
      isoWeekEnd(referenceDate),
    ),
    monthly: buildPeriodReport(
      trips,
      mileageRate,
      'monthly',
      monthLabel(referenceDate),
      monthStart(referenceDate),
      monthEnd(referenceDate),
    ),
    annual: buildPeriodReport(
      trips,
      mileageRate,
      'annual',
      ytdLabel(referenceDate),
      yearStart(referenceDate),
      referenceDate,
    ),
  };
}

export function buildReportHistory(trips, period, mileageRate, count = 8, referenceDate = formatDate(new Date())) {
  const reports = [];

  for (let i = 0; i < count; i++) {
    let start;
    let end;
    let label;
    let key;

    if (period === 'weekly') {
      const d = new Date(referenceDate + 'T12:00:00');
      d.setDate(d.getDate() - i * 7);
      const dateStr = formatDate(d);
      start = isoWeekStart(dateStr);
      end = isoWeekEnd(dateStr);
      label = weekLabel(start, end);
      key = `week-${start}`;
    } else if (period === 'monthly') {
      const d = new Date(referenceDate + 'T12:00:00');
      d.setMonth(d.getMonth() - i);
      const dateStr = formatDate(d);
      start = monthStart(dateStr);
      end = monthEnd(dateStr);
      label = monthLabel(dateStr);
      key = `month-${start.slice(0, 7)}`;
    } else if (period === 'annual') {
      const refYear = new Date(referenceDate + 'T12:00:00').getFullYear();
      if (i === 0) {
        start = yearStart(referenceDate);
        end = referenceDate;
        label = ytdLabel(referenceDate);
        key = `ytd-${refYear}`;
      } else {
        const year = refYear - i;
        start = `${year}-01-01`;
        end = `${year}-12-31`;
        label = String(year);
        key = `year-${year}`;
      }
    } else {
      throw new Error('period must be weekly, monthly, or annual');
    }

    reports.push(buildPeriodReport(trips, mileageRate, key, label, start, end));
  }

  return reports;
}
import { isoDate } from './period.js';
import { isWeekend } from './quote.js';

export const SAMPLE_DRIVERS = [
  { user_id: 'sample-12', label: 'Maya Chen', driverNumber: '12' },
  { user_id: 'sample-4', label: 'Luis Ortega', driverNumber: '4' },
  { user_id: 'sample-9', label: 'Priya Shah', driverNumber: '9' },
];

const ROUTES = [
  { pickup_city: 'Englewood', dropoff_city: 'Hackensack', quote: 180, afterHours: false, driver: 'sample-12', number: '1042' },
  { pickup_city: 'Fort Lee', dropoff_city: 'Newark', quote: 140, afterHours: false, driver: 'sample-12', number: '1043' },
  { pickup_city: 'Teaneck', dropoff_city: 'Hoboken', quote: 165, afterHours: true, driver: 'sample-4', number: '1048' },
  { pickup_city: 'Englewood', dropoff_city: 'Jersey City', quote: 210, afterHours: false, driver: 'sample-4', number: '1051' },
  { pickup_city: 'Paramus', dropoff_city: 'Paterson', quote: 95, afterHours: false, driver: 'sample-9', number: '1055' },
  { pickup_city: 'Hackensack', dropoff_city: 'Clifton', quote: 120, afterHours: false, driver: 'sample-9', number: '1058' },
  { pickup_city: 'Englewood', dropoff_city: 'Manhattan', quote: 240, afterHours: true, driver: 'sample-12', number: '1060' },
  { pickup_city: 'Fort Lee', dropoff_city: 'Ridgewood', quote: 110, afterHours: false, driver: 'sample-4', number: '1064' },
  { pickup_city: 'Tenafly', dropoff_city: 'Newark', quote: 155, afterHours: false, driver: 'sample-9', number: '1067' },
  { pickup_city: 'Bergenfield', dropoff_city: 'Secaucus', quote: 130, afterHours: false, driver: 'sample-12', number: '1071' },
  { pickup_city: 'Englewood', dropoff_city: 'Passaic', quote: 88, afterHours: false, driver: 'sample-4', number: '1074', status: 'open' },
  { pickup_city: 'Hackensack', dropoff_city: 'Union City', quote: 102, afterHours: true, driver: 'sample-9', number: '1078', status: 'cancelled' },
];

function daysInRange(start, end) {
  const days = [];
  const cursor = new Date(`${start}T12:00:00`);
  const last = new Date(`${end}T12:00:00`);
  if (Number.isNaN(cursor.getTime()) || Number.isNaN(last.getTime())) return [isoDate(new Date())];
  while (cursor <= last && days.length < 62) {
    days.push(isoDate(cursor));
    cursor.setDate(cursor.getDate() + 1);
  }
  return days.length ? days : [start];
}

function money(quote, weekend, afterHours) {
  let amount = quote;
  if (weekend) amount *= 1.25;
  if (afterHours) amount *= 1.25;
  amount = Math.round(amount * 100) / 100;
  const take = Math.round(amount * 0.3 * 100) / 100;
  return { quoted_amount: amount, company_take: take, driver_pay: Math.round((amount - take) * 100) / 100 };
}

export function buildSampleReport(start, end) {
  const days = daysInRange(start, end);
  const jobs = ROUTES.map((route, i) => {
    const jobDate = days[Math.floor((i * (days.length - 1)) / Math.max(ROUTES.length - 1, 1))] || days[0];
    const weekend = isWeekend(jobDate);
    const afterHours = Boolean(route.afterHours);
    const pay = money(route.quote, weekend, afterHours);
    return {
      id: `sample-${route.number}`,
      job_date: jobDate,
      job_number: route.number,
      status: route.status || 'done',
      assigned_user_id: route.driver,
      pickup_city: route.pickup_city,
      dropoff_city: route.dropoff_city,
      quote_weekend: weekend,
      quote_after_hours: afterHours,
      ...pay,
    };
  });
  return { drivers: SAMPLE_DRIVERS, jobs };
}

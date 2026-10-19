import { digitsOnly, fillFormFromCustomer, findCustomerByCharge, numericOnly } from './accountForm.js';
import { suggestedCustomerId } from './accountMatch.js';
import { addressFromJob, composeAddress, trim } from './address.js';
import { isoDate } from './period.js';
import { addHours, computeQuote, isAfterHours, isWeekend } from './quote.js';

export function ratesForAccount(orgRates, customer) {
  if (!customer) return orgRates;
  const pick = (value, fallback) => {
    if (value == null || value === '') return fallback;
    const n = Number(value);
    return Number.isFinite(n) ? n : fallback;
  };
  return {
    ...orgRates,
    quotePerMile: pick(customer.quote_per_mile, orgRates.quotePerMile),
    quoteMinimum: pick(customer.quote_minimum, orgRates.quoteMinimum),
    weekendMult: pick(customer.quote_weekend_mult, orgRates.weekendMult),
    afterHoursMult: pick(customer.quote_after_hours_mult, orgRates.afterHoursMult),
    companyTakePct: pick(customer.company_take_pct, orgRates.companyTakePct),
  };
}

export function emptyAddress() {
  return { line1: '', line2: '', city: '', state: '', zip: '' };
}

export function emptyForm({
  assignedUserId = '',
  jobDate = isoDate(new Date()),
  takePct = 30,
  customerId = '',
  weightUnit = 'lb',
  jobPrefix = '',
} = {}) {
  return {
    job_number: String(jobPrefix || ''),
    job_date: jobDate,
    pickup_time: '',
    dropoff_time: '',
    pickup_name: '',
    pickup: emptyAddress(),
    pickup_phone: '',
    pickup_email: '',
    dropoff_name: '',
    dropoff: emptyAddress(),
    dropoff_phone: '',
    dropoff_email: '',
    details: '',
    notes: '',
    assigned_user_id: assignedUserId,
    customer_id: customerId || '',
    charge_number: '',
    item_count: '',
    weight_value: '',
    weight_unit: weightUnit === 'kg' ? 'kg' : 'lb',
    status: 'open',
    failure_reason: '',
    pod_note: '',
    attempt_fee: '',
    stop_order: '',
    cod_amount: '',
    cod_collected: false,
    estimated_miles: '',
    service_level: '',
    service_addon: '',
    quoted_amount: '',
    driver_pay: '',
    company_take: '',
    company_take_pct: String(takePct),
    quote_manual: false,
    quote_weekend: isWeekend(jobDate),
    quote_after_hours: false,
    weekdays: [],
    dropoffDirty: false,
    weekendDirty: false,
    afterHoursDirty: false,
    milesDirty: false,
    accountDirty: false,
  };
}

export function moneyOrNull(value) {
  if (value === '' || value == null) return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

export function withQuote(form, rates) {
  const take = Number(form.company_take_pct);
  const result = computeQuote({
    miles: form.estimated_miles,
    date: form.job_date,
    pickupTime: form.pickup_time,
    rates,
    weekendOverride: form.quote_weekend,
    afterHoursOverride: form.quote_after_hours,
    quotedAmount: form.quoted_amount,
    quoteManual: form.quote_manual,
    takePct: Number.isFinite(take) ? take / 100 : rates.companyTakePct,
    serviceAddon: form.service_addon,
  });
  return {
    ...form,
    quoted_amount: form.quote_manual && form.quoted_amount !== ''
      ? form.quoted_amount
      : String(result.quotedAmount),
    driver_pay: String(result.driverPay),
    company_take: String(result.companyTake),
    quote_weekend: result.weekend,
    quote_after_hours: result.afterHours,
  };
}

export function applyFormChange(prev, key, value, rates, customers) {
  let next = { ...prev, [key]: value };
  if (key === 'item_count') next.item_count = digitsOnly(value, 6);
  if (key === 'weight_value') next.weight_value = numericOnly(value);
  if (key === 'charge_number') {
    const code = digitsOnly(value, 5);
    next.charge_number = code;
    const hit = findCustomerByCharge(customers, code);
    if (hit) next = fillFormFromCustomer(next, hit);
  }
  if (key === 'customer_id') {
    const customer = (customers || []).find((row) => row.id === value) || null;
    next = fillFormFromCustomer({ ...prev, accountDirty: true }, customer);
  }
  if (key === 'pickup_time') {
    if (!prev.dropoffDirty) next.dropoff_time = value ? addHours(value, 2) : '';
    if (!prev.afterHoursDirty) {
      next.quote_after_hours = isAfterHours(
        next.pickup_time,
        rates.afterHoursStart,
        rates.afterHoursEnd,
      );
    }
  }
  if (key === 'dropoff_time') next.dropoffDirty = true;
  if (key === 'job_date' && !prev.weekendDirty) next.quote_weekend = isWeekend(next.job_date);
  if (key === 'quote_weekend') next.weekendDirty = true;
  if (key === 'quote_after_hours') next.afterHoursDirty = true;
  if (key === 'quoted_amount') next.quote_manual = true;
  if (key === 'pickup' || key === 'dropoff') next.milesDirty = false;
  if (key === 'estimated_miles') next.milesDirty = String(value ?? '').trim() !== '';
  if (key === 'customer_id') next.accountDirty = true;
  return withQuote(next, rates);
}

export function withSuggestedAccount(form, customers, orgRates) {
  const id = suggestedCustomerId(form, customers);
  if (id === (form.customer_id || '')) return form;
  const customer = (customers || []).find((row) => row.id === id);
  const rates = ratesForAccount(orgRates, customer);
  const next = { ...form, customer_id: id, charge_number: customer?.charge_number || form.charge_number || '' };
  if (!form.quote_manual) {
    next.company_take_pct = String(Math.round((rates.companyTakePct ?? 0.3) * 100));
  }
  return withQuote(next, rates);
}

export function payloadFromForm(form) {
  const pickup = {
    line1: trim(form.pickup.line1),
    line2: trim(form.pickup.line2),
    city: trim(form.pickup.city),
    state: trim(form.pickup.state).toUpperCase(),
    zip: trim(form.pickup.zip),
  };
  const dropoff = {
    line1: trim(form.dropoff.line1),
    line2: trim(form.dropoff.line2),
    city: trim(form.dropoff.city),
    state: trim(form.dropoff.state).toUpperCase(),
    zip: trim(form.dropoff.zip),
  };
  return {
    job_number: trim(form.job_number),
    job_date: form.job_date,
    pickup_time: trim(form.pickup_time) || null,
    dropoff_time: trim(form.dropoff_time) || null,
    job_time: trim(form.pickup_time) || null,
    pickup_name: trim(form.pickup_name),
    pickup_line1: pickup.line1,
    pickup_line2: pickup.line2,
    pickup_city: pickup.city,
    pickup_state: pickup.state,
    pickup_zip: pickup.zip,
    pickup_address: composeAddress(pickup),
    pickup_phone: trim(form.pickup_phone),
    pickup_email: trim(form.pickup_email),
    dropoff_name: trim(form.dropoff_name),
    dropoff_line1: dropoff.line1,
    dropoff_line2: dropoff.line2,
    dropoff_city: dropoff.city,
    dropoff_state: dropoff.state,
    dropoff_zip: dropoff.zip,
    dropoff_address: composeAddress(dropoff),
    dropoff_phone: trim(form.dropoff_phone),
    dropoff_email: trim(form.dropoff_email),
    details: trim(form.details),
    notes: trim(form.notes),
    assigned_user_id: form.assigned_user_id || null,
    customer_id: form.customer_id || null,
    item_count: (() => {
      if (form.item_count === '' || form.item_count == null) return null;
      const n = Number(form.item_count);
      return Number.isFinite(n) ? Math.round(n) : null;
    })(),
    weight_value: moneyOrNull(form.weight_value),
    weight_unit: form.weight_unit === 'kg' ? 'kg' : 'lb',
    status: form.status === 'done' ? 'delivered' : (form.status || 'open'),
    failure_reason: trim(form.failure_reason),
    pod_note: trim(form.pod_note),
    attempt_fee: moneyOrNull(form.attempt_fee),
    stop_order: (() => {
      if (form.stop_order === '' || form.stop_order == null) return null;
      const n = Number(form.stop_order);
      return Number.isFinite(n) ? Math.round(n) : null;
    })(),
    cod_amount: moneyOrNull(form.cod_amount),
    cod_collected: Boolean(form.cod_collected),
    estimated_miles: moneyOrNull(form.estimated_miles),
    service_level: trim(form.service_level),
    service_addon: moneyOrNull(form.service_addon),
    estimated_cost: moneyOrNull(form.quoted_amount),
    quoted_amount: moneyOrNull(form.quoted_amount),
    driver_pay: moneyOrNull(form.driver_pay),
    company_take: moneyOrNull(form.company_take),
    company_take_pct: (() => {
      const n = Number(form.company_take_pct);
      return Number.isFinite(n) ? n / 100 : null;
    })(),
    quote_manual: Boolean(form.quote_manual),
    quote_weekend: Boolean(form.quote_weekend),
    quote_after_hours: Boolean(form.quote_after_hours),
  };
}

export function formFromJob(job, { takePct = 30, jobDate, customers } = {}) {
  const pickup = addressFromJob(job, 'pickup');
  const dropoff = addressFromJob(job, 'dropoff');
  if (!pickup.city) pickup.city = trim(job.pickup_city);
  if (!dropoff.city) dropoff.city = trim(job.dropoff_city);
  return {
    job_number: job.job_number ?? '',
    job_date: job.job_date ?? jobDate ?? isoDate(new Date()),
    pickup_time: String(job.pickup_time || job.job_time || '').slice(0, 5),
    dropoff_time: String(job.dropoff_time || '').slice(0, 5),
    pickup_name: job.pickup_name ?? '',
    pickup,
    pickup_phone: job.pickup_phone ?? '',
    pickup_email: job.pickup_email ?? '',
    dropoff_name: job.dropoff_name ?? '',
    dropoff,
    dropoff_phone: job.dropoff_phone ?? '',
    dropoff_email: job.dropoff_email ?? '',
    details: job.details ?? '',
    notes: job.notes ?? '',
    assigned_user_id: job.assigned_user_id ?? '',
    customer_id: job.customer_id ?? '',
    charge_number: (customers || []).find((row) => row.id === job.customer_id)?.charge_number || '',
    item_count: job.item_count == null ? '' : String(job.item_count),
    weight_value: job.weight_value == null ? '' : String(job.weight_value),
    weight_unit: job.weight_unit === 'kg' ? 'kg' : 'lb',
    status: job.status === 'done' ? 'delivered' : (job.status ?? 'open'),
    failure_reason: job.failure_reason ?? '',
    pod_note: job.pod_note ?? '',
    attempt_fee: job.attempt_fee == null ? '' : String(job.attempt_fee),
    stop_order: job.stop_order == null ? '' : String(job.stop_order),
    cod_amount: job.cod_amount == null ? '' : String(job.cod_amount),
    cod_collected: Boolean(job.cod_collected),
    estimated_miles: job.estimated_miles == null ? '' : String(job.estimated_miles),
    service_level: job.service_level ?? '',
    service_addon: job.service_addon == null ? '' : String(job.service_addon),
    quoted_amount: job.quoted_amount == null ? (job.estimated_cost == null ? '' : String(job.estimated_cost)) : String(job.quoted_amount),
    driver_pay: job.driver_pay == null ? '' : String(job.driver_pay),
    company_take: job.company_take == null ? '' : String(job.company_take),
    company_take_pct: job.company_take_pct == null
      ? String(takePct)
      : String(Math.round(Number(job.company_take_pct) * 100)),
    quote_manual: Boolean(job.quote_manual),
    quote_weekend: job.quote_weekend != null ? Boolean(job.quote_weekend) : isWeekend(job.job_date),
    quote_after_hours: Boolean(job.quote_after_hours),
    weekdays: [],
    dropoffDirty: Boolean(job.dropoff_time),
    weekendDirty: job.quote_weekend != null,
    afterHoursDirty: job.quote_after_hours != null,
    milesDirty: job.estimated_miles != null && job.estimated_miles !== '',
    accountDirty: Boolean(job.customer_id),
  };
}

import { trim } from './address.js';

export const ACCOUNT_TERMS = ['Net 15', 'Net 30', 'Net 45', 'Net 60'];

export const EMPTY_ACCOUNT = {
  name: '',
  charge_number: '',
  billing_email: '',
  phone: '',
  terms: 'Net 30',
  quote_per_mile: '',
  quote_minimum: '',
  quote_weekend_mult: '',
  quote_after_hours_mult: '',
  company_take_pct: '',
  pickup_name: '',
  pickup_line1: '',
  pickup_line2: '',
  pickup_city: '',
  pickup_state: '',
  pickup_zip: '',
  pickup_phone: '',
  pickup_email: '',
  dropoff_name: '',
  dropoff_line1: '',
  dropoff_line2: '',
  dropoff_city: '',
  dropoff_state: '',
  dropoff_zip: '',
  dropoff_phone: '',
  dropoff_email: '',
};

export function digitsOnly(value, max = 5) {
  return String(value || '').replace(/\D/g, '').slice(0, max);
}

export function numericOnly(value) {
  const raw = String(value || '').replace(/[^\d.]/g, '');
  const dot = raw.indexOf('.');
  if (dot === -1) return raw;
  return `${raw.slice(0, dot + 1)}${raw.slice(dot + 1).replace(/\./g, '')}`;
}

export function isChargeNumber(value) {
  return /^[0-9]{4,5}$/.test(String(value || '').trim());
}

export function weightUnitOf(org) {
  return org?.weightUnit === 'kg' || org?.weight_unit === 'kg' ? 'kg' : 'lb';
}

export function weightLabel(unit) {
  return unit === 'kg' ? 'kg' : 'lb';
}

export function formFromCustomer(customer, defaults = {}) {
  const fallbackTerms = String(defaults.terms || EMPTY_ACCOUNT.terms).trim() || 'Net 30';
  if (!customer) return { ...EMPTY_ACCOUNT, terms: fallbackTerms };
  const pct = customer.company_take_pct == null ? '' : String(Math.round(Number(customer.company_take_pct) * 100));
  return {
    ...EMPTY_ACCOUNT,
    name: customer.name || '',
    charge_number: customer.charge_number || '',
    billing_email: customer.billing_email || '',
    phone: customer.phone || '',
    terms: customer.terms || 'Net 30',
    quote_per_mile: customer.quote_per_mile ?? '',
    quote_minimum: customer.quote_minimum ?? '',
    quote_weekend_mult: customer.quote_weekend_mult ?? '',
    quote_after_hours_mult: customer.quote_after_hours_mult ?? '',
    company_take_pct: pct,
    pickup_name: customer.pickup_name || '',
    pickup_line1: customer.pickup_line1 || '',
    pickup_line2: customer.pickup_line2 || '',
    pickup_city: customer.pickup_city || '',
    pickup_state: customer.pickup_state || '',
    pickup_zip: customer.pickup_zip || '',
    pickup_phone: customer.pickup_phone || '',
    pickup_email: customer.pickup_email || '',
    dropoff_name: customer.dropoff_name || '',
    dropoff_line1: customer.dropoff_line1 || '',
    dropoff_line2: customer.dropoff_line2 || '',
    dropoff_city: customer.dropoff_city || '',
    dropoff_state: customer.dropoff_state || '',
    dropoff_zip: customer.dropoff_zip || '',
    dropoff_phone: customer.dropoff_phone || '',
    dropoff_email: customer.dropoff_email || '',
  };
}

export function addressFromCustomer(customer, prefix) {
  return {
    line1: trim(customer?.[`${prefix}_line1`]),
    line2: trim(customer?.[`${prefix}_line2`]),
    city: trim(customer?.[`${prefix}_city`]),
    state: trim(customer?.[`${prefix}_state`]),
    zip: trim(customer?.[`${prefix}_zip`]),
  };
}

export function customerHasStop(customer, prefix) {
  const addr = addressFromCustomer(customer, prefix);
  return Boolean(
    trim(customer?.[`${prefix}_name`])
    || addr.line1
    || addr.city
    || trim(customer?.[`${prefix}_phone`])
    || trim(customer?.[`${prefix}_email`]),
  );
}

export function nextChargeNumber(customers) {
  const used = new Set((customers || []).map((row) => digitsOnly(row.charge_number, 5)));
  for (let n = 1000; n <= 99999; n += 1) {
    const code = String(n);
    if (!used.has(code)) return code;
  }
  return '';
}

export function findCustomerByCharge(customers, charge) {
  const code = digitsOnly(charge, 5);
  if (!isChargeNumber(code)) return null;
  const hits = (customers || []).filter((row) => digitsOnly(row.charge_number, 5) === code);
  return hits.length === 1 ? hits[0] : null;
}

export function fillFormFromCustomer(form, customer) {
  if (!customer) {
    return {
      ...form,
      customer_id: '',
      charge_number: '',
      accountDirty: true,
    };
  }
  const next = {
    ...form,
    customer_id: customer.id,
    charge_number: customer.charge_number || '',
    accountDirty: true,
  };
  if (customerHasStop(customer, 'pickup')) {
    if (trim(customer.pickup_name)) next.pickup_name = customer.pickup_name;
    if (trim(customer.pickup_phone)) next.pickup_phone = customer.pickup_phone;
    if (trim(customer.pickup_email)) next.pickup_email = customer.pickup_email;
    const pickup = addressFromCustomer(customer, 'pickup');
    if (pickup.line1 || pickup.city) next.pickup = pickup;
  }
  if (customerHasStop(customer, 'dropoff')) {
    if (trim(customer.dropoff_name)) next.dropoff_name = customer.dropoff_name;
    if (trim(customer.dropoff_phone)) next.dropoff_phone = customer.dropoff_phone;
    if (trim(customer.dropoff_email)) next.dropoff_email = customer.dropoff_email;
    const dropoff = addressFromCustomer(customer, 'dropoff');
    if (dropoff.line1 || dropoff.city) next.dropoff = dropoff;
  }
  return next;
}

export function accountLabel(customer) {
  if (!customer) return '';
  const charge = digitsOnly(customer.charge_number, 5);
  return charge ? `${charge} · ${customer.name}` : customer.name;
}

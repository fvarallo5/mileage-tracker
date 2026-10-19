import { trim } from './address.js';

function storageKey(orgId) {
  return `trektrack-last-customer:${orgId}`;
}

export function matchCustomer(customers, { name, email } = {}) {
  const list = customers || [];
  const emailNorm = trim(email).toLowerCase();
  if (emailNorm) {
    const hits = list.filter((row) => trim(row.billing_email).toLowerCase() === emailNorm);
    if (hits.length === 1) return hits[0];
  }
  const nameNorm = trim(name).toLowerCase();
  if (nameNorm) {
    const hits = list.filter((row) => trim(row.name).toLowerCase() === nameNorm);
    if (hits.length === 1) return hits[0];
  }
  return null;
}

export function lastCustomerId(orgId, customers) {
  if (!orgId || typeof localStorage === 'undefined') return '';
  try {
    const id = localStorage.getItem(storageKey(orgId)) || '';
    if (!id) return '';
    return (customers || []).some((row) => row.id === id) ? id : '';
  } catch {
    return '';
  }
}

export function rememberLastCustomer(orgId, customerId) {
  if (!orgId || !customerId || typeof localStorage === 'undefined') return;
  try {
    localStorage.setItem(storageKey(orgId), customerId);
  } catch {
    /* quota */
  }
}

export function suggestedCustomerId(form, customers) {
  if (form?.accountDirty) return form.customer_id || '';
  const matched = matchCustomer(customers, {
    name: form?.pickup_name,
    email: form?.pickup_email,
  });
  if (matched) return matched.id;
  return form?.customer_id || '';
}

export function customerFromPickup(form, defaults = {}) {
  return {
    name: trim(form?.pickup_name),
    billing_email: trim(form?.pickup_email),
    phone: trim(form?.pickup_phone),
    terms: String(defaults.terms || 'Net 30').trim() || 'Net 30',
    pickup_name: trim(form?.pickup_name),
    pickup_line1: trim(form?.pickup?.line1),
    pickup_line2: trim(form?.pickup?.line2),
    pickup_city: trim(form?.pickup?.city),
    pickup_state: trim(form?.pickup?.state),
    pickup_zip: trim(form?.pickup?.zip),
    pickup_phone: trim(form?.pickup_phone),
    pickup_email: trim(form?.pickup_email),
    dropoff_name: trim(form?.dropoff_name),
    dropoff_line1: trim(form?.dropoff?.line1),
    dropoff_line2: trim(form?.dropoff?.line2),
    dropoff_city: trim(form?.dropoff?.city),
    dropoff_state: trim(form?.dropoff?.state),
    dropoff_zip: trim(form?.dropoff?.zip),
    dropoff_phone: trim(form?.dropoff_phone),
    dropoff_email: trim(form?.dropoff_email),
  };
}

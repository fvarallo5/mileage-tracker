export const COMPANY_KINDS = [
  { id: 'delivery', label: 'Delivery / courier', jobStyle: 'delivery' },
  { id: 'fleet', label: 'IC fleet / rideshare', jobStyle: 'delivery' },
  { id: 'other', label: 'Other driving', jobStyle: 'delivery' },
];

/** Canonical org types. `fleet` from older rows maps to courier. */
export const ORG_MODES = [
  {
    id: 'courier',
    label: 'Courier Dispatch',
    hint: 'Pickup and delivery jobs, drivers, and today’s board.',
    jobStyle: 'delivery',
    defaultPayType: 'contractor',
  },
  {
    id: 'reimbursement',
    label: 'Reimbursement',
    hint: 'Employee miles, receipts, and tolls. No job board.',
    jobStyle: 'delivery',
    defaultPayType: 'reimbursement',
  },
  {
    id: 'service',
    label: 'Service business',
    hint: 'Plumbers, HVAC, electricians, landscapers. One site per visit.',
    jobStyle: 'service',
    defaultPayType: 'hourly',
  },
  {
    id: 'driving_school',
    label: 'Driving School',
    hint: 'Lessons with an instructor and a student. Hours and GPS miles.',
    jobStyle: 'service',
    defaultPayType: 'hourly',
  },
];

export const PAY_TYPES = [
  { id: 'reimbursement', label: 'Mileage reimbursement' },
  { id: 'contractor', label: 'Independent contractor' },
  { id: 'hourly', label: 'Hourly' },
];

export function normalizeOperatingMode(mode) {
  const value = String(mode || '').toLowerCase().trim();
  if (value === 'reimbursement') return 'reimbursement';
  if (value === 'service') return 'service';
  if (value === 'driving_school') return 'driving_school';
  return 'courier';
}

export function orgModeMeta(mode) {
  const id = normalizeOperatingMode(mode);
  return ORG_MODES.find((row) => row.id === id) || ORG_MODES[0];
}

export function orgModeLabel(mode) {
  return orgModeMeta(mode).label;
}

export function isReimbursementMode(mode) {
  return normalizeOperatingMode(mode) === 'reimbursement';
}

export function isCourierMode(mode) {
  return normalizeOperatingMode(mode) === 'courier';
}

export function isServiceMode(mode) {
  return normalizeOperatingMode(mode) === 'service';
}

export function isSchoolMode(mode) {
  return normalizeOperatingMode(mode) === 'driving_school';
}

export function isServiceJobStyle(mode) {
  return orgModeMeta(mode).jobStyle === 'service';
}

export function jobStyleForMode(mode) {
  return orgModeMeta(mode).jobStyle;
}

export function jobStyleForKind() {
  return 'delivery';
}

export function payTypeForMode(mode) {
  return orgModeMeta(mode).defaultPayType;
}

export function normalizePayType(value, mode) {
  const pay = String(value || '').toLowerCase().trim();
  if (pay === 'hourly' || pay === 'reimbursement' || pay === 'contractor') return pay;
  return payTypeForMode(mode);
}

export function payTypeLabel(type) {
  return PAY_TYPES.find((p) => p.id === type)?.label ?? 'Independent contractor';
}

export const US_TIMEZONES = [
  { id: 'America/New_York', label: 'Eastern' },
  { id: 'America/Chicago', label: 'Central' },
  { id: 'America/Denver', label: 'Mountain' },
  { id: 'America/Phoenix', label: 'Arizona' },
  { id: 'America/Los_Angeles', label: 'Pacific' },
  { id: 'America/Anchorage', label: 'Alaska' },
  { id: 'Pacific/Honolulu', label: 'Hawaii' },
];

export function cleanJobPrefix(value) {
  return String(value || '').replace(/[^A-Za-z0-9-]/g, '').slice(0, 12);
}

export function identityFromOrg(org = {}) {
  const tz = String(org.timezone || '').trim();
  return {
    phone: String(org.phone || '').trim(),
    dispatchEmail: String(org.dispatchEmail || org.dispatch_email || '').trim(),
    addressLine1: String(org.addressLine1 || org.address_line1 || '').trim(),
    addressCity: String(org.addressCity || org.address_city || '').trim(),
    addressState: String(org.addressState || org.address_state || '').trim().toUpperCase(),
    addressZip: String(org.addressZip || org.address_zip || '').trim(),
    timezone: US_TIMEZONES.some((row) => row.id === tz) ? tz : 'America/New_York',
    jobPrefix: cleanJobPrefix(org.jobPrefix || org.job_prefix),
    officeClosesJobs: org.officeClosesJobs === true || org.office_closes_jobs === true,
    useCod: org.useCod === true || org.use_cod === true,
  };
}

export const CLOSE_POLICIES = [
  {
    id: 'drivers',
    label: 'Drivers on the phone',
    hint: 'Driver marks delivered or couldn’t deliver, with photo and signature.',
  },
  {
    id: 'office',
    label: 'Office on this desk',
    hint: 'Drivers still mark picked up. Dispatch sets delivered or couldn’t deliver here.',
  },
];

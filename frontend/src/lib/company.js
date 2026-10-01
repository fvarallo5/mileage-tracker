export const COMPANY_KINDS = [
  { id: 'hvac', label: 'HVAC', jobStyle: 'service' },
  { id: 'plumbing', label: 'Plumbing', jobStyle: 'service' },
  { id: 'landscaping', label: 'Landscaping', jobStyle: 'service' },
  { id: 'delivery', label: 'Delivery / courier', jobStyle: 'delivery' },
  { id: 'other', label: 'Other service', jobStyle: 'service' },
];

export const PAY_TYPES = [
  { id: 'hourly', label: 'Hourly wage' },
  { id: 'reimbursement', label: 'Mileage reimbursement' },
  { id: 'contractor', label: 'Independent contractor' },
];

export function jobStyleForKind(kind) {
  return COMPANY_KINDS.find((k) => k.id === kind)?.jobStyle ?? 'service';
}

export function payTypeLabel(type) {
  return PAY_TYPES.find((p) => p.id === type)?.label ?? 'Hourly wage';
}

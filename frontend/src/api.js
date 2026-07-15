const BASE = '/api';

async function request(path, options = {}) {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error(err.error || 'Request failed');
  }

  if (res.status === 204) return null;
  return res.json();
}

export const api = {
  getTrips: (params = {}) => {
    const qs = new URLSearchParams(params).toString();
    return request(`/trips${qs ? `?${qs}` : ''}`);
  },
  createTrip: (data) => request('/trips', { method: 'POST', body: JSON.stringify(data) }),
  updateTrip: (id, data) => request(`/trips/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteTrip: (id) => request(`/trips/${id}`, { method: 'DELETE' }),
  getReportSummary: (date) => request(`/reports/summary${date ? `?date=${date}` : ''}`),
  getReports: (period, count = 6) => request(`/reports/${period}?count=${count}`),
  getSettings: () => request('/settings'),
  setMileageRate: (rate) =>
    request('/settings/mileage-rate', { method: 'PUT', body: JSON.stringify({ rate }) }),
  getImportFormats: () => request('/trips/import/formats'),
  previewImport: (data) =>
    request('/trips/import/preview', { method: 'POST', body: JSON.stringify(data) }),
  importTrips: (data) =>
    request('/trips/import', { method: 'POST', body: JSON.stringify(data) }),
};
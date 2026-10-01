export const milesFmt = new Intl.NumberFormat('en-US', { maximumFractionDigits: 1 });
export const moneyFmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

export function costLabel(category) {
  switch (category) {
    case 'fuel':
      return 'Gas';
    case 'parking':
      return 'Parking';
    case 'tolls':
      return 'Tolls';
    case 'meals':
      return 'Client meals';
    case 'supplies':
      return 'Supplies';
    case 'maintenance':
      return 'Maintenance';
    case 'car_wash':
      return 'Car wash';
    case 'phone':
      return 'Phone / data';
    case 'uniforms':
      return 'Uniforms';
    case 'office':
      return 'Office';
    case 'software':
      return 'Software';
    case 'insurance':
      return 'Insurance';
    default:
      return 'Other';
  }
}

export function roleLabel(role) {
  if (role === 'owner') return 'Owner';
  if (role === 'admin') return 'Admin';
  return 'Driver';
}

export function formatShortDate(iso) {
  if (!iso) return '—';
  const d = new Date(`${String(iso).slice(0, 10)}T12:00:00`);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export function csvEscape(value) {
  const s = String(value ?? '');
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

export function downloadCsv(name, rows) {
  const body = rows.map((row) => row.map(csvEscape).join(',')).join('\n');
  const blob = new Blob([`\uFEFF${body}`], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  a.click();
  URL.revokeObjectURL(url);
}

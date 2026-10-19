export function digitsOnly(value) {
  return String(value || '').replace(/\D/g, '');
}

export function looksLikeEmail(value) {
  const raw = String(value || '').trim().toLowerCase();
  return raw.includes('@') && /@[^\s@]+\.[^\s@]+$/.test(raw);
}

export function looksLikePhone(value) {
  const raw = String(value || '').trim();
  if (!raw || raw.includes('@')) return false;
  const digits = digitsOnly(raw);
  return digits.length >= 10 && digits.length <= 15;
}

/** US 10-digit numbers become +1. Already-international + stays. */
export function toE164(value) {
  const raw = String(value || '').trim();
  if (!raw) return '';
  const digits = digitsOnly(raw);
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith('1')) return `+${digits}`;
  if (raw.startsWith('+') && digits.length >= 10) return `+${digits}`;
  if (digits.length >= 10 && digits.length <= 15) return `+${digits}`;
  return '';
}

export function loginKind(value) {
  if (looksLikeEmail(value)) return 'email';
  if (looksLikePhone(value)) return 'phone';
  return null;
}

export function contactLabel(email, phone) {
  const mail = String(email || '').trim();
  const tel = String(phone || '').trim();
  if (mail && tel) return `${mail} · ${tel}`;
  return mail || tel || '—';
}

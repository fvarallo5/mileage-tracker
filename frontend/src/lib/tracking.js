const TOKEN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function trackTokenFromUrl() {
  if (typeof window === 'undefined') return null;
  const token = new URLSearchParams(window.location.search).get('track');
  return TOKEN.test(token || '') ? token : null;
}

export function trackingUrl(token) {
  if (!token || typeof window === 'undefined') return '';
  return `${window.location.origin}/?track=${token}`;
}

export function smsHref(phone, url) {
  const digits = String(phone || '').replace(/[^\d+]/g, '');
  if (!digits || !url) return '';
  return `sms:${digits}?&body=${encodeURIComponent(`Track your delivery: ${url}`)}`;
}

export function mailHref(emails, url, { jobNumber, status } = {}) {
  const to = [];
  for (const raw of emails || []) {
    const email = String(raw || '').trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) continue;
    if (!to.includes(email)) to.push(email);
  }
  if (!to.length || !url) return '';
  const label = trackStatusLabel(status);
  const subject = jobNumber ? `TrekTrack job ${jobNumber} · ${label}` : `TrekTrack delivery · ${label}`;
  const body = `${jobNumber ? `Job ${jobNumber} is ${label}.` : `This delivery is ${label}.`}\n\nTrack: ${url}`;
  return `mailto:${to.join(',')}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
}

export function trackStatusLabel(status) {
  if (status === 'picked_up') return 'Picked up';
  if (status === 'delivered' || status === 'done') return 'Delivered';
  if (status === 'failed') return "Couldn't deliver";
  if (status === 'cancelled') return 'Cancelled';
  return 'Scheduled';
}

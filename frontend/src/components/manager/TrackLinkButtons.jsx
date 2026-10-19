import { useState } from 'react';
import { mailHref, smsHref, trackingUrl } from '../../lib/tracking.js';

export default function TrackLinkButtons({ token, phone, emails, jobNumber, status }) {
  const [copied, setCopied] = useState(false);
  if (!token) return null;
  const url = trackingUrl(token);
  const sms = smsHref(phone, url);
  const mail = mailHref(emails, url, { jobNumber, status });

  async function copy() {
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
    } catch {
      setCopied(false);
    }
  }

  return (
    <div className="track-link-row">
      <button type="button" className="btn btn-secondary btn-sm" onClick={copy}>
        {copied ? 'Link copied' : 'Copy tracking link'}
      </button>
      {sms ? (
        <a className="btn btn-secondary btn-sm" href={sms}>Text dropoff</a>
      ) : null}
      {mail ? (
        <a className="btn btn-secondary btn-sm" href={mail}>Email tracking</a>
      ) : null}
    </div>
  );
}

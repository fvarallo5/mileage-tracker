import { useEffect, useState } from 'react';
import { drivingMinutes, geocodeAddress } from '../lib/geo.js';
import { trackStatusLabel } from '../lib/tracking.js';
import { supabase } from '../supabase.js';

function clock(value) {
  if (!value) return '';
  const [h, m] = String(value).slice(0, 5).split(':').map(Number);
  if (!Number.isFinite(h)) return '';
  return new Date(2020, 0, 1, h, m || 0).toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
  });
}

export default function TrackPage({ token }) {
  const [row, setRow] = useState(null);
  const [missing, setMissing] = useState(false);
  const [eta, setEta] = useState(null);

  useEffect(() => {
    let live = true;
    async function load() {
      if (!supabase) {
        if (live) setMissing(true);
        return;
      }
      const { data, error } = await supabase.rpc('track_job', { p_token: token });
      if (!live) return;
      if (error || !data?.length) {
        setMissing(true);
        return;
      }
      const job = data[0];
      setRow(job);
      if (job.status !== 'picked_up') return;
      try {
        const drop = await geocodeAddress(job.dropoff_address);
        let origin = null;
        if (Number.isFinite(job.driver_lat) && Number.isFinite(job.driver_lng)) {
          origin = { lat: job.driver_lat, lng: job.driver_lng };
        } else if (job.pickup_address) {
          origin = await geocodeAddress(job.pickup_address);
        }
        if (!origin || !drop) return;
        const minutes = await drivingMinutes(origin, drop);
        if (live) setEta(minutes);
      } catch {
        if (live) setEta(null);
      }
    }
    load();
    return () => {
      live = false;
    };
  }, [token]);

  const when = [clock(row?.pickup_time), clock(row?.dropoff_time)].filter(Boolean).join(' – ');
  const towns = [row?.pickup_city, row?.dropoff_city].filter(Boolean).join(' → ');

  return (
    <div className="app track-page">
      <main className="track-card">
        <p className="muted-row">{row?.company_name || 'TrekTrack'}</p>
        {row?.company_phone ? <p className="muted-row">{row.company_phone}</p> : null}
        {!row && !missing ? <p>Loading…</p> : null}
        {missing ? <h1>This link does not match a delivery.</h1> : null}
        {row ? (
          <>
            <p className="track-kicker">{row.job_number ? `Job ${row.job_number}` : 'Delivery'}</p>
            <h1>{trackStatusLabel(row.status)}</h1>
            {towns ? <p className="track-towns">{towns}</p> : null}
            {when ? <p className="muted-row">{when}</p> : null}
            {row.status === 'picked_up' && eta != null ? (
              <p className="track-eta">About {eta} min</p>
            ) : null}
          </>
        ) : null}
      </main>
    </div>
  );
}

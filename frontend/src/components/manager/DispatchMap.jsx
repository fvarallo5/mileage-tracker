import { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { drivingRoute, geocodeAddress, jobAddress } from '../../lib/geo.js';

export default function DispatchMap({ jobs, pings, showPings, expanded = false }) {
  const rootRef = useRef(null);
  const mapRef = useRef(null);
  const layerRef = useRef(null);

  useEffect(() => {
    if (!rootRef.current || mapRef.current) return undefined;
    const map = L.map(rootRef.current, {
      zoomControl: true,
      attributionControl: true,
      dragging: true,
      scrollWheelZoom: true,
      doubleClickZoom: true,
      boxZoom: true,
      keyboard: true,
      touchZoom: true,
    }).setView([39.8, -98.5], 4);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap',
    }).addTo(map);
    layerRef.current = L.layerGroup().addTo(map);
    mapRef.current = map;
    const onResize = () => map.invalidateSize();
    window.addEventListener('resize', onResize);
    setTimeout(onResize, 80);
    return () => {
      window.removeEventListener('resize', onResize);
      map.remove();
      mapRef.current = null;
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    const layer = layerRef.current;
    if (!map || !layer) return undefined;
    let cancelled = false;

    (async () => {
      layer.clearLayers();
      const bounds = [];

      for (const job of jobs) {
        const pickup = jobAddress(job, 'pickup');
        const drop = jobAddress(job, 'dropoff');
        const p = pickup ? await geocodeAddress(pickup) : null;
        if (cancelled) return;
        const d = drop ? await geocodeAddress(drop) : null;
        if (cancelled) return;
        if (p) {
          L.circleMarker([p.lat, p.lng], {
            radius: 7,
            color: '#3B9EFF',
            fillColor: '#3B9EFF',
            fillOpacity: 0.9,
            weight: 2,
          })
            .bindPopup(`<strong>${job.job_number}</strong><br/>Pickup<br/>${pickup}`)
            .addTo(layer);
          bounds.push([p.lat, p.lng]);
        }
        if (d) {
          L.circleMarker([d.lat, d.lng], {
            radius: 6,
            color: '#34D399',
            fillColor: '#34D399',
            fillOpacity: 0.85,
            weight: 2,
          })
            .bindPopup(`<strong>${job.job_number}</strong><br/>Delivery<br/>${drop}`)
            .addTo(layer);
          bounds.push([d.lat, d.lng]);
          if (p) {
            let line = [[p.lat, p.lng], [d.lat, d.lng]];
            let milesLabel = '';
            try {
              const route = await drivingRoute(p, d);
              if (cancelled) return;
              if (route?.coordinates?.length > 1) {
                line = route.coordinates;
                milesLabel = `${route.miles.toFixed(1)} mi`;
              }
            } catch {
              /* dashed straight line below */
            }
            const road = Boolean(milesLabel);
            const poly = L.polyline(line, {
              color: '#3B9EFF',
              weight: road ? 3 : 2,
              opacity: road ? 0.85 : 0.45,
              ...(road ? {} : { dashArray: '6 6' }),
            }).addTo(layer);
            if (road) {
              poly.bindTooltip(milesLabel, {
                permanent: true,
                direction: 'center',
                className: 'route-miles',
              });
            }
          }
        }
      }

      if (showPings) {
        for (const ping of pings) {
          if (!Number.isFinite(ping.lat) || !Number.isFinite(ping.lng)) continue;
          L.circleMarker([ping.lat, ping.lng], {
            radius: 8,
            color: '#0F172A',
            fillColor: '#F59E0B',
            fillOpacity: 1,
            weight: 2,
          })
            .bindPopup(
              `<strong>${ping.label}</strong><br/>Last GPS${ping.seen_at ? `<br/>${new Date(ping.seen_at).toLocaleString()}` : ''}`,
            )
            .addTo(layer);
          bounds.push([ping.lat, ping.lng]);
        }
      }

      if (bounds.length === 1) map.setView(bounds[0], 12);
      else if (bounds.length > 1) map.fitBounds(bounds, { padding: [28, 28], maxZoom: 13 });
      setTimeout(() => map.invalidateSize(), 50);
    })();

    return () => {
      cancelled = true;
    };
  }, [jobs, pings, showPings]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return undefined;
    if (expanded) {
      map.dragging.enable();
      map.scrollWheelZoom.enable();
      map.doubleClickZoom.enable();
      map.boxZoom.enable();
      map.keyboard.enable();
      map.touchZoom.enable();
    } else {
      map.dragging.disable();
      map.scrollWheelZoom.disable();
      map.doubleClickZoom.disable();
      map.boxZoom.disable();
      map.keyboard.disable();
      map.touchZoom.disable();
    }
    const t = window.setTimeout(() => map.invalidateSize(), 120);
    const t2 = window.setTimeout(() => map.invalidateSize(), 320);
    return () => {
      window.clearTimeout(t);
      window.clearTimeout(t2);
    };
  }, [expanded]);

  return (
    <div
      ref={rootRef}
      className="dispatch-map"
      role="region"
      aria-label="Map of today's jobs"
    />
  );
}

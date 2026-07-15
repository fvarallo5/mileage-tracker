import { useEffect, useState } from 'react';
import { api } from '../api';

const PLATFORMS = [
  { id: 'uber', label: 'Uber' },
  { id: 'doordash', label: 'DoorDash' },
  { id: 'lyft', label: 'Lyft' },
  { id: 'instacart', label: 'Instacart' },
  { id: 'generic', label: 'Other CSV' },
];

export default function ImportTrips({ onImported }) {
  const [open, setOpen] = useState(false);
  const [platform, setPlatform] = useState('uber');
  const [csv, setCsv] = useState('');
  const [defaultMiles, setDefaultMiles] = useState('2.5');
  const [preview, setPreview] = useState(null);
  const [formats, setFormats] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (open && !formats) {
      api.getImportFormats().then(setFormats).catch(() => {});
    }
  }, [open, formats]);

  async function handlePreview() {
    setLoading(true);
    setError(null);
    try {
      const result = await api.previewImport({
        csv,
        platform,
        default_miles: parseFloat(defaultMiles) || 0,
      });
      setPreview(result);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleImport() {
    setLoading(true);
    setError(null);
    try {
      const result = await api.importTrips({
        csv,
        platform,
        default_miles: parseFloat(defaultMiles) || 0,
      });
      setOpen(false);
      setCsv('');
      setPreview(null);
      onImported?.(result);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  function loadSample() {
    const sample = formats?.sample_csv?.[platform];
    if (sample) setCsv(sample);
  }

  const instructions = formats?.instructions?.[platform];

  if (!open) {
    return (
      <button className="btn btn-ghost" onClick={() => setOpen(true)}>
        Import from Uber / DoorDash
      </button>
    );
  }

  return (
    <div className="card" style={{ marginBottom: '1.5rem' }}>
      <div className="card-title">Import Trips from Gig Apps</div>

      <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', marginBottom: '1rem' }}>
        {PLATFORMS.map((p) => (
          <button
            key={p.id}
            className={`period-btn ${platform === p.id ? 'active' : ''}`}
            onClick={() => { setPlatform(p.id); setPreview(null); }}
          >
            {p.label}
          </button>
        ))}
      </div>

      {instructions && (
        <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '1rem' }}>
          <strong>{instructions.name}</strong>
          <ol style={{ margin: '0.5rem 0 0 1.2rem', padding: 0 }}>
            {instructions.steps.map((s, i) => <li key={i}>{s}</li>)}
          </ol>
          {instructions.note && (
            <p style={{ color: 'var(--amber)', marginTop: '0.5rem' }}>{instructions.note}</p>
          )}
        </div>
      )}

      <div className="form-group">
        <label>Default miles (when CSV has no distance)</label>
        <input
          type="number"
          step="0.1"
          value={defaultMiles}
          onChange={(e) => setDefaultMiles(e.target.value)}
        />
      </div>

      <div className="form-group">
        <label>CSV data</label>
        <textarea
          rows={6}
          value={csv}
          onChange={(e) => { setCsv(e.target.value); setPreview(null); }}
          placeholder="Paste exported CSV here..."
          style={{ fontFamily: 'monospace', fontSize: '0.8rem' }}
        />
      </div>

      {error && <div className="error-banner">{error}</div>}

      <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
        <button className="btn btn-ghost" onClick={loadSample}>Load sample</button>
        <button className="btn btn-primary" onClick={handlePreview} disabled={loading || !csv.trim()}>
          {loading ? 'Working…' : 'Preview'}
        </button>
        {preview?.preview?.length > 0 && (
          <button className="btn btn-primary" onClick={handleImport} disabled={loading}>
            Import {preview.preview.length} trips
          </button>
        )}
        <button className="btn btn-ghost" onClick={() => setOpen(false)}>Cancel</button>
      </div>

      {preview?.preview?.length > 0 && (
        <div className="table-wrap" style={{ marginTop: '1rem' }}>
          <table>
            <thead>
              <tr><th>Date</th><th>Miles</th><th>Tips</th><th>Notes</th></tr>
            </thead>
            <tbody>
              {preview.preview.slice(0, 5).map((row, i) => (
                <tr key={i}>
                  <td>{row.date}</td>
                  <td>{row.miles}</td>
                  <td>${row.tips}</td>
                  <td>{row.notes}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
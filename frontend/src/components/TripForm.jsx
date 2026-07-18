import { useState } from 'react';

const today = () => new Date().toISOString().slice(0, 10);

export default function TripForm({ onSubmit, editing, onCancel }) {
  const [date, setDate] = useState(editing?.date ?? today());
  const [miles, setMiles] = useState(editing?.miles?.toString() ?? '');
  const [tips, setTips] = useState(editing?.tips?.toString() ?? '');
  const [notes, setNotes] = useState(editing?.notes ?? '');
  const [isBusiness, setIsBusiness] = useState(editing?.is_business !== false);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setSubmitting(true);
    try {
      await onSubmit({
        date,
        miles: parseFloat(miles),
        tips: parseFloat(tips) || 0,
        notes,
        is_business: isBusiness,
      });
      if (!editing) {
        setMiles('');
        setTips('');
        setNotes('');
        setIsBusiness(true);
      }
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <div className="form-group">
        <label>Purpose</label>
        <div className="purpose-toggle" role="group" aria-label="Trip purpose">
          <button
            type="button"
            className={isBusiness ? 'active business' : ''}
            onClick={() => setIsBusiness(true)}
          >
            Business
          </button>
          <button
            type="button"
            className={!isBusiness ? 'active personal' : ''}
            onClick={() => setIsBusiness(false)}
          >
            Personal
          </button>
        </div>
        <p className="field-hint">
          {isBusiness
            ? 'Counts toward reports and tax totals.'
            : 'Excluded from deductible miles.'}
        </p>
      </div>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor="date">Date</label>
          <input
            id="date"
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            required
          />
        </div>
        <div className="form-group">
          <label htmlFor="miles">Miles</label>
          <input
            id="miles"
            type="number"
            step="0.1"
            min="0.1"
            placeholder="0.0"
            value={miles}
            onChange={(e) => setMiles(e.target.value)}
            required
          />
        </div>
        <div className="form-group">
          <label htmlFor="tips">Tips / Earnings ($)</label>
          <input
            id="tips"
            type="number"
            step="0.01"
            min="0"
            placeholder="0.00"
            value={tips}
            onChange={(e) => setTips(e.target.value)}
          />
        </div>
      </div>
      <div className="form-group">
        <label htmlFor="notes">Notes (optional)</label>
        <input
          id="notes"
          type="text"
          placeholder="Route, client, etc."
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
        />
      </div>
      <div style={{ display: 'flex', gap: '0.75rem' }}>
        <button type="submit" className="btn btn-primary" disabled={submitting}>
          {submitting ? 'Saving…' : editing ? 'Update Trip' : 'Log Trip'}
        </button>
        {editing && (
          <button type="button" className="btn btn-ghost" onClick={onCancel}>
            Cancel
          </button>
        )}
      </div>
    </form>
  );
}

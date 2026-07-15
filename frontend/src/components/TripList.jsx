const fmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });
const fmtMiles = (n) => `${n.toFixed(1)} mi`;

export default function TripList({ trips, onEdit, onDelete }) {
  if (trips.length === 0) {
    return <div className="empty">No trips logged yet. Add your first trip above.</div>;
  }

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Date</th>
            <th>Miles</th>
            <th>Tips</th>
            <th>$/Mile</th>
            <th>Notes</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {trips.map((trip) => (
            <tr key={trip.id}>
              <td>{trip.date}</td>
              <td>{fmtMiles(trip.miles)}</td>
              <td>{fmt.format(trip.tips)}</td>
              <td>{trip.miles > 0 ? fmt.format(trip.tips / trip.miles) : '—'}</td>
              <td style={{ color: 'var(--text-muted)', maxWidth: 200 }}>{trip.notes || '—'}</td>
              <td style={{ textAlign: 'right', whiteSpace: 'nowrap' }}>
                <button className="btn btn-ghost" style={{ padding: '0.3rem 0.6rem', fontSize: '0.8rem' }} onClick={() => onEdit(trip)}>
                  Edit
                </button>
                <button className="btn btn-danger" onClick={() => onDelete(trip.id)}>
                  Delete
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
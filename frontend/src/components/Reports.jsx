import { useEffect, useState } from 'react';
import { api } from '../api';
import ReportStats from './ReportStats';

const fmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });
const PERIODS = ['weekly', 'monthly', 'annual'];

const PERIOD_LABELS = {
  weekly: 'Weekly',
  monthly: 'Monthly',
  annual: 'Annual',
};

export default function Reports() {
  const [period, setPeriod] = useState('weekly');
  const [summary, setSummary] = useState(null);
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadReports();
  }, [period]);

  async function loadReports() {
    setLoading(true);
    setError(null);
    try {
      const [summaryData, historyData] = await Promise.all([
        api.getReportSummary(),
        api.getReports(period, 8),
      ]);
      setSummary(summaryData);
      setHistory(historyData.reports);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  const currentReport = summary?.[period];

  if (loading) return <div className="loading">Loading reports…</div>;

  return (
    <div>
      {error && <div className="error-banner">{error}</div>}

      <div className="report-period-tabs">
        {PERIODS.map((p) => (
          <button
            key={p}
            className={`period-btn ${period === p ? 'active' : ''}`}
            onClick={() => setPeriod(p)}
          >
            {PERIOD_LABELS[p]}
          </button>
        ))}
      </div>

      {currentReport && (
        <div className="report-highlight">
          <h2>Current {PERIOD_LABELS[period]} Report</h2>
          <div className="date-range">
            {currentReport.label} · {currentReport.start_date} to {currentReport.end_date}
          </div>
          <ReportStats report={currentReport} />
          <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
            Mileage rate: {fmt.format(currentReport.mileage_rate)}/mi
          </div>
        </div>
      )}

      <div className="card">
        <div className="card-title">Historical {PERIOD_LABELS[period]} Reports</div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Period</th>
                <th>Miles</th>
                <th>Tips</th>
                <th>Expense</th>
                <th>$/Mile</th>
                <th>Net</th>
                <th>Trips</th>
              </tr>
            </thead>
            <tbody>
              {history.map((r) => (
                <tr key={r.period}>
                  <td>
                    <div>{r.label}</div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                      {r.start_date} – {r.end_date}
                    </div>
                  </td>
                  <td>{r.total_miles.toFixed(1)}</td>
                  <td>{fmt.format(r.total_tips)}</td>
                  <td>{fmt.format(r.mileage_expense)}</td>
                  <td style={{ color: 'var(--green)' }}>{fmt.format(r.earnings_per_mile)}</td>
                  <td style={{ color: r.net_earnings >= 0 ? 'var(--green)' : 'var(--red)' }}>
                    {fmt.format(r.net_earnings)}
                  </td>
                  <td>{r.trip_count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
const fmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

export default function ReportStats({ report }) {
  if (!report) return null;

  return (
    <div className="stats-grid">
      <div className="stat-card">
        <div className="label">Total Miles</div>
        <div className="value accent">{report.total_miles.toFixed(1)}</div>
      </div>
      <div className="stat-card">
        <div className="label">Total Tips</div>
        <div className="value green">{fmt.format(report.total_tips)}</div>
      </div>
      <div className="stat-card">
        <div className="label">Mileage Expense</div>
        <div className="value amber">{fmt.format(report.mileage_expense)}</div>
      </div>
      <div className="stat-card">
        <div className="label">Earnings / Mile</div>
        <div className="value green">{fmt.format(report.earnings_per_mile)}</div>
      </div>
      <div className="stat-card">
        <div className="label">Net Earnings</div>
        <div className={`value ${report.net_earnings >= 0 ? 'green' : ''}`} style={report.net_earnings < 0 ? { color: 'var(--red)' } : {}}>
          {fmt.format(report.net_earnings)}
        </div>
      </div>
      <div className="stat-card">
        <div className="label">Trips</div>
        <div className="value">{report.trip_count}</div>
      </div>
    </div>
  );
}
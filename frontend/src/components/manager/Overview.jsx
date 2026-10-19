import { useEffect, useMemo, useState } from 'react';
import { isoDate, PERIODS, formatRangeMdY } from '../../lib/period.js';
import {
  jobDurationHours,
  jobPay,
  jobQuote,
  jobRateTags,
  jobTake,
  jobTown,
  jobsForReport,
  settleByDriver,
  totalsForJobs,
} from '../../lib/jobReport.js';
import { statusLabel, statusesForMode } from '../../lib/jobStatus.js';
import { countNoun, deskSkin } from '../../lib/layout.js';
import { buildSampleReport } from '../../lib/sampleReport.js';
import { notifyJob, shouldNotifyJob } from '../../lib/jobNotify.js';
import { orgApi } from '../../orgApi.js';
import { jobMatchesQuery, jobsWithProof } from '../../lib/jobSearch.js';
import { useTeam } from '../../context/TeamContext.jsx';
import { useDeskChrome, useDeskNav } from '../../context/DeskNav.jsx';
import PeriodRail, { PeriodMini } from './PeriodRail.jsx';
import DriverTable from './DriverTable.jsx';
import Module from './Module.jsx';
import PodPhoto from './PodPhoto.jsx';
import ReportJobEditor from './ReportJobEditor.jsx';
import { costLabel, downloadCsv, milesFmt, moneyFmt } from './format.js';

const JOB_STATUSES = [
  ['delivered', 'Delivered'],
  ['open', 'Open'],
  ['picked_up', 'Picked up'],
  ['failed', "Couldn't deliver"],
  ['cancelled', 'Cancelled'],
  ['all', 'All'],
];

function milesCell(job, jobMiles) {
  const gps = jobMiles?.[job.id];
  const est = job.estimated_miles;
  const gpsText = gps == null ? '' : `${Number(gps).toFixed(1)} gps`;
  const estText = est == null || est === '' ? '' : `${Number(est).toFixed(1)} est`;
  if (!gpsText && !estText) return '—';
  return [gpsText, estText].filter(Boolean).join(' / ');
}

function reportDate(iso) {
  if (!iso) return '—';
  const d = new Date(`${String(iso).slice(0, 10)}T12:00:00`);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('en-US');
}

export default function Overview() {
  const team = useTeam();
  const mode = team.membership?.operatingMode;
  if (mode === 'reimbursement') {
    return <ReimbursementReports team={team} />;
  }
  return <FleetReports team={team} />;
}

function FleetReports({ team }) {
  const { period, setPeriod, range, jobs, drivers, customers, jobMiles, quoteRates, reload, setError, membership } = team;
  const skin = deskSkin(membership?.operatingMode);
  const mode = membership?.operatingMode;
  const [driverId, setDriverId] = useState('');
  const [status, setStatus] = useState('delivered');
  const [forceSample, setForceSample] = useState(false);
  const [sampleJobs, setSampleJobs] = useState(null);
  const [openDrivers, setOpenDrivers] = useState({});
  const [selectedId, setSelectedId] = useState(null);
  const [saving, setSaving] = useState(false);
  const [query, setQuery] = useState('');

  const liveRows = useMemo(
    () => jobsForReport(jobs, {
      start: range.start,
      end: range.end,
      status: 'all',
    }),
    [jobs, range.start, range.end],
  );

  const samplePack = useMemo(
    () => buildSampleReport(range.start, range.end),
    [range.start, range.end],
  );

  useEffect(() => {
    setSampleJobs(null);
  }, [range.start, range.end]);

  const usingSample = forceSample || liveRows.length === 0;
  const sourceJobs = usingSample ? (sampleJobs || samplePack.jobs) : jobs;
  const sourceDrivers = usingSample ? samplePack.drivers : drivers;
  const activeDriverId = sourceDrivers.some((d) => d.user_id === driverId) ? driverId : '';

  const rows = useMemo(
    () => jobsForReport(sourceJobs, {
      start: range.start,
      end: range.end,
      driverId: activeDriverId,
      status,
    }).filter((job) => jobMatchesQuery(job, query, { customers, drivers: sourceDrivers })),
    [sourceJobs, range.start, range.end, activeDriverId, status, query, customers, sourceDrivers],
  );

  const proofs = useMemo(
    () => (usingSample ? [] : jobsWithProof(rows)),
    [usingSample, rows],
  );

  const totals = useMemo(() => totalsForJobs(rows), [rows]);
  const groups = useMemo(() => settleByDriver(rows, sourceDrivers), [rows, sourceDrivers]);
  const statusName = statusesForMode(mode).find((row) => row.id === status)?.label
    || JOB_STATUSES.find(([key]) => key === status)?.[1]
    || 'Delivered';
  const hoursTotal = rows.reduce((sum, job) => sum + jobDurationHours(job), 0);
  const milesTotal = rows.reduce((sum, job) => {
    const gps = jobMiles?.[job.id];
    const est = Number(job.estimated_miles);
    const n = Number.isFinite(Number(gps)) ? Number(gps) : (Number.isFinite(est) ? est : 0);
    return sum + n;
  }, 0);
  const noShows = rows.filter((job) => job.status === 'failed').length;
  const selectedJob = rows.find((job) => String(job.id) === String(selectedId)) || null;

  const quotesKind = skin.reviewKind === 'quotes';
  const siteOnly = skin.reviewKind === 'hours' || skin.reviewKind === 'visits';

  function handleExport() {
    const safe = `${usingSample ? 'Sample_' : ''}${range.label.replace(/\s+/g, '_')}`;
    const worker = sourceDrivers.find.bind(sourceDrivers);
    const workerName = (job) => worker((d) => d.user_id === job.assigned_user_id)?.label || (job.assigned_user_id ? '' : 'Unassigned');
    if (quotesKind) {
      downloadCsv(`TrekTrack_Jobs_${safe}.csv`, [
        ['Date', 'Job #', 'Pickup town', 'Drop-off town', 'Total pay', 'Quote', 'Company take', 'Driver', 'Status', 'Rate'],
        ...rows.map((job) => [
          job.job_date,
          job.job_number,
          jobTown(job, 'pickup'),
          jobTown(job, 'dropoff'),
          jobPay(job).toFixed(2),
          jobQuote(job).toFixed(2),
          jobTake(job).toFixed(2),
          workerName(job),
          statusLabel(job.status, mode),
          jobRateTags(job).join('; '),
        ]),
        ['Total', '', '', '', totals.pay.toFixed(2), totals.quote.toFixed(2), totals.take.toFixed(2), '', '', ''],
      ]);
      return;
    }
    downloadCsv(`TrekTrack_${skin.boardNoun}_${safe}.csv`, [
      ['Date', `${skin.jobWord} #`, skin.siteTitle, 'Hours', 'Miles', skin.worker, 'Status'],
      ...rows.map((job) => [
        job.job_date,
        job.job_number,
        jobTown(job, 'pickup'),
        jobDurationHours(job).toFixed(1),
        milesCell(job, jobMiles),
        workerName(job),
        statusLabel(job.status, mode),
      ]),
      ['Total', '', '', hoursTotal.toFixed(1), milesTotal.toFixed(1), '', ''],
    ]);
  }

  function toggleDriver(id) {
    setOpenDrivers((prev) => ({ ...prev, [id]: !prev[id] }));
  }

  function pickJob(job) {
    setSelectedId(job.id);
    setOpenDrivers((prev) => ({ ...prev, [job.assigned_user_id]: true }));
  }

  async function duplicateJob(job, body) {
    setSaving(true);
    setError(null);
    try {
      if (usingSample) {
        setSampleJobs((prev) => [
          ...(prev || samplePack.jobs),
          { ...job, ...body, id: `sample-copy-${Date.now()}` },
        ]);
      } else {
        const created = await orgApi.createJob(membership.orgId, { ...body, job_date: isoDate(new Date()) });
        if (created?.id) await notifyJob(created.id);
        await reload();
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  async function saveJob(job, body) {
    setSaving(true);
    setError(null);
    try {
      if (usingSample) {
        setSampleJobs((prev) => (prev || samplePack.jobs).map((row) => (
          String(row.id) === String(job.id) ? { ...row, ...body } : row
        )));
      } else {
        await orgApi.updateJob(job.id, body);
        if (shouldNotifyJob({ prevStatus: job.status, nextStatus: body.status })) {
          await notifyJob(job.id);
        }
        await reload();
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  async function deleteJob(job) {
    if (!confirm(`Delete ${skin.jobWord.toLowerCase()} ${job.job_number}?`)) return;
    setSaving(true);
    setError(null);
    try {
      if (usingSample) {
        setSampleJobs((prev) => (prev || samplePack.jobs).filter((row) => String(row.id) !== String(job.id)));
      } else {
        await orgApi.deleteJob(job.id);
        await reload();
      }
      setSelectedId(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }

  const desk = useDeskNav();
  const org = membership?.name || 'TrekTrack';
  useDeskChrome(() => ({
    header: {
      title: 'Reports',
      crumb: `${org} › Reports`,
      sub: (
        <>
          {range.label}
          <span className="sep">·</span>
          <span className="num">{formatRangeMdY(range.start, range.end)}</span>
          <span className="sep">·</span>
          {usingSample ? 'Sample preview' : `${totals.count} ${statusName.toLowerCase()}`}
        </>
      ),
    },
    rail: (
      <PeriodRail
        period={period}
        setPeriod={setPeriod}
        range={range}
        mileageRate={team.mileageRate || 0.725}
        onExport={handleExport}
        primaryLabel="Books"
        onPrimary={() => desk?.setPage('books')}
      />
    ),
    mini: <PeriodMini period={period} onExport={handleExport} />,
  }), [org, range.label, range.start, range.end, usingSample, totals.count, statusName, period, team.mileageRate]);

  return (
    <div className="desk-page">
    <div className="mgr-page reports-page">
      <div className="page-toolbar">
        <div />
        <div className="toolbar-actions">
          {liveRows.length > 0 ? (
            <button
              type="button"
              className="btn btn-secondary btn-sm"
              onClick={() => setForceSample((v) => !v)}
            >
              {forceSample ? 'Hide sample' : 'Show sample'}
            </button>
          ) : null}
          <select
            className="report-driver-filter"
            value={activeDriverId}
            onChange={(e) => setDriverId(e.target.value)}
            aria-label={skin.workers}
          >
            <option value="">All {skin.workers.toLowerCase()}</option>
            {sourceDrivers.map((d) => (
              <option key={d.user_id} value={d.user_id}>
                {d.driverNumber ? `${d.driverNumber} - ${d.label}` : d.label}
              </option>
            ))}
          </select>
          <div className="period-pills" role="tablist" aria-label="Status">
            {[...statusesForMode(mode).map((row) => [row.id, row.label]), ['all', 'All']].map(([key, label]) => (
              <button
                key={key}
                type="button"
                className={status === key ? 'active' : ''}
                onClick={() => setStatus(key)}
              >
                {label}
              </button>
            ))}
          </div>
          <div className="period-pills" role="tablist" aria-label="Period">
            {PERIODS.map(([key, label]) => (
              <button
                key={key}
                type="button"
                className={period === key ? 'active' : ''}
                onClick={() => setPeriod(key)}
              >
                {label}
              </button>
            ))}
          </div>
          <button type="button" className="btn btn-secondary btn-sm" onClick={handleExport} disabled={!rows.length}>
            Export
          </button>
        </div>
      </div>
      {usingSample ? (
        <div className="sample-banner">Sample preview · fictional jobs so you can see the layout. Not used in pay.</div>
      ) : null}

      <div className="command-row review-command">
        <Module title="Totals">
          <div className="kpi-row kpi-4 desk-kpis">
            {skin.reviewKind === 'hours' ? (
              <>
                <Kpi label="Lessons" value={String(totals.count)} />
                <Kpi label="Hours" value={hoursTotal.toFixed(1)} />
                <Kpi label="Miles" value={milesTotal.toFixed(1)} />
                <Kpi label="No-shows" value={String(noShows)} />
              </>
            ) : skin.reviewKind === 'visits' ? (
              <>
                <Kpi label="Visits" value={String(totals.count)} />
                <Kpi label="Hours" value={hoursTotal.toFixed(1)} />
                <Kpi label="Miles" value={milesTotal.toFixed(1)} />
                <Kpi label="Open" value={String(rows.filter((j) => j.status === 'open').length)} />
              </>
            ) : (
              <>
                <Kpi label="Jobs" value={String(totals.count)} />
                <Kpi label="Quoted" value={moneyFmt.format(totals.quote)} />
                <Kpi label="Driver pay" value={moneyFmt.format(totals.pay)} />
                <Kpi label="Company take" value={moneyFmt.format(totals.take)} />
              </>
            )}
          </div>
        </Module>
        <Module title="Find">
          <input
            className="find-input"
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={skin.findPlaceholder}
            aria-label={`Find ${skin.boardNoun.toLowerCase()}`}
          />
        </Module>
      </div>
      {proofs.length ? (
        <Module title="Proofs">
          <div className="proof-strip">
            {proofs.map((job) => (
              <button
                key={job.id}
                type="button"
                className="proof-card"
                onClick={() => pickJob(job)}
              >
                <PodPhoto path={job.pod_photo_path || job.pod_signature_path} alt="" />
                <span>{job.job_number}</span>
              </button>
            ))}
          </div>
        </Module>
      ) : null}

      <div className="reports-split">
        <Module title="Register" fill className="report-pack">
          {rows.length === 0 ? (
            <p className="empty">No {statusName.toLowerCase()} {skin.boardNoun.toLowerCase()} in this period.</p>
          ) : (
            <>
              <div className="settle-list">
                {groups.map((group) => {
                  const open = Boolean(openDrivers[group.userId]);
                  return (
                    <div key={group.userId} className="settle-card">
                      <button
                        type="button"
                        className="settle-toggle"
                        onClick={() => toggleDriver(group.userId)}
                        aria-expanded={open}
                      >
                        <span className="disclosure-caret" aria-hidden="true">{open ? '▾' : '▸'}</span>
                        <strong>{group.label}</strong>
                        <span className="settle-stat">{countNoun(group.count, skin)}</span>
                        {quotesKind ? (
                          <span className="settle-stat pay">{moneyFmt.format(group.pay)}</span>
                        ) : (
                          <span className="settle-stat pay">
                            {group.jobs.reduce((sum, job) => sum + jobDurationHours(job), 0).toFixed(1)} h
                          </span>
                        )}
                      </button>
                      {open ? (
                        <div className="settle-jobs">
                          <table className="data-table compact">
                            <thead>
                              <tr>
                                <th>Date</th>
                                <th>{skin.jobWord} #</th>
                                <th>{siteOnly ? skin.siteTitle : 'Pickup town'}</th>
                                {siteOnly ? null : <th>Drop-off town</th>}
                                {quotesKind ? <th>Rate</th> : <th className="num">Hours</th>}
                                <th className="num">Miles</th>
                                {quotesKind ? <th className="num">Total pay</th> : null}
                              </tr>
                            </thead>
                            <tbody>
                              {group.jobs.map((job) => {
                                const tags = jobRateTags(job);
                                return (
                                  <tr
                                    key={job.id}
                                    className={`job-pick${String(selectedId) === String(job.id) ? ' active' : ''}`}
                                    onClick={() => pickJob(job)}
                                  >
                                    <td>{reportDate(job.job_date)}</td>
                                    <td>{job.job_number}</td>
                                    <td>{jobTown(job, 'pickup')}</td>
                                    {siteOnly ? null : <td>{jobTown(job, 'dropoff')}</td>}
                                    {quotesKind ? (
                                      <td>
                                        {tags.length ? (
                                          <span className="rate-tags">
                                            {tags.map((tag) => (
                                              <span key={tag} className="rate-tag">{tag}</span>
                                            ))}
                                          </span>
                                        ) : '—'}
                                      </td>
                                    ) : (
                                      <td className="num">{jobDurationHours(job).toFixed(1)}</td>
                                    )}
                                    <td className="num">{milesCell(job, jobMiles)}</td>
                                    {quotesKind ? <td className="num">{moneyFmt.format(jobPay(job))}</td> : null}
                                  </tr>
                                );
                              })}
                            </tbody>
                          </table>
                        </div>
                      ) : null}
                    </div>
                  );
                })}
              </div>
              <div className="settle-foot">
                <span>Total</span>
                <span>{quotesKind ? moneyFmt.format(totals.pay) : `${hoursTotal.toFixed(1)} h`}</span>
              </div>
            </>
          )}
        </Module>
        <ReportJobEditor
          job={selectedJob}
          drivers={sourceDrivers}
          customers={usingSample ? [] : customers}
          rates={quoteRates}
          jobs={sourceJobs}
          sample={usingSample}
          gpsMiles={selectedJob ? jobMiles?.[selectedJob.id] : null}
          busy={saving}
          onSave={saveJob}
          onDelete={deleteJob}
          onDuplicate={duplicateJob}
          onClose={() => setSelectedId(null)}
        />
      </div>
    </div>
    </div>
  );
}

function ReimbursementReports({ team }) {
  const { period, setPeriod, range, kpis, drivers, trips, expenses, membership, mileageRate } = team;
  const desk = useDeskNav();
  const org = membership?.name || 'TrekTrack';
  useDeskChrome(() => ({
    header: {
      title: 'Reports',
      crumb: `${org} › Reports`,
      sub: (
        <>
          {range.label}
          <span className="sep">·</span>
          <span className="num">{formatRangeMdY(range.start, range.end)}</span>
        </>
      ),
    },
    rail: (
      <PeriodRail
        period={period}
        setPeriod={setPeriod}
        range={range}
        mileageRate={mileageRate || 0.725}
        onExport={handleExport}
        primaryLabel="Books"
        onPrimary={() => desk?.setPage('books')}
      />
    ),
    mini: <PeriodMini period={period} onExport={handleExport} />,
  }), [org, range.label, range.start, range.end, period, mileageRate]);



  function handleExport() {
    const safe = range.label.replace(/\s+/g, '_');
    downloadCsv(`TrekTrack_Team_Mileage_${safe}.csv`, [
      ['Date', 'Driver', 'Class', 'Miles', 'Earnings (USD)', 'Notes'],
      ...trips.map((trip) => [
        trip.trip_date,
        trip.nickname || trip.email,
        trip.is_business === true ? 'Business' : trip.is_business === false ? 'Personal' : 'Unclassified',
        Number(trip.miles).toFixed(2),
        Number(trip.tips ?? 0).toFixed(2),
        trip.notes || '',
      ]),
    ]);
    const total = kpis.buckets.tolls + kpis.buckets.parking + kpis.buckets.gas + kpis.buckets.misc;
    downloadCsv(`TrekTrack_Team_FieldCosts_${safe}.csv`, [
      ['Date', 'Driver', 'Category', 'Merchant', 'Amount (USD)', 'Receipt', 'Notes'],
      ...expenses.map((row) => [
        row.expense_date,
        row.nickname || row.email,
        costLabel(row.category),
        row.merchant || '',
        Number(row.amount ?? 0).toFixed(2),
        row.has_receipt ? 'Yes' : '',
        row.notes || '',
      ]),
      ['Total', '', '', '', total.toFixed(2), '', ''],
    ]);
  }

  return (
    <div className="desk-page">
    <div className="mgr-page">
      <div className="page-toolbar">
        <div />
        <div className="toolbar-actions">
          <div className="period-pills" role="tablist" aria-label="Period">
            {PERIODS.map(([key, label]) => (
              <button
                key={key}
                type="button"
                className={period === key ? 'active' : ''}
                onClick={() => setPeriod(key)}
              >
                {label}
              </button>
            ))}
          </div>
          <button type="button" className="btn btn-secondary btn-sm" onClick={handleExport}>
            Export
          </button>
        </div>
      </div>

      <Module title="Totals">
        <div className="kpi-row">
          <Kpi label="Business miles" value={milesFmt.format(kpis.miles)} />
          <Kpi label="Trips" value={String(kpis.trips)} />
          <Kpi label="Unclassified" value={String(kpis.unclassified)} warn={kpis.unclassified > 0} />
          <Kpi label="Field costs" value={moneyFmt.format(kpis.field)} />
        </div>
        <div className="bucket-row">
          <span>Tolls {moneyFmt.format(kpis.buckets.tolls)}</span>
          <span>Parking {moneyFmt.format(kpis.buckets.parking)}</span>
          <span>Gas {moneyFmt.format(kpis.buckets.gas)}</span>
          <span>Misc {moneyFmt.format(kpis.buckets.misc)}</span>
        </div>
      </Module>
      <Module title="Employees" fill>
        <DriverTable
          drivers={drivers}
          rangeLabel={range.label}
          heading="Employees"
          hideJobs
        />
      </Module>
    </div>
    </div>
  );
}

function Kpi({ label, value, warn = false }) {
  return (
    <div className={`kpi${warn ? ' warn' : ''}`}>
      <div className="label">{label}</div>
      <div className="kpi-value">{value}</div>
    </div>
  );
}

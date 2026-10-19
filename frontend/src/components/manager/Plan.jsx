import { useEffect, useMemo, useState } from 'react';
import { composeAddress, recentJobStops } from '../../lib/address.js';
import { nextChargeNumber } from '../../lib/accountForm.js';
import { customerFromPickup, lastCustomerId, rememberLastCustomer } from '../../lib/accountMatch.js';
import { drivingEstimate } from '../../lib/geo.js';
import { applyFormChange, emptyForm, formFromJob, ratesForAccount, withQuote, withSuggestedAccount } from '../../lib/jobForm.js';
import { isoDate } from '../../lib/period.js';
import {
  BOARD_DATE_KEY,
  CAL_DOW,
  cellStats,
  hoursByUserMap,
  hoursLabel,
  monthGrid,
  monthTitle,
  shiftMonth,
} from '../../lib/planMonth.js';
import { deleteJobById, duplicateJobForm, jobSaveHint, saveJobForm } from '../../lib/jobSave.js';
import { isCourierMode, isServiceJobStyle } from '../../lib/company.js';
import { deskSkin } from '../../lib/layout.js';
import { orgApi } from '../../orgApi.js';
import { useDeskNav } from '../../context/DeskNav.jsx';
import { useTeam } from '../../context/TeamContext.jsx';
import DispatchMap from './DispatchMap.jsx';
import JobDayList, { formatJobTime, jobsOnDate } from './JobDayList.jsx';
import JobForm from './JobForm.jsx';
import Module from './Module.jsx';
import { moneyFmt } from './format.js';
import DeskTitle from './DeskTitle.jsx';

function writeBoardDate(iso) {
  try {
    sessionStorage.setItem(BOARD_DATE_KEY, iso);
  } catch {
    /* private mode */
  }
}

export default function Plan() {
  const team = useTeam();
  const skin = deskSkin(team.membership?.operatingMode);
  const deskNav = useDeskNav();
  const today = isoDate(new Date());
  const now = new Date();
  const [cursor, setCursor] = useState({ year: now.getFullYear(), month: now.getMonth() });
  const [selected, setSelected] = useState(today);
  const [hoursRows, setHoursRows] = useState([]);
  const [driverPop, setDriverPop] = useState(null);
  const [jobPop, setJobPop] = useState(null);
  const [formOpen, setFormOpen] = useState(false);
  const [form, setForm] = useState(() => emptyForm({ jobDate: today }));
  const [editingId, setEditingId] = useState(null);
  const [busy, setBusy] = useState(false);
  const [estimating, setEstimating] = useState(false);
  const [savingAccount, setSavingAccount] = useState(false);

  const takePctDisplay = Math.round((team.quoteRates?.companyTakePct ?? 0.3) * 100);

  useEffect(() => {
    const orgId = team.membership?.orgId;
    if (!orgId) return undefined;
    let live = true;
    orgApi.listDriverHours(orgId).then((rows) => {
      if (live) setHoursRows(rows);
    }).catch(() => {
      if (live) setHoursRows([]);
    });
    return () => {
      live = false;
    };
  }, [team.membership?.orgId, team.jobs]);

  useEffect(() => {
    if (!formOpen && !driverPop && !jobPop) return undefined;
    function onKey(e) {
      if (e.key !== 'Escape') return;
      if (formOpen) {
        setFormOpen(false);
        setEditingId(null);
      } else if (jobPop) {
        setJobPop(null);
      } else {
        setDriverPop(null);
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [formOpen, driverPop, jobPop]);

  const hoursMap = useMemo(() => hoursByUserMap(hoursRows), [hoursRows]);
  const cells = useMemo(() => monthGrid(cursor.year, cursor.month), [cursor.year, cursor.month]);
  const statsByIso = useMemo(() => {
    const map = new Map();
    for (const cell of cells) {
      map.set(cell.iso, cellStats(cell.iso, {
        jobs: team.jobs,
        hoursMap,
        drivers: team.drivers,
      }));
    }
    return map;
  }, [cells, team.jobs, hoursMap, team.drivers]);

  const dayJobs = useMemo(() => jobsOnDate(team.jobs, selected), [team.jobs, selected]);
  const recents = useMemo(() => recentJobStops(team.jobs), [team.jobs]);

  function ratesFor(nextForm) {
    const customer = (team.customers || []).find((row) => row.id === nextForm.customer_id);
    return ratesForAccount(team.quoteRates, customer);
  }

  function blankForm(date) {
    const customerId = lastCustomerId(team.membership?.orgId, team.customers);
    const next = emptyForm({
      jobDate: date || selected,
      assignedUserId: '',
      takePct: takePctDisplay,
      customerId,
      weightUnit: team.weightUnit,
      jobPrefix: team.membership?.jobPrefix,
    });
    if (!customerId) return next;
    const customer = (team.customers || []).find((row) => row.id === customerId);
    next.charge_number = customer?.charge_number || '';
    return withQuote(next, ratesForAccount(team.quoteRates, customer));
  }

  function setField(key, value) {
    setForm((prev) => {
      const nextForm = key === 'customer_id' ? { ...prev, customer_id: value } : prev;
      const rates = ratesFor(nextForm);
      const base = key === 'customer_id' && !prev.quote_manual
        ? { ...prev, company_take_pct: String(Math.round((rates.companyTakePct ?? 0.3) * 100)) }
        : prev;
      const changed = applyFormChange(base, key, value, rates, team.customers);
      if (key === 'pickup_name' || key === 'pickup_email') {
        return withSuggestedAccount(changed, team.customers, team.quoteRates);
      }
      return changed;
    });
  }

  function toggleWeekday(id) {
    setForm((prev) => {
      const on = prev.weekdays.includes(id);
      return { ...prev, weekdays: on ? prev.weekdays.filter((d) => d !== id) : [...prev.weekdays, id] };
    });
  }

  function closeForm() {
    setFormOpen(false);
    setEditingId(null);
    setForm(blankForm(selected));
  }

  function openNew(date) {
    const iso = date || selected;
    setSelected(iso);
    setEditingId(null);
    setForm(blankForm(iso));
    setFormOpen(true);
    setDriverPop(null);
    setJobPop(null);
  }

  function startEdit(job) {
    setSelected(job.job_date);
    setEditingId(job.id);
    setForm(formFromJob(job, { takePct: takePctDisplay, jobDate: job.job_date, customers: team.customers }));
    setFormOpen(true);
    setDriverPop(null);
    setJobPop(null);
  }

  function pickDate(iso) {
    setSelected(iso);
    setDriverPop(null);
  }

  function openJobs(iso) {
    setSelected(iso);
    setJobPop(iso);
    setDriverPop(null);
  }

  function jumpToday() {
    writeBoardDate(selected);
    deskNav?.setPage('jobs');
  }

  async function handleMarkDelivered(job) {
    team.setError(null);
    try {
      await orgApi.updateJob(job.id, { status: 'delivered' });
      if (editingId === job.id) closeForm();
      await team.reload();
    } catch (err) {
      team.setError(err.message);
    }
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setBusy(true);
    team.setError(null);
    try {
      const result = await saveJobForm({
        form,
        editingId,
        orgId: team.membership.orgId,
        jobs: team.jobs,
        ratesFor,
      });
      if (result.boardDate) setSelected(result.boardDate);
      closeForm();
      await team.reload();
    } catch (err) {
      team.setError(`${err.message}${jobSaveHint(err.message)}`);
    } finally {
      setBusy(false);
    }
  }

  async function handleDuplicate() {
    if (!editingId) return;
    setBusy(true);
    team.setError(null);
    try {
      const result = await duplicateJobForm({
        form,
        orgId: team.membership.orgId,
        jobDate: selected,
      });
      if (result.boardDate) setSelected(result.boardDate);
      closeForm();
      await team.reload();
    } catch (err) {
      team.setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleDelete() {
    if (!editingId) return;
    if (!confirm('Delete this job?')) return;
    setBusy(true);
    team.setError(null);
    try {
      await deleteJobById(editingId);
      closeForm();
      await team.reload();
    } catch (err) {
      team.setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleEstimate() {
    const pickup = composeAddress(form.pickup);
    const dropoff = composeAddress(form.dropoff);
    if (!pickup || !dropoff) {
      team.setError('Fill pickup and delivery addresses first.');
      return;
    }
    setEstimating(true);
    team.setError(null);
    try {
      const { miles } = await drivingEstimate(pickup, dropoff);
      setForm((prev) => withQuote({
        ...prev,
        estimated_miles: miles.toFixed(1),
        milesDirty: true,
      }, ratesFor(form)));
    } catch (err) {
      team.setError(err.message);
    } finally {
      setEstimating(false);
    }
  }

  async function handleSaveAccount() {
    const fields = customerFromPickup(form, { terms: team.membership?.defaultTerms });
    if (!fields.charge_number) fields.charge_number = nextChargeNumber(team.customers);
    if (!fields.name || !team.membership?.orgId) return;
    setSavingAccount(true);
    team.setError(null);
    try {
      const row = await orgApi.saveCustomer(team.membership.orgId, fields);
      rememberLastCustomer(team.membership.orgId, row.id);
      setField('customer_id', row.id);
      await team.reload();
    } catch (err) {
      team.setError(err.message);
    } finally {
      setSavingAccount(false);
    }
  }

  function driverName(userId) {
    if (!userId) return 'Unassigned';
    return team.drivers.find((d) => d.user_id === userId)?.label || skin.worker;
  }

  const popStats = driverPop ? statsByIso.get(driverPop) : null;
  const jobPopList = jobPop ? jobsOnDate(team.jobs, jobPop) : [];

  return (
    <div className="desk-page">
    <DeskTitle title="Plan" sub="Month coverage and the map for the selected day." />
    <div className="mgr-page dispatch-page plan-page">
      <div className="page-toolbar">
        <div>
          <h1>Plan</h1>
          <p className="page-sub">Month coverage and the map for the selected day.</p>
        </div>
        <div className="toolbar-actions">
          <button
            type="button"
            className="btn btn-secondary btn-sm"
            onClick={() => {
              const n = new Date();
              setCursor({ year: n.getFullYear(), month: n.getMonth() });
              setSelected(today);
            }}
          >
            This month
          </button>
          <button type="button" className="btn btn-secondary btn-sm" onClick={jumpToday}>
            Jump to Today
          </button>
        </div>
      </div>

      <div className="plan-grid">
        <Module fill className="plan-cal-mod">
          <div className="plan-month">
          <div className="plan-month-nav">
            <button
              type="button"
              className="btn-ghost btn-sm"
              onClick={() => setCursor((c) => shiftMonth(c.year, c.month, -1))}
              aria-label="Previous month"
            >
              ‹
            </button>
            <h2>{monthTitle(cursor.year, cursor.month)}</h2>
            <button
              type="button"
              className="btn-ghost btn-sm"
              onClick={() => setCursor((c) => shiftMonth(c.year, c.month, 1))}
              aria-label="Next month"
            >
              ›
            </button>
          </div>
          <div className="plan-cal-head">
            {CAL_DOW.map((d) => (
              <span key={d}>{d}</span>
            ))}
          </div>
          <div className="plan-cal">
            {cells.map((cell) => {
              const stats = statsByIso.get(cell.iso);
              const classes = [
                'plan-cell',
                cell.inMonth ? '' : 'out',
                cell.iso === selected ? 'selected' : '',
                cell.iso === today ? 'today' : '',
                stats?.weekend ? 'weekend' : '',
                stats?.uncovered ? 'uncovered' : '',
                stats?.idle ? 'idle' : '',
              ].filter(Boolean).join(' ');
              return (
                <div key={cell.iso} className={classes}>
                  <button type="button" className="plan-cell-day" onClick={() => pickDate(cell.iso)}>
                    {cell.day}
                  </button>
                  <button
                    type="button"
                    className="plan-cell-stat"
                    title={`${skin.boardNoun} this day`}
                    onClick={() => openJobs(cell.iso)}
                  >
                    {stats?.jobs || 0} {stats?.jobs === 1 ? skin.jobWord.toLowerCase() : skin.boardNoun.toLowerCase()}
                  </button>
                  <button
                    type="button"
                    className="plan-cell-stat"
                    title={`${skin.workers} scheduled`}
                    onClick={(e) => {
                      e.stopPropagation();
                      setSelected(cell.iso);
                      setDriverPop(cell.iso);
                      setJobPop(null);
                    }}
                  >
                    {stats?.drivers || 0} {skin.workerShort.toLowerCase()}
                  </button>
                  {stats?.jobs && skin.showCourierQuotes ? (
                    <span className="plan-cell-money">{moneyFmt.format(stats.quoted)}</span>
                  ) : null}
                  {stats?.unassigned ? <span className="plan-cell-badge">Unassigned</span> : null}
                  <button type="button" className="plan-cell-add" onClick={() => openNew(cell.iso)}>
                    + {skin.jobWord}
                  </button>
                </div>
              );
            })}
          </div>
          </div>
        </Module>

        <Module title="Map" fill>
          <div className="plan-map">
            <DispatchMap jobs={dayJobs} pings={[]} showPings={false} expanded />
          </div>
        </Module>
      </div>

      {jobPop ? (
        <div className="plan-pop-wrap">
          <button type="button" className="plan-pop-scrim" aria-label="Close jobs" onClick={() => setJobPop(null)} />
          <div className="plan-pop plan-pop-jobs" role="dialog" aria-label={`${skin.boardNoun} this day`}>
            <div className="mod-head-row">
              <h2 className="mod-head">{skin.boardNoun} · {jobPop}</h2>
              <div className="mod-actions">
                <button type="button" className="btn btn-primary btn-sm" onClick={() => openNew(jobPop)}>
                  Add {skin.jobWord.toLowerCase()}
                </button>
                <button type="button" className="btn-ghost btn-sm" onClick={() => setJobPop(null)}>Close</button>
              </div>
            </div>
            {jobPopList.length === 0 ? (
              <p className="empty">No {skin.boardNoun.toLowerCase()} this day.</p>
            ) : (
              <JobDayList
                jobs={jobPopList}
                editingId={editingId}
                onPick={startEdit}
                driverName={driverName}
                officeClosesJobs={team.membership?.officeClosesJobs}
                onMarkDelivered={handleMarkDelivered}
                mode={team.membership?.operatingMode}
                serviceStyle={isServiceJobStyle(team.membership?.operatingMode)}
                showMoney={skin.showCourierQuotes}
              />
            )}
          </div>
        </div>
      ) : null}

      {driverPop && popStats ? (
        <div className="plan-pop-wrap">
          <button type="button" className="plan-pop-scrim" aria-label={`Close ${skin.workers.toLowerCase()}`} onClick={() => setDriverPop(null)} />
          <div className="plan-pop" role="dialog" aria-label={`${skin.workers} scheduled`}>
            <div className="mod-head-row">
              <h2 className="mod-head">{skin.workers} · {driverPop}</h2>
              <button type="button" className="btn-ghost btn-sm" onClick={() => setDriverPop(null)}>Close</button>
            </div>
            {popStats.roster.length === 0 ? (
              <p className="empty">No hours and no assigned {skin.workers.toLowerCase()} this day.</p>
            ) : (
              <ul className="plan-pop-list">
                {popStats.roster.map((row) => (
                  <li key={row.user_id}>
                    <strong>{row.driverNumber ? `${row.driverNumber} · ${row.label}` : row.label}</strong>
                    <span>{hoursLabel(row.hours)}</span>
                    <span>
                      {row.jobCount
                        ? `${row.jobCount} ${row.jobCount === 1 ? skin.jobWord.toLowerCase() : skin.boardNoun.toLowerCase()}${row.firstTime ? ` · ${formatJobTime(row.firstTime)}${row.lastTime && row.lastTime !== row.firstTime ? `–${formatJobTime(row.lastTime)}` : ''}` : ''}`
                        : `No ${skin.boardNoun.toLowerCase()}`}
                    </span>
                    {row.fromHours ? null : <span className="plan-cell-badge">On a job</span>}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      ) : null}

      {formOpen ? (
        <div className="plan-modal-wrap">
          <button type="button" className="plan-modal-scrim" aria-label="Close job form" onClick={closeForm} />
          <div className="plan-modal" role="dialog" aria-modal="true">
            <JobForm
              form={form}
              setField={setField}
              patchForm={setForm}
              toggleWeekday={toggleWeekday}
              editingId={editingId}
              drivers={team.drivers}
              customers={team.customers}
              recents={recents}
              busy={busy}
              estimating={estimating}
              savingAccount={savingAccount}
              onSubmit={handleSubmit}
              onEstimate={handleEstimate}
              onDuplicate={handleDuplicate}
              onDelete={handleDelete}
              onSaveAccount={handleSaveAccount}
              onClose={closeForm}
              ratesFor={ratesFor}
              trackingToken={team.jobs.find((job) => job.id === editingId)?.tracking_token}
              idPrefix="plan-job"
              weightUnit={team.weightUnit}
              officeClosesJobs={team.membership?.officeClosesJobs}
              useCod={team.membership?.useCod}
              serviceStyle={isServiceJobStyle(team.membership?.operatingMode)}
              courierQuotes={isCourierMode(team.membership?.operatingMode)}
              operatingMode={team.membership?.operatingMode}
              workerLabel={skin.worker}
              siteTitle={skin.siteTitle}
              jobWord={skin.jobWord}
            />
          </div>
        </div>
      ) : null}
    </div>
    </div>
  );
}

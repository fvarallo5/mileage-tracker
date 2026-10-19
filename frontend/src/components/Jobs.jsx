import { useEffect, useMemo, useState } from 'react';
import { useTeam } from '../context/TeamContext.jsx';
import { composeAddress, recentJobStops } from '../lib/address.js';
import { nearestPing, pingOnDay } from '../lib/assignNearest.js';
import { nextChargeNumber } from '../lib/accountForm.js';
import { customerFromPickup, lastCustomerId, rememberLastCustomer } from '../lib/accountMatch.js';
import { drivingEstimate, drivingMinutes, geocodeAddress, jobAddress } from '../lib/geo.js';
import { applyFormChange, emptyForm, formFromJob, ratesForAccount, withQuote, withSuggestedAccount } from '../lib/jobForm.js';
import { boardRank, isActiveJob, isDelivered } from '../lib/jobStatus.js';
import { useDeskChrome } from '../context/DeskNav.jsx';
import { ICO } from './manager/icons.jsx';
import { Avatar } from './manager/DeskWidgets.jsx';
import DispatchMap from './manager/DispatchMap.jsx';
import { formatJobTime, stopLine } from './manager/JobDayList.jsx';
import { isoDate } from '../lib/period.js';
import { BOARD_DATE_KEY } from '../lib/planMonth.js';
import { dayExceptions, dayPulse, jobMatchesQuery } from '../lib/jobSearch.js';
import { nearestOrder } from '../lib/routeOrder.js';
import { deleteJobById, duplicateJobForm, jobSaveHint, saveJobForm } from '../lib/jobSave.js';
import { orgApi } from '../orgApi.js';
import { driverHeadline, isDriverActive, milesFmt, moneyFmt, presenceLabel } from './manager/format.js';
import Module from './manager/Module.jsx';
import { useDeskNav } from '../context/DeskNav.jsx';
import JobDayList from './manager/JobDayList.jsx';
import { isCourierMode, isServiceJobStyle } from '../lib/company.js';
import { deskSkin } from '../lib/layout.js';
import JobForm from './manager/JobForm.jsx';

const UNASSIGNED = '__unassigned__';

function shiftDay(iso, n) {
  const d = new Date(`${iso}T12:00:00`);
  d.setDate(d.getDate() + n);
  return isoDate(d);
}

function prettyDay(iso) {
  const d = new Date(`${iso}T12:00:00`);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' });
}

function isLateJob(job, boardDate, today) {
  if (job.status === 'failed') return true;
  if (isDelivered(job.status) || job.status === 'picked_up' || job.status === 'cancelled') return false;
  if (boardDate < today) return true;
  if (boardDate > today) return false;
  const t = job.pickup_time || job.job_time;
  if (!t) return false;
  const [h, m] = String(t).split(':').map(Number);
  if (!Number.isFinite(h)) return false;
  const at = new Date();
  at.setHours(h, Number.isFinite(m) ? m : 0, 0, 0);
  return Date.now() > at.getTime();
}

function boardChip(job, boardDate, today) {
  if (isDelivered(job.status)) return { id: 'on', label: 'Done' };
  if (job.status === 'picked_up') return { id: 'pri', label: 'En route' };
  if (isLateJob(job, boardDate, today)) return { id: 'alert', label: 'Late' };
  return { id: 'off', label: 'Scheduled' };
}

function readBoardDate(fallback) {
  try {
    const saved = sessionStorage.getItem(BOARD_DATE_KEY);
    if (saved && /^\d{4}-\d{2}-\d{2}$/.test(saved)) {
      sessionStorage.removeItem(BOARD_DATE_KEY);
      return saved;
    }
  } catch {
    /* private mode */
  }
  return fallback;
}

export default function Jobs() {
  const team = useTeam();
  const today = isoDate(new Date());
  const [boardDate, setBoardDate] = useState(() => readBoardDate(today));
  const [form, setForm] = useState(() => emptyForm({ jobDate: today }));
  const [editingId, setEditingId] = useState(null);
  const [busy, setBusy] = useState(false);
  const [hideDone, setHideDone] = useState(false);
  const [selectedDriver, setSelectedDriver] = useState('');
  const [estimating, setEstimating] = useState(false);
  const [ordering, setOrdering] = useState(false);
  const [assigning, setAssigning] = useState(false);
  const [etas, setEtas] = useState({});
  const [savingAccount, setSavingAccount] = useState(false);
  const [query, setQuery] = useState('');
  const [pulseFilter, setPulseFilter] = useState('');
  const [statusChip, setStatusChip] = useState('all');
  const [view, setView] = useState('board');
  const [formOpen, setFormOpen] = useState(false);
  const [showRoutes, setShowRoutes] = useState(true);
  const deskNav = useDeskNav();

  const driverList = useMemo(() => {
    const known = new Map(team.drivers.map((d) => [d.user_id, d]));
    for (const job of team.jobs) {
      if (job.job_date !== boardDate) continue;
      if (job.assigned_user_id && !known.has(job.assigned_user_id)) {
        known.set(job.assigned_user_id, {
          user_id: job.assigned_user_id,
          label: 'Driver',
          phone: '',
          vehicle: '',
          vehicleColor: '',
        });
      }
    }
    return [...known.values()];
  }, [team.drivers, team.jobs, boardDate]);

  const pulse = useMemo(() => dayPulse(team.jobs, boardDate), [team.jobs, boardDate]);
  const exceptions = useMemo(
    () => dayExceptions(team.jobs, boardDate, team.membership?.operatingMode),
    [team.jobs, boardDate, team.membership?.operatingMode],
  );

  const dayJobs = useMemo(() => {
    const list = [];
    for (const job of team.jobs) {
      if (job.job_date !== boardDate) continue;
      if (hideDone && !isActiveJob(job.status)) continue;
      if (view !== 'board') {
        if (selectedDriver === UNASSIGNED) {
          if (job.assigned_user_id) continue;
        } else if (selectedDriver && job.assigned_user_id !== selectedDriver) continue;
      }
      if (pulseFilter === 'open' && job.status !== 'open') continue;
      if (pulseFilter === 'picked_up' && job.status !== 'picked_up') continue;
      if (pulseFilter === 'delivered' && !isDelivered(job.status)) continue;
      if (pulseFilter === 'failed' && job.status !== 'failed') continue;
      if (pulseFilter === 'unassigned' && job.assigned_user_id) continue;
      if (statusChip === 'open' && job.status !== 'open') continue;
      if (statusChip === 'picked_up' && job.status !== 'picked_up') continue;
      if (statusChip === 'delivered' && !isDelivered(job.status)) continue;
      if (statusChip === 'failed' && job.status !== 'failed' && !isLateJob(job, boardDate, today)) continue;
      if (!jobMatchesQuery(job, query, { customers: team.customers, drivers: team.drivers })) continue;
      list.push(job);
    }
    list.sort((a, b) => {
      const rank = boardRank(a.status) - boardRank(b.status);
      if (rank) return rank;
      const unassigned = Number(Boolean(a.assigned_user_id)) - Number(Boolean(b.assigned_user_id));
      if (unassigned) return unassigned;
      const orderA = Number(a.stop_order);
      const orderB = Number(b.stop_order);
      if (Number.isFinite(orderA) && Number.isFinite(orderB) && orderA !== orderB) return orderA - orderB;
      return String(a.pickup_time || a.job_time || '99').localeCompare(String(b.pickup_time || b.job_time || '99'));
    });
    return list;
  }, [team.jobs, boardDate, hideDone, selectedDriver, pulseFilter, statusChip, query, team.customers, team.drivers, today, view]);

  const recents = useMemo(() => recentJobStops(team.jobs), [team.jobs]);

  const pingMarkers = useMemo(
    () =>
      (team.pings || []).map((p) => ({
        ...p,
        label: team.drivers.find((d) => d.user_id === p.user_id)?.label || 'Driver',
      })),
    [team.pings, team.drivers],
  );

  useEffect(() => {
    let live = true;
    async function loadEtas() {
      const next = {};
      for (const job of dayJobs) {
        if (job.status !== 'picked_up') continue;
        try {
          const dropQuery = jobAddress(job, 'dropoff') || job.dropoff_address;
          const drop = dropQuery ? await geocodeAddress(dropQuery) : null;
          if (!live) return;
          const ping = pingMarkers.find((row) => row.user_id === job.assigned_user_id && pingOnDay(row, boardDate));
          let origin = ping && Number.isFinite(Number(ping.lat)) && Number.isFinite(Number(ping.lng))
            ? { lat: Number(ping.lat), lng: Number(ping.lng) }
            : null;
          if (!origin) {
            const pickupQuery = jobAddress(job, 'pickup') || job.pickup_address;
            origin = pickupQuery ? await geocodeAddress(pickupQuery) : null;
          }
          if (!live) return;
          if (!origin || !drop) continue;
          const minutes = await drivingMinutes(origin, drop);
          if (minutes != null) next[job.id] = minutes;
        } catch {
          /* keep card without an ETA */
        }
      }
      if (live) setEtas(next);
    }
    loadEtas();
    return () => {
      live = false;
    };
  }, [dayJobs, pingMarkers, boardDate]);

  function todayOpenCount(userId) {
    return team.jobs.filter((j) => {
      if (j.job_date !== boardDate || !isActiveJob(j.status)) return false;
      if (userId === UNASSIGNED) return !j.assigned_user_id;
      return j.assigned_user_id === userId;
    }).length;
  }

  const takePctDisplay = Math.round((team.quoteRates?.companyTakePct ?? 0.3) * 100);

  function blankForm() {
    const customerId = lastCustomerId(team.membership?.orgId, team.customers);
    const next = emptyForm({
      jobDate: boardDate,
      assignedUserId: selectedDriver === UNASSIGNED ? '' : selectedDriver,
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

  function ratesFor(form) {
    const customer = (team.customers || []).find((row) => row.id === form.customer_id);
    return ratesForAccount(team.quoteRates, customer);
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

  useEffect(() => {
    if (editingId) return;
    setForm((prev) => {
      if (prev.accountDirty || prev.customer_id) return prev;
      const last = lastCustomerId(team.membership?.orgId, team.customers);
      if (!last) return prev;
      const customer = (team.customers || []).find((row) => row.id === last);
      return withQuote({
        ...prev,
        customer_id: last,
        charge_number: customer?.charge_number || '',
      }, ratesForAccount(team.quoteRates, customer));
    });
  }, [team.customers, team.membership?.orgId, editingId, team.quoteRates]);

  function toggleWeekday(id) {
    setForm((prev) => {
      const on = prev.weekdays.includes(id);
      return { ...prev, weekdays: on ? prev.weekdays.filter((d) => d !== id) : [...prev.weekdays, id] };
    });
  }

  function pickDriver(userId) {
    const next = selectedDriver === userId ? '' : userId;
    setSelectedDriver(next);
    if (!editingId) {
      setForm((prev) => ({
        ...prev,
        assigned_user_id: next === UNASSIGNED ? '' : next,
        job_date: boardDate,
      }));
    }
  }

  function startEdit(job) {
    setEditingId(job.id);
    setForm(formFromJob(job, { takePct: takePctDisplay, jobDate: boardDate, customers: team.customers }));
    setFormOpen(true);
  }

  function closeForm() {
    setEditingId(null);
    setForm(blankForm());
    setFormOpen(false);
  }

  function openNew(assigned = '') {
    setEditingId(null);
    setForm({ ...blankForm(), assigned_user_id: assigned === UNASSIGNED ? '' : assigned, job_date: boardDate });
    setFormOpen(true);
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
      if (result.boardDate) setBoardDate(result.boardDate);
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
      await duplicateJobForm({
        form,
        orgId: team.membership.orgId,
        jobDate: boardDate,
      });
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

  async function handleSuggest() {
    const pool = team.jobs.filter((job) => {
      if (job.job_date !== boardDate || !isActiveJob(job.status)) return false;
      if (selectedDriver === UNASSIGNED) return !job.assigned_user_id;
      if (selectedDriver && job.assigned_user_id !== selectedDriver) return false;
      return true;
    });
    const groups = new Map();
    for (const job of pool) {
      const key = job.assigned_user_id || '';
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(job);
    }
    setOrdering(true);
    team.setError(null);
    try {
      let changed = false;
      for (const jobs of groups.values()) {
        if (jobs.length < 2) continue;
        const stops = [];
        for (const job of jobs) {
          const address = job.pickup_address
            || [job.pickup_line1, job.pickup_city, job.pickup_state, job.pickup_zip].filter(Boolean).join(', ');
          const point = address ? await geocodeAddress(address) : null;
          stops.push({
            id: job.id,
            lat: point?.lat,
            lng: point?.lng,
            time: job.pickup_time || job.job_time || '',
          });
        }
        const ids = nearestOrder(stops);
        for (let i = 0; i < ids.length; i += 1) {
          await orgApi.updateJob(ids[i], { stop_order: i + 1 });
        }
        changed = true;
      }
      if (changed) await team.reload();
      else team.setError('Need at least two active jobs for one driver on this day.');
    } catch (err) {
      team.setError(err.message);
    } finally {
      setOrdering(false);
    }
  }

  async function handleAssign() {
    const openJobs = team.jobs.filter((job) => job.job_date === boardDate && job.status === 'open');
    if (!openJobs.length) {
      team.setError('No open jobs on this day.');
      return;
    }
    const pings = (team.pings || []).filter((ping) => pingOnDay(ping, boardDate));
    if (!pings.length) {
      team.setError('No driver has a location ping on this day.');
      return;
    }
    const countLabel = `${openJobs.length} open job${openJobs.length === 1 ? '' : 's'}`;
    if (!confirm(`Move ${countLabel} to the nearest driver with a location ping today? Drivers without a ping are not chosen. You can change any driver after.`)) {
      return;
    }
    setAssigning(true);
    team.setError(null);
    try {
      let moved = 0;
      let skipped = 0;
      for (const job of openJobs) {
        const address = job.pickup_address
          || [job.pickup_line1, job.pickup_city, job.pickup_state, job.pickup_zip].filter(Boolean).join(', ');
        const point = address ? await geocodeAddress(address) : null;
        if (!point) {
          skipped += 1;
          continue;
        }
        const ping = nearestPing(point, pings);
        if (!ping || ping.user_id === job.assigned_user_id) continue;
        await orgApi.updateJob(job.id, { assigned_user_id: ping.user_id });
        moved += 1;
      }
      if (moved) await team.reload();
      if (!moved && skipped) {
        team.setError(`${skipped} open job${skipped === 1 ? '' : 's'} had no map point, so nothing was reassigned.`);
      } else if (!moved) {
        team.setError('Those open jobs are already on the nearest driver.');
      } else if (skipped) {
        team.setError(`${skipped} open job${skipped === 1 ? '' : 's'} had no map point and stayed put.`);
      }
    } catch (err) {
      team.setError(err.message);
    } finally {
      setAssigning(false);
    }
  }

  function driverName(userId) {
    if (!userId) return 'Unassigned';
    return driverList.find((d) => d.user_id === userId)?.label || 'Driver';
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

  const skin = deskSkin(team.membership?.operatingMode);
  const pulseValue = (id) => {
    if (id === 'unassigned') return pulse.unassigned;
    return pulse[id] ?? 0;
  };
  const PULSE = skin.pulse.map(([id, label]) => [id, label, pulseValue(id)]);
  const org = team.membership?.name || 'TrekTrack';
  const serviceStyle = isServiceJobStyle(team.membership?.operatingMode);
  const allDay = team.jobs.filter((j) => j.job_date === boardDate);
  const doneCount = allDay.filter((j) => isDelivered(j.status)).length;
  const estMiles = allDay.reduce((s, j) => s + Number(j.estimated_miles || 0), 0);
  const chipCounts = {
    all: allDay.length,
    open: allDay.filter((j) => j.status === 'open').length,
    picked_up: allDay.filter((j) => j.status === 'picked_up').length,
    failed: allDay.filter((j) => j.status === 'failed' || isLateJob(j, boardDate, today)).length,
    delivered: allDay.filter((j) => isDelivered(j.status)).length,
  };

  useDeskChrome(() => ({
    header: {
      title: skin.boardNoun,
      crumb: `${org} › ${skin.boardNoun}`,
      sub: (
        <>
          {boardDate === today ? 'Today' : prettyDay(boardDate)}
          <span className="sep">·</span>
          <span className="num">{allDay.length} {allDay.length === 1 ? skin.jobWord.toLowerCase() : skin.boardNoun.toLowerCase()}</span>
          <span className="sep">·</span>
          {serviceStyle ? 'One site' : 'Pickup and delivery'}
        </>
      ),
      right: (
        <>
          <span className="pill well"><b className="num">{doneCount}/{allDay.length}</b> done</span>
          <span className="pill well"><b className="num">{milesFmt.format(estMiles)}</b> mi est.</span>
        </>
      ),
    },
    rail: (
      <section className="mgr-controls metal" aria-label="Day and actions">
        <div className="range">
          <button type="button" className="step fill-steel" onClick={() => setBoardDate((d) => shiftDay(d, -1))} aria-label="Previous day">{ICO.prev}</button>
          <div className="lbl num">
            {prettyDay(boardDate)}
            <small>{boardDate === today ? 'Today' : 'Scheduled'} · {allDay.length} {skin.boardNoun.toLowerCase()}</small>
          </div>
          <button type="button" className="step fill-steel" onClick={() => setBoardDate((d) => shiftDay(d, 1))} aria-label="Next day">{ICO.next}</button>
        </div>
        <div className="toggle-row">
          Hide done jobs
          <button type="button" className={`mgr-switch well${hideDone ? ' on' : ''}`} aria-pressed={hideDone} onClick={() => setHideDone((v) => !v)} />
        </div>
        <div className="toggle-row">
          Show route lines
          <button type="button" className={`mgr-switch well${showRoutes ? ' on' : ''}`} aria-pressed={showRoutes} onClick={() => setShowRoutes((v) => !v)} />
        </div>
        <div className="btn-row">
          {skin.showAssignTools ? (
            <button type="button" className="btn fill-steel" onClick={handleAssign} disabled={ordering || assigning}>
              {ICO.bolt}{assigning ? 'Assigning…' : 'Assign'}
            </button>
          ) : <span />}
          <button type="button" className="btn fill-blue" onClick={() => openNew('')}>
            {ICO.plus}New {skin.jobWord.toLowerCase()}
          </button>
        </div>
      </section>
    ),
    mini: (
      <section className="mgr-controls c-mini metal">
        <button type="button" className="icon-btn fill-blue" title="Today" onClick={() => setBoardDate(today)}>T</button>
        {skin.showAssignTools ? (
          <button type="button" className="icon-btn fill-steel" title="Assign nearest" onClick={handleAssign}>{ICO.bolt}</button>
        ) : null}
        <button type="button" className="icon-btn fill-blue" title="New job" onClick={() => openNew('')}>{ICO.plus}</button>
      </section>
    ),
  }), [org, skin.boardNoun, skin.jobWord, skin.showAssignTools, boardDate, today, allDay.length, doneCount, estMiles, hideDone, showRoutes, assigning, ordering]);

  const formEl = (
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
      weightUnit={team.weightUnit}
      officeClosesJobs={team.membership?.officeClosesJobs}
      useCod={team.membership?.useCod}
      serviceStyle={serviceStyle}
      courierQuotes={isCourierMode(team.membership?.operatingMode)}
      operatingMode={team.membership?.operatingMode}
      workerLabel={skin.worker}
      siteTitle={skin.siteTitle}
      jobWord={skin.jobWord}
    />
  );

  return (
    <div className="desk-page is-board">
      <div className="toolbar">
        <div className="seg well" style={{ gridTemplateColumns: 'repeat(3, auto)' }}>
          {[
            ['board', ICO.board, 'Board'],
            ['list', ICO.list, 'List'],
            ['map', ICO.map, 'Map'],
          ].map(([id, icon, label]) => (
            <button
              key={id}
              type="button"
              className={view === id ? 'fill-blue' : ''}
              aria-pressed={view === id}
              style={{ padding: '5px 12px', display: 'flex', gap: 6, alignItems: 'center' }}
              onClick={() => setView(id)}
            >
              {icon}{label}
            </button>
          ))}
        </div>
        <div className="chips">
          {[
            ['all', 'All'],
            ['open', 'Scheduled'],
            ['picked_up', 'En route'],
            ['failed', 'Late'],
            ['delivered', 'Done'],
          ].map(([id, label]) => (
            <button key={id} type="button" className="fchip" aria-pressed={statusChip === id} onClick={() => setStatusChip(id)}>
              {label} <span className="n">{chipCounts[id]}</span>
            </button>
          ))}
        </div>
        <div className="search well" style={{ marginLeft: 'auto', width: 240 }}>
          {ICO.search}
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={skin.findPlaceholder}
            aria-label={`Find ${skin.boardNoun.toLowerCase()}`}
            style={{ flex: 1, border: 0, background: 'transparent', color: 'inherit', font: 'inherit', outline: 'none', minWidth: 0 }}
          />
        </div>
      </div>

      {exceptions.length ? (
        <div className="card metal" style={{ marginBottom: 14, padding: '10px 16px' }}>
          {exceptions.map((row) => (
            <button key={`${row.kind}-${row.job.id}`} type="button" className="btn btn-xs fill-steel" style={{ marginRight: 8 }} onClick={() => startEdit(row.job)}>
              {row.job.job_number || 'Job'} · {row.label}
            </button>
          ))}
        </div>
      ) : null}

      {view === 'board' ? (
        <div className="board">
          {[{ user_id: '', label: 'Unassigned', lastSeenAt: null }, ...driverList].map((d) => {
            const uid = d.user_id;
            const colJobs = dayJobs.filter((j) => (uid ? j.assigned_user_id === uid : !j.assigned_user_id));
            const done = colJobs.filter((j) => isDelivered(j.status)).length;
            const pct = colJobs.length ? Math.round((done / colJobs.length) * 100) : 0;
            return (
              <section className="col well" key={uid || 'unassigned'}>
                <div className="col-h">
                  {uid ? <Avatar name={d.label} status={isDriverActive(d.lastSeenAt) ? 'on' : 'off'} seed={uid} /> : <span className="avatar" style={{ background: 'var(--surface-2)' }}>—</span>}
                  <div>
                    <b>{d.label}</b>
                    <span>{colJobs.length} jobs · {done} done</span>
                  </div>
                  <button type="button" className="btn fill-steel" onClick={() => openNew(uid || UNASSIGNED)}>{ICO.plus}Add</button>
                </div>
                <div className="progress"><i style={{ '--w': `${pct}%` }} /></div>
                {colJobs.length === 0 ? (
                  <div className="add-slot" style={{ padding: '28px 10px' }}>
                    {uid ? 'Off shift today' : 'No unassigned jobs'}
                    <br />
                    <span style={{ fontSize: 11.5 }}>Add a job to this column</span>
                  </div>
                ) : colJobs.map((job, idx) => {
                  const chip = boardChip(job, boardDate, today);
                  const late = chip.id === 'alert' && !isDelivered(job.status);
                  const pickup = stopLine(job, 'pickup');
                  const drop = stopLine(job, 'dropoff');
                  const [pName, pCity] = splitStop(pickup);
                  const [dName, dCity] = splitStop(drop);
                  const miles = Number(job.estimated_miles || 0);
                  const lit = job.status === 'picked_up';
                  return (
                    <article
                      key={job.id}
                      className={`job metal${lit ? ' chrome-edge sheen is-lit' : ''}${isDelivered(job.status) ? ' done' : ''}${late ? ' late' : ''}`}
                      onClick={() => startEdit(job)}
                    >
                      <div className="job-top">
                        <span className="no fill-steel">{job.stop_order || idx + 1}</span>
                        <span className="time">{formatJobTime(job.pickup_time || job.job_time) || '—'}</span>
                        <span className={`status ${chip.id}`}>{chip.label}</span>
                      </div>
                      <div className="route">
                        <i className="pin a" />
                        <div><b>{pName || 'Pickup'}</b> {pCity ? <span>· {pCity}</span> : null}</div>
                        {serviceStyle ? null : (
                          <>
                            <i className="pin b" />
                            <div><b>{dName || 'Dropoff'}</b> {dCity ? <span>· {dCity}</span> : null}</div>
                          </>
                        )}
                      </div>
                      <div className="job-foot">
                        <span><b className="num">{miles ? milesFmt.format(miles) : '—'}</b> mi est.</span>
                        {skin.showCourierQuotes && miles ? <span className="money-t num">{moneyFmt.format(miles * (team.mileageRate || 0.725))}</span> : null}
                        <span style={{ marginLeft: 'auto', display: 'flex', gap: 6, alignItems: 'center' }}>
                          {job.pod_photo_path ? ICO.camera : null}
                          {job.pod_signature_path ? ICO.pod : null}
                        </span>
                      </div>
                    </article>
                  );
                })}
                {colJobs.length ? <div className="add-slot" onClick={() => openNew(uid || UNASSIGNED)}>+ Drop or add a job</div> : null}
              </section>
            );
          })}
        </div>
      ) : null}

      {view === 'list' ? (
        <section className="card metal" style={{ flex: 1, minHeight: 0, overflow: 'auto' }}>
          {dayJobs.length === 0 ? (
            <p className="empty">No {skin.boardNoun.toLowerCase()} for this day.</p>
          ) : (
            <JobDayList
              jobs={dayJobs}
              editingId={editingId}
              onPick={startEdit}
              driverName={driverName}
              etas={etas}
              officeClosesJobs={team.membership?.officeClosesJobs}
              onMarkDelivered={handleMarkDelivered}
              mode={team.membership?.operatingMode}
              serviceStyle={serviceStyle}
              showMoney={skin.showCourierQuotes}
            />
          )}
        </section>
      ) : null}

      {view === 'map' ? (
        <section className="card metal" style={{ flex: 1, minHeight: 0 }}>
          <DispatchMap jobs={dayJobs} pings={showRoutes ? pingMarkers : []} showPings={showRoutes} expanded />
        </section>
      ) : null}

      {formOpen ? (
        <div className="desk-drawer-scrim" onClick={closeForm} role="presentation">
          <div className="desk-drawer" onClick={(e) => e.stopPropagation()}>
            {formEl}
          </div>
        </div>
      ) : null}
    </div>
  );
}

function splitStop(line) {
  const s = String(line || '');
  const i = s.indexOf(' · ');
  if (i < 0) return [s, ''];
  return [s.slice(0, i), s.slice(i + 3)];
}

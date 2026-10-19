import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { api } from '../api.js';
import { periodRange } from '../lib/period.js';
import { isActiveJob } from '../lib/jobStatus.js';
import { DEFAULT_QUOTE_RATES } from '../lib/quote.js';
import { fullName } from '../components/manager/format.js';
import { clearInviteFromUrl, inviteTokenFromUrl, orgApi } from '../orgApi.js';

const TeamContext = createContext(null);

const DESK_PREVIEW_KEY = 'trektrack-desk-preview';
const DESK_PREVIEW_MODES = new Set(['courier', 'reimbursement', 'service', 'driving_school']);

function readDeskPreview() {
  try {
    const value = sessionStorage.getItem(DESK_PREVIEW_KEY);
    return DESK_PREVIEW_MODES.has(value) ? value : null;
  } catch {
    return null;
  }
}

function writeDeskPreview(mode) {
  try {
    if (DESK_PREVIEW_MODES.has(mode)) sessionStorage.setItem(DESK_PREVIEW_KEY, mode);
    else sessionStorage.removeItem(DESK_PREVIEW_KEY);
  } catch {
    /* private mode */
  }
}

export function useTeam() {
  const value = useContext(TeamContext);
  if (!value) throw new Error('useTeam outside TeamProvider');
  return value;
}

function costBucket(category) {
  if (category === 'tolls') return 'tolls';
  if (category === 'parking') return 'parking';
  if (category === 'fuel') return 'gas';
  return 'misc';
}

export function TeamProvider({ children }) {
  const [period, setPeriod] = useState('week');
  const [membership, setMembership] = useState(null);
  const [roster, setRoster] = useState([]);
  const [trips, setTrips] = useState([]);
  const [expenses, setExpenses] = useState([]);
  const [jobs, setJobs] = useState([]);
  const [customers, setCustomers] = useState([]);
  const [jobMiles, setJobMiles] = useState({});
  const [invites, setInvites] = useState([]);
  const [profiles, setProfiles] = useState([]);
  const [driverNumbers, setDriverNumbers] = useState([]);
  const [pings, setPings] = useState([]);
  const [ownProfile, setOwnProfile] = useState(null);
  const [mileageRate, setMileageRate] = useState(0.725);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [notice, setNotice] = useState(null);
  const [deskPreview, setDeskPreviewState] = useState(readDeskPreview);

  const range = useMemo(() => periodRange(period), [period]);
  const setDeskPreview = useCallback((mode) => {
    const next = DESK_PREVIEW_MODES.has(mode) ? mode : null;
    writeDeskPreview(next);
    setDeskPreviewState(next);
  }, []);
  const deskMembership = useMemo(() => {
    if (!membership) return null;
    const savedOperatingMode = membership.operatingMode;
    if (!deskPreview || deskPreview === savedOperatingMode) {
      return { ...membership, savedOperatingMode };
    }
    return { ...membership, operatingMode: deskPreview, savedOperatingMode };
  }, [membership, deskPreview]);
  const bootRef = useRef(true);

  const reload = useCallback(async () => {
    setError(null);
    const mem = await orgApi.getMembership();
    setMembership(mem);
    const me = await orgApi.getOwnProfile().catch(() => null);
    setOwnProfile(me);
    if (!mem?.isDesk) {
      setRoster([]);
      setTrips([]);
      setExpenses([]);
      setJobs([]);
      setCustomers([]);
      setJobMiles({});
      setInvites([]);
      setProfiles([]);
      setDriverNumbers([]);
      setPings([]);
      return mem;
    }
    const [rows, allTrips, costs, jobRows, pending, rate, accounts, mileRows, accessRows] = await Promise.all([
      orgApi.rosterForPeriod(mem.orgId, range.start, range.end),
      orgApi.periodTrips(mem.orgId, range.start, range.end),
      orgApi.periodExpenses(mem.orgId, range.start, range.end),
      orgApi.listJobs(mem.orgId),
      mem.isAdmin ? orgApi.pendingInvites(mem.orgId) : Promise.resolve([]),
      api.getSettings().then((s) => Number(s.mileage_rate) || 0.725).catch(() => 0.725),
      orgApi.listCustomers(mem.orgId),
      orgApi.jobMiles(mem.orgId, range.start, range.end),
      orgApi.memberAccess(mem.orgId),
    ]);
    const ids = rows.map((r) => r.user_id);
    const [memberProfiles, locations, numbers] = await Promise.all([
      orgApi.memberProfiles(ids),
      orgApi.driverLastLocations(mem.orgId),
      orgApi.memberDriverNumbers(mem.orgId),
    ]);
    const accessById = {};
    for (const row of accessRows || []) accessById[row.user_id] = row.access;
    setRoster((rows || []).map((row) => ({ ...row, access: accessById[row.user_id] })));
    setTrips(allTrips);
    setExpenses(costs);
    setJobs(jobRows);
    setCustomers(accounts);
    const miles = {};
    for (const row of mileRows || []) {
      const n = Number(row.miles);
      if (row.job_id != null && Number.isFinite(n)) miles[row.job_id] = n;
    }
    setJobMiles(miles);
    setInvites(pending);
    setMileageRate(rate);
    setProfiles(memberProfiles);
    setDriverNumbers(numbers);
    setPings(locations);
    return mem;
  }, [range.start, range.end]);

  useEffect(() => {
    let cancelled = false;
    const first = bootRef.current;
    (async () => {
      if (first) setLoading(true);
      try {
        if (first) {
          const token = inviteTokenFromUrl();
          if (token) {
            try {
              await orgApi.acceptInvite(token);
              clearInviteFromUrl();
              if (!cancelled) setNotice('You joined the team.');
            } catch (err) {
              if (!cancelled) setError(err.message);
            }
          }
        }
        if (!cancelled) await reload();
      } catch (err) {
        if (!cancelled) setError(err.message);
      } finally {
        if (!cancelled) {
          bootRef.current = false;
          if (first) setLoading(false);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [reload]);

  useEffect(() => {
    if (!membership?.isDesk) return undefined;
    const t = window.setInterval(async () => {
      try {
        const ids = roster.map((r) => r.user_id);
        if (!ids.length) return;
        const next = await orgApi.memberProfiles(ids);
        setProfiles(next);
      } catch {
        /* keep last */
      }
    }, 30000);
    return () => window.clearInterval(t);
  }, [membership?.isDesk, roster]);

  const drivers = useMemo(() => {
    return roster
      .map((row) => {
        const mine = trips.filter((t) => t.user_id === row.user_id);
        const costs = expenses.filter((e) => e.user_id === row.user_id);
        const openJobs = jobs.filter(
          (j) => j.assigned_user_id === row.user_id && isActiveJob(j.status),
        ).length;
        const businessMiles = Number(row.business_miles_this_period ?? row.business_miles_this_month ?? 0);
        const personalMiles = mine
          .filter((t) => t.is_business === false)
          .reduce((sum, t) => sum + Number(t.miles || 0), 0);
        const tips = mine.reduce((sum, t) => sum + Number(t.tips || 0), 0);
        const buckets = { tolls: 0, parking: 0, gas: 0, misc: 0 };
        for (const rowCost of costs) {
          buckets[costBucket(rowCost.category)] += Number(rowCost.amount || 0);
        }
        const field = buckets.tolls + buckets.parking + buckets.gas + buckets.misc;
        const profile = profiles.find((p) => p.user_id === row.user_id);
        const vehicle = [profile?.vehicle_year, profile?.vehicle_make, profile?.vehicle_model]
          .filter(Boolean)
          .join(' ');
        const numberRow = driverNumbers.find((n) => n.user_id === row.user_id);
        return {
          ...row,
          profile,
          phone: profile?.phone || '',
          address: profile?.address || '',
          firstName: profile?.first_name || '',
          lastName: profile?.last_name || '',
          driverNumber: numberRow?.driver_number || '',
          vehicle,
          vehicleColor: profile?.vehicle_color || '',
          lastSeenAt: profile?.last_seen_at || null,
          label: fullName(profile, row.nickname || row.email),
          businessMiles,
          personalMiles,
          deduction: businessMiles * mileageRate,
          tips,
          buckets,
          field,
          costs,
          tripRows: mine,
          openJobs,
          unclassified: Number(row.unclassified_this_period ?? row.unclassified_this_month ?? 0),
          tripCount: Number(row.trips_this_period ?? row.trips_this_month ?? mine.length),
        };
      })
      .sort((a, b) => {
        const na = Number(a.driverNumber);
        const nb = Number(b.driverNumber);
        if (Number.isFinite(na) && Number.isFinite(nb) && a.driverNumber && b.driverNumber && na !== nb) {
          return na - nb;
        }
        if (a.driverNumber && !b.driverNumber) return -1;
        if (!a.driverNumber && b.driverNumber) return 1;
        return a.label.localeCompare(b.label);
      });
  }, [roster, trips, expenses, jobs, mileageRate, profiles, driverNumbers]);

  const kpis = useMemo(() => {
    const miles = drivers.reduce((s, d) => s + d.businessMiles, 0);
    const field = drivers.reduce((s, d) => s + d.field, 0);
    return {
      miles,
      deduction: miles * mileageRate,
      trips: drivers.reduce((s, d) => s + d.tripCount, 0),
      unclassified: drivers.reduce((s, d) => s + d.unclassified, 0),
      field,
      jobs: jobs.filter((j) => isActiveJob(j.status)).length,
      buckets: drivers.reduce(
        (b, d) => ({
          tolls: b.tolls + d.buckets.tolls,
          parking: b.parking + d.buckets.parking,
          gas: b.gas + d.buckets.gas,
          misc: b.misc + d.buckets.misc,
        }),
        { tolls: 0, parking: 0, gas: 0, misc: 0 },
      ),
    };
  }, [drivers, jobs, mileageRate]);

  async function run(fn) {
    setBusy(true);
    setError(null);
    try {
      await fn();
      await reload();
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setBusy(false);
    }
  }

  const value = {
    period,
    setPeriod,
    range,
    membership: deskMembership,
    roster,
    trips,
    expenses,
    jobs,
    customers,
    jobMiles,
    invites,
    profiles,
    pings,
    ownProfile,
    drivers,
    kpis,
    mileageRate,
    quoteRates: membership?.quoteRates ?? DEFAULT_QUOTE_RATES,
    weightUnit: membership?.weightUnit === 'kg' ? 'kg' : 'lb',
    defaultTerms: membership?.defaultTerms || 'Net 30',
    loading,
    busy,
    error,
    setError,
    notice,
    setNotice,
    reload,
    run,
    createOrg: (name, opts) => run(() => orgApi.createOrg(name, opts)),
    updateMemberPay: (userId, payType, hourlyRate) =>
      run(() => orgApi.updateMemberPay(membership.orgId, userId, payType, hourlyRate)),
    updateOrgStyle: (jobStyle) =>
      run(() => orgApi.updateOrgStyle(membership.orgId, jobStyle)),
    setDeskPreview,
    updateOrgOperatingMode: async (mode) => {
      try {
        await run(() => orgApi.updateOrgOperatingMode(membership.orgId, mode));
        setDeskPreview(null);
      } catch (err) {
        if (/044_company_types/.test(err.message || '')) setDeskPreview(mode);
        throw err;
      }
    },
    updateQuoteRates: (rates) =>
      run(() => orgApi.updateOrgQuoteRates(membership.orgId, rates)),
    updateWeightUnit: (unit) =>
      run(() => orgApi.updateOrgWeightUnit(membership.orgId, unit)),
    updateOrgIdentity: (fields) =>
      run(() => orgApi.updateOrgIdentity(membership.orgId, fields)),
    updateOrgClosePolicy: (officeClosesJobs) =>
      run(() => orgApi.updateOrgClosePolicy(membership.orgId, officeClosesJobs)),
    updateOrgCodPolicy: (useCod) =>
      run(() => orgApi.updateOrgCodPolicy(membership.orgId, useCod)),
    updateDriverProfile: (userId, fields) =>
      run(() => orgApi.updateDriverProfile(membership.orgId, userId, fields)),
    invite: (emailOrFields, role, access) =>
      orgApi.invite(membership.orgId, emailOrFields, role, access),
    createMember: (fields) => orgApi.createMember(membership.orgId, fields),
    updateMemberAccess: (userId, role, access) =>
      run(() => orgApi.updateMemberAccess(membership.orgId, userId, role, access)),
    revokeInvite: (id) => run(() => orgApi.revokeInvite(id)),
    removeMember: (userId) => run(() => orgApi.removeMember(membership.orgId, userId)),
    leaveOrg: () => run(() => orgApi.leaveOrg()),
    saveProfile: async (fields) => {
      setBusy(true);
      setError(null);
      try {
        await orgApi.upsertProfile(fields);
        await reload();
      } catch (err) {
        setError(err.message);
        throw err;
      } finally {
        setBusy(false);
      }
    },
  };

  return <TeamContext.Provider value={value}>{children}</TeamContext.Provider>;
}

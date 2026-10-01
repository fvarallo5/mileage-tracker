import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api } from '../api.js';
import { periodRange } from '../lib/period.js';
import { clearInviteFromUrl, inviteTokenFromUrl, orgApi } from '../orgApi.js';

const TeamContext = createContext(null);

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
  const [period, setPeriod] = useState('month');
  const [membership, setMembership] = useState(null);
  const [roster, setRoster] = useState([]);
  const [trips, setTrips] = useState([]);
  const [expenses, setExpenses] = useState([]);
  const [jobs, setJobs] = useState([]);
  const [invites, setInvites] = useState([]);
  const [mileageRate, setMileageRate] = useState(0.725);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [notice, setNotice] = useState(null);

  const range = useMemo(() => periodRange(period), [period]);

  const reload = useCallback(async () => {
    setError(null);
    const mem = await orgApi.getMembership();
    setMembership(mem);
    if (!mem?.isManager) {
      setRoster([]);
      setTrips([]);
      setExpenses([]);
      setJobs([]);
      setInvites([]);
      return mem;
    }
    const [rows, allTrips, costs, jobRows, pending, rate] = await Promise.all([
      orgApi.rosterForPeriod(mem.orgId, range.start, range.end),
      orgApi.periodTrips(mem.orgId, range.start, range.end),
      orgApi.periodExpenses(mem.orgId, range.start, range.end),
      orgApi.listJobs(mem.orgId),
      orgApi.pendingInvites(mem.orgId),
      api.getSettings().then((s) => Number(s.mileage_rate) || 0.725).catch(() => 0.725),
    ]);
    setRoster(rows);
    setTrips(allTrips);
    setExpenses(costs);
    setJobs(jobRows);
    setInvites(pending);
    setMileageRate(rate);
    return mem;
  }, [range.start, range.end]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      try {
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
        if (!cancelled) await reload();
      } catch (err) {
        if (!cancelled) setError(err.message);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [reload]);

  const drivers = useMemo(() => {
    return roster
      .map((row) => {
        const mine = trips.filter((t) => t.user_id === row.user_id);
        const costs = expenses.filter((e) => e.user_id === row.user_id);
        const openJobs = jobs.filter(
          (j) => j.assigned_user_id === row.user_id && j.status === 'open',
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
        return {
          ...row,
          label: row.nickname || row.email || 'Driver',
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
      .sort((a, b) => b.businessMiles - a.businessMiles || a.label.localeCompare(b.label));
  }, [roster, trips, expenses, jobs, mileageRate]);

  const kpis = useMemo(() => {
    const miles = drivers.reduce((s, d) => s + d.businessMiles, 0);
    const field = drivers.reduce((s, d) => s + d.field, 0);
    return {
      miles,
      deduction: miles * mileageRate,
      trips: drivers.reduce((s, d) => s + d.tripCount, 0),
      unclassified: drivers.reduce((s, d) => s + d.unclassified, 0),
      field,
      jobs: jobs.filter((j) => j.status === 'open').length,
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
    } finally {
      setBusy(false);
    }
  }

  const value = {
    period,
    setPeriod,
    range,
    membership,
    roster,
    trips,
    expenses,
    jobs,
    invites,
    drivers,
    kpis,
    mileageRate,
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
    invite: (email, role) => orgApi.invite(membership.orgId, email, role),
    revokeInvite: (id) => run(() => orgApi.revokeInvite(id)),
    removeMember: (userId) => run(() => orgApi.removeMember(membership.orgId, userId)),
    leaveOrg: () => run(() => orgApi.leaveOrg()),
  };

  return <TeamContext.Provider value={value}>{children}</TeamContext.Provider>;
}

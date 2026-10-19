import { useEffect, useState } from 'react';
import { PAY_TYPES, payTypeLabel } from '../../lib/company.js';
import { ALL_END, ALL_START, emptyWeek, weekFromRows, weekDaysPayload } from '../../lib/driverHours.js';
import { accessLabel, canEditMember, defaultAccess, inviteRoles, normalizeAccess, roleLabel } from '../../lib/roles.js';
import { orgApi } from '../../orgApi.js';
import { useTeam } from '../../context/TeamContext.jsx';
import AccessFields from './AccessFields.jsx';
import { splitName } from './format.js';
import FactList from './FactList.jsx';
import { HoursEditor, HoursSummary } from './Hours.jsx';
import Module from './Module.jsx';

function driverForm(row) {
  const split = splitName(row?.nickname || row?.label);
  return {
    driver_number: row?.driverNumber || '',
    first_name: row?.firstName || split.first,
    last_name: row?.lastName || split.last,
    phone: row?.phone || '',
    address: row?.address || '',
  };
}

function payId(row) {
  return row?.pay_type === 'reimbursement' ? 'reimbursement' : 'contractor';
}

export default function DriverSheet({ row, fleet, onClose }) {
  const team = useTeam();
  const [form, setForm] = useState(() => driverForm(row));
  const [payType, setPayType] = useState(() => payId(row));
  const [memberRole, setMemberRole] = useState(row?.role || 'driver');
  const [access, setAccess] = useState(() => normalizeAccess(row?.role, row?.access));
  const [week, setWeek] = useState(emptyWeek);
  const [savedWeek, setSavedWeek] = useState(emptyWeek);
  const [editProfile, setEditProfile] = useState(false);
  const [editPay, setEditPay] = useState(false);
  const [editHours, setEditHours] = useState(false);
  const [busy, setBusy] = useState('');
  const actorRole = team.membership?.role;
  const companyType = team.membership?.operatingMode;
  const canEdit = canEditMember(actorRole, row?.role);
  const canEditRole = canEdit && row?.role !== 'owner';
  const roleOptions = inviteRoles(actorRole);

  useEffect(() => {
    setForm(driverForm(row));
    setPayType(payId(row));
    setMemberRole(row?.role || 'driver');
    setAccess(normalizeAccess(row?.role, row?.access));
    setEditProfile(false);
    setEditPay(false);
    setEditHours(false);
  }, [row]);

  useEffect(() => {
    const orgId = team.membership?.orgId;
    if (!orgId || !row?.user_id) return undefined;
    let live = true;
    orgApi.listDriverHours(orgId).then((data) => {
      if (!live) return;
      const next = weekFromRows(data, row.user_id);
      setWeek(next);
      setSavedWeek(next);
    }).catch((err) => {
      if (!live) return;
      team.setError(err.message);
    });
    return () => {
      live = false;
    };
  }, [team.membership?.orgId, row?.user_id]);

  if (!row) return null;

  function set(key, value) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  function setDay(id, key, value) {
    setWeek((prev) => ({ ...prev, [id]: { ...prev[id], [key]: value } }));
  }

  function toggleAllDay(id, on) {
    setWeek((prev) => ({
      ...prev,
      [id]: on ? { start: ALL_START, end: ALL_END } : { start: '', end: '' },
    }));
  }

  async function saveProfile(e) {
    e.preventDefault();
    setBusy('profile');
    team.setError(null);
    try {
      await team.updateDriverProfile(row.user_id, form);
      setEditProfile(false);
    } catch (err) {
      team.setError(err.message);
    } finally {
      setBusy('');
    }
  }

  async function savePay(e) {
    e.preventDefault();
    setBusy('pay');
    team.setError(null);
    try {
      await orgApi.updateMemberPay(team.membership.orgId, row.user_id, payType, null);
      if (canEditRole && memberRole !== 'owner') {
        await orgApi.updateMemberAccess(team.membership.orgId, row.user_id, memberRole, access);
      }
      await team.reload();
      setEditPay(false);
    } catch (err) {
      team.setError(err.message);
    } finally {
      setBusy('');
    }
  }

  async function saveHours(e) {
    e.preventDefault();
    if (!team.membership?.orgId) return;
    setBusy('hours');
    team.setError(null);
    try {
      await orgApi.saveDriverHours(team.membership.orgId, row.user_id, weekDaysPayload(week));
      setSavedWeek(week);
      setEditHours(false);
    } catch (err) {
      team.setError(err.message);
    } finally {
      setBusy('');
    }
  }

  const name = [form.first_name, form.last_name].filter(Boolean).join(' ');

  return (
    <div className="plan-modal-wrap people-sheet-wrap">
      <button type="button" className="plan-modal-scrim" aria-label="Close driver" onClick={onClose} />
      <div className="plan-modal people-sheet" role="dialog" aria-labelledby="driver-sheet-title">
        <div className="drawer-head">
          <div>
            <h2 id="driver-sheet-title">{name || row.label}</h2>
            <p className="page-sub">{row.email} · {roleLabel(memberRole, { fleet, companyType })}</p>
          </div>
          <button type="button" className="btn-ghost btn-sm" onClick={onClose}>Close</button>
        </div>
        <div className="people-sheet-grid">
          <Module
            className={editProfile ? 'is-editing' : ''}
            title="Profile"
            actions={(
              <>
                {editProfile ? (
                  <button type="submit" form="drv-profile" className="btn btn-primary btn-sm" disabled={Boolean(busy)}>
                    {busy === 'profile' ? 'Saving…' : 'Save'}
                  </button>
                ) : null}
                {canEdit ? (
                <button
                  type="button"
                  className="btn-ghost btn-sm settings-edit"
                  onClick={() => {
                    if (editProfile) setForm(driverForm(row));
                    setEditProfile((v) => !v);
                  }}
                >
                  {editProfile ? 'Cancel' : 'Edit'}
                </button>
                ) : null}
              </>
            )}
          >
            {editProfile ? (
              <form id="drv-profile" onSubmit={saveProfile} className="stack-form">
                <div className="form-row">
                  <div className="form-group">
                    <label htmlFor="drv-number">Driver #</label>
                    <input id="drv-number" value={form.driver_number} onChange={(e) => set('driver_number', e.target.value)} maxLength={12} />
                  </div>
                  <div className="form-group">
                    <label htmlFor="drv-phone">Phone</label>
                    <input id="drv-phone" type="tel" value={form.phone} onChange={(e) => set('phone', e.target.value)} />
                  </div>
                </div>
                <div className="form-row">
                  <div className="form-group">
                    <label htmlFor="drv-first">First name</label>
                    <input id="drv-first" value={form.first_name} onChange={(e) => set('first_name', e.target.value)} required maxLength={40} />
                  </div>
                  <div className="form-group">
                    <label htmlFor="drv-last">Last name</label>
                    <input id="drv-last" value={form.last_name} onChange={(e) => set('last_name', e.target.value)} required maxLength={40} />
                  </div>
                </div>
                <div className="form-group">
                  <label htmlFor="drv-email">Email</label>
                  <input id="drv-email" type="email" value={row.email || ''} readOnly />
                </div>
                <div className="form-group">
                  <label htmlFor="drv-address">Address</label>
                  <input id="drv-address" value={form.address} onChange={(e) => set('address', e.target.value)} />
                </div>
              </form>
            ) : (
              <FactList
                className="people-facts"
                rows={[
                  { label: 'Driver #', value: form.driver_number },
                  { label: 'Name', value: name },
                  { label: 'Phone', value: form.phone },
                  { label: 'Email', value: row.email },
                  { label: 'Address', value: form.address },
                ]}
              />
            )}
          </Module>

          <Module
            className={editPay ? 'is-editing' : ''}
            title="Role & pay"
            actions={(
              <>
                {editPay ? (
                  <button type="submit" form="drv-pay" className="btn btn-primary btn-sm" disabled={Boolean(busy)}>
                    {busy === 'pay' ? 'Saving…' : 'Save'}
                  </button>
                ) : null}
                {canEdit ? (
                <button
                  type="button"
                  className="btn-ghost btn-sm settings-edit"
                  onClick={() => {
                    if (editPay) {
                      setPayType(payId(row));
                      setMemberRole(row.role || 'driver');
                      setAccess(normalizeAccess(row.role, row.access));
                    }
                    setEditPay((v) => !v);
                  }}
                >
                  {editPay ? 'Cancel' : 'Edit'}
                </button>
                ) : null}
              </>
            )}
          >
            {editPay ? (
              <form id="drv-pay" onSubmit={savePay} className="stack-form">
                <div className="form-group">
                  <label htmlFor="drv-role">Role</label>
                  {canEditRole ? (
                    <select
                      id="drv-role"
                      value={memberRole}
                      onChange={(e) => {
                        const next = e.target.value;
                        setMemberRole(next);
                        setAccess(defaultAccess(next));
                      }}
                    >
                      {roleOptions.map((id) => (
                        <option key={id} value={id}>{roleLabel(id, { fleet, companyType })}</option>
                      ))}
                    </select>
                  ) : (
                    <input id="drv-role" value={roleLabel(memberRole, { fleet, companyType })} readOnly />
                  )}
                </div>
                <div className="form-group">
                  <span className="access-label">Access</span>
                  {canEditRole ? (
                    <AccessFields role={memberRole} access={access} onChange={setAccess} idPrefix="drv-access" />
                  ) : (
                    <p className="field-hint">{accessLabel(memberRole, access)}</p>
                  )}
                </div>
                <div className="form-group">
                  <label htmlFor="drv-pay-type">Pay type</label>
                  <select id="drv-pay-type" value={payType} onChange={(e) => setPayType(e.target.value)}>
                    {PAY_TYPES.map((opt) => (
                      <option key={opt.id} value={opt.id}>{payTypeLabel(opt.id)}</option>
                    ))}
                  </select>
                </div>
              </form>
            ) : (
              <FactList
                className="people-facts"
                rows={[
                  { label: 'Role', value: roleLabel(memberRole, { fleet, companyType }) },
                  { label: 'Access', value: accessLabel(memberRole, access) },
                  { label: 'Type', value: payTypeLabel(payType) },
                ]}
              />
            )}
          </Module>

          {fleet ? (
            <Module
              className={editHours ? 'is-editing' : ''}
              title="Hours"
              actions={(
                <>
                  {editHours ? (
                    <button type="submit" form="drv-hours" id="hours-save" className="btn btn-primary btn-sm" disabled={Boolean(busy)}>
                      {busy === 'hours' ? 'Saving…' : 'Save'}
                    </button>
                  ) : null}
                  {canEdit ? (
                  <button
                    type="button"
                    className="btn-ghost btn-sm settings-edit"
                    onClick={() => {
                      if (editHours) setWeek(savedWeek);
                      setEditHours((v) => !v);
                    }}
                  >
                    {editHours ? 'Cancel' : 'Edit'}
                  </button>
                  ) : null}
                </>
              )}
            >
              {editHours ? (
                <form id="drv-hours" onSubmit={saveHours} className="stack-form">
                  <HoursEditor week={week} setDay={setDay} toggleAllDay={toggleAllDay} />
                </form>
              ) : (
                <HoursSummary week={week} />
              )}
            </Module>
          ) : null}
        </div>
      </div>
    </div>
  );
}

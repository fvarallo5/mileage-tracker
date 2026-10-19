import { useState } from 'react';
import { isReimbursementMode, normalizePayType, payTypeLabel } from '../../lib/company.js';
import { contactLabel } from '../../lib/phone.js';
import { canRemoveMember, roleLabel } from '../../lib/roles.js';
import { inviteLink } from '../../orgApi.js';
import { useTeam } from '../../context/TeamContext.jsx';
import Accounts from './Accounts.jsx';
import DriverSheet from './DriverSheet.jsx';
import NewMemberSheet from './NewMemberSheet.jsx';
import { isDriverActive, presenceLabel } from './format.js';
import Module from './Module.jsx';
import DeskTitle from './DeskTitle.jsx';

function inviteName(inv) {
  return [inv.first_name, inv.last_name].filter(Boolean).join(' ') || '—';
}

export default function People() {
  const team = useTeam();
  const [copied, setCopied] = useState(null);
  const [creating, setCreating] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const companyType = team.membership?.operatingMode;
  const fleet = !isReimbursementMode(companyType);
  const editing = team.drivers.find((d) => d.user_id === editingId) || null;
  const canInvite = team.membership?.isAdmin;

  async function handleCreate(fields) {
    setCopied(null);
    team.setError(null);
    team.setNotice(null);
    if (fields.password) {
      try {
        await team.createMember(fields);
        await team.reload();
        setCreating(false);
        team.setNotice('Account is open. They sign in with that email or phone and the password you set.');
        return;
      } catch (err) {
        if (err.message !== 'CREATE_MEMBER_MISSING') throw err;
      }
    }
    const token = await team.invite(fields);
    await team.reload();
    const link = inviteLink(token);
    try {
      await navigator.clipboard.writeText(link);
    } catch {
      /* show the link either way */
    }
    setCopied(link);
    setCreating(false);
    team.setNotice(
      fields.password
        ? 'Join link copied. Deploy create-member to open the password from this desk. They set a password when they join.'
        : 'Join link copied. They sign in with that email or phone and join the team.',
    );
  }

  async function handleRevoke(id) {
    if (!confirm('Revoke this invite?')) return;
    await team.revokeInvite(id);
  }

  async function handleRemove(userId, label) {
    if (!confirm(`Remove ${label} from the team?`)) return;
    await team.removeMember(userId);
    if (editingId === userId) setEditingId(null);
  }

  async function handleLeave() {
    if (!confirm('Leave this team?')) return;
    await team.leaveOrg();
  }

  return (
    <div className="desk-page">
    <DeskTitle title="People" sub="Roster, invites, and pay." />
    <div className="mgr-page people-page">
      <div className="page-toolbar">
        <h1>People</h1>
        {canInvite ? (
          <button type="button" className="btn btn-primary" id="new-member-btn" onClick={() => setCreating(true)}>
            New member
          </button>
        ) : null}
      </div>

      <div className="people-layout">
        <Module className="people-pending" title="Pending">
          {team.invites.length === 0 ? (
            <p className="empty">No invites waiting.</p>
          ) : (
            <table className="data-table compact">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Contact</th>
                  <th>Role</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {team.invites.map((inv) => (
                  <tr key={inv.id}>
                    <td>{inviteName(inv)}</td>
                    <td>{contactLabel(inv.email, inv.phone)}</td>
                    <td>{roleLabel(inv.role, { fleet, companyType })}</td>
                    <td className="num">
                      <button type="button" className="btn-danger" onClick={() => handleRevoke(inv.id)} disabled={team.busy}>
                        Revoke
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          {copied ? (
            <p className="invite-copied">
              Join link copied.
              <code>{copied}</code>
            </p>
          ) : null}
        </Module>

        {fleet ? <Accounts /> : (
          <Module className="people-accounts" title="Accounts">
            <p className="empty">Accounts live on the job desk.</p>
          </Module>
        )}

        <Module className="people-members" title="Members" fill>
          {team.drivers.length === 0 ? (
            <p className="empty">Add a member. This card stays open so the roster is easy to scan.</p>
          ) : null}
          <div className="people-members-body">
            <table className="data-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Phone</th>
                  <th>Role</th>
                  <th>Pay</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {team.drivers.map((row) => (
                  <tr key={row.user_id}>
                    <td>{row.driverNumber || '—'}</td>
                    <td>
                      <button type="button" className="linkish" onClick={() => setEditingId(row.user_id)}>
                        {row.label}
                      </button>
                      {presenceLabel(row.lastSeenAt) ? (
                        <div className={`presence-row${isDriverActive(row.lastSeenAt) ? ' on' : ''}`}>
                          {presenceLabel(row.lastSeenAt)}
                        </div>
                      ) : null}
                    </td>
                    <td>{row.email}</td>
                    <td>{row.phone || '—'}</td>
                    <td>{roleLabel(row.role, { fleet, companyType })}</td>
                    <td>{payTypeLabel(normalizePayType(row.pay_type, companyType))}</td>
                    <td className="num">
                      <button type="button" className="btn btn-secondary btn-sm" onClick={() => setEditingId(row.user_id)} disabled={team.busy}>
                        Open
                      </button>
                      {canRemoveMember(team.membership?.role, row.role) ? (
                        <button
                          type="button"
                          className="btn-danger"
                          onClick={() => handleRemove(row.user_id, row.label)}
                          disabled={team.busy}
                        >
                          Remove
                        </button>
                      ) : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {team.membership?.role !== 'owner' ? (
            <div className="page-toolbar">
              <button type="button" className="btn-danger" onClick={handleLeave} disabled={team.busy}>
                Leave team
              </button>
            </div>
          ) : null}
        </Module>
      </div>

      {creating ? (
        <NewMemberSheet
          fleet={fleet}
          companyType={companyType}
          actorRole={team.membership?.role}
          defaultPayType={team.membership?.defaultPayType}
          busy={team.busy}
          onClose={() => setCreating(false)}
          onCreate={handleCreate}
        />
      ) : null}
      {editing ? (
        <DriverSheet
          key={editing.user_id}
          row={editing}
          fleet={fleet}
          onClose={() => setEditingId(null)}
        />
      ) : null}
    </div>
    </div>
  );
}

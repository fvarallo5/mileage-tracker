import { useState } from 'react';
import { inviteLink } from '../../orgApi.js';
import { useTeam } from '../../context/TeamContext.jsx';
import { roleLabel } from './format.js';

export default function People() {
  const team = useTeam();
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('driver');
  const [copied, setCopied] = useState(null);

  async function handleInvite(e) {
    e.preventDefault();
    setCopied(null);
    team.setError(null);
    try {
      const token = await team.invite(email, role);
      setEmail('');
      await team.reload();
      const link = inviteLink(token);
      try {
        await navigator.clipboard.writeText(link);
      } catch {
        /* show the link either way */
      }
      setCopied(link);
    } catch (err) {
      team.setError(err.message);
    }
  }

  async function handleRevoke(id) {
    if (!confirm('Revoke this invite?')) return;
    await team.revokeInvite(id);
  }

  async function handleRemove(userId, label) {
    if (!confirm(`Remove ${label} from the team?`)) return;
    await team.removeMember(userId);
  }

  async function handleLeave() {
    if (!confirm('Leave this team?')) return;
    await team.leaveOrg();
  }

  return (
    <div className="mgr-page">
      <div className="page-toolbar">
        <div>
          <h1>People</h1>
          <p className="page-sub">Invites and roles. Mileage stays on Overview.</p>
        </div>
      </div>

      <div className="grid-2">
        <section className="panel">
          <h2>Invite</h2>
          <form onSubmit={handleInvite}>
            <div className="form-group">
              <label htmlFor="invite-email">Email</label>
              <input
                id="invite-email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                placeholder="driver@company.com"
              />
            </div>
            <div className="form-group">
              <label htmlFor="invite-role">Role</label>
              <select id="invite-role" value={role} onChange={(e) => setRole(e.target.value)}>
                <option value="driver">Driver</option>
                <option value="admin">Admin</option>
              </select>
            </div>
            <button type="submit" className="btn btn-primary" disabled={team.busy}>
              {team.busy ? 'Working…' : 'Create invite link'}
            </button>
          </form>
          {copied ? (
            <p className="invite-copied">
              Link copied. They sign in with this email and join the team.
              <br />
              <code>{copied}</code>
            </p>
          ) : (
            <p className="field-hint">Copy the link. There is no email blast yet.</p>
          )}
        </section>

        <section className="panel">
          <h2>Pending</h2>
          {team.invites.length === 0 ? (
            <p className="empty">No invites waiting.</p>
          ) : (
            <table className="data-table compact">
              <thead>
                <tr>
                  <th>Email</th>
                  <th>Role</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {team.invites.map((inv) => (
                  <tr key={inv.id}>
                    <td>{inv.email}</td>
                    <td>{roleLabel(inv.role)}</td>
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
        </section>
      </div>

      <section className="panel">
        <h2>Members</h2>
        <table className="data-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Role</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {team.drivers.map((row) => (
              <tr key={row.user_id}>
                <td>{row.label}</td>
                <td>{row.email}</td>
                <td>{roleLabel(row.role)}</td>
                <td className="num">
                  {row.role !== 'owner' ? (
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
      </section>

      {team.membership?.role !== 'owner' ? (
        <div className="page-toolbar">
          <button type="button" className="btn-danger" onClick={handleLeave} disabled={team.busy}>
            Leave team
          </button>
        </div>
      ) : null}
    </div>
  );
}

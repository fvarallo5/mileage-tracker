import { requireSession, supabase } from './supabase.js';

function rpcError(error, fallback) {
  if (!error) return;
  throw new Error(error.message || fallback);
}

export const orgApi = {
  async getMembership() {
    await requireSession();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not signed in');

    const { data, error } = await supabase
      .from('org_members')
      .select('org_id, role, orgs (id, name)')
      .eq('user_id', user.id)
      .maybeSingle();

    rpcError(error, 'Could not load team');
    if (!data) return null;

    return {
      orgId: data.org_id,
      role: data.role,
      name: data.orgs?.name ?? 'Team',
      isManager: data.role === 'owner' || data.role === 'admin',
    };
  },

  async createOrg(name) {
    await requireSession();
    const { data, error } = await supabase.rpc('create_org', { org_name: name.trim() });
    rpcError(error, 'Could not create team');
    return data;
  },

  async invite(orgId, email, role = 'driver') {
    await requireSession();
    const { data, error } = await supabase.rpc('invite_to_org', {
      p_org_id: orgId,
      p_email: email.trim(),
      p_role: role,
    });
    rpcError(error, 'Could not send invite');
    return data;
  },

  async acceptInvite(token) {
    await requireSession();
    const { data, error } = await supabase.rpc('accept_org_invite', { p_token: token });
    rpcError(error, 'Could not accept invite');
    return data;
  },

  async roster(orgId) {
    await requireSession();
    const { data, error } = await supabase.rpc('org_roster', { p_org_id: orgId });
    rpcError(error, 'Could not load roster');
    return data ?? [];
  },

  async unclassified(orgId) {
    await requireSession();
    const { data, error } = await supabase.rpc('org_unclassified_trips', { p_org_id: orgId });
    rpcError(error, 'Could not load unclassified trips');
    return data ?? [];
  },

  async pendingInvites(orgId) {
    await requireSession();
    const { data, error } = await supabase
      .from('org_invites')
      .select('id, email, role, token, created_at, expires_at, accepted_at')
      .eq('org_id', orgId)
      .is('accepted_at', null)
      .order('created_at', { ascending: false });
    rpcError(error, 'Could not load invites');
    return data ?? [];
  },

  async revokeInvite(id) {
    await requireSession();
    const { error } = await supabase.from('org_invites').delete().eq('id', id);
    rpcError(error, 'Could not revoke invite');
  },

  async rosterForPeriod(orgId, start, end) {
    await requireSession();
    const { data, error } = await supabase.rpc('org_roster_for_period', {
      p_org_id: orgId,
      p_start: start,
      p_end: end,
    });
    rpcError(error, 'Could not load roster');
    return data ?? [];
  },

  async periodTrips(orgId, start, end) {
    await requireSession();
    const { data, error } = await supabase.rpc('org_period_trips', {
      p_org_id: orgId,
      p_start: start,
      p_end: end,
    });
    rpcError(error, 'Could not load trips');
    return data ?? [];
  },

  async periodExpenses(orgId, start, end) {
    await requireSession();
    const { data, error } = await supabase.rpc('org_period_expenses', {
      p_org_id: orgId,
      p_start: start,
      p_end: end,
    });
    rpcError(error, 'Could not load field costs');
    return data ?? [];
  },

  async removeMember(orgId, userId) {
    await requireSession();
    const { error } = await supabase.rpc('remove_org_member', {
      p_org_id: orgId,
      p_user_id: userId,
    });
    rpcError(error, 'Could not remove member');
  },

  async leaveOrg() {
    await requireSession();
    const { error } = await supabase.rpc('leave_org');
    rpcError(error, 'Could not leave team');
  },

  async listJobs(orgId) {
    await requireSession();
    const { data, error } = await supabase
      .from('org_jobs')
      .select('*')
      .eq('org_id', orgId)
      .order('job_date', { ascending: true })
      .order('id', { ascending: true });
    rpcError(error, 'Could not load jobs. Run migration 022_org_jobs.sql.');
    return data ?? [];
  },

  async createJob(orgId, row) {
    await requireSession();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not signed in');
    const { data, error } = await supabase
      .from('org_jobs')
      .insert({
        org_id: orgId,
        created_by: user.id,
        ...row,
      })
      .select()
      .single();
    rpcError(error, 'Could not create job');
    return data;
  },

  async updateJob(id, row) {
    await requireSession();
    const { data, error } = await supabase
      .from('org_jobs')
      .update({ ...row, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single();
    rpcError(error, 'Could not update job');
    return data;
  },

  async deleteJob(id) {
    await requireSession();
    const { error } = await supabase.from('org_jobs').delete().eq('id', id);
    rpcError(error, 'Could not delete job');
  },
};

export function inviteTokenFromUrl() {
  if (typeof window === 'undefined') return null;
  const params = new URLSearchParams(window.location.search);
  const token = params.get('invite');
  if (!token) return null;
  const uuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuid.test(token) ? token : null;
}

export function inviteLink(token) {
  const origin = typeof window !== 'undefined' ? window.location.origin : '';
  return `${origin}/?invite=${token}`;
}

export function clearInviteFromUrl() {
  if (typeof window === 'undefined') return;
  const url = new URL(window.location.href);
  if (!url.searchParams.has('invite')) return;
  url.searchParams.delete('invite');
  const next = `${url.pathname}${url.search}${url.hash}`;
  window.history.replaceState({}, '', next);
}

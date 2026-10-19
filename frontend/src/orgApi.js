import { requireSession, supabase } from './supabase.js';
import { identityFromOrg, jobStyleForMode, normalizeOperatingMode, normalizePayType, payTypeForMode } from './lib/company.js';
import { isAdminRole, isDeskRole, normalizeAccess } from './lib/roles.js';
import { ratesFromOrg } from './lib/quote.js';
import { toE164 } from './lib/phone.js';

function rpcError(error, fallback) {
  if (!error) return;
  const message = error.message || '';
  if (/null value in column "assigned_user_id"/i.test(message)) {
    throw new Error('Unassigned jobs need 035_unassigned_jobs.sql pasted in the SQL editor.');
  }
  throw new Error(message || fallback);
}

const ORG_BASE =
  'id, name, job_style, company_kind, default_pay_type, operating_mode';
const ORG_QUOTE =
  'quote_per_mile, quote_minimum, quote_weekend_mult, quote_after_hours_mult, quote_after_hours_start, quote_after_hours_end, company_take_pct, weight_unit, default_terms';
const ORG_PROFILE =
  'phone, dispatch_email, address_line1, address_city, address_state, address_zip, timezone, job_prefix, office_closes_jobs, use_cod';

const JOB_QUOTE_KEYS = [
  'estimated_miles',
  'estimated_cost',
  'pickup_time',
  'dropoff_time',
  'quoted_amount',
  'driver_pay',
  'company_take',
  'company_take_pct',
  'quote_manual',
  'quote_weekend',
  'quote_after_hours',
  'series_id',
];

const JOB_BOOK_KEYS = [
  'customer_id',
  'failure_reason',
  'pod_note',
  'attempt_fee',
  'stop_order',
  'cod_amount',
  'cod_collected',
  'item_count',
  'weight_value',
  'weight_unit',
];

const JOB_NOTIFY_KEYS = [
  'pickup_email',
  'dropoff_email',
  'service_level',
  'service_addon',
  'pod_signature_path',
];

function stripJobExtras(row) {
  const next = { ...row };
  for (const key of [...JOB_QUOTE_KEYS, ...JOB_BOOK_KEYS, ...JOB_NOTIFY_KEYS]) delete next[key];
  return next;
}

function jobSchemaMissing(message) {
  return /estimated_|pickup_time|dropoff_time|quoted_amount|driver_pay|company_take|quote_manual|quote_weekend|quote_after_hours|series_id|customer_id|failure_reason|pod_note|attempt_fee|stop_order|cod_amount|cod_collected|pickup_email|dropoff_email|service_level|service_addon|pod_signature|item_count|weight_value|weight_unit|schema cache/i.test(
    message || '',
  );
}

export const orgApi = {
  async getMembership() {
    await requireSession();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not signed in');

    let { data, error } = await supabase
      .from('org_members')
      .select(`org_id, role, pay_type, hourly_rate, access, orgs (${ORG_BASE}, ${ORG_QUOTE}, ${ORG_PROFILE})`)
      .eq('user_id', user.id)
      .maybeSingle();
    if (error && /access|043_/i.test(error.message || '')) {
      ({ data, error } = await supabase
        .from('org_members')
        .select(`org_id, role, pay_type, hourly_rate, orgs (${ORG_BASE}, ${ORG_QUOTE}, ${ORG_PROFILE})`)
        .eq('user_id', user.id)
        .maybeSingle());
    }
    if (error && /use_cod|042_/i.test(error.message || '')) {
      ({ data, error } = await supabase
        .from('org_members')
        .select(`org_id, role, pay_type, hourly_rate, orgs (${ORG_BASE}, ${ORG_QUOTE}, phone, dispatch_email, address_line1, address_city, address_state, address_zip, timezone, job_prefix, office_closes_jobs)`)
        .eq('user_id', user.id)
        .maybeSingle());
    }
    if (error && /office_closes_jobs|041_/i.test(error.message || '')) {
      ({ data, error } = await supabase
        .from('org_members')
        .select(`org_id, role, pay_type, hourly_rate, orgs (${ORG_BASE}, ${ORG_QUOTE}, phone, dispatch_email, address_line1, address_city, address_state, address_zip, timezone, job_prefix)`)
        .eq('user_id', user.id)
        .maybeSingle());
    }
    if (error && /phone|dispatch_email|address_line1|timezone|job_prefix|040_|schema cache/i.test(error.message || '')) {
      ({ data, error } = await supabase
        .from('org_members')
        .select(`org_id, role, pay_type, hourly_rate, orgs (${ORG_BASE}, ${ORG_QUOTE})`)
        .eq('user_id', user.id)
        .maybeSingle());
    }
    if (error && /quote_weekend|quote_after|company_take|weight_unit|default_terms|schema cache/i.test(error.message || '')) {
      ({ data, error } = await supabase
        .from('org_members')
        .select(`org_id, role, pay_type, hourly_rate, orgs (${ORG_BASE}, quote_per_mile, quote_minimum)`)
        .eq('user_id', user.id)
        .maybeSingle());
    }
    if (error && /quote_|company_take|schema cache/i.test(error.message || '')) {
      ({ data, error } = await supabase
        .from('org_members')
        .select(`org_id, role, pay_type, hourly_rate, orgs (${ORG_BASE})`)
        .eq('user_id', user.id)
        .maybeSingle());
    }
    if (error && /operating_mode|schema cache/i.test(error.message || '')) {
      ({ data, error } = await supabase
        .from('org_members')
        .select('org_id, role, pay_type, hourly_rate, orgs (id, name, job_style, company_kind, default_pay_type)')
        .eq('user_id', user.id)
        .maybeSingle());
    }

    rpcError(error, 'Could not load team. Run migration 024_org_job_style_and_pay.sql if columns are missing.');
    if (!data) return null;

    const mode = normalizeOperatingMode(data.orgs?.operating_mode);
    const role = data.role;
    return {
      orgId: data.org_id,
      role,
      name: data.orgs?.name ?? 'Team',
      access: normalizeAccess(role, data.access),
      isAdmin: isAdminRole(role),
      isDesk: isDeskRole(role),
      isManager: isAdminRole(role),
      jobStyle: data.orgs?.job_style === 'service' ? 'service' : jobStyleForMode(mode),
      companyKind: data.orgs?.company_kind ?? 'other',
      operatingMode: mode,
      defaultPayType: normalizePayType(data.orgs?.default_pay_type, mode),
      payType: normalizePayType(data.pay_type, mode),
      hourlyRate: Number(data.hourly_rate) || null,
      quoteRates: ratesFromOrg(data.orgs),
      weightUnit: data.orgs?.weight_unit === 'kg' ? 'kg' : 'lb',
      defaultTerms: String(data.orgs?.default_terms || '').trim() || 'Net 30',
      ...identityFromOrg(data.orgs),
    };
  },

  async createOrg(name, {
    jobStyle = 'delivery',
    companyKind = 'other',
    defaultPayType = 'contractor',
    operatingMode = 'courier',
  } = {}) {
    await requireSession();
    const mode = normalizeOperatingMode(operatingMode);
    const pay = defaultPayType || payTypeForMode(mode);
    jobStyle = jobStyle || jobStyleForMode(mode);
    let { data, error } = await supabase.rpc('create_org', {
      org_name: name.trim(),
      p_job_style: jobStyle,
      p_company_kind: companyKind,
      p_default_pay_type: pay,
      p_operating_mode: mode,
    });
    if (error && /p_operating_mode|operating_mode|schema cache/i.test(error.message || '')) {
      ({ data, error } = await supabase.rpc('create_org', {
        org_name: name.trim(),
        p_job_style: jobStyle,
        p_company_kind: companyKind,
        p_default_pay_type: pay,
      }));
    }
    rpcError(error, 'Could not create team. Run migration 024_org_job_style_and_pay.sql.');
    return data;
  },

  async updateOrgOperatingMode(orgId, operatingMode) {
    await requireSession();
    const mode = normalizeOperatingMode(operatingMode);
    let { error } = await supabase.rpc('update_org_operating_mode', {
      p_org_id: orgId,
      p_operating_mode: mode,
    });
    if (error && mode === 'courier' && /invalid company type|operating_mode/i.test(error.message || '')) {
      ({ error } = await supabase.rpc('update_org_operating_mode', {
        p_org_id: orgId,
        p_operating_mode: 'fleet',
      }));
    }
    if (error && /invalid company type|operating_mode|check constraint/i.test(error.message || '')) {
      throw new Error('Could not update company type. Paste 044_company_types.sql in the SQL editor, then save again.');
    }
    rpcError(error, 'Could not update company type. Paste 044_company_types.sql in the SQL editor.');
  },

  async updateOrgQuoteRates(orgId, rates) {
    await requireSession();
    const { error } = await supabase.rpc('update_org_quote_settings', {
      p_org_id: orgId,
      p_quote_per_mile: Number(rates.quotePerMile),
      p_quote_minimum: Number(rates.quoteMinimum),
      p_weekend_mult: Number(rates.weekendMult),
      p_after_hours_mult: Number(rates.afterHoursMult),
      p_after_hours_start: rates.afterHoursStart,
      p_after_hours_end: rates.afterHoursEnd,
      p_company_take_pct: Number(rates.companyTakePct),
    });
    rpcError(error, 'Could not save quote rates. Run 030_job_quotes_schedule.sql in the SQL editor.');
  },

  async updateOrgIdentity(orgId, fields) {
    await requireSession();
    const ident = identityFromOrg(fields);
    const { error } = await supabase.rpc('update_org_identity', {
      p_org_id: orgId,
      p_name: String(fields?.name || '').trim(),
      p_default_terms: String(fields?.defaultTerms || '').trim() || 'Net 30',
      p_phone: ident.phone,
      p_dispatch_email: ident.dispatchEmail,
      p_address_line1: ident.addressLine1,
      p_address_city: ident.addressCity,
      p_address_state: ident.addressState,
      p_address_zip: ident.addressZip,
      p_timezone: ident.timezone,
      p_job_prefix: ident.jobPrefix,
    });
    if (error && /update_org_identity|Could not find the function|040_|job_prefix|dispatch_email|address_line1/i.test(error.message || '')) {
      throw new Error('Paste 040_org_company_profile.sql in the SQL editor, then hard-refresh.');
    }
    rpcError(error, 'Could not save company');
  },

  async updateOrgClosePolicy(orgId, officeClosesJobs) {
    await requireSession();
    const { error } = await supabase.rpc('update_org_close_policy', {
      p_org_id: orgId,
      p_office_closes_jobs: Boolean(officeClosesJobs),
    });
    if (error && /update_org_close_policy|office_closes_jobs|041_/i.test(error.message || '')) {
      throw new Error('Paste 041_office_closes_jobs.sql in the SQL editor, then hard-refresh.');
    }
    rpcError(error, 'Could not save who closes jobs');
  },

  async updateOrgCodPolicy(orgId, useCod) {
    await requireSession();
    const { error } = await supabase.rpc('update_org_cod_policy', {
      p_org_id: orgId,
      p_use_cod: Boolean(useCod),
    });
    if (error && /update_org_cod_policy|use_cod|042_/i.test(error.message || '')) {
      throw new Error('Paste 042_org_use_cod.sql in the SQL editor, then hard-refresh.');
    }
    rpcError(error, 'Could not save COD');
  },

  async updateOrgWeightUnit(orgId, unit) {
    await requireSession();
    const { error } = await supabase.rpc('update_org_weight_unit', {
      p_org_id: orgId,
      p_weight_unit: unit === 'kg' ? 'kg' : 'lb',
    });
    if (error && /update_org_weight_unit|weight_unit|schema cache|038_/i.test(error.message || '')) {
      throw new Error('Paste 038_account_stops_weight.sql in the SQL editor, then hard-refresh.');
    }
    rpcError(error, 'Could not save weight unit');
  },

  async updateOrgStyle(orgId, jobStyle) {
    await requireSession();
    const { error } = await supabase.rpc('update_org_style', {
      p_org_id: orgId,
      p_job_style: jobStyle,
    });
    rpcError(error, 'Could not update job style');
  },

  async updateMemberPay(orgId, userId, payType, hourlyRate) {
    await requireSession();
    const { error } = await supabase.rpc('update_org_member_pay', {
      p_org_id: orgId,
      p_user_id: userId,
      p_pay_type: payType,
      p_hourly_rate: payType === 'hourly' && hourlyRate !== '' && hourlyRate != null
        ? Number(hourlyRate)
        : null,
    });
    rpcError(error, 'Could not update pay');
  },

  async invite(orgId, emailOrFields, role = 'driver', access = null) {
    await requireSession();
    const fields = typeof emailOrFields === 'object' && emailOrFields
      ? emailOrFields
      : { email: emailOrFields, role, access };
    const nextRole = fields.role || 'driver';
    const { data, error } = await supabase.rpc('invite_to_org', {
      p_org_id: orgId,
      p_email: fields.email ? String(fields.email).trim().toLowerCase() : null,
      p_role: nextRole,
      p_access: nextRole === 'dispatcher' ? normalizeAccess(nextRole, fields.access) : null,
      p_phone: fields.phone ? toE164(fields.phone) : null,
      p_first_name: fields.first_name || '',
      p_last_name: fields.last_name || '',
      p_driver_number: fields.driver_number || null,
    });
    if (error && /p_phone|p_first_name|045_|org_invites.phone/i.test(error.message || '')) {
      throw new Error('Paste 045_member_phone_invite.sql in the SQL editor, then hard-refresh.');
    }
    if (error && /dispatcher|p_access|043_|invite_to_org/i.test(error.message || '')) {
      throw new Error('Paste 043_org_roles_access.sql in the SQL editor, then hard-refresh.');
    }
    rpcError(error, 'Could not send invite');
    return data;
  },

  async createMember(orgId, fields) {
    await requireSession();
    const { data, error } = await supabase.functions.invoke('create-member', {
      body: {
        org_id: orgId,
        email: fields.email || null,
        phone: fields.phone || null,
        password: fields.password,
        role: fields.role || 'driver',
        access: fields.role === 'dispatcher' ? normalizeAccess(fields.role, fields.access) : null,
        first_name: fields.first_name || '',
        last_name: fields.last_name || '',
        driver_number: fields.driver_number || null,
      },
    });
    const message = data?.error || error?.message || '';
    if (/Failed to send a request|not found|404|FunctionsRelayError/i.test(message)) {
      const missing = new Error('CREATE_MEMBER_MISSING');
      throw missing;
    }
    if (error || data?.error) {
      throw new Error(message || 'Could not create account');
    }
    return data;
  },

  async updateMemberAccess(orgId, userId, role, access = null) {
    await requireSession();
    const { error } = await supabase.rpc('update_org_member_access', {
      p_org_id: orgId,
      p_user_id: userId,
      p_role: role,
      p_access: role === 'dispatcher' ? normalizeAccess(role, access) : null,
    });
    if (error && /update_org_member_access|dispatcher|043_/i.test(error.message || '')) {
      throw new Error('Paste 043_org_roles_access.sql in the SQL editor, then hard-refresh.');
    }
    rpcError(error, 'Could not update access');
  },

  async memberAccess(orgId) {
    await requireSession();
    const { data, error } = await supabase
      .from('org_members')
      .select('user_id, role, access')
      .eq('org_id', orgId);
    if (error && /access|043_/i.test(error.message || '')) return [];
    rpcError(error, 'Could not load access');
    return data ?? [];
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
    let { data, error } = await supabase
      .from('org_invites')
      .select('id, email, phone, first_name, last_name, role, token, created_at, expires_at, accepted_at')
      .eq('org_id', orgId)
      .is('accepted_at', null)
      .order('created_at', { ascending: false });
    if (error && /phone|first_name|last_name|045_|schema cache/i.test(error.message || '')) {
      ({ data, error } = await supabase
        .from('org_invites')
        .select('id, email, role, token, created_at, expires_at, accepted_at')
        .eq('org_id', orgId)
        .is('accepted_at', null)
        .order('created_at', { ascending: false }));
    }
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

  async jobMiles(orgId, start, end) {
    await requireSession();
    const { data, error } = await supabase.rpc('org_job_miles', {
      p_org_id: orgId,
      p_start: start,
      p_end: end,
    });
    if (error && /org_job_miles|schema cache/i.test(error.message || '')) return [];
    if (error) return [];
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
    let { data, error } = await supabase
      .from('org_jobs')
      .insert({
        org_id: orgId,
        created_by: user.id,
        ...row,
      })
      .select()
      .single();
    if (error && jobSchemaMissing(error.message)) {
      ({ data, error } = await supabase
        .from('org_jobs')
        .insert({
          org_id: orgId,
          created_by: user.id,
          ...stripJobExtras(row),
        })
        .select()
        .single());
    }
    rpcError(error, 'Could not create job');
    return data;
  },

  async createJobs(orgId, rows) {
    if (!rows.length) return [];
    await requireSession();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not signed in');
    const payload = rows.map((row) => ({
      org_id: orgId,
      created_by: user.id,
      ...row,
    }));
    let { data, error } = await supabase.from('org_jobs').insert(payload).select();
    if (error && jobSchemaMissing(error.message)) {
      ({ data, error } = await supabase
        .from('org_jobs')
        .insert(payload.map((row) => stripJobExtras(row)))
        .select());
    }
    rpcError(error, 'Could not create jobs');
    return data ?? [];
  },

  async updateJob(id, row) {
    await requireSession();
    let { data, error } = await supabase
      .from('org_jobs')
      .update({ ...row, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single();
    if (error && jobSchemaMissing(error.message)) {
      ({ data, error } = await supabase
        .from('org_jobs')
        .update({ ...stripJobExtras(row), updated_at: new Date().toISOString() })
        .eq('id', id)
        .select()
        .single());
    }
    rpcError(error, 'Could not update job');
    return data;
  },

  async getOwnProfile() {
    await requireSession();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not signed in');
    let { data, error } = await supabase
      .from('profiles')
      .select('user_id, nickname, first_name, last_name, address, phone, vehicle_year, vehicle_make, vehicle_model, vehicle_color')
      .eq('user_id', user.id)
      .maybeSingle();
    if (error && /first_name|last_name|address|schema cache/i.test(error.message || '')) {
      ({ data, error } = await supabase
        .from('profiles')
        .select('user_id, nickname, phone, vehicle_year, vehicle_make, vehicle_model, vehicle_color')
        .eq('user_id', user.id)
        .maybeSingle());
    }
    if (error && /phone|schema cache/i.test(error.message || '')) {
      const retry = await supabase
        .from('profiles')
        .select('user_id, nickname, vehicle_year, vehicle_make, vehicle_model, vehicle_color')
        .eq('user_id', user.id)
        .maybeSingle();
      rpcError(retry.error, 'Could not load profile');
      return retry.data
        ? { ...retry.data, phone: '', email: user.email ?? '' }
        : { user_id: user.id, nickname: '', phone: '', email: user.email ?? '' };
    }
    rpcError(error, 'Could not load profile');
    return { ...(data ?? { user_id: user.id, nickname: '', phone: '' }), email: user.email ?? '' };
  },

  async upsertProfile(fields) {
    await requireSession();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not signed in');
    const first = String(fields.first_name ?? '').trim();
    const last = String(fields.last_name ?? '').trim();
    const nickname = [first, last].filter(Boolean).join(' ') || String(fields.nickname ?? '').trim();
    const row = {
      user_id: user.id,
      nickname,
      first_name: first,
      last_name: last,
      address: String(fields.address ?? '').trim(),
      phone: String(fields.phone ?? '').trim(),
      vehicle_year: fields.vehicle_year ? Number(fields.vehicle_year) : null,
      vehicle_make: String(fields.vehicle_make ?? '').trim(),
      vehicle_model: String(fields.vehicle_model ?? '').trim(),
      vehicle_color: String(fields.vehicle_color ?? '').trim(),
      updated_at: new Date().toISOString(),
    };
    let { error } = await supabase.from('profiles').upsert(row, { onConflict: 'user_id' });
    if (error && /first_name|last_name|address|schema cache/i.test(error.message || '')) {
      const { first_name, last_name, address, ...rest } = row;
      ({ error } = await supabase.from('profiles').upsert(rest, { onConflict: 'user_id' }));
    }
    if (error && /phone|schema cache/i.test(error.message || '')) {
      const { phone, first_name, last_name, address, ...rest } = row;
      ({ error } = await supabase.from('profiles').upsert(rest, { onConflict: 'user_id' }));
    }
    rpcError(error, 'Could not save profile');
  },

  async memberProfiles(userIds) {
    if (!userIds.length) return [];
    await requireSession();
    let { data, error } = await supabase
      .from('profiles')
      .select('user_id, nickname, first_name, last_name, address, phone, vehicle_year, vehicle_make, vehicle_model, vehicle_color, last_seen_at')
      .in('user_id', userIds);
    if (error && /first_name|last_name|address|schema cache/i.test(error.message || '')) {
      ({ data, error } = await supabase
        .from('profiles')
        .select('user_id, nickname, phone, vehicle_year, vehicle_make, vehicle_model, vehicle_color, last_seen_at')
        .in('user_id', userIds));
    }
    if (error && /last_seen_at|schema cache/i.test(error.message || '')) {
      ({ data, error } = await supabase
        .from('profiles')
        .select('user_id, nickname, phone, vehicle_year, vehicle_make, vehicle_model, vehicle_color')
        .in('user_id', userIds));
    }
    if (error) return [];
    return data ?? [];
  },

  async memberDriverNumbers(orgId) {
    await requireSession();
    let { data, error } = await supabase
      .from('org_members')
      .select('user_id, driver_number')
      .eq('org_id', orgId);
    if (error && /driver_number|schema cache/i.test(error.message || '')) {
      return [];
    }
    if (error) return [];
    return data ?? [];
  },

  async updateDriverProfile(orgId, userId, fields) {
    await requireSession();
    const { error } = await supabase.rpc('update_org_driver_profile', {
      p_org_id: orgId,
      p_user_id: userId,
      p_driver_number: fields.driver_number ?? '',
      p_first_name: fields.first_name ?? '',
      p_last_name: fields.last_name ?? '',
      p_phone: fields.phone ?? '',
      p_address: fields.address ?? '',
    });
    rpcError(error, 'Could not save driver profile. Run 031_driver_profile.sql in the SQL editor.');
  },

  async driverLastLocations(orgId) {
    await requireSession();
    const { data, error } = await supabase.rpc('org_driver_last_locations', {
      p_org_id: orgId,
    });
    if (error) return [];
    return data ?? [];
  },

  async deleteJob(id) {
    await requireSession();
    const { error } = await supabase.from('org_jobs').delete().eq('id', id);
    rpcError(error, 'Could not delete job');
  },

  async listCustomers(orgId) {
    await requireSession();
    const { data, error } = await supabase
      .from('org_customers')
      .select('*')
      .eq('org_id', orgId)
      .order('name', { ascending: true });
    if (error && /org_customers|schema cache/i.test(error.message || '')) return [];
    rpcError(error, 'Could not load accounts. Run 032_customers_books.sql.');
    return data ?? [];
  },

  async saveCustomer(orgId, fields) {
    await requireSession();
    const charge = String(fields.charge_number || '').replace(/\D/g, '');
    if (charge && !/^[0-9]{4,5}$/.test(charge)) {
      throw new Error('Charge number is 4 or 5 digits.');
    }
    if (!charge) throw new Error('Charge number is required.');
    const text = (value) => String(value || '').trim();
    const row = {
      org_id: orgId,
      name: text(fields.name),
      charge_number: charge,
      billing_email: text(fields.billing_email),
      phone: text(fields.phone),
      terms: text(fields.terms) || 'Net 30',
      quote_per_mile: numberOrNull(fields.quote_per_mile),
      quote_minimum: numberOrNull(fields.quote_minimum),
      quote_weekend_mult: numberOrNull(fields.quote_weekend_mult),
      quote_after_hours_mult: numberOrNull(fields.quote_after_hours_mult),
      company_take_pct: (() => {
        const n = numberOrNull(fields.company_take_pct);
        return n == null ? null : n / 100;
      })(),
      pickup_name: text(fields.pickup_name),
      pickup_line1: text(fields.pickup_line1),
      pickup_line2: text(fields.pickup_line2),
      pickup_city: text(fields.pickup_city),
      pickup_state: text(fields.pickup_state).toUpperCase(),
      pickup_zip: text(fields.pickup_zip),
      pickup_phone: text(fields.pickup_phone),
      pickup_email: text(fields.pickup_email),
      dropoff_name: text(fields.dropoff_name),
      dropoff_line1: text(fields.dropoff_line1),
      dropoff_line2: text(fields.dropoff_line2),
      dropoff_city: text(fields.dropoff_city),
      dropoff_state: text(fields.dropoff_state).toUpperCase(),
      dropoff_zip: text(fields.dropoff_zip),
      dropoff_phone: text(fields.dropoff_phone),
      dropoff_email: text(fields.dropoff_email),
      updated_at: new Date().toISOString(),
    };
    if (!row.name) throw new Error('Account name is required.');
    const query = fields.id
      ? supabase.from('org_customers').update(row).eq('id', fields.id).select().single()
      : supabase.from('org_customers').insert(row).select().single();
    const { data, error } = await query;
    if (error && /charge_number|pickup_line1|dropoff_line1|038_|schema cache/i.test(error.message || '')) {
      throw new Error('Paste 038_account_stops_weight.sql in the SQL editor, then hard-refresh.');
    }
    if (error && /org_customers_charge_unique|duplicate key/i.test(error.message || '')) {
      throw new Error('That charge number is already on an account.');
    }
    if (error && /org_customers|schema cache/i.test(error.message || '')) {
      throw new Error('Run 032_customers_books.sql in the Supabase SQL editor.');
    }
    rpcError(error, 'Could not save account');
    return data;
  },

  async deleteCustomer(id) {
    await requireSession();
    const { error } = await supabase.from('org_customers').delete().eq('id', id);
    if (error && /org_customers|schema cache/i.test(error.message || '')) {
      throw new Error('Run 032_customers_books.sql in the Supabase SQL editor.');
    }
    rpcError(error, 'Could not delete account');
  },

  async saveBooks(orgId, docs) {
    if (!docs.length) return;
    await requireSession();
    const rows = docs.map((doc) => ({
      org_id: orgId,
      doc_type: doc.docType,
      doc_number: doc.docNumber,
      period_start: doc.periodStart,
      period_end: doc.periodEnd,
      party_key: doc.partyKey,
      party_name: doc.partyName,
      total: doc.total,
      line_count: doc.lines.length,
      payload: doc.lines,
      status: 'ready',
      updated_at: new Date().toISOString(),
    }));
    const { error } = await supabase
      .from('org_books_documents')
      .upsert(rows, { onConflict: 'org_id,doc_number' });
    if (error && /org_books_documents|schema cache/i.test(error.message || '')) {
      throw new Error('The file downloaded. Run 032_customers_books.sql so this week is remembered and a second download updates the same documents.');
    }
    rpcError(error, 'Could not save the books packet');
  },

  async listDriverHours(orgId) {
    await requireSession();
    const { data, error } = await supabase
      .from('org_driver_hours')
      .select('id, org_id, user_id, weekday, start_time, end_time')
      .eq('org_id', orgId);
    if (error && /org_driver_hours|schema cache/i.test(error.message || '')) {
      throw new Error('Paste 037_driver_hours.sql in the SQL editor, then hard-refresh.');
    }
    rpcError(error, 'Could not load driver hours');
    return data ?? [];
  },

  async saveDriverHours(orgId, userId, days) {
    await requireSession();
    const rows = [];
    for (const day of days || []) {
      const start = String(day.start_time || '').trim();
      const end = String(day.end_time || '').trim();
      if (!start || !end) continue;
      if (end <= start) throw new Error('End time must be after start time.');
      rows.push({
        org_id: orgId,
        user_id: userId,
        weekday: Number(day.weekday),
        start_time: start.length === 5 ? `${start}:00` : start,
        end_time: end.length === 5 ? `${end}:00` : end,
        updated_at: new Date().toISOString(),
      });
    }
    const { error: delErr } = await supabase
      .from('org_driver_hours')
      .delete()
      .eq('org_id', orgId)
      .eq('user_id', userId);
    if (delErr && /org_driver_hours|schema cache/i.test(delErr.message || '')) {
      throw new Error('Paste 037_driver_hours.sql in the SQL editor, then hard-refresh.');
    }
    rpcError(delErr, 'Could not save driver hours');
    if (!rows.length) return [];
    const { data, error } = await supabase.from('org_driver_hours').insert(rows).select();
    rpcError(error, 'Could not save driver hours');
    return data ?? [];
  },
};

function numberOrNull(value) {
  if (value === '' || value == null) return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

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

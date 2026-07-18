import { getImportFormats, parseTripCsv } from './lib/csvImporter.js';
import { buildReportHistory, buildReportSummary } from './lib/reports.js';
import { requireSession, supabase } from './supabase.js';

function tripFromRow(row) {
  return {
    id: row.id,
    date: row.date,
    miles: Number(row.miles),
    tips: Number(row.tips ?? 0),
    notes: row.notes ?? '',
    source: row.source ?? 'manual',
    is_business: row.is_business !== false,
    created_at: row.created_at,
  };
}

function isDuplicate(existing, trip) {
  return existing.some(
    (t) =>
      t.date === trip.date &&
      t.source === trip.source &&
      Math.abs(t.miles - trip.miles) < 0.05 &&
      Math.abs(t.tips - trip.tips) < 0.01,
  );
}

async function getAllTrips() {
  const { data, error } = await supabase
    .from('trips')
    .select('*')
    .order('date', { ascending: false })
    .order('id', { ascending: false });

  if (error) throw new Error(error.message);
  return (data ?? []).map(tripFromRow);
}

async function getMileageRate() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not signed in');

  const { data, error } = await supabase
    .from('settings')
    .select('mileage_rate')
    .eq('user_id', user.id)
    .maybeSingle();

  if (error) throw new Error(error.message);
  return data ? Number(data.mileage_rate) : 0.7;
}

export const api = {
  async init() {
    await requireSession();
  },

  getTrips: async (params = {}) => {
    const trips = await getAllTrips();
    const limit = params.limit ? Number(params.limit) : null;
    return limit ? trips.slice(0, limit) : trips;
  },

  createTrip: async (data) => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not signed in');

    const { data: row, error } = await supabase
      .from('trips')
      .insert({
        user_id: user.id,
        date: data.date,
        miles: data.miles,
        tips: data.tips ?? 0,
        notes: data.notes ?? '',
        source: data.source ?? 'manual',
        is_business: data.is_business !== false,
      })
      .select()
      .single();

    if (error) throw new Error(error.message);
    return tripFromRow(row);
  },

  updateTrip: async (id, data) => {
    const { data: row, error } = await supabase
      .from('trips')
      .update({
        date: data.date,
        miles: data.miles,
        tips: data.tips ?? 0,
        notes: data.notes ?? '',
        is_business: data.is_business !== false,
      })
      .eq('id', id)
      .select()
      .single();

    if (error) throw new Error(error.message);
    return tripFromRow(row);
  },

  deleteTrip: async (id) => {
    const { error } = await supabase.from('trips').delete().eq('id', id);
    if (error) throw new Error(error.message);
    return null;
  },

  getReportSummary: async (date) => {
    const trips = await getAllTrips();
    const rate = await getMileageRate();
    return buildReportSummary(trips, rate, date);
  },

  getReports: async (period, count = 6) => {
    const trips = await getAllTrips();
    const rate = await getMileageRate();
    return { period, reports: buildReportHistory(trips, period, rate, count) };
  },

  getSettings: async () => {
    const rate = await getMileageRate();
    return { mileage_rate: String(rate) };
  },

  setMileageRate: async (rate) => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not signed in');

    const { data, error } = await supabase
      .from('settings')
      .upsert({
        user_id: user.id,
        mileage_rate: rate,
        updated_at: new Date().toISOString(),
      })
      .select('mileage_rate')
      .single();

    if (error) throw new Error(error.message);
    return { mileage_rate: Number(data.mileage_rate) };
  },

  getImportFormats: async () => getImportFormats(),

  previewImport: async ({ csv, platform = 'generic', default_miles = 0 }) => {
    const result = parseTripCsv(csv, { platform, defaultMiles: Number(default_miles) || 0 });
    return {
      dry_run: true,
      platform: result.platform,
      detected_columns: result.columns,
      preview: result.trips,
      errors: result.errors,
      total_parsed: result.trips.length,
    };
  },

  importTrips: async ({ csv, platform = 'generic', default_miles = 0 }) => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('Not signed in');

    const result = parseTripCsv(csv, { platform, defaultMiles: Number(default_miles) || 0 });
    const existing = await getAllTrips();
    const imported = [];
    const skipped = [];

    for (const trip of result.trips) {
      if (isDuplicate(existing, trip)) {
        skipped.push({ ...trip, reason: 'duplicate' });
        continue;
      }

      const { data: row, error } = await supabase
        .from('trips')
        .insert({
          user_id: user.id,
          date: trip.date,
          miles: trip.miles,
          tips: trip.tips,
          notes: trip.notes,
          source: trip.source,
          is_business: true,
        })
        .select()
        .single();

      if (error) throw new Error(error.message);
      imported.push(tripFromRow(row));
      existing.push(tripFromRow(row));
    }

    return {
      platform: result.platform,
      imported_count: imported.length,
      skipped_count: skipped.length,
      error_count: result.errors.length,
      imported,
      skipped,
      errors: result.errors,
    };
  },
};
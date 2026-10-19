export function trim(v) {
  return String(v ?? '').trim();
}

export function composeAddress({ line1, line2, city, state, zip }) {
  const street = [trim(line1), trim(line2)].filter(Boolean);
  const region = [trim(city), [trim(state).toUpperCase(), trim(zip)].filter(Boolean).join(' ')]
    .filter(Boolean)
    .join(', ');
  return [...street, region].filter(Boolean).join(', ');
}

export function addressFromJob(job, prefix) {
  const line1 = trim(job[`${prefix}_line1`]);
  const line2 = trim(job[`${prefix}_line2`]);
  const city = trim(job[`${prefix}_city`]);
  const state = trim(job[`${prefix}_state`]);
  const zip = trim(job[`${prefix}_zip`]);
  if (line1 || line2 || city || state || zip) {
    return { line1, line2, city, state, zip };
  }
  return {
    line1: trim(job[`${prefix}_address`]),
    line2: '',
    city: '',
    state: '',
    zip: '',
  };
}

export const US_STATES = [
  'AL','AK','AZ','AR','CA','CO','CT','DE','DC','FL','GA','HI','ID','IL','IN','IA','KS',
  'KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC',
  'ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY',
];

const US_STATE_NAMES = {
  alabama: 'AL', alaska: 'AK', arizona: 'AZ', arkansas: 'AR', california: 'CA',
  colorado: 'CO', connecticut: 'CT', delaware: 'DE', 'district of columbia': 'DC',
  florida: 'FL', georgia: 'GA', hawaii: 'HI', idaho: 'ID', illinois: 'IL',
  indiana: 'IN', iowa: 'IA', kansas: 'KS', kentucky: 'KY', louisiana: 'LA',
  maine: 'ME', maryland: 'MD', massachusetts: 'MA', michigan: 'MI', minnesota: 'MN',
  mississippi: 'MS', missouri: 'MO', montana: 'MT', nebraska: 'NE', nevada: 'NV',
  'new hampshire': 'NH', 'new jersey': 'NJ', 'new mexico': 'NM', 'new york': 'NY',
  'north carolina': 'NC', 'north dakota': 'ND', ohio: 'OH', oklahoma: 'OK',
  oregon: 'OR', pennsylvania: 'PA', 'rhode island': 'RI', 'south carolina': 'SC',
  'south dakota': 'SD', tennessee: 'TN', texas: 'TX', utah: 'UT', vermont: 'VT',
  virginia: 'VA', washington: 'WA', 'west virginia': 'WV', wisconsin: 'WI',
  wyoming: 'WY',
};

export function toStateCode(value) {
  const raw = trim(value);
  if (!raw) return '';
  const upper = raw.toUpperCase();
  if (US_STATES.includes(upper)) return upper;
  return US_STATE_NAMES[raw.toLowerCase()] || '';
}

export function recentJobStops(jobs) {
  const seen = new Set();
  const out = [];
  for (const job of jobs || []) {
    for (const prefix of ['pickup', 'dropoff']) {
      const hit = {
        line1: trim(job[`${prefix}_line1`]) || trim(job[`${prefix}_address`]),
        line2: trim(job[`${prefix}_line2`]),
        city: trim(job[`${prefix}_city`]),
        state: toStateCode(job[`${prefix}_state`]),
        zip: trim(job[`${prefix}_zip`]),
        business: trim(job[`${prefix}_name`]),
        source: 'recent',
      };
      if (!hit.line1 && !hit.city) continue;
      const key = composeAddress(hit).toLowerCase();
      if (!key || seen.has(key)) continue;
      seen.add(key);
      hit.label = [hit.business, composeAddress(hit)].filter(Boolean).join(' · ');
      out.push(hit);
    }
  }
  return out;
}

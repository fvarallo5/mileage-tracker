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

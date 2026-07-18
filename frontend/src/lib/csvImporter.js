const PLATFORMS = ['uber', 'doordash', 'lyft', 'instacart', 'generic'];

const COLUMN_ALIASES = {
  date: [
    'date',
    'trip date',
    'trip request time',
    'pickup time',
    'dropoff time',
    'delivery date',
    'completed at',
    'timestamp',
    'start time',
    'end time',
    'time',
  ],
  miles: [
    'miles',
    'distance',
    'trip distance',
    'distance (miles)',
    'delivery distance',
    'mileage',
    'total distance',
    'distance mi',
  ],
  tips: [
    'tips',
    'tip',
    'tip amount',
    'earnings',
    'driver earnings',
    'total pay',
    'total earnings',
    'dasher pay',
    'net pay',
    'payout',
    'fare',
    'trip fare',
    'amount',
    'pay',
  ],
  notes: [
    'notes',
    'description',
    'store name',
    'restaurant',
    'product type',
    'service type',
    'trip id',
    'delivery',
    'type',
  ],
};

const PLATFORM_HINTS = {
  uber: ['uber', 'trip request', 'trip fare', 'rider'],
  doordash: ['doordash', 'dasher', 'delivery pay', 'store name'],
  lyft: ['lyft', 'ride', 'passenger'],
  instacart: ['instacart', 'batch', 'shop'],
};

function normalizeHeader(h) {
  return h.trim().toLowerCase().replace(/[_"]/g, ' ').replace(/\s+/g, ' ');
}

function parseCsv(text) {
  const lines = text
    .replace(/^\uFEFF/, '')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  if (lines.length < 2) {
    throw new Error('CSV must have a header row and at least one data row');
  }

  const delimiter = detectDelimiter(lines[0]);
  const headers = parseCsvLine(lines[0], delimiter).map(normalizeHeader);
  const rows = lines.slice(1).map((line) => {
    const values = parseCsvLine(line, delimiter);
    const row = {};
    headers.forEach((h, i) => {
      row[h] = values[i] ?? '';
    });
    return row;
  });

  return { headers, rows };
}

function detectDelimiter(headerLine) {
  const commas = (headerLine.match(/,/g) || []).length;
  const tabs = (headerLine.match(/\t/g) || []).length;
  const semis = (headerLine.match(/;/g) || []).length;
  if (tabs >= commas && tabs >= semis) return '\t';
  if (semis > commas) return ';';
  return ',';
}

function parseCsvLine(line, delimiter) {
  const result = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch === delimiter && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += ch;
    }
  }
  result.push(current.trim());
  return result;
}

function findColumn(headers, aliases) {
  for (const alias of aliases) {
    const exact = headers.find((h) => h === alias);
    if (exact) return exact;
  }
  for (const alias of aliases) {
    const partial = headers.find((h) => h.includes(alias) || alias.includes(h));
    if (partial) return partial;
  }
  return null;
}

function detectPlatform(headers, hint) {
  if (hint && hint !== 'generic' && PLATFORMS.includes(hint)) return hint;

  const joined = headers.join(' ');
  for (const [platform, keywords] of Object.entries(PLATFORM_HINTS)) {
    if (keywords.some((k) => joined.includes(k))) return platform;
  }
  return 'generic';
}

function parseMoney(value) {
  if (value == null || value === '') return 0;
  const cleaned = String(value).replace(/[$,\s]/g, '').replace(/[()]/g, '');
  const num = parseFloat(cleaned);
  return Number.isFinite(num) ? Math.max(0, num) : 0;
}

function parseMiles(value) {
  if (value == null || value === '') return null;
  const str = String(value).toLowerCase().trim();
  const kmMatch = str.match(/([\d.]+)\s*km/);
  if (kmMatch) return parseFloat(kmMatch[1]) * 0.621371;

  const miMatch = str.match(/([\d.]+)\s*mi/);
  if (miMatch) return parseFloat(miMatch[1]);

  const num = parseFloat(str.replace(/[^\d.]/g, ''));
  return Number.isFinite(num) && num > 0 ? num : null;
}

function parseDate(value) {
  if (!value || String(value).trim() === '') return null;
  const str = String(value).trim();

  // ISO or YYYY-MM-DD prefix
  const iso = str.match(/^(\d{4}-\d{2}-\d{2})/);
  if (iso) return iso[1];

  // MM/DD/YYYY or M/D/YY
  const us = str.match(/^(\d{1,2})\/(\d{1,2})\/(\d{2,4})/);
  if (us) {
    let year = parseInt(us[3], 10);
    if (year < 100) year += 2000;
    const month = us[1].padStart(2, '0');
    const day = us[2].padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  const parsed = new Date(str);
  if (!Number.isNaN(parsed.getTime())) {
    const y = parsed.getFullYear();
    const m = String(parsed.getMonth() + 1).padStart(2, '0');
    const d = String(parsed.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  return null;
}

function mapColumns(headers, platform) {
  const mapping = {};
  for (const [field, aliases] of Object.entries(COLUMN_ALIASES)) {
    mapping[field] = findColumn(headers, aliases);
  }

  // Platform-specific fallbacks
  if (platform === 'uber') {
    mapping.date ??= findColumn(headers, ['trip request time', 'pickup time']);
    mapping.miles ??= findColumn(headers, ['trip distance', 'distance']);
    mapping.tips ??= findColumn(headers, ['driver earnings', 'earnings', 'trip fare']);
  }
  if (platform === 'doordash') {
    mapping.date ??= findColumn(headers, ['delivery date', 'completed at']);
    mapping.tips ??= findColumn(headers, ['total pay', 'dasher pay', 'earnings']);
    mapping.notes ??= findColumn(headers, ['store name', 'merchant']);
  }

  return mapping;
}

export function parseTripCsv(csvText, { platform = 'generic', defaultMiles = 0 } = {}) {
  const { headers, rows } = parseCsv(csvText);
  const detected = detectPlatform(headers, platform);
  const columns = mapColumns(headers, detected);

  if (!columns.date) {
    throw new Error(
      `Could not find a date column. Headers found: ${headers.join(', ')}. ` +
        'Expected columns like "Date", "Trip Request Time", or "Delivery Date".'
    );
  }

  const parsed = [];
  const errors = [];

  rows.forEach((row, index) => {
    const lineNum = index + 2;
    try {
      const date = parseDate(row[columns.date]);
      if (!date) {
        errors.push({ line: lineNum, error: 'Invalid or missing date' });
        return;
      }

      let miles = columns.miles ? parseMiles(row[columns.miles]) : null;
      if (miles == null && defaultMiles > 0) {
        miles = defaultMiles;
      }
      if (miles == null || miles <= 0) {
        errors.push({
          line: lineNum,
          error: 'Missing miles/distance — set a default miles value for earnings-only exports',
        });
        return;
      }

      const tips = columns.tips ? parseMoney(row[columns.tips]) : 0;
      let notes = columns.notes ? String(row[columns.notes] ?? '').trim() : '';
      if (!notes) notes = `Imported from ${detected}`;

      parsed.push({
        date,
        miles: Math.round(miles * 100) / 100,
        tips: Math.round(tips * 100) / 100,
        notes,
        source: detected,
        line: lineNum,
      });
    } catch (e) {
      errors.push({ line: lineNum, error: e.message });
    }
  });

  return {
    platform: detected,
    headers,
    columns,
    trips: parsed,
    errors,
  };
}

export function getImportFormats() {
  return {
    platforms: PLATFORMS,
    instructions: {
      uber: {
        name: 'Uber Driver',
        steps: [
          'Open the Uber Driver app → Account → Wallet → See earnings activity',
          'Or visit driver.uber.com → Earnings → export/download trip data',
          'Export as CSV and import here',
        ],
        expected_columns: ['Trip request time', 'Trip distance', 'Driver earnings or Tips'],
        note: 'Uber exports usually include trip distance in miles.',
      },
      doordash: {
        name: 'DoorDash Dasher',
        steps: [
          'Open Dasher app → Earnings → View earnings by week',
          'Or request your data at privacy.doordash.com (Download My Data)',
          'Export earnings CSV and import here',
        ],
        expected_columns: ['Date', 'Total Pay or Tips', 'Distance (if available)'],
        note: 'DoorDash exports often lack mileage — set a default miles estimate per delivery.',
      },
      lyft: {
        name: 'Lyft Driver',
        steps: [
          'Visit lyft.com/driver/dashboard → Earnings → download ride history',
          'Export CSV and import here',
        ],
        expected_columns: ['Date', 'Distance', 'Earnings'],
      },
      instacart: {
        name: 'Instacart Shopper',
        steps: [
          'Open Instacart Shopper app → Earnings → batch history',
          'Export or copy earnings data as CSV',
        ],
        expected_columns: ['Date', 'Distance', 'Earnings'],
      },
      generic: {
        name: 'Generic CSV',
        steps: ['Use any CSV with Date, Miles/Distance, and Tips/Earnings columns'],
        expected_columns: ['date', 'miles', 'tips', 'notes (optional)'],
      },
    },
    sample_csv: {
      uber: 'Trip request time,Trip distance,Driver earnings,Product type\n2026-07-01 14:30:00,5.2,18.50,UberX\n2026-07-02 09:15:00,3.8,12.25,UberX',
      doordash: 'Date,Store Name,Total Pay,Distance\n07/01/2026,Chipotle,14.50,2.1\n07/02/2026,McDonalds,9.75,1.8',
      generic: 'date,miles,tips,notes\n2026-07-01,5.2,18.50,Airport run\n2026-07-02,3.8,12.25,Downtown',
    },
  };
}
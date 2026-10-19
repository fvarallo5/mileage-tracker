import {
  isCourierMode,
  isReimbursementMode,
  isSchoolMode,
  isServiceJobStyle,
  normalizeOperatingMode,
} from './company.js';

const COURIER_NAV = [
  ['overview', 'Overview'],
  ['drivers', 'Drivers'],
  ['jobs', 'Jobs'],
  ['plan', 'Plan'],
  ['trips', 'Trips'],
  ['expenses', 'Expenses'],
  ['review', 'Reports'],
  ['books', 'Books'],
  ['people', 'People'],
  ['profile', 'Settings'],
];

const REIMBURSE_NAV = [
  ['overview', 'Overview'],
  ['home', 'Employees'],
  ['trips', 'Trips'],
  ['expenses', 'Expenses'],
  ['review', 'Reports'],
  ['books', 'Books'],
  ['people', 'People'],
  ['profile', 'Settings'],
];

const SCHOOL_NAV = [
  ['overview', 'Overview'],
  ['drivers', 'Instructors'],
  ['jobs', 'Lessons'],
  ['plan', 'Plan'],
  ['trips', 'Trips'],
  ['expenses', 'Expenses'],
  ['review', 'Reports'],
  ['books', 'Books'],
  ['people', 'People'],
  ['profile', 'Settings'],
];

const SERVICE_NAV = [
  ['overview', 'Overview'],
  ['drivers', 'Technicians'],
  ['jobs', 'Visits'],
  ['plan', 'Plan'],
  ['trips', 'Trips'],
  ['expenses', 'Expenses'],
  ['review', 'Reports'],
  ['books', 'Books'],
  ['people', 'People'],
  ['profile', 'Settings'],
];

const SKINS = {
  courier: {
    id: 'courier',
    boardNoun: 'Jobs',
    jobWord: 'Job',
    worker: 'Driver',
    workers: 'Drivers',
    workerShort: 'Drv',
    officeRole: 'Dispatcher',
    siteTitle: 'Pickup',
    findPlaceholder: 'Job #, town, account, driver',
    pulse: [
      ['open', 'Open'],
      ['picked_up', 'Picked up'],
      ['delivered', 'Delivered'],
      ['unassigned', 'Unassigned'],
      ['failed', "Couldn't"],
    ],
    showAssignTools: true,
    showCourierQuotes: true,
    showCourierBooksExtra: true,
    booksKind: 'courier',
    reviewKind: 'quotes',
    showJobQuotesSettings: true,
  },
  reimbursement: {
    id: 'reimbursement',
    boardNoun: 'Miles',
    jobWord: 'Trip',
    worker: 'Employee',
    workers: 'Employees',
    workerShort: 'Emp',
    officeRole: 'Admin',
    siteTitle: 'Site',
    findPlaceholder: 'Name, notes',
    pulse: [],
    showAssignTools: false,
    showCourierQuotes: false,
    showCourierBooksExtra: false,
    booksKind: 'expense',
    reviewKind: 'miles',
    showJobQuotesSettings: false,
  },
  service: {
    id: 'service',
    boardNoun: 'Visits',
    jobWord: 'Visit',
    worker: 'Technician',
    workers: 'Technicians',
    workerShort: 'Tech',
    officeRole: 'Office',
    siteTitle: 'Site',
    findPlaceholder: 'Visit #, customer, site, technician',
    pulse: [
      ['open', 'Open'],
      ['picked_up', 'On site'],
      ['delivered', 'Done'],
      ['unassigned', 'Unassigned'],
      ['failed', "Couldn't"],
    ],
    showAssignTools: false,
    showCourierQuotes: false,
    showCourierBooksExtra: false,
    booksKind: 'accounts',
    reviewKind: 'visits',
    showJobQuotesSettings: false,
  },
  driving_school: {
    id: 'driving_school',
    boardNoun: 'Lessons',
    jobWord: 'Lesson',
    worker: 'Instructor',
    workers: 'Instructors',
    workerShort: 'Instr',
    officeRole: 'Instructor',
    siteTitle: 'Meet',
    findPlaceholder: 'Lesson #, student, lot, instructor',
    pulse: [
      ['open', 'Scheduled'],
      ['picked_up', 'In lesson'],
      ['delivered', 'Done'],
      ['unassigned', 'Unassigned'],
      ['failed', 'No-show'],
    ],
    showAssignTools: false,
    showCourierQuotes: false,
    showCourierBooksExtra: false,
    booksKind: 'accounts',
    reviewKind: 'hours',
    showJobQuotesSettings: false,
  },
};

export function deskSkin(mode) {
  const type = normalizeOperatingMode(mode);
  return SKINS[type] || SKINS.courier;
}

export function countNoun(n, skin) {
  const one = (skin?.jobWord || 'Job').toLowerCase();
  const many = (skin?.boardNoun || 'Jobs').toLowerCase();
  return `${n} ${n === 1 ? one : many}`;
}

export function deskNavForMode(mode) {
  const type = normalizeOperatingMode(mode);
  if (type === 'reimbursement') return REIMBURSE_NAV;
  if (type === 'driving_school') return SCHOOL_NAV;
  if (type === 'service') return SERVICE_NAV;
  return COURIER_NAV;
}

export function layoutFor({ companyType, onTeam = false, preferSolo = true, role = 'driver' } = {}) {
  const type = onTeam ? normalizeOperatingMode(companyType) : null;
  const showSoloSeat = !onTeam || type === 'courier';
  const isSolo = !onTeam || (showSoloSeat && preferSolo);
  const isTeamMember = onTeam && !isSolo;
  return {
    companyType: type,
    role,
    showSoloSeat,
    isSolo,
    isTeamMember,
    showMoneyMode: isSolo,
    showImport: isSolo,
    showMerge: isSolo,
    showTax: isSolo,
    showPurpose: isSolo,
    showJobs: isTeamMember && type !== 'reimbursement',
    showCourierQuotes: isCourierMode(type),
    serviceJob: isServiceJobStyle(type),
    deskNav: deskNavForMode(type),
    deskFallback: 'overview',
    homeNavLabel: isSolo ? 'Track' : (isSchoolMode(type) ? 'Lessons' : (isServiceJobStyle(type) ? 'Visits' : 'Jobs')),
    jobsTitle: isSchoolMode(type) ? 'Lessons' : (isServiceJobStyle(type) ? 'Visits' : 'Jobs'),
    skin: deskSkin(type),
  };
}

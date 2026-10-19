export const ROLE_ORDER = ['owner', 'admin', 'dispatcher', 'driver'];

export const ROLES = [
  { id: 'owner', label: 'Owner', rank: 4 },
  { id: 'admin', label: 'Admin', rank: 3 },
  { id: 'dispatcher', label: 'Dispatcher', rank: 2 },
  { id: 'driver', label: 'Driver', rank: 1 },
];

export const DESK_PAGES = [
  { id: 'today', label: 'Jobs' },
  { id: 'plan', label: 'Plan' },
  { id: 'review', label: 'Reports' },
  { id: 'books', label: 'Books' },
];

const EMPTY_ACCESS = {
  today: false,
  plan: false,
  review: false,
  books: false,
  people: false,
  settings: false,
};

const FULL_ACCESS = {
  today: true,
  plan: true,
  review: true,
  books: true,
  people: true,
  settings: true,
};

const DISPATCHER_ACCESS = {
  ...EMPTY_ACCESS,
  today: true,
  plan: true,
  review: true,
};

export function roleRank(role) {
  return ROLES.find((row) => row.id === role)?.rank ?? 0;
}

export function isAdminRole(role) {
  return role === 'owner' || role === 'admin';
}

export function isDeskRole(role) {
  return role === 'owner' || role === 'admin' || role === 'dispatcher';
}

export function roleLabel(role, { fleet = true, companyType } = {}) {
  const type = companyType
    ? String(companyType)
    : (fleet ? 'courier' : 'reimbursement');
  const mode = type === 'fleet' ? 'courier' : type;
  if (role === 'owner') return 'Owner';
  if (role === 'admin') return 'Admin';
  if (role === 'dispatcher') {
    if (mode === 'driving_school') return 'Instructor';
    if (mode === 'service') return 'Office';
    return 'Dispatcher';
  }
  if (mode === 'reimbursement') return 'Employee';
  if (mode === 'driving_school') return 'Student';
  if (mode === 'service') return 'Technician';
  return 'Driver';
}

export function inviteRoles(actorRole) {
  if (!isAdminRole(actorRole)) return [];
  return ['admin', 'dispatcher', 'driver'];
}

export function canEditMember(actorRole, targetRole) {
  if (!isAdminRole(actorRole)) return false;
  if (targetRole === 'owner') return actorRole === 'owner';
  return true;
}

export function canRemoveMember(actorRole, targetRole) {
  if (!isAdminRole(actorRole) || targetRole === 'owner') return false;
  return true;
}

export function defaultAccess(role) {
  if (isAdminRole(role)) return { ...FULL_ACCESS };
  if (role === 'dispatcher') return { ...DISPATCHER_ACCESS };
  return { ...EMPTY_ACCESS };
}

export function normalizeAccess(role, access) {
  const base = defaultAccess(role);
  if (isAdminRole(role)) return base;
  if (role !== 'dispatcher') return { ...EMPTY_ACCESS };
  const next = { ...base };
  for (const page of DESK_PAGES) {
    if (access && typeof access[page.id] === 'boolean') next[page.id] = access[page.id];
  }
  next.people = false;
  next.settings = false;
  return next;
}

export function hasPage(membership, pageId) {
  if (!membership) return false;
  if (pageId === 'people' || pageId === 'settings') return isAdminRole(membership.role);
  if (isAdminRole(membership.role)) return true;
  if (membership.role !== 'dispatcher') return false;
  return Boolean(membership.access?.[pageId]);
}

export function accessLabel(role, access) {
  if (isAdminRole(role)) return 'Full desk';
  if (role !== 'dispatcher') return 'Phone app';
  const on = DESK_PAGES.filter((page) => normalizeAccess(role, access)[page.id]).map((page) => page.label);
  return on.length ? on.join(', ') : 'No desk pages';
}

export function pageNav(nav, membership) {
  return nav.filter(([id]) => {
    if (id === 'jobs' || id === 'home') return hasPage(membership, 'today');
    if (id === 'plan') return hasPage(membership, 'plan');
    if (id === 'overview' || id === 'drivers' || id === 'trips' || id === 'expenses' || id === 'review') {
      return hasPage(membership, 'review');
    }
    if (id === 'books') return hasPage(membership, 'books');
    if (id === 'people') return hasPage(membership, 'people');
    if (id === 'profile') return isDeskRole(membership?.role);
    return true;
  });
}

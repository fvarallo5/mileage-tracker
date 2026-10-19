export const SUPPORT_EMAIL = 'support.ultraforgellc@gmail.com';

export const FAQ_ITEMS = [
  {
    title: 'Does every job need pickup and delivery?',
    body: 'Yes. TrekTrack is a courier desk. Pickup and delivery both live on the job so quotes, the map, and the phone card stay a full run.',
  },
  {
    title: 'What is a charge number?',
    body: 'A 4 or 5 digit code on each customer account. Type it on Today to fill saved pickup or delivery stops. It is unique on your team.',
  },
  {
    title: 'Who can use the desk?',
    body: 'Owner, then Admin, then Dispatcher, then Driver. Owner and Admin have the full desk. New member on People opens a card for name, phone or email, role, and optional password. Dispatcher access is set there. Drivers use the phone app.',
  },
  {
    title: 'Can office staff create a job with no driver?',
    body: 'Yes. Leave the driver blank. Unassigned jobs stay on Today. Drivers on the phone only see jobs assigned to them.',
  },
  {
    title: 'Who closes a job?',
    body: 'Settings → Job quotes. Drivers on the phone is the default (photo and signature). Office on this desk lets dispatch mark delivered. Drivers can still mark picked up.',
  },
  {
    title: 'How is the quote calculated?',
    body: 'Auto quote is the greater of the minimum and road miles × per-mile, then weekend and after-hours multipliers. A per-job add-on is applied after that. You can type a manual quote.',
  },
  {
    title: 'Is cash on delivery income?',
    body: 'No. COD is cash for the shipper. It is not added to the quote or the invoice. Turn COD on in Settings → Job quotes to show it on the job. Uncollected COD shows on Books.',
  },
  {
    title: 'Why is a delivered job Held?',
    body: 'It has no customer account. Assign one on Books or People, then it can go on the week packet.',
  },
  {
    title: 'Where is QuickBooks?',
    body: 'The week packet CSV is on Books. TrekTrack is the dispatch desk. QuickBooks stays the books of record.',
  },
];

export const TROUBLE_ITEMS = [
  {
    title: 'Assign nearest skipped a driver',
    body: 'That driver has no location ping today. Nearest only uses a same-day ping. You can still pick them on the job.',
  },
  {
    title: 'Books invoices are $0.00',
    body: 'The packet only includes delivered jobs that have an account and a driver in the selected period. Held and unassigned delivered jobs sit in their own lists.',
  },
  {
    title: 'By day is empty',
    body: 'Dates with no jobs are hidden. Switch period or add a job on Today / Plan.',
  },
  {
    title: 'The confirmation email sent me to a password screen',
    body: 'Open a new confirmation on this computer. Sign-up already has the password. Only a password-reset link opens a new-password screen.',
  },
  {
    title: 'Light and dark keep changing',
    body: 'Theme is saved in this browser only. The header toggle and Desk on this page are the same control.',
  },
];

export const TUTORIAL_ITEMS = [
  {
    title: '1. Settings',
    body: 'Set team name, quote rates, after-hours window, and LBs or KGs. Save before you build the board.',
  },
  {
    title: '2. People',
    body: 'Owner or Admin taps New member, fills name plus email or phone, and sets dispatcher desk pages. Set weekly hours so Plan can show coverage.',
  },
  {
    title: '3. Accounts',
    body: 'On Books, Add account. Charge number is required. Optional pickup and delivery stops autofill the job form.',
  },
  {
    title: '4. Today',
    body: 'Create a job. Type the charge number or pick the account. Leave the driver blank until you know who is taking it.',
  },
  {
    title: '5. Plan',
    body: 'Use the month to see jobs, uncovered days, and hours. Add a job onto a date from the calendar.',
  },
  {
    title: '6. Review and Books',
    body: 'When jobs are delivered, Review is the register. Books builds one invoice per customer and one bill per driver. Download the week packet.',
  },
];

const SERVICE_FAQ = [
  {
    title: 'Does a visit need pickup and delivery?',
    body: 'No. A visit is one customer site. The technician’s miles come from GPS on the phone.',
  },
  {
    title: 'Where are invoices?',
    body: 'Books. One invoice per customer account for the selected period. Customer portal comes later.',
  },
  {
    title: 'Who can use the desk?',
    body: 'Owner, Admin, Office, then Technician. Technicians work on the phone. New member on People opens the invite card.',
  },
];

const SCHOOL_FAQ = [
  {
    title: 'What is a lesson?',
    body: 'One meet site with an instructor and a student. Status is Scheduled, In lesson, Done, No-show, or Cancelled.',
  },
  {
    title: 'Where are hours?',
    body: 'Review totals lesson hours from start and end time. GPS miles sit next to that. Permit hours on the phone are the student record.',
  },
  {
    title: 'Where are invoices?',
    body: 'Books. One invoice per student account for the selected period. Customer portal comes later.',
  },
];

const REIMBURSE_FAQ = [
  {
    title: 'Where do miles come from?',
    body: 'Employees classify trips and add receipts on the phone. This desk is the accountant view.',
  },
  {
    title: 'Where is the expense file?',
    body: 'Books. Download the period packet for QuickBooks.',
  },
];

const SERVICE_TUTORIAL = [
  { title: '1. Settings', body: 'Set team name, address, and default invoice terms.' },
  { title: '2. People', body: 'Add technicians and office staff. Set weekly hours so Plan can show coverage.' },
  { title: '3. Accounts', body: 'On Books, add customer accounts. Charge number is required.' },
  { title: '4. Today', body: 'Create a visit at one site. Leave the technician blank until you know who is taking it.' },
  { title: '5. Review and Books', body: 'Review is hours and miles. Books is invoices per account.' },
];

const SCHOOL_TUTORIAL = [
  { title: '1. Settings', body: 'Set school name, address, and default invoice terms.' },
  { title: '2. People', body: 'Add instructors. Set weekly hours so Plan can show coverage.' },
  { title: '3. Accounts', body: 'On Books, add student accounts. Charge number is required.' },
  { title: '4. Today', body: 'Create a lesson with a meet site and an instructor.' },
  { title: '5. Review and Books', body: 'Review is lesson hours. Books is invoices per student account.' },
];

const REIMBURSE_TUTORIAL = [
  { title: '1. Settings', body: 'Set company name and who is on the team.' },
  { title: '2. People', body: 'Invite employees. They log miles on the phone.' },
  { title: '3. Mileage and Books', body: 'Mileage is the register. Books is the expense file.' },
];

export function faqItems(mode) {
  const type = String(mode || '').toLowerCase();
  if (type === 'reimbursement') return REIMBURSE_FAQ;
  if (type === 'driving_school') return SCHOOL_FAQ;
  if (type === 'service') return SERVICE_FAQ;
  return FAQ_ITEMS;
}

export function tutorialItems(mode) {
  const type = String(mode || '').toLowerCase();
  if (type === 'reimbursement') return REIMBURSE_TUTORIAL;
  if (type === 'driving_school') return SCHOOL_TUTORIAL;
  if (type === 'service') return SERVICE_TUTORIAL;
  return TUTORIAL_ITEMS;
}

export function troubleItems(mode) {
  const type = String(mode || '').toLowerCase();
  if (type === 'courier' || type === 'fleet' || !type) return TROUBLE_ITEMS;
  return TROUBLE_ITEMS.filter((item) => item.title !== 'Assign nearest skipped a driver');
}

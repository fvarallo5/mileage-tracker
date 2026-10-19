import { isoDate } from './period.js';
import { jobPay, jobQuote, jobTake, jobTown } from './jobReport.js';
import { isDelivered } from './jobStatus.js';

const SUBCONTRACTORS = 'Subcontractors';

export function dueDate(endIso, terms) {
  const match = /net\s*(\d+)/i.exec(String(terms || ''));
  const days = match ? Number(match[1]) : 0;
  const date = new Date(`${String(endIso).slice(0, 10)}T12:00:00`);
  if (Number.isNaN(date.getTime())) return String(endIso).slice(0, 10);
  date.setDate(date.getDate() + days);
  return isoDate(date);
}

export function copyJobNumber(value) {
  const raw = String(value || '').trim() || 'Job';
  const match = /^(.*?)(?: copy(?: (\d+))?)$/.exec(raw);
  if (!match) return `${raw} copy`;
  const next = match[2] ? Number(match[2]) + 1 : 2;
  return `${match[1]} copy ${next}`;
}

function money(n) {
  return Math.round((Number(n) + Number.EPSILON) * 100) / 100;
}

function lineDescription(job) {
  const pickup = jobTown(job, 'pickup');
  const dropoff = jobTown(job, 'dropoff');
  if (!dropoff || dropoff === '—' || dropoff === pickup) {
    return `${job.job_number || 'Job'} ${pickup}`.trim();
  }
  return `${job.job_number || 'Job'} ${pickup} to ${dropoff}`.trim();
}

function chargeFor(job) {
  if (isDelivered(job.status)) return money(jobQuote(job));
  if (job.status === 'failed') {
    const fee = Number(job.attempt_fee);
    return Number.isFinite(fee) && fee > 0 ? money(fee) : 0;
  }
  return 0;
}

function payFor(job) {
  if (chargeFor(job) <= 0) return 0;
  if (isDelivered(job.status)) return money(jobPay(job));
  const pay = Number(job.driver_pay);
  return Number.isFinite(pay) ? money(pay) : 0;
}

function shortId(value) {
  return String(value || '').replace(/-/g, '').slice(0, 8) || 'na';
}

function pushDoc(map, key, doc) {
  const existing = map.get(key);
  if (!existing) {
    map.set(key, doc);
    return;
  }
  existing.lines.push(...doc.lines);
  existing.total = money(existing.total + doc.total);
}

export function buildWeekBooks({ jobs, customers, drivers, start, end }) {
  const customerById = new Map((customers || []).map((row) => [row.id, row]));
  const driverById = new Map((drivers || []).map((row) => [row.user_id, row]));
  const invoices = new Map();
  const bills = new Map();
  const blocked = [];
  const needsDriver = [];
  const cod = [];

  for (const job of jobs || []) {
    if (start && job.job_date < start) continue;
    if (end && job.job_date > end) continue;
    const charge = chargeFor(job);
    const pay = payFor(job);
    const codAmount = Number(job.cod_amount);
    if (Number.isFinite(codAmount) && codAmount > 0) {
      cod.push({
        type: 'COD',
        docNumber: '',
        party: customerById.get(job.customer_id)?.name || job.pickup_name || '',
        date: job.job_date,
        due: '',
        account: '',
        jobNumber: job.job_number || '',
        description: `${lineDescription(job)} · cash on delivery, not income`,
        amount: money(codAmount),
        taxCode: '',
        collected: job.cod_collected ? 'Yes' : '',
      });
    }
    if (charge <= 0 && pay <= 0) continue;

    const customer = customerById.get(job.customer_id);
    if (!customer) {
      blocked.push(job);
      continue;
    }
    if (!job.assigned_user_id) {
      needsDriver.push(job);
      continue;
    }
    const description = lineDescription(job);
    const invoiceNumber = `TT-${start}-${shortId(customer.id)}`;
    pushDoc(invoices, customer.id, {
      docType: 'invoice',
      docNumber: invoiceNumber,
      periodStart: start,
      periodEnd: end,
      partyKey: customer.id,
      partyName: customer.name,
      total: charge,
      lines: [{
        type: 'Invoice',
        docNumber: invoiceNumber,
        party: customer.name,
        date: end,
        due: dueDate(end, customer.terms),
        account: '',
        jobNumber: job.job_number || '',
        description,
        amount: charge,
        taxCode: '',
      }],
    });

    if (pay > 0 && job.assigned_user_id) {
      const driver = driverById.get(job.assigned_user_id);
      const partyName = driver?.driverNumber
        ? `${driver.driverNumber} - ${driver.label}`
        : (driver?.label || 'Driver');
      const billNumber = `TT-PAY-${start}-${shortId(job.assigned_user_id)}`;
      pushDoc(bills, job.assigned_user_id, {
        docType: 'bill',
        docNumber: billNumber,
        periodStart: start,
        periodEnd: end,
        partyKey: job.assigned_user_id,
        partyName,
        total: pay,
        lines: [{
          type: 'Bill',
          docNumber: billNumber,
          party: partyName,
          date: end,
          due: end,
          account: SUBCONTRACTORS,
          jobNumber: job.job_number || '',
          description,
          amount: pay,
          taxCode: '',
        }],
      });
    }
  }

  const invoiceDocs = [...invoices.values()];
  const billDocs = [...bills.values()];
  const invoiceTotal = money(invoiceDocs.reduce((sum, doc) => sum + doc.total, 0));
  const billTotal = money(billDocs.reduce((sum, doc) => sum + doc.total, 0));
  return {
    invoices: invoiceDocs,
    bills: billDocs,
    blocked,
    needsDriver,
    cod,
    invoiceTotal,
    billTotal,
    take: money(invoiceTotal - billTotal),
  };
}

export function accountBooksSummary({ customers, jobs, invoices, start, end }) {
  const billed = new Map((invoices || []).map((doc) => [doc.partyKey, money(doc.total)]));
  return (customers || [])
    .map((customer) => {
      let jobsCount = 0;
      for (const job of jobs || []) {
        if (job.customer_id !== customer.id) continue;
        const date = job.job_date || '';
        if (start && date < start) continue;
        if (end && date > end) continue;
        if (job.status === 'cancelled') continue;
        jobsCount += 1;
      }
      return {
        id: customer.id,
        name: customer.name || '',
        charge_number: String(customer.charge_number || '').replace(/\D/g, ''),
        jobs: jobsCount,
        invoiceTotal: billed.get(customer.id) || 0,
      };
    })
    .sort((a, b) => {
      if (a.charge_number && b.charge_number && a.charge_number !== b.charge_number) {
        return a.charge_number.localeCompare(b.charge_number, undefined, { numeric: true });
      }
      return a.name.localeCompare(b.name);
    });
}

export function closeGapMessage(pack) {
  const accounts = (pack?.blocked || []).length;
  const drivers = (pack?.needsDriver || []).length;
  const n = accounts + drivers;
  if (!n) return '';
  const jobs = n === 1 ? 'job' : 'jobs';
  const verb = n === 1 ? 'needs' : 'need';
  if (accounts && !drivers) {
    return `${accounts} delivered ${jobs} ${verb} an account before this week can close.`;
  }
  if (drivers && !accounts) {
    return `${drivers} delivered ${jobs} ${verb} a driver before this week can close.`;
  }
  return `${n} delivered jobs need an account or a driver before this week can close.`;
}

export const BOOKS_HEADERS = [
  'Type',
  'Doc number',
  'Party',
  'Date',
  'Due',
  'Account',
  'Job #',
  'Description',
  'Amount',
  'Tax code',
];

function csvLine(row) {
  return [
    row.type,
    row.docNumber,
    row.party,
    row.date,
    row.due,
    row.account,
    row.jobNumber,
    row.description,
    Number(row.amount).toFixed(2),
    row.taxCode,
  ];
}

export function booksCsvRows(pack) {
  const rows = [BOOKS_HEADERS];
  for (const doc of [...pack.invoices, ...pack.bills]) {
    for (const line of doc.lines) rows.push(csvLine(line));
  }
  for (const line of pack.cod) rows.push(csvLine(line));
  for (const job of pack.blocked) {
    rows.push([
      'Held',
      '',
      '',
      job.job_date || '',
      '',
      '',
      job.job_number || '',
      `${lineDescription(job)} · assign an account before this can be invoiced`,
      chargeFor(job).toFixed(2),
      '',
    ]);
  }
  for (const job of pack.needsDriver || []) {
    rows.push([
      'Held',
      '',
      '',
      job.job_date || '',
      '',
      '',
      job.job_number || '',
      `${lineDescription(job)} · assign a driver before this can be invoiced`,
      chargeFor(job).toFixed(2),
      '',
    ]);
  }
  const expenseOnly = pack.invoices.length === 0;
  rows.push([
    'Total',
    '',
    '',
    '',
    '',
    '',
    '',
    expenseOnly
      ? 'Expenses. Not a customer invoice.'
      : 'Invoices minus bills. Company take is not exported.',
    (expenseOnly ? pack.billTotal : pack.take).toFixed(2),
    '',
  ]);
  return rows;
}

const EXPENSE_ACCOUNT = {
  tolls: 'Tolls',
  parking: 'Parking',
  fuel: 'Fuel',
  gas: 'Fuel',
};

export function buildExpenseBooks({ expenses, drivers, start, end, mileageRate }) {
  const driverById = new Map((drivers || []).map((row) => [row.user_id, row]));
  const docs = new Map();
  for (const row of expenses || []) {
    const amount = Number(row.amount);
    if (!Number.isFinite(amount) || amount === 0) continue;
    const driver = driverById.get(row.user_id);
    const party = driver?.label || row.nickname || row.email || 'Employee';
    const key = row.user_id || party;
    const docNumber = `TT-EXP-${start}-${shortId(key)}`;
    const account = EXPENSE_ACCOUNT[row.category] || 'Field costs';
    const line = {
      type: 'Expense',
      docNumber,
      party,
      date: row.expense_date || end,
      due: end,
      account,
      jobNumber: '',
      description: [row.merchant, row.notes].filter(Boolean).join(' · ') || account,
      amount: money(amount),
      taxCode: '',
    };
    pushDoc(docs, key, {
      docType: 'bill',
      docNumber,
      periodStart: start,
      periodEnd: end,
      partyKey: key,
      partyName: party,
      total: line.amount,
      lines: [line],
    });
  }
  for (const driver of drivers || []) {
    const miles = Number(driver.businessMiles);
    const rate = Number(mileageRate);
    if (!Number.isFinite(miles) || miles <= 0 || !Number.isFinite(rate)) continue;
    const amount = money(miles * rate);
    const docNumber = `TT-EXP-${start}-${shortId(driver.user_id)}`;
    const line = {
      type: 'Expense',
      docNumber,
      party: driver.label,
      date: end,
      due: end,
      account: 'Mileage reimbursement',
      jobNumber: '',
      description: `${miles.toFixed(1)} mi`,
      amount,
      taxCode: '',
    };
    pushDoc(docs, driver.user_id, {
      docType: 'bill',
      docNumber,
      periodStart: start,
      periodEnd: end,
      partyKey: driver.user_id,
      partyName: driver.label,
      total: amount,
      lines: [line],
    });
  }
  const list = [...docs.values()];
  return {
    invoices: [],
    bills: list,
    blocked: [],
    needsDriver: [],
    cod: [],
    invoiceTotal: 0,
    billTotal: money(list.reduce((sum, doc) => sum + doc.total, 0)),
    take: 0,
  };
}

export function booksByDay({ jobs, start, end }) {
  const days = [];
  if (!start || !end) return days;
  const cursor = new Date(`${String(start).slice(0, 10)}T12:00:00`);
  const last = new Date(`${String(end).slice(0, 10)}T12:00:00`);
  if (Number.isNaN(cursor.getTime()) || Number.isNaN(last.getTime()) || cursor > last) return days;
  while (cursor <= last) {
    const iso = isoDate(cursor);
    let quoted = 0;
    let take = 0;
    let count = 0;
    for (const job of jobs || []) {
      if (job.job_date !== iso) continue;
      count += 1;
      quoted += jobQuote(job);
      take += jobTake(job);
    }
    if (count > 0 || quoted || take) {
      days.push({
        date: iso,
        jobs: count,
        quoted: money(quoted),
        take: money(take),
      });
    }
    cursor.setDate(cursor.getDate() + 1);
  }
  return days;
}

export function closeChecklist(books, { jobWord = 'job', worker = 'driver', includeCod = true } = {}) {
  const items = [];
  const noAccount = books?.blocked?.length || 0;
  const noDriver = books?.needsDriver?.length || 0;
  const codOpen = (books?.cod || []).filter((row) => row.collected !== 'Yes').length;
  const jobs = (n) => `${n} ${jobWord}${n === 1 ? '' : 's'}`;
  if (noAccount) items.push({ id: 'account', label: `${jobs(noAccount)} need an account` });
  if (noDriver) items.push({ id: 'driver', label: `${jobs(noDriver)} need a ${worker.toLowerCase()}` });
  if (includeCod && codOpen) items.push({ id: 'cod', label: `${codOpen} COD still to collect` });
  return items;
}

export function uncollectedCod(books) {
  return (books?.cod || []).filter((row) => row.collected !== 'Yes');
}

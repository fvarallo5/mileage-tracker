import { useEffect, useMemo, useState } from 'react';
import { useTeam } from '../../context/TeamContext.jsx';
import { EMPTY_ACCOUNT, accountLabel, formFromCustomer } from '../../lib/accountForm.js';
import { rememberLastCustomer } from '../../lib/accountMatch.js';
import { accountBooksSummary, booksByDay, booksCsvRows, buildExpenseBooks, buildWeekBooks, closeChecklist, uncollectedCod } from '../../lib/books.js';
import { deskSkin } from '../../lib/layout.js';
import { jobTown } from '../../lib/jobReport.js';
import { formatMdY, formatRangeMdY, PERIODS } from '../../lib/period.js';
import { orgApi } from '../../orgApi.js';
import AccountForm from './AccountForm.jsx';
import { downloadCsv, moneyFmt } from './format.js';
import Module from './Module.jsx';
import DeskTitle from './DeskTitle.jsx';
import PeriodRail, { PeriodMini } from './PeriodRail.jsx';

function PeriodPills({ period, setPeriod }) {
  return (
    <div className="period-pills" role="tablist" aria-label="Period">
      {PERIODS.map(([key, label]) => (
        <button
          key={key}
          type="button"
          className={period === key ? 'active' : ''}
          onClick={() => setPeriod(key)}
        >
          {label}
        </button>
      ))}
    </div>
  );
}

function Kpi({ label, value }) {
  return (
    <div className="kpi">
      <div className="label">{label}</div>
      <div className="kpi-value">{value}</div>
    </div>
  );
}

function moneyRows(docs) {
  return docs.map((doc) => (
    <tr key={doc.docNumber}>
      <td>{doc.partyName}</td>
      <td>{doc.docNumber}</td>
      <td>{doc.lines[0]?.due || doc.periodEnd}</td>
      <td className="num">{moneyFmt.format(doc.total)}</td>
    </tr>
  ));
}

export default function Books() {
  const team = useTeam();
  const skin = deskSkin(team.membership?.operatingMode);
  if (skin.booksKind === 'expense') {
    return <ExpenseBooks team={team} />;
  }
  return <FleetBooks team={team} skin={skin} />;
}

function AccountAssign({ job, customers, busy, onSave }) {
  const [customerId, setCustomerId] = useState('');
  return (
    <div className="books-assign">
      <select
        aria-label={`Account for ${job.job_number || 'job'}`}
        value={customerId}
        onChange={(e) => setCustomerId(e.target.value)}
      >
        <option value="">Account</option>
        {(customers || []).map((customer) => (
          <option key={customer.id} value={customer.id}>{accountLabel(customer)}</option>
        ))}
      </select>
      <button
        type="button"
        className="btn btn-secondary btn-sm"
        disabled={!customerId || busy}
        onClick={() => onSave(job, { customer_id: customerId })}
      >
        Save
      </button>
    </div>
  );
}

function DriverAssign({ job, drivers, busy, onSave, worker = 'Driver' }) {
  const [driverId, setDriverId] = useState('');
  return (
    <div className="books-assign">
      <select
        aria-label={`${worker} for ${job.job_number || 'job'}`}
        value={driverId}
        onChange={(e) => setDriverId(e.target.value)}
      >
        <option value="">{worker}</option>
        {(drivers || []).map((driver) => (
          <option key={driver.user_id} value={driver.user_id}>
            {driver.driverNumber ? `${driver.driverNumber} - ${driver.label}` : driver.label}
          </option>
        ))}
      </select>
      <button
        type="button"
        className="btn btn-secondary btn-sm"
        disabled={!driverId || busy}
        onClick={() => onSave(job, { assigned_user_id: driverId })}
      >
        Save
      </button>
    </div>
  );
}

function FleetBooks({ team, skin }) {
  const { period, setPeriod, range, jobs, customers, drivers, membership, setError, reload, busy } = team;
  const courierExtra = skin.showCourierBooksExtra;
  const jobWord = (skin.jobWord || 'Job').toLowerCase();
  const siteOnly = skin.id === 'service' || skin.id === 'driving_school';
  const [assigningId, setAssigningId] = useState(null);
  const [accountOpen, setAccountOpen] = useState(false);
  const [accountForm, setAccountForm] = useState(EMPTY_ACCOUNT);
  const [editingAccountId, setEditingAccountId] = useState(null);

  useEffect(() => {
    if (!accountOpen) return undefined;
    function onKey(e) {
      if (e.key === 'Escape') closeAccount();
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [accountOpen]);
  const books = useMemo(
    () => buildWeekBooks({
      jobs,
      customers,
      drivers,
      start: range.start,
      end: range.end,
    }),
    [jobs, customers, drivers, range.start, range.end],
  );
  const codTotal = books.cod.reduce((sum, row) => sum + Number(row.amount || 0), 0);
  const empty = books.invoices.length === 0
    && books.blocked.length === 0
    && books.needsDriver.length === 0
    && (courierExtra ? books.bills.length === 0 && books.cod.length === 0 : true);
  const byDay = useMemo(
    () => booksByDay({ jobs, start: range.start, end: range.end }),
    [jobs, range.start, range.end],
  );
  const accountRows = useMemo(
    () => accountBooksSummary({
      customers,
      jobs,
      invoices: books.invoices,
      start: range.start,
      end: range.end,
    }),
    [customers, jobs, books.invoices, range.start, range.end],
  );
  const checklist = closeChecklist(books, {
    jobWord,
    worker: skin.worker,
    includeCod: courierExtra,
  });
  const remit = courierExtra ? uncollectedCod(books) : [];
  const hasExtra = Boolean(
    books.invoices.length
    || books.blocked.length
    || books.needsDriver.length
    || (courierExtra && (books.bills.length || books.cod.length || remit.length)),
  );

  async function download() {
    const safe = range.label.replace(/\s+/g, '_');
    downloadCsv(`TrekTrack_Books_${safe}.csv`, booksCsvRows(books));
    try {
      await orgApi.saveBooks(membership.orgId, [...books.invoices, ...books.bills]);
    } catch (err) {
      setError(err.message);
    }
  }

  async function assignJob(job, patch) {
    setAssigningId(job.id);
    setError(null);
    try {
      await orgApi.updateJob(job.id, patch);
      if (patch.customer_id) rememberLastCustomer(membership.orgId, patch.customer_id);
      await reload();
    } catch (err) {
      setError(err.message);
    } finally {
      setAssigningId(null);
    }
  }

  function openAccount(customer) {
    setEditingAccountId(customer?.id || null);
    setAccountForm(formFromCustomer(customer || null, { terms: membership.defaultTerms }));
    setAccountOpen(true);
    setError(null);
  }

  function closeAccount() {
    setAccountOpen(false);
    setEditingAccountId(null);
    setAccountForm(EMPTY_ACCOUNT);
  }

  async function saveAccount(e) {
    e.preventDefault();
    setError(null);
    try {
      await orgApi.saveCustomer(membership.orgId, { ...accountForm, id: editingAccountId });
      closeAccount();
      await reload();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="desk-page">
    <DeskTitle
      title="Books"
      sub={`${range.label} · ${formatRangeMdY(range.start, range.end)}`}
      rail={(
        <PeriodRail
          period={period}
          setPeriod={setPeriod}
          range={range}
          mileageRate={team.mileageRate || 0.725}
          onExport={download}
          primaryLabel="Add account"
          onPrimary={() => { setAccountOpen(true); setAccountForm(EMPTY_ACCOUNT); setEditingAccountId(null); }}
        />
      )}
      mini={<PeriodMini period={period} onExport={download} />}
    />
    <div className="mgr-page books-page">
      <div className="page-toolbar">
        <div>
          <h1>Books</h1>
          <p className="page-sub">
            {range.label} · {formatRangeMdY(range.start, range.end)}.
            {courierExtra
              ? ' Week packet: one invoice per customer, one bill per driver. Company take stays on this screen.'
              : ' One invoice per customer account. Customer portal comes later.'}
          </p>
        </div>
        <div className="toolbar-actions">
          <PeriodPills period={period} setPeriod={setPeriod} />
          <button type="button" className="btn btn-primary btn-sm" onClick={download} disabled={empty}>
            {courierExtra ? 'Download week packet' : 'Download invoices'}
          </button>
        </div>
      </div>

      <Module className="books-totals" title="Totals">
        <div className="kpi-row kpi-4 desk-kpis">
          <Kpi label="Invoices" value={moneyFmt.format(books.invoiceTotal)} />
          {courierExtra ? (
            <>
              <Kpi label="Driver bills" value={moneyFmt.format(books.billTotal)} />
              <Kpi label="Company take" value={moneyFmt.format(books.take)} />
            </>
          ) : (
            <>
              <Kpi label={skin.boardNoun} value={String(accountRows.reduce((sum, row) => sum + row.jobs, 0))} />
              <Kpi label="Accounts" value={String(accountRows.length)} />
            </>
          )}
          <Kpi label="Held" value={String(books.blocked.length + books.needsDriver.length)} />
        </div>
      </Module>

      {checklist.length ? (
        <Module title="Close checklist">
          <div className="ex-list">
            {checklist.map((item) => (
              <div key={item.id} className="ex-row" style={{ cursor: 'default' }}>
                <span>{item.label}</span>
                <span className="muted-row">Assign below</span>
              </div>
            ))}
          </div>
        </Module>
      ) : null}

      <div className="books-split">
        <Module
          title="Customer Accounts"
          fill
          actions={
            <button type="button" className="btn btn-secondary btn-sm" onClick={() => openAccount()}>
              Add account
            </button>
          }
        >
          <table className="data-table compact books-acct-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Charge #</th>
                <th className="num">{skin.boardNoun}</th>
                <th className="num">Invoice total</th>
              </tr>
            </thead>
            <tbody>
              {accountRows.length === 0 ? (
                <tr>
                  <td colSpan={4} className="empty">No accounts yet.</td>
                </tr>
              ) : (
                accountRows.map((row) => (
                  <tr key={row.id} className="job-pick" onClick={() => openAccount(customers.find((c) => c.id === row.id))}>
                    <td>{row.name}</td>
                    <td>{row.charge_number || '—'}</td>
                    <td className="num">{row.jobs}</td>
                    <td className="num">{moneyFmt.format(row.invoiceTotal)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </Module>
        <Module title="By day" fill>
          <table className="data-table compact">
            <thead>
              <tr>
                <th>Date</th>
                <th className="num">{skin.boardNoun}</th>
                <th className="num">{courierExtra ? 'Quoted' : 'Billed'}</th>
                {courierExtra ? <th className="num">Take</th> : null}
              </tr>
            </thead>
            <tbody>
              {byDay.length === 0 ? (
                <tr>
                  <td colSpan={courierExtra ? 4 : 3} className="empty">No {skin.boardNoun.toLowerCase()} in this period.</td>
                </tr>
              ) : (
                byDay.map((row) => (
                  <tr key={row.date}>
                    <td>{formatMdY(row.date)}</td>
                    <td className="num">{row.jobs}</td>
                    <td className="num">{moneyFmt.format(row.quoted)}</td>
                    {courierExtra ? <td className="num">{moneyFmt.format(row.take)}</td> : null}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </Module>
      </div>
      {hasExtra ? (
      <div className="books-extra">
        {books.invoices.length ? (
          <Module title="Invoices">
            <table className="data-table compact">
              <thead>
                <tr>
                  <th>Customer</th>
                  <th>Number</th>
                  <th>Due</th>
                  <th className="num">Amount</th>
                </tr>
              </thead>
              <tbody>{moneyRows(books.invoices)}</tbody>
            </table>
          </Module>
        ) : null}
        {courierExtra && books.bills.length ? (
          <Module title="Driver bills">
            <table className="data-table compact">
              <thead>
                <tr>
                  <th>Driver</th>
                  <th>Number</th>
                  <th>Due</th>
                  <th className="num">Amount</th>
                </tr>
              </thead>
              <tbody>{moneyRows(books.bills)}</tbody>
            </table>
          </Module>
        ) : null}
          {books.blocked.length ? (
            <Module title="Held">
              <p className="field-hint">These {skin.boardNoun.toLowerCase()} need a customer account before they can be invoiced.</p>
              <table className="data-table compact">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>{skin.jobWord} #</th>
                    <th>{skin.siteTitle}</th>
                    {siteOnly ? null : <th>Drop-off</th>}
                    <th>Account</th>
                  </tr>
                </thead>
                <tbody>
                  {books.blocked.map((job) => (
                    <tr key={job.id}>
                      <td>{job.job_date}</td>
                      <td>{job.job_number}</td>
                      <td>{jobTown(job, 'pickup')}</td>
                      {siteOnly ? null : <td>{jobTown(job, 'dropoff')}</td>}
                      <td>
                        <AccountAssign
                          job={job}
                          customers={customers}
                          busy={assigningId === job.id}
                          onSave={assignJob}
                        />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Module>
          ) : null}
          {books.needsDriver.length ? (
            <Module title={`No ${skin.worker.toLowerCase()}`}>
              <p className="field-hint">Assign a {skin.worker.toLowerCase()} on Today before these can be invoiced.</p>
              <table className="data-table compact">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>{skin.jobWord} #</th>
                    <th>{skin.siteTitle}</th>
                    {siteOnly ? null : <th>Drop-off</th>}
                    <th>{skin.worker}</th>
                  </tr>
                </thead>
                <tbody>
                  {books.needsDriver.map((job) => (
                    <tr key={job.id}>
                      <td>{job.job_date}</td>
                      <td>{job.job_number}</td>
                      <td>{jobTown(job, 'pickup')}</td>
                      {siteOnly ? null : <td>{jobTown(job, 'dropoff')}</td>}
                      <td>
                        <DriverAssign
                          job={job}
                          drivers={drivers}
                          busy={assigningId === job.id}
                          onSave={assignJob}
                          worker={skin.worker}
                        />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Module>
          ) : null}
          {courierExtra && books.cod.length ? (
            <Module title="Cash on delivery">
              <p className="field-hint">{moneyFmt.format(codTotal)} collected for the customer. This is not income.</p>
              <table className="data-table compact">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Job #</th>
                    <th>Customer</th>
                    <th>Collected</th>
                    <th className="num">Amount</th>
                  </tr>
                </thead>
                <tbody>
                  {books.cod.map((row) => (
                    <tr key={`${row.jobNumber}-${row.date}`}>
                      <td>{row.date}</td>
                      <td>{row.jobNumber}</td>
                      <td>{row.party}</td>
                      <td>{row.collected || 'No'}</td>
                      <td className="num">{moneyFmt.format(row.amount)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Module>
          ) : null}
          {books.invoices.length ? (
            <Module title="Top accounts">
              <table className="data-table compact">
                <thead>
                  <tr>
                    <th>Customer</th>
                    <th className="num">{skin.boardNoun}</th>
                    <th className="num">Invoiced</th>
                  </tr>
                </thead>
                <tbody>
                  {[...books.invoices]
                    .sort((a, b) => b.total - a.total)
                    .map((doc) => (
                      <tr key={doc.docNumber}>
                        <td>{doc.partyName}</td>
                        <td className="num">{doc.lines.length}</td>
                        <td className="num">{moneyFmt.format(doc.total)}</td>
                      </tr>
                    ))}
                </tbody>
              </table>
            </Module>
          ) : null}
          {courierExtra && remit.length ? (
            <Module title="COD to remit">
              <p className="field-hint">Cash still marked uncollected. This is not income.</p>
              <table className="data-table compact">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Job #</th>
                    <th>Customer</th>
                    <th className="num">Amount</th>
                  </tr>
                </thead>
                <tbody>
                  {remit.map((row) => (
                    <tr key={`${row.jobNumber}-${row.date}`}>
                      <td>{row.date}</td>
                      <td>{row.jobNumber}</td>
                      <td>{row.party}</td>
                      <td className="num">{moneyFmt.format(row.amount)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Module>
          ) : null}
      </div>
      ) : null}
      {accountOpen ? (
        <div className="plan-modal-wrap">
          <button type="button" className="plan-modal-scrim" aria-label="Close account form" onClick={closeAccount} />
          <div className="plan-modal account-modal" role="dialog" aria-modal="true" aria-labelledby="books-account-title">
            <div className="drawer-head">
              <h2 id="books-account-title">{editingAccountId ? 'Edit account' : 'Add account'}</h2>
              <button type="button" className="btn-ghost btn-sm" onClick={closeAccount}>Close</button>
            </div>
            <AccountForm
              form={accountForm}
              set={(key, value) => setAccountForm((prev) => ({ ...prev, [key]: value }))}
              idPrefix="books-acct"
              busy={busy}
              editingId={editingAccountId}
              onSubmit={saveAccount}
              onClose={closeAccount}
            />
          </div>
        </div>
      ) : null}
    </div>
    </div>
  );
}

function ExpenseBooks({ team }) {
  const { period, setPeriod, range, expenses, drivers, mileageRate } = team;
  const pack = useMemo(
    () => buildExpenseBooks({
      expenses,
      drivers,
      start: range.start,
      end: range.end,
      mileageRate,
    }),
    [expenses, drivers, range.start, range.end, mileageRate],
  );
  const lines = pack.bills.flatMap((doc) => doc.lines);

  function download() {
    const safe = range.label.replace(/\s+/g, '_');
    downloadCsv(`TrekTrack_Expenses_${safe}.csv`, booksCsvRows(pack));
  }

  return (
    <div className="desk-page">
    <DeskTitle
      title="Books"
      sub={`${range.label} · ${formatRangeMdY(range.start, range.end)}`}
      rail={(
        <PeriodRail
          period={period}
          setPeriod={setPeriod}
          range={range}
          mileageRate={mileageRate || 0.725}
          onExport={download}
        />
      )}
      mini={<PeriodMini period={period} onExport={download} />}
    />
    <div className="mgr-page books-page">
      <div className="page-toolbar">
        <div>
          <h1>Books</h1>
          <p className="page-sub">
            {range.label} · {formatRangeMdY(range.start, range.end)}. Mileage and receipts. This is not a customer invoice.
          </p>
        </div>
        <div className="toolbar-actions">
          <PeriodPills period={period} setPeriod={setPeriod} />
          <button type="button" className="btn btn-primary btn-sm" onClick={download} disabled={!lines.length}>
            QuickBooks file
          </button>
        </div>
      </div>
      <Module title="Totals">
        <div className="kpi-row desk-kpis">
          <Kpi label="Expenses" value={moneyFmt.format(pack.billTotal)} />
          <Kpi label="Lines" value={String(lines.length)} />
        </div>
      </Module>
      <Module title="Packet" fill>
        {lines.length === 0 ? (
          <p className="empty">No mileage or receipts in this period.</p>
        ) : (
          <table className="data-table compact">
            <thead>
              <tr>
                <th>Employee</th>
                <th>Account</th>
                <th>Description</th>
                <th className="num">Amount</th>
              </tr>
            </thead>
            <tbody>
              {lines.map((line, index) => (
                <tr key={`${line.docNumber}-${line.account}-${index}`}>
                  <td>{line.party}</td>
                  <td>{line.account}</td>
                  <td>{line.description}</td>
                  <td className="num">{moneyFmt.format(line.amount)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Module>
    </div>
    </div>
  );
}

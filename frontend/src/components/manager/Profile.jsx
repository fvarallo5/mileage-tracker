import { useEffect, useState } from 'react';
import { supabase } from '../../supabase.js';
import { useTeam } from '../../context/TeamContext.jsx';
import { ACCOUNT_TERMS } from '../../lib/accountForm.js';
import { composeAddress, US_STATES } from '../../lib/address.js';
import { CLOSE_POLICIES, cleanJobPrefix, identityFromOrg, isCourierMode, jobStyleForMode, ORG_MODES, orgModeLabel, normalizeOperatingMode, payTypeForMode, US_TIMEZONES } from '../../lib/company.js';
import { faqItems, SUPPORT_EMAIL, troubleItems, tutorialItems } from '../../lib/deskHelp.js';
import { deskSkin } from '../../lib/layout.js';
import { DEFAULT_QUOTE_RATES } from '../../lib/quote.js';
import { formatTime12 } from '../../lib/planMonth.js';
import { splitName } from './format.js';
import FactList from './FactList.jsx';
import HelpList from './HelpList.jsx';
import ThemeToggle from './ThemeToggle.jsx';
import Module from './Module.jsx';
import TimeSelect from './TimeSelect.jsx';
import DeskTitle from './DeskTitle.jsx';

function emptyCompany(membership) {
  const ident = identityFromOrg(membership || {});
  return {
    name: membership?.name || '',
    phone: ident.phone,
    dispatchEmail: ident.dispatchEmail,
    addressLine1: ident.addressLine1,
    addressCity: ident.addressCity,
    addressState: ident.addressState,
    addressZip: ident.addressZip,
    timezone: ident.timezone,
    jobPrefix: ident.jobPrefix,
    officeClosesJobs: ident.officeClosesJobs,
    useCod: ident.useCod,
  };
}

function emptyRates(rates) {
  const r = { ...DEFAULT_QUOTE_RATES, ...rates };
  return {
    quotePerMile: String(r.quotePerMile),
    quoteMinimum: String(r.quoteMinimum),
    weekendMult: String(r.weekendMult),
    afterHoursMult: String(r.afterHoursMult),
    afterHoursStart: r.afterHoursStart,
    afterHoursEnd: r.afterHoursEnd,
    companyTakePct: String(Math.round(Number(r.companyTakePct) * 100)),
  };
}

function emptyAccount(profile) {
  const split = splitName(profile?.nickname);
  return {
    first_name: profile?.first_name || split.first,
    last_name: profile?.last_name || split.last,
    address: profile?.address ?? '',
    phone: profile?.phone ?? '',
    vehicle_year: profile?.vehicle_year ? String(profile.vehicle_year) : '',
    vehicle_make: profile?.vehicle_make ?? '',
    vehicle_model: profile?.vehicle_model ?? '',
    vehicle_color: profile?.vehicle_color ?? '',
  };
}

function AccountFields({ form, set, email, showVehicle }) {
  return (
    <>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor="profile-first">First name</label>
          <input
            id="profile-first"
            value={form.first_name}
            onChange={(e) => set('first_name', e.target.value)}
            required
            maxLength={40}
            autoComplete="given-name"
          />
        </div>
        <div className="form-group">
          <label htmlFor="profile-last">Last name</label>
          <input
            id="profile-last"
            value={form.last_name}
            onChange={(e) => set('last_name', e.target.value)}
            required
            maxLength={40}
            autoComplete="family-name"
          />
        </div>
      </div>
      <div className="form-group">
        <label htmlFor="profile-phone">Phone</label>
        <input
          id="profile-phone"
          type="tel"
          value={form.phone}
          onChange={(e) => set('phone', e.target.value)}
          autoComplete="tel"
        />
      </div>
      <div className="form-group">
        <label htmlFor="profile-email">Email</label>
        <input id="profile-email" type="email" value={email} readOnly />
        <p className="field-hint">Sign-in email for this account. Same login as the phone app.</p>
      </div>
      <div className="form-group">
        <label htmlFor="profile-address">Address</label>
        <input
          id="profile-address"
          value={form.address}
          onChange={(e) => set('address', e.target.value)}
          autoComplete="street-address"
        />
      </div>
      {showVehicle ? (
        <>
          <p className="field-hint">Vehicle, if you drive.</p>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="profile-year">Year</label>
              <input id="profile-year" inputMode="numeric" value={form.vehicle_year} onChange={(e) => set('vehicle_year', e.target.value)} />
            </div>
            <div className="form-group">
              <label htmlFor="profile-color">Color</label>
              <input id="profile-color" value={form.vehicle_color} onChange={(e) => set('vehicle_color', e.target.value)} />
            </div>
          </div>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="profile-make">Make</label>
              <input id="profile-make" value={form.vehicle_make} onChange={(e) => set('vehicle_make', e.target.value)} />
            </div>
            <div className="form-group">
              <label htmlFor="profile-model">Model</label>
              <input id="profile-model" value={form.vehicle_model} onChange={(e) => set('vehicle_model', e.target.value)} />
            </div>
          </div>
        </>
      ) : null}
    </>
  );
}

function AccountSummary({ form, email, showVehicle }) {
  const name = [form.first_name, form.last_name].filter(Boolean).join(' ');
  const vehicle = [form.vehicle_year, form.vehicle_color, form.vehicle_make, form.vehicle_model]
    .filter(Boolean)
    .join(' ');
  const rows = [
    { label: 'Name', value: name },
    { label: 'Phone', value: form.phone },
    { label: 'Email', value: email },
    { label: 'Address', value: form.address },
  ];
  if (showVehicle) rows.push({ label: 'Vehicle', value: vehicle });
  return <FactList rows={rows} />;
}

function CompanySummary({ company, mode }) {
  const address = composeAddress({
    line1: company.addressLine1,
    city: company.addressCity,
    state: company.addressState,
    zip: company.addressZip,
  });
  const zone = US_TIMEZONES.find((row) => row.id === company.timezone)?.label || company.timezone;
  return (
    <FactList
      rows={[
        { label: 'Team', value: company.name },
        { label: 'Desk phone', value: company.phone },
        { label: 'Dispatch email', value: company.dispatchEmail },
        { label: 'Address', value: address },
        { label: 'Time zone', value: zone },
        { label: 'Job prefix', value: company.jobPrefix },
        { label: 'Type', value: orgModeLabel(mode) },
      ]}
    />
  );
}

function QuoteSummary({ rates, weightUnit, company }) {
  const closeLabel = CLOSE_POLICIES.find((opt) => opt.id === (company.officeClosesJobs ? 'office' : 'drivers'))?.label;
  const from = formatTime12(rates.afterHoursStart);
  const to = formatTime12(rates.afterHoursEnd);
  return (
    <FactList
      rows={[
        { label: 'Charge / mile', value: rates.quotePerMile === '' ? '' : `$${rates.quotePerMile}` },
        { label: 'Minimum', value: rates.quoteMinimum === '' ? '' : `$${rates.quoteMinimum}` },
        { label: 'Company take', value: rates.companyTakePct === '' ? '' : `${rates.companyTakePct}%` },
        { label: 'Weekend', value: rates.weekendMult === '' ? '' : `${rates.weekendMult}×` },
        { label: 'After hours', value: [rates.afterHoursMult && `${rates.afterHoursMult}×`, from && to && `${from}–${to}`].filter(Boolean).join(' ') },
        { label: 'Weight', value: weightUnit === 'kg' ? 'KGs' : 'LBs' },
        { label: 'COD', value: company.useCod ? 'Yes' : 'No' },
        { label: 'Closes', value: closeLabel },
      ]}
    />
  );
}

function QuoteFields({ rates, setRate, weightUnit, setWeightUnit, company, setCompanyField }) {
  return (
    <>
      <p className="field-hint">
        Quote is max(minimum, miles × rate), then weekend and after-hours. Driver pay is quote minus take.
      </p>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor="quote-per-mile">Charge / mile</label>
          <input id="quote-per-mile" inputMode="decimal" value={rates.quotePerMile} onChange={(e) => setRate('quotePerMile', e.target.value)} />
        </div>
        <div className="form-group">
          <label htmlFor="quote-min">Minimum fare</label>
          <input id="quote-min" inputMode="decimal" value={rates.quoteMinimum} onChange={(e) => setRate('quoteMinimum', e.target.value)} />
        </div>
        <div className="form-group">
          <label htmlFor="quote-take">Company take %</label>
          <input id="quote-take" inputMode="decimal" value={rates.companyTakePct} onChange={(e) => setRate('companyTakePct', e.target.value)} />
        </div>
      </div>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor="quote-weekend">Weekend ×</label>
          <input id="quote-weekend" inputMode="decimal" value={rates.weekendMult} onChange={(e) => setRate('weekendMult', e.target.value)} />
        </div>
        <div className="form-group">
          <label htmlFor="quote-after">After hours ×</label>
          <input id="quote-after" inputMode="decimal" value={rates.afterHoursMult} onChange={(e) => setRate('afterHoursMult', e.target.value)} />
        </div>
        <div className="form-group">
          <label htmlFor="quote-after-start">After hours from</label>
          <TimeSelect
            id="quote-after-start"
            value={rates.afterHoursStart}
            onChange={(value) => setRate('afterHoursStart', value)}
          />
        </div>
        <div className="form-group">
          <label htmlFor="quote-after-end">After hours to</label>
          <TimeSelect
            id="quote-after-end"
            value={rates.afterHoursEnd}
            onChange={(value) => setRate('afterHoursEnd', value)}
          />
        </div>
      </div>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor="quote-weight">Weight unit</label>
          <select id="quote-weight" value={weightUnit} onChange={(e) => setWeightUnit(e.target.value)}>
            <option value="lb">LBs</option>
            <option value="kg">KGs</option>
          </select>
        </div>
        <div className="form-group">
          <label htmlFor="quote-cod">COD</label>
          <select
            id="quote-cod"
            value={company.useCod ? 'yes' : 'no'}
            onChange={(e) => setCompanyField('useCod', e.target.value === 'yes')}
          >
            <option value="no">No</option>
            <option value="yes">Yes</option>
          </select>
        </div>
      </div>
      <div className="form-group">
        <label htmlFor="close-policy">Who closes jobs</label>
        <select
          id="close-policy"
          value={company.officeClosesJobs ? 'office' : 'drivers'}
          onChange={(e) => setCompanyField('officeClosesJobs', e.target.value === 'office')}
        >
          {CLOSE_POLICIES.map((opt) => (
            <option key={opt.id} value={opt.id}>{opt.label}</option>
          ))}
        </select>
        <p className="field-hint">
          {company.officeClosesJobs
            ? 'Drivers mark picked up. Dispatch marks delivered here.'
            : 'Driver marks delivered on the phone.'}
        </p>
      </div>
    </>
  );
}

function CompanyFields({ company, setCompanyField, mode, setMode }) {
  return (
    <>
      <div className="form-group">
        <label htmlFor="org-name">Team name</label>
        <input
          id="org-name"
          value={company.name}
          onChange={(e) => setCompanyField('name', e.target.value)}
          required
          maxLength={80}
        />
      </div>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor="org-phone">Desk phone</label>
          <input
            id="org-phone"
            type="tel"
            value={company.phone}
            onChange={(e) => setCompanyField('phone', e.target.value)}
            autoComplete="tel"
          />
        </div>
        <div className="form-group">
          <label htmlFor="org-email">Dispatch email</label>
          <input
            id="org-email"
            type="email"
            value={company.dispatchEmail}
            onChange={(e) => setCompanyField('dispatchEmail', e.target.value)}
            autoComplete="email"
          />
        </div>
      </div>
      <div className="form-group">
        <label htmlFor="org-line1">Address</label>
        <input
          id="org-line1"
          value={company.addressLine1}
          onChange={(e) => setCompanyField('addressLine1', e.target.value)}
          autoComplete="street-address"
        />
      </div>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor="org-city">City</label>
          <input
            id="org-city"
            value={company.addressCity}
            onChange={(e) => setCompanyField('addressCity', e.target.value)}
            autoComplete="address-level2"
          />
        </div>
        <div className="form-group">
          <label htmlFor="org-state">State</label>
          <select
            id="org-state"
            value={company.addressState}
            onChange={(e) => setCompanyField('addressState', e.target.value)}
          >
            <option value="">—</option>
            {US_STATES.map((code) => (
              <option key={code} value={code}>{code}</option>
            ))}
          </select>
        </div>
        <div className="form-group">
          <label htmlFor="org-zip">ZIP</label>
          <input
            id="org-zip"
            value={company.addressZip}
            onChange={(e) => setCompanyField('addressZip', e.target.value)}
            autoComplete="postal-code"
          />
        </div>
      </div>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor="org-tz">Time zone</label>
          <select
            id="org-tz"
            value={company.timezone}
            onChange={(e) => setCompanyField('timezone', e.target.value)}
          >
            {US_TIMEZONES.map((row) => (
              <option key={row.id} value={row.id}>{row.label}</option>
            ))}
          </select>
        </div>
        <div className="form-group">
          <label htmlFor="org-prefix">Job prefix</label>
          <input
            id="org-prefix"
            value={company.jobPrefix}
            onChange={(e) => setCompanyField('jobPrefix', cleanJobPrefix(e.target.value))}
            placeholder="GT-"
            maxLength={12}
          />
        </div>
      </div>
      <p className="field-hint">Name and phone show on the public tracking page. Prefix fills a new job number.</p>
      <ModePicker value={mode} onChange={setMode} />
    </>
  );
}

function ModePicker({ value, onChange, id = 'org-mode' }) {
  const hint = ORG_MODES.find((opt) => opt.id === value)?.hint;
  return (
    <div className="form-group">
      <label htmlFor={id}>Type of company</label>
      <select id={id} value={value} onChange={(e) => onChange(e.target.value)}>
        {ORG_MODES.map((opt) => (
          <option key={opt.id} value={opt.id}>{opt.label}</option>
        ))}
      </select>
      {hint ? <p className="field-hint">{hint}</p> : null}
    </div>
  );
}

export default function Profile() {
  const team = useTeam();
  const [form, setForm] = useState(() => emptyAccount(team.ownProfile));
  const [mode, setMode] = useState(normalizeOperatingMode(team.membership?.operatingMode));
  const [rates, setRates] = useState(() => emptyRates(team.quoteRates));
  const [weightUnit, setWeightUnit] = useState(team.weightUnit === 'kg' ? 'kg' : 'lb');
  const [company, setCompany] = useState(() => emptyCompany(team.membership));
  const [defaultTerms, setDefaultTerms] = useState(team.defaultTerms || 'Net 30');
  const [editAccount, setEditAccount] = useState(false);
  const [editCompany, setEditCompany] = useState(false);
  const [editQuotes, setEditQuotes] = useState(false);
  const email = team.ownProfile?.email || '';

  useEffect(() => {
    setForm(emptyAccount(team.ownProfile));
  }, [team.ownProfile]);

  useEffect(() => {
    setMode(normalizeOperatingMode(team.membership?.operatingMode));
  }, [team.membership?.operatingMode]);

  useEffect(() => {
    setRates(emptyRates(team.quoteRates));
  }, [team.quoteRates]);

  useEffect(() => {
    setWeightUnit(team.weightUnit === 'kg' ? 'kg' : 'lb');
  }, [team.weightUnit]);

  useEffect(() => {
    setCompany(emptyCompany(team.membership));
  }, [team.membership]);

  useEffect(() => {
    setDefaultTerms(team.defaultTerms || 'Net 30');
  }, [team.defaultTerms]);

  function set(key, value) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  function setRate(key, value) {
    setRates((prev) => ({ ...prev, [key]: value }));
  }

  function setCompanyField(key, value) {
    setCompany((prev) => ({ ...prev, [key]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    try {
      await team.saveProfile(form);
      if (team.membership?.isManager) {
        await team.updateOrgIdentity({
          ...company,
          defaultTerms,
        });
        await team.updateOrgClosePolicy(company.officeClosesJobs);
        await team.updateOrgCodPolicy(company.useCod);
      }
      if (team.membership?.isManager && isCourierMode(mode)) {
        const take = Number(rates.companyTakePct);
        await team.updateQuoteRates({
          quotePerMile: Number(rates.quotePerMile),
          quoteMinimum: Number(rates.quoteMinimum),
          weekendMult: Number(rates.weekendMult),
          afterHoursMult: Number(rates.afterHoursMult),
          afterHoursStart: rates.afterHoursStart,
          afterHoursEnd: rates.afterHoursEnd,
          companyTakePct: Number.isFinite(take) ? take / 100 : 0.3,
        });
        await team.updateWeightUnit(weightUnit);
      }
      if (team.membership?.isManager) {
        const saved = team.membership.savedOperatingMode || team.membership.operatingMode;
        if (mode !== saved) {
          await team.updateOrgOperatingMode(mode);
        } else {
          team.setDeskPreview(null);
        }
      }
      setEditAccount(false);
      setEditCompany(false);
      setEditQuotes(false);
    } catch {
      /* error banner via TeamContext */
    }
  }

  function cancelAccount() {
    setForm(emptyAccount(team.ownProfile));
    setEditAccount(false);
  }

  function cancelCompany() {
    setCompany(emptyCompany(team.membership));
    setMode(normalizeOperatingMode(team.membership?.operatingMode));
    setEditCompany(false);
  }

  function cancelQuotes() {
    const ident = identityFromOrg(team.membership || {});
    setRates(emptyRates(team.quoteRates));
    setWeightUnit(team.weightUnit === 'kg' ? 'kg' : 'lb');
    setCompany((prev) => ({
      ...prev,
      useCod: ident.useCod,
      officeClosesJobs: ident.officeClosesJobs,
    }));
    setEditQuotes(false);
  }

  const fleet = isCourierMode(mode);
  const skin = deskSkin(mode);
  const sampleTrack = typeof window !== 'undefined' ? `${window.location.origin}/?track=` : '/?track=';

  async function copyTrackSample() {
    try {
      await navigator.clipboard.writeText(sampleTrack);
    } catch {
      /* ignore */
    }
  }

  return (
    <div className="desk-page">
    <DeskTitle title="Settings" sub="Account, company, and job quotes." />
    <div className="mgr-page profile-page">
      <div className="page-toolbar">
        <h1>Settings</h1>
        <div className="toolbar-actions">
          <button type="submit" form="settings-form" className="btn btn-primary" disabled={team.busy}>
            {team.busy ? 'Saving…' : 'Save'}
          </button>
        </div>
      </div>
      <form id="settings-form" onSubmit={handleSubmit} className="settings-mods">
        <Module
          className={editAccount ? 'is-editing' : ''}
          title="Your account"
          actions={(
            <button
              type="button"
              className="btn-ghost btn-sm settings-edit"
              onClick={() => (editAccount ? cancelAccount() : setEditAccount(true))}
            >
              {editAccount ? 'Cancel' : 'Edit'}
            </button>
          )}
        >
          {editAccount ? (
            <AccountFields form={form} set={set} email={email} showVehicle={fleet} />
          ) : (
            <AccountSummary form={form} email={email} showVehicle={fleet} />
          )}
        </Module>
          {team.membership?.isManager ? (
            <>
              <Module
                className={editCompany ? 'is-editing' : ''}
                title="Company"
                actions={(
                  <button
                    type="button"
                    className="btn-ghost btn-sm settings-edit"
                    onClick={() => (editCompany ? cancelCompany() : setEditCompany(true))}
                  >
                    {editCompany ? 'Cancel' : 'Edit'}
                  </button>
                )}
              >
                {editCompany ? (
                  <CompanyFields
                    company={company}
                    setCompanyField={setCompanyField}
                    mode={mode}
                    setMode={setMode}
                  />
                ) : (
                  <CompanySummary company={company} mode={mode} />
                )}
              </Module>
              {skin.showJobQuotesSettings ? (
                <Module
                  className={editQuotes ? 'is-editing' : ''}
                  title="Job quotes"
                  actions={(
                    <button
                      type="button"
                      className="btn-ghost btn-sm settings-edit"
                      onClick={() => (editQuotes ? cancelQuotes() : setEditQuotes(true))}
                    >
                      {editQuotes ? 'Cancel' : 'Edit'}
                    </button>
                  )}
                >
                  {editQuotes ? (
                    <QuoteFields
                      rates={rates}
                      setRate={setRate}
                      weightUnit={weightUnit}
                      setWeightUnit={setWeightUnit}
                      company={company}
                      setCompanyField={setCompanyField}
                    />
                  ) : (
                    <QuoteSummary rates={rates} weightUnit={weightUnit} company={company} />
                  )}
                </Module>
              ) : (
                <Module title={skin.booksKind === 'expense' ? 'Mileage' : 'Invoices'}>
                  {skin.booksKind === 'expense' ? (
                    <p className="field-hint">Employees log miles and receipts on the phone. Books is the expense file for the selected period.</p>
                  ) : (
                    <>
                      <div className="form-group">
                        <label htmlFor="default-terms">Default terms</label>
                        <select id="default-terms" value={defaultTerms} onChange={(e) => setDefaultTerms(e.target.value)}>
                          {(ACCOUNT_TERMS.includes(defaultTerms) ? ACCOUNT_TERMS : [defaultTerms, ...ACCOUNT_TERMS]).map((row) => (
                            <option key={row} value={row}>{row}</option>
                          ))}
                        </select>
                      </div>
                      <p className="field-hint">New accounts copy these terms. Invoice schedules live on Books.</p>
                    </>
                  )}
                </Module>
              )}
            </>
          ) : null}
              <Module className="help-mod" title="FAQ">
                <HelpList items={faqItems(mode)} />
              </Module>
              <Module className="help-mod" title="Troubleshooting">
                <HelpList
                  items={troubleItems(mode)}
                  footer={`Need more help? ${SUPPORT_EMAIL}`}
                />
              </Module>
              <Module className="help-mod" title="Tutorial">
                <HelpList items={tutorialItems(mode)} />
              </Module>
              {team.membership?.isManager && fleet ? (
                <Module className="settings-foot" title="Tracking">
                  <p className="field-hint">
                    Each job gets a public link. The shipper sees status and the map while the job is picked up. Pay stays off that page.
                  </p>
                  <p className="field-hint"><code>{sampleTrack}</code></p>
                  <button type="button" className="btn btn-secondary settings-copy" onClick={copyTrackSample}>
                    Copy sample path
                  </button>
                </Module>
              ) : null}
              {team.membership?.isManager && fleet ? (
                <Module className="settings-foot" title="Close defaults">
                  <div className="form-group">
                    <label htmlFor="default-terms">Default terms</label>
                    <select id="default-terms" value={defaultTerms} onChange={(e) => setDefaultTerms(e.target.value)}>
                      {(ACCOUNT_TERMS.includes(defaultTerms) ? ACCOUNT_TERMS : [defaultTerms, ...ACCOUNT_TERMS]).map((row) => (
                        <option key={row} value={row}>{row}</option>
                      ))}
                    </select>
                  </div>
                  <p className="field-hint">New accounts copy these terms. COD is cash for the shipper, not income.</p>
                  <p className="field-hint">A delivered job without an account is Held until you assign one on Books or People.</p>
                </Module>
              ) : null}
        <Module className="settings-foot" title="Desk">
          <p className="field-hint">Light or dark for this browser. Same control as the header.</p>
          <ThemeToggle />
        </Module>
      </form>
    </div>
    </div>
  );
}

export function ProfileSetup({ onDone, onSignOut, includeMode = false, initialMode = 'courier' }) {
  const team = useTeam();
  const [form, setForm] = useState(() => emptyAccount(team.ownProfile));
  const [mode, setMode] = useState(normalizeOperatingMode(initialMode));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    setForm(emptyAccount(team.ownProfile));
  }, [team.ownProfile]);

  function set(key, value) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await team.saveProfile(form);
      const answers = {
        operatingMode: normalizeOperatingMode(mode),
        companyKind: mode === 'courier' ? 'delivery' : 'other',
        jobStyle: jobStyleForMode(mode),
        defaultPayType: payTypeForMode(mode),
      };
      if (includeMode && supabase) {
        const { error: metaErr } = await supabase.auth.updateUser({
          data: {
            operating_mode: answers.operatingMode,
            company_kind: answers.companyKind,
            job_style: answers.jobStyle,
            default_pay_type: answers.defaultPayType,
          },
        });
        if (metaErr) throw metaErr;
      }
      onDone?.(answers);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  const inner = (
    <>
      <h1>{includeMode ? 'Set up your account' : 'Your profile'}</h1>
      <p className="page-sub">
        {includeMode
          ? 'Name and company type for this dispatcher account.'
          : 'Name and phone so the team can reach you.'}
      </p>
      {error ? <div className="error-banner">{error}</div> : null}
      <form onSubmit={handleSubmit}>
        <AccountFields form={form} set={set} email={team.ownProfile?.email || ''} showVehicle={false} />
        {includeMode ? <ModePicker value={mode} onChange={setMode} id="setup-org-mode" /> : null}
        <button type="submit" className="btn btn-primary" disabled={busy}>
          {busy ? 'Saving…' : 'Continue'}
        </button>
      </form>
    </>
  );

  if (!onSignOut) {
    return <div className="gate"><div className="gate-card">{inner}</div></div>;
  }

  return (
    <div className="gate">
      <header className="mgr-brand gate-brand">
        <img src="/icon-192.png" alt="" width="40" height="40" />
        <strong>TrekTrack</strong>
        <ThemeToggle />
        <button type="button" className="btn-ghost btn-sm" onClick={onSignOut}>
          Sign out
        </button>
      </header>
      <div className="gate-card">{inner}</div>
    </div>
  );
}

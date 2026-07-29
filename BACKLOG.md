# TrekTrack backlog

Living list of product work. Order is guidance, not a hard commitment.

## Now / near-term (launch path)

- [ ] DUNS approved → Apple / Google **organization** accounts
- [ ] **Live IAP** — monthly + yearly + 7-day trial (store products match `billing_config.dart`)
- [ ] Store listings — screenshots, subtitle, privacy/terms URLs, support `info@trektrack.pro`
- [ ] Android **home widget** smoke test / polish on device
- [x] Tax disclaimer on export + Pro paywall + PrivacyInfo / Android FGS compliance pass

## Later (post-IAP)

- [ ] iOS home **Widget Extension** (Xcode target + App Group)
- [ ] **Receipt / expense saver (MVP)** for reimbursement  
  - Manual expense log: amount, date, category, note  
  - Optional photo attachment (no OCR required for MVP)  
  - Optional link to a trip  
  - Supabase table + Storage; wipe on account delete  
  - CSV/PDF-style export for boss/CPA  
  - Privacy/Terms update when photos are stored  
  - *Not* bank sync or full Everlance-style suite
- [ ] Receipt **OCR** (suggest amount/date/merchant; user always confirms) — after MVP expenses
- [ ] CarPlay / Android Auto (drive-mode start/stop + live miles) — differentiator, large native effort

## Parked / rethink later

- [ ] Places / geofencing (removed for now; only revisit with a clear Home-only design)
- [ ] Full web dashboard (desk tax review only after mobile Pro is live)
- [ ] Multi-language
- [ ] Teams / admin / ELD
- [ ] Ads

## Done (high level)

- Core tracking, auto-detect free limit, Pro funnel UI
- Work hours, car Bluetooth, charging gate, vehicle motion gates
- Tax package export, reports, multi-platform CSV import guides
- Your data (export / clear trips / delete account)
- Terms + Privacy (UltraForge LLC, NJ) + acceptance gate + server logs
- Site: trektrack.pro

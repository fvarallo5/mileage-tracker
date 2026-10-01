# TrekTrack team dashboard

Vite + React app for fleet managers. Phone still logs trips; this UI is roster, unclassified trips, and CSV export.

## Run locally

```bash
cp .env.example .env   # if you add one
# VITE_SUPABASE_URL=...
# VITE_SUPABASE_ANON_KEY=...
npm install
npm run dev
```

## Host at app.trektrack.pro

1. Apply `supabase/migrations/019_org_dashboard.sql` and `020_org_field_costs.sql` on the live project.
2. Deploy this folder (Cloudflare Pages or similar) with the two Vite env vars.
3. Add `https://app.trektrack.pro` to Supabase Auth redirect URLs.
4. Invite links are `https://app.trektrack.pro/?invite=<token>` (mobile also accepts `com.ultraforge.trektrack://invite?token=`).

# Evter

Evter is a calmer, shared place to plan a bachelor or bachelorette party. It replaces the fragmented mix of group texts, spreadsheets, polls, and payment reminders with a single party workspace.

## What works today

- Supabase email/password sign-up and sign-in.
- Google OAuth entry point, ready to configure later in Supabase.
- A responsive, seed-rich San Diego → Las Vegas party dashboard for 12 people.
- Interactive date/destination voting, activity RSVP, supply claiming, and role-aware planning navigation.
- A production-minded Postgres schema with RLS in `supabase/migrations/`.

The demo route is deliberately self-contained so a reviewer can explore it without any external API dependency. Flight, activity, dining, and payment integrations are intentionally deferred behind the app's data model.

## Local setup

```bash
npm install
cp .env.example .env.local
npm run dev
```

Set the two values from your Supabase project’s **API Keys** settings:

```bash
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Apply `supabase/migrations/20261008170000_initial_schema.sql` in the Supabase SQL Editor before wiring the seeded experience to live data.

## Verification

```bash
npm run lint
npx next build --webpack
```

The default Turbopack build is not reliable in this sandbox because its CSS worker cannot bind a local port; the Webpack production build passes.

## Google OAuth later

Create a Google OAuth client, add its client ID and secret in Supabase Authentication → Providers → Google, and add the deployed URL to Supabase Authentication → URL Configuration.

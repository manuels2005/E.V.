-- ============================================================
--  E.V. STATUS TRACKER — Supabase setup for account-based sync
--  Run this in your Supabase dashboard: SQL Editor → New query → Run.
--  Safe to run on an existing ev_tracker table; it only adds policies.
-- ============================================================

-- 1. Table (skip if you already have it).
create table if not exists public.ev_tracker (
  sync_code  text primary key,
  state      jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now()
);

-- 2. Turn on row level security. Until policies exist below, this
--    blocks ALL access — which is the point: nothing is readable by default.
alter table public.ev_tracker enable row level security;

-- 3. Drop old policies so this script can be re-run safely.
drop policy if exists ev_own_select on public.ev_tracker;
drop policy if exists ev_own_insert on public.ev_tracker;
drop policy if exists ev_own_update on public.ev_tracker;
drop policy if exists ev_own_delete on public.ev_tracker;

-- 4. A signed-in user may touch exactly one row: the one whose key
--    equals their own user id. The database enforces this, so it holds
--    even though the anon key is public in the browser.
create policy ev_own_select on public.ev_tracker
  for select to authenticated using (sync_code = auth.uid()::text);

create policy ev_own_insert on public.ev_tracker
  for insert to authenticated with check (sync_code = auth.uid()::text);

create policy ev_own_update on public.ev_tracker
  for update to authenticated
  using (sync_code = auth.uid()::text)
  with check (sync_code = auth.uid()::text);

create policy ev_own_delete on public.ev_tracker
  for delete to authenticated using (sync_code = auth.uid()::text);

-- ------------------------------------------------------------
--  IMPORTANT — read before running
--
--  These policies grant access to AUTHENTICATED users only. The moment
--  you run this, signed-out sync-code mode stops working, because the
--  anonymous role has no policy at all. That is deliberate: sync codes
--  are a shared password sitting in plain text, and anyone who guesses
--  yours can read and overwrite everything.
--
--  So the order matters:
--    1. Create your account in the app first (IDENTITY tab → CREATE ACCOUNT).
--    2. Confirm the email Supabase sends you.
--    3. Sign in, and let it push your existing data up under your user id.
--    4. THEN run this script to lock the table down.
--
--  If you run it before signing in, your existing sync-code row becomes
--  unreadable — the data is still there, but you'd need to re-open access
--  or copy it across from a device that still has it in local storage.
--
--  Also: enable Email auth under Authentication → Providers in the
--  dashboard, or CREATE ACCOUNT will fail.
-- ------------------------------------------------------------

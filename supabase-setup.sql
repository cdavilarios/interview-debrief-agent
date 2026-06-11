-- ============================================================
--  Interview Debrief — Supabase schema
--  Run this once in the Supabase dashboard → SQL Editor → New query.
-- ============================================================

-- 1. PROFILES ------------------------------------------------
--    One row per auth user. Holds the Anthropic API key.
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  api_key    text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

create policy "profiles_select_own"
  on public.profiles for select using (auth.uid() = id);
create policy "profiles_insert_own"
  on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update_own"
  on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- 2. AUTO-CREATE PROFILE ON SIGNUP ---------------------------
--    A trigger guarantees every new auth user gets a profile row,
--    even if email confirmation is enabled (no client session yet).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3. SESSIONS ------------------------------------------------
--    One row per interview debrief.
create table if not exists public.sessions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  company    text,
  role       text,
  round      text,
  date       text,
  jd         text,
  transcript text,
  results    jsonb,
  created_at timestamptz not null default now()
);

alter table public.sessions enable row level security;

drop policy if exists "sessions_select_own" on public.sessions;
drop policy if exists "sessions_insert_own" on public.sessions;
drop policy if exists "sessions_update_own" on public.sessions;
drop policy if exists "sessions_delete_own" on public.sessions;

create policy "sessions_select_own"
  on public.sessions for select using (auth.uid() = user_id);
create policy "sessions_insert_own"
  on public.sessions for insert with check (auth.uid() = user_id);
create policy "sessions_update_own"
  on public.sessions for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "sessions_delete_own"
  on public.sessions for delete using (auth.uid() = user_id);

create index if not exists sessions_user_id_idx on public.sessions(user_id);

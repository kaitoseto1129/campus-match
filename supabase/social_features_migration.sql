-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。

alter table public.likes
    add column if not exists reminded_at timestamptz;

alter table public.profiles
    add column if not exists private_mode boolean not null default false;

create or replace function public.purchase_likes_mock()
returns integer
language sql
security definer
set search_path = public
as $$
  update public.profiles
  set remaining_likes = remaining_likes + 100
  where id = auth.uid()
  returning remaining_likes;
$$;
grant execute on function public.purchase_likes_mock() to authenticated;

create table if not exists public.profile_visits (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default now(),
    viewer_id uuid not null references auth.users(id),
    visited_id uuid not null references auth.users(id)
);
create index if not exists profile_visits_visited_id_created_at_idx
    on public.profile_visits (visited_id, created_at desc);

alter table public.profile_visits enable row level security;

drop policy if exists "Visited users can read their footprints" on public.profile_visits;
create policy "Visited users can read their footprints"
on public.profile_visits
for select
to authenticated
using (visited_id = auth.uid());

drop policy if exists "Users can record their own visits" on public.profile_visits;
create policy "Users can record their own visits"
on public.profile_visits
for insert
to authenticated
with check (viewer_id = auth.uid());

create table if not exists public.user_actions (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default now(),
    actor_id uuid not null references auth.users(id),
    target_id uuid not null references auth.users(id),
    action text not null check (action in ('hide', 'block')),
    unique (actor_id, target_id, action)
);
alter table public.user_actions enable row level security;

drop policy if exists "Users can manage their own actions" on public.user_actions;
create policy "Users can manage their own actions"
on public.user_actions
for all
to authenticated
using (actor_id = auth.uid())
with check (actor_id = auth.uid());

create table if not exists public.reports (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default now(),
    reporter_id uuid not null references auth.users(id),
    reported_id uuid not null references auth.users(id),
    reason text
);
alter table public.reports enable row level security;

drop policy if exists "Users can create and read their own reports" on public.reports;
create policy "Users can create and read their own reports"
on public.reports
for all
to authenticated
using (reporter_id = auth.uid())
with check (reporter_id = auth.uid());

create table if not exists public.hidden_matches (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default now(),
    user_id uuid not null references auth.users(id),
    match_id uuid not null references public.matches(id),
    unique (user_id, match_id)
);
alter table public.hidden_matches enable row level security;

drop policy if exists "Users can manage their own hidden matches" on public.hidden_matches;
create policy "Users can manage their own hidden matches"
on public.hidden_matches
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

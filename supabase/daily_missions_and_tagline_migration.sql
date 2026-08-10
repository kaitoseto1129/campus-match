-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。

alter table public.profiles add column if not exists tagline text;
alter table public.profiles alter column remaining_likes set default 50;
alter table public.likes add column if not exists is_special boolean not null default false;

create table if not exists public.mission_claims (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default now(),
    user_id uuid not null references auth.users(id),
    mission_key text not null,
    claim_date date not null,
    unique (user_id, mission_key, claim_date)
);
alter table public.mission_claims enable row level security;

drop policy if exists "Users can manage their own mission claims" on public.mission_claims;
create policy "Users can manage their own mission claims"
on public.mission_claims
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- ミッション達成報酬付与。同じミッション・同じ日に二重付与できないようunique制約で保護。
create or replace function public.claim_daily_mission(mission text, reward integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  new_count integer;
begin
  insert into public.mission_claims (user_id, mission_key, claim_date)
  values (auth.uid(), mission, current_date);

  update public.profiles
  set remaining_likes = remaining_likes + reward
  where id = auth.uid()
  returning remaining_likes into new_count;

  return new_count;
end;
$$;
grant execute on function public.claim_daily_mission(text, integer) to authenticated;

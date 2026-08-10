-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- 電話ボタンを押しても直接発信せず、相手に「通話リクエスト」を送り、
-- 相手が承諾した場合のみ次に進める仕組み(安全のための同意フロー)。

create table public.call_requests (
    id uuid primary key default gen_random_uuid(),
    match_id uuid not null references public.matches(id),
    requester_id uuid not null references auth.users(id),
    status text not null default 'pending' check (status in ('pending','accepted','declined','canceled')),
    created_at timestamptz not null default now(),
    responded_at timestamptz
);

alter table public.call_requests enable row level security;

create policy "Match participants can read call requests"
on public.call_requests for select to authenticated
using (
  exists (
    select 1 from public.matches m
    where m.id = call_requests.match_id
      and (m.user_a_id = (select auth.uid()) or m.user_b_id = (select auth.uid()))
  )
);

create policy "Requester can create call requests"
on public.call_requests for insert to authenticated
with check (
  requester_id = (select auth.uid())
  and exists (
    select 1 from public.matches m
    where m.id = call_requests.match_id
      and (m.user_a_id = (select auth.uid()) or m.user_b_id = (select auth.uid()))
  )
);

create policy "Match participants can update call requests"
on public.call_requests for update to authenticated
using (
  exists (
    select 1 from public.matches m
    where m.id = call_requests.match_id
      and (m.user_a_id = (select auth.uid()) or m.user_b_id = (select auth.uid()))
  )
)
with check (
  exists (
    select 1 from public.matches m
    where m.id = call_requests.match_id
      and (m.user_a_id = (select auth.uid()) or m.user_b_id = (select auth.uid()))
  )
);

create index idx_call_requests_match_id on public.call_requests (match_id);
create index idx_call_requests_requester_id on public.call_requests (requester_id);

alter publication supabase_realtime add table public.call_requests;

-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- 「ありがとう」でマッチが成立したペアを表す。1ペアにつき1行。
-- user_a_id < user_b_id を強制することで、どちらが先にいいねしたかに関わらず
-- ペアごとに1行だけになるようにしている(UUIDの通常の文字列表現での比較順)。

create table if not exists public.matches (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default now(),
    like_id uuid references public.likes(id),
    user_a_id uuid not null references auth.users(id),
    user_b_id uuid not null references auth.users(id),
    constraint matches_user_order check (user_a_id < user_b_id),
    unique (user_a_id, user_b_id)
);

alter table public.matches enable row level security;

drop policy if exists "Users can read own matches" on public.matches;
create policy "Users can read own matches"
on public.matches
for select
to authenticated
using (user_a_id = auth.uid() or user_b_id = auth.uid());

drop policy if exists "Users can create matches they are part of" on public.matches;
create policy "Users can create matches they are part of"
on public.matches
for insert
to authenticated
with check (user_a_id = auth.uid() or user_b_id = auth.uid());

-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- チャット機能はまだアプリ側に実装していないが、近いうちに作る前提で
-- スキーマだけ先に用意しておく(matches の実装に合わせて追加)。

create table if not exists public.messages (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default now(),
    match_id uuid not null references public.matches(id),
    sender_id uuid not null references auth.users(id),
    body text not null
);

alter table public.messages enable row level security;

drop policy if exists "Match participants can read messages" on public.messages;
create policy "Match participants can read messages"
on public.messages
for select
to authenticated
using (
    exists (
        select 1 from public.matches m
        where m.id = messages.match_id
          and (m.user_a_id = auth.uid() or m.user_b_id = auth.uid())
    )
);

drop policy if exists "Match participants can send messages" on public.messages;
create policy "Match participants can send messages"
on public.messages
for insert
to authenticated
with check (
    sender_id = auth.uid()
    and exists (
        select 1 from public.matches m
        where m.id = messages.match_id
          and (m.user_a_id = auth.uid() or m.user_b_id = auth.uid())
    )
);

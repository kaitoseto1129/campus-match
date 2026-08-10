-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- likes は「誰が誰にいいねしたか」だけを表すイミュータブルなログ。
-- マッチ状態は別途 matches テーブル(matches_policies.sql)で管理する。

create table if not exists public.likes (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default now(),
    from_user_id uuid not null references auth.users(id),
    to_user_id uuid not null references auth.users(id),
    unique (from_user_id, to_user_id)
);

-- 旧バージョン(matches テーブルを作る前)で追加していた列を後片付け。
alter table public.likes drop column if exists matched_at;

alter table public.likes enable row level security;

drop policy if exists "Users can read own likes" on public.likes;
create policy "Users can read own likes"
on public.likes
for select
to authenticated
using (from_user_id = auth.uid() or to_user_id = auth.uid());

drop policy if exists "Users can send likes" on public.likes;
create policy "Users can send likes"
on public.likes
for insert
to authenticated
with check (from_user_id = auth.uid() and from_user_id <> to_user_id);

-- マッチ状態は likes を更新せず matches テーブルへの挿入で表すため、
-- likes に対する update ポリシーはもう不要。
drop policy if exists "Receiver can mark match" on public.likes;

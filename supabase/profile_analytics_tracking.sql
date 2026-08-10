-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。
-- マイページの「プロフィール分析」機能のためのトラッキング列。
-- どの写真が見られたか(photo_ids_viewed)、閲覧者がどのセクションまでスクロールしたか(reached_section)を
-- 訪問レコード(profile_visits)に追記していく。

alter table public.profile_visits
    add column if not exists photo_ids_viewed uuid[] not null default '{}',
    add column if not exists reached_section text;

-- 閲覧者(viewer_id = auth.uid())が自分のvisitレコードを更新できるようにする。
drop policy if exists "Viewers can update their own visit records" on public.profile_visits;
create policy "Viewers can update their own visit records"
on public.profile_visits
for update
to authenticated
using (viewer_id = auth.uid())
with check (viewer_id = auth.uid());

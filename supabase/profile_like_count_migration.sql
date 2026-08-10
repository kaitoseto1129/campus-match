-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。
-- 他ユーザーのプロフィールで「受け取ったいいね数」を表示するための仕組み。
-- likes テーブルは自分が当事者の行しかSELECTできないRLSのため、
-- 個々のいいね行を晒さずに件数だけを返すSECURITY DEFINER関数を用意する。

alter table public.profiles
    add column if not exists show_like_count boolean not null default true;

create or replace function public.get_like_count(target_user_id uuid)
returns integer
language sql
security definer
set search_path = public
as $$
  select count(*)::integer from public.likes where to_user_id = target_user_id;
$$;

grant execute on function public.get_like_count(uuid) to authenticated;

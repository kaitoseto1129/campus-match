-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。

alter table public.profiles
    add column if not exists remaining_likes integer not null default 100;

-- last_active_at から5分以内ならオンライン扱い。個々のタイムスタンプを晒さず真偽値だけ返す。
create or replace function public.is_user_online(target_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select now() - last_active_at < interval '5 minutes' from public.profiles where id = target_user_id),
    false
  );
$$;

grant execute on function public.is_user_online(uuid) to authenticated;

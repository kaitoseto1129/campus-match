-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。
-- オンライン状態の表示/非表示設定。show_online_statusがfalseの相手にはis_user_onlineがNULLを返し、
-- クライアント側ではその場合オンライン/オフライン表示自体を出さない。
alter table public.profiles
    add column if not exists show_online_status boolean not null default true;

create or replace function public.is_user_online(target_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  show_status boolean;
  last_active timestamptz;
begin
  select show_online_status, last_active_at into show_status, last_active
  from public.profiles where id = target_user_id;
  if show_status is null or not show_status then
    return null;
  end if;
  return last_active > now() - interval '5 minutes';
end;
$$;

grant execute on function public.is_user_online(uuid) to authenticated;

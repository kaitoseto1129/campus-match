-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。

-- ブースト(アピール)機能: 10いいねで1時間、探す画面の最上部に表示される。
alter table public.profiles
    add column if not exists boost_expires_at timestamptz;

create or replace function public.activate_boost()
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  current_likes integer;
  new_expiry timestamptz;
begin
  select remaining_likes into current_likes from public.profiles where id = auth.uid();
  if current_likes is null or current_likes < 10 then
    raise exception 'not enough likes';
  end if;
  new_expiry := now() + interval '1 hour';
  update public.profiles
  set remaining_likes = remaining_likes - 10,
      boost_expires_at = new_expiry
  where id = auth.uid();
  return new_expiry;
end;
$$;

grant execute on function public.activate_boost() to authenticated;

-- 足あとの既読管理(マイページタブのバッジ表示用)。
alter table public.profiles
    add column if not exists footprints_last_viewed_at timestamptz not null default '1970-01-01';

create or replace function public.get_new_footprints_count()
returns integer
language sql
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.profile_visits pv
  join public.profiles p on p.id = auth.uid()
  where pv.visited_id = auth.uid()
    and pv.created_at > p.footprints_last_viewed_at
    and pv.viewer_id <> auth.uid();
$$;

grant execute on function public.get_new_footprints_count() to authenticated;

create or replace function public.mark_footprints_viewed()
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles set footprints_last_viewed_at = now() where id = auth.uid();
$$;

grant execute on function public.mark_footprints_viewed() to authenticated;

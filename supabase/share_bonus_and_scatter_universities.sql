-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。

-- アプリ紹介(共有)で1回だけ10いいねを付与するための列とRPC。
alter table public.profiles
    add column if not exists share_bonus_claimed boolean not null default false;

create or replace function public.claim_share_bonus()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  already boolean;
  result integer;
begin
  select share_bonus_claimed into already from public.profiles where id = auth.uid();
  if already is null then
    raise exception 'profile not found';
  end if;
  if not already then
    update public.profiles
    set remaining_likes = remaining_likes + 10,
        share_bonus_claimed = true
    where id = auth.uid()
    returning remaining_likes into result;
  else
    select remaining_likes into result from public.profiles where id = auth.uid();
  end if;
  return result;
end;
$$;

grant execute on function public.claim_share_bonus() to authenticated;

-- ダミー40人の大学をインターカレッジ風にランダムへ再割り当て(md5(id||p.id)でp.idと相関させ、
-- 行ごとに違う結果になるようにする -- lateral(order by random())だけだとプランナに
-- 一度だけ評価されてしまうケースがあったため)。
update public.profiles p
set university_id = (
  select id from public.universities
  order by md5(id::text || p.id::text)
  limit 1
)
from auth.users u
where u.id = p.id and u.email like 'cmu.dummy%';

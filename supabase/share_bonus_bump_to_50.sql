-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際にはMCP経由で適用済み)。
-- アプリ紹介ボーナスを10いいね→50いいねに増額。
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
    set remaining_likes = remaining_likes + 50,
        share_bonus_claimed = true
    where id = auth.uid()
    returning remaining_likes into result;
  else
    select remaining_likes into result from public.profiles where id = auth.uid();
  end if;
  return result;
end;
$$;

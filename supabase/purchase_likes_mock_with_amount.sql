-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際にはMCP経由で適用済み)。
-- いいね購入をワンタップ固定(100円=100いいね)から、複数の金額プランを選べるようにするための変更。
-- 既存のpurchase_likes_mock()(引数なし)は後方互換のため残しつつ、金額プラン対応版を追加する。

create or replace function public.purchase_likes_mock(p_amount integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_remaining integer;
begin
  if p_amount not in (10, 50, 100) then
    raise exception 'invalid purchase amount';
  end if;

  update public.profiles
  set remaining_likes = remaining_likes + p_amount
  where id = auth.uid()
  returning remaining_likes into v_new_remaining;

  return v_new_remaining;
end;
$$;

grant execute on function public.purchase_likes_mock(integer) to authenticated;
revoke execute on function public.purchase_likes_mock(integer) from anon;

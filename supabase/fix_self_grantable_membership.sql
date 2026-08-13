-- Supabase Dashboard > SQL Editor で一度だけ実行してください
-- (このリポジトリでは MCP 経由で適用済み)。
--
-- 【重要な脆弱性の修正】
-- 課金をStoreKit + サーバー側検証(verify-purchase)に移行した際、
-- モック時代に作った purchase_membership(p_tier text) が authenticated/anon から
-- 実行可能なまま残っていた。この関数は任意のプランを自分に設定でき、
-- さらに無料→有料への切り替え時に30いいねまで付与するため、
-- ログインさえしていれば誰でも「課金せずにVIP会員 + 30いいね」を取得できる状態だった。
--
-- 特典の付与はすべて grant_purchased_* (service_role限定、Edge Functionからのみ)に
-- 一本化されているので、この関数は削除する。
--
-- ただしクライアントには「サブスクが失効しているのにサーバーが有料会員のままなら
-- 自分を無料会員に戻す」という正当な用途があるため、
-- 降格しかできない専用の関数を用意して置き換える。

drop function if exists purchase_membership(text);

-- 自分自身を無料会員に戻すことしかできない関数。
-- 有料プランへの昇格はできないため、悪用しても損をするだけになる。
create or replace function downgrade_own_membership_to_free()
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'ログインが必要です';
  end if;

  update public.profiles
  set membership_tier = 'free',
      -- プライベートモードはVIP限定機能のため、無料に戻す際は解除する。
      private_mode = false
  where id = v_uid;
end;
$$;

revoke all on function downgrade_own_membership_to_free() from public, anon;
grant execute on function downgrade_own_membership_to_free() to authenticated;

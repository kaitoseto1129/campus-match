-- Supabase Dashboard > SQL Editor で一度だけ実行してください
-- (このリポジトリでは MCP 経由で適用済み)。
--
-- App Store Server Notifications V2 を受け取って、サブスクリプションの
-- 更新・解約・失効・返金をサーバー側で会員ステータスに反映できるようにする。
--
-- Appleからの通知には「どのSupabaseユーザーか」という情報が入っておらず、
-- 代わりにoriginalTransactionId(そのサブスクリプション契約を通して不変のID)が入っている。
-- そのため購入検証時にoriginalTransactionIdを保存しておき、通知受信時にそこからユーザーを引く。

alter table public.redeemed_transactions
    add column if not exists original_transaction_id text;

create index if not exists redeemed_transactions_original_transaction_id_idx
    on public.redeemed_transactions (original_transaction_id);

-- originalTransactionIdから、その契約を購入したユーザーを引く。
-- 同じoriginalTransactionIdで複数行(毎月の更新など)ある場合は最初の購入者を採用する。
create or replace function user_id_for_original_transaction(p_original_transaction_id text)
returns uuid
language sql
security definer
set search_path to 'public'
as $$
  select user_id
  from public.redeemed_transactions
  where original_transaction_id = p_original_transaction_id
  order by redeemed_at asc
  limit 1;
$$;

revoke all on function user_id_for_original_transaction(text) from public, anon, authenticated;

-- 解約・失効・返金時に会員ステータスを無料へ戻す。
-- VIP限定のプライベートモードもあわせて解除する(purchase_membershipと同じ扱い)。
create or replace function revoke_purchased_membership(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  update public.profiles
  set membership_tier = 'free',
      private_mode = false
  where id = p_user_id;
end;
$$;

revoke all on function revoke_purchased_membership(uuid) from public, anon, authenticated;

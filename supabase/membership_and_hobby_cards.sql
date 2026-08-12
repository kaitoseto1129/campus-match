-- Supabase Dashboard > SQL Editor で一度だけ実行してください
-- (このリポジトリでは MCP 経由で適用済み)。
--
-- 1) 会員ステータス(無料会員 / 有料会員 / VIPオプション)
--    1ユーザーは必ずこの3つのいずれか1つに属する。上位ほど下位の特典を含む。
--      free    … プロフィール閲覧・いいね送信のみ。マッチ後もメッセージは送れず、いいね数も見えない
--      premium … メッセージし放題 + いいね数表示 + 契約時に30いいね付与
--      vip     … premiumの全特典 + プライベートモード + トークの既読表示 + お相手とのマッチ度表示
-- 2) 趣味カード(複数選択)

alter table public.profiles
    add column if not exists membership_tier text not null default 'free';

alter table public.profiles
    drop constraint if exists profiles_membership_tier_check;
alter table public.profiles
    add constraint profiles_membership_tier_check
    check (membership_tier in ('free', 'premium', 'vip'));

alter table public.profiles
    add column if not exists hobby_cards text[] not null default '{}';

-- 会員ステータスの購入(モック)。実際の課金は入れず、契約状態の切り替えのみ行う。
-- 有料プランへの「新規」アップグレード時だけ30いいねを付与する
-- (同じプランを買い直したり、上位から下位へ戻した時には付与しない)。
create or replace function purchase_membership(p_tier text)
returns public.profiles
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
  v_current text;
  v_row public.profiles;
begin
  if v_uid is null then
    raise exception 'ログインが必要です';
  end if;
  if p_tier not in ('free', 'premium', 'vip') then
    raise exception '不明なプランです: %', p_tier;
  end if;

  select membership_tier into v_current from public.profiles where id = v_uid;

  update public.profiles
  set membership_tier = p_tier,
      remaining_likes = remaining_likes
        + case when p_tier in ('premium', 'vip') and coalesce(v_current, 'free') = 'free'
               then 30 else 0 end,
      -- 無料に戻した場合、VIP限定のプライベートモードは維持できないため解除する。
      private_mode = case when p_tier = 'vip' then private_mode else false end
  where id = v_uid
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function purchase_membership(text) from public;
grant execute on function purchase_membership(text) to authenticated;

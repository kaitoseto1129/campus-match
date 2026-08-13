-- App Store側での本物の購入検証(Edge Function)を経由しない限り、いいね/有料会員を
-- 付与できないようにする。これまでのpurchase_likes_mock/purchase_membershipは
-- authenticatedロールから直接叩けてしまい、実際の決済なしに特典を得られる抜け穴だった。

-- 1) リプレイ防止用: 同じApple取引IDを二度使えないようにする。
create table if not exists public.redeemed_transactions (
  transaction_id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id text not null,
  redeemed_at timestamptz not null default now()
);
alter table public.redeemed_transactions enable row level security;
create policy "Users can view their own redeemed transactions"
  on public.redeemed_transactions for select
  using (auth.uid() = user_id);
-- insertはEdge FunctionのService Roleからのみ行う(RLSはservice_roleには適用されないため、
-- authenticated/anon向けのinsertポリシーはあえて作らない = クライアントからは書き込めない)。

-- 2) 実購入検証後の特典付与専用関数。Edge Function(service_role)からのみ呼べる。
create or replace function public.grant_purchased_likes(p_user_id uuid, p_amount integer)
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
  where id = p_user_id
  returning remaining_likes into v_new_remaining;

  return v_new_remaining;
end;
$$;
revoke all on function public.grant_purchased_likes(uuid, integer) from public, anon, authenticated;
grant execute on function public.grant_purchased_likes(uuid, integer) to service_role;

create or replace function public.grant_purchased_membership(p_user_id uuid, p_tier text)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current text;
  v_row public.profiles;
begin
  if p_tier not in ('premium', 'vip') then
    raise exception '不明なプランです: %', p_tier;
  end if;

  select membership_tier into v_current from public.profiles where id = p_user_id;

  update public.profiles
  set membership_tier = p_tier,
      remaining_likes = remaining_likes
        + case when coalesce(v_current, 'free') = 'free' then 30 else 0 end
  where id = p_user_id
  returning * into v_row;

  return v_row;
end;
$$;
revoke all on function public.grant_purchased_membership(uuid, text) from public, anon, authenticated;
grant execute on function public.grant_purchased_membership(uuid, text) to service_role;

-- 3) 旧関数はクライアントから直接呼べないようにする。
--    purchase_membershipは「無料会員に戻す」の自己申告だけ引き続き許可し、
--    有料プランへの直接付与はできないようにする(有料化はgrant_purchased_membership経由のみ)。
drop function if exists public.purchase_likes_mock(integer);
drop function if exists public.purchase_likes_mock();

create or replace function public.purchase_membership(p_tier text)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.profiles;
begin
  if v_uid is null then
    raise exception 'ログインが必要です';
  end if;
  if p_tier <> 'free' then
    raise exception 'このプランへの変更には購入手続きが必要です: %', p_tier;
  end if;

  update public.profiles
  set membership_tier = 'free',
      private_mode = false
  where id = v_uid
  returning * into v_row;

  return v_row;
end;
$$;

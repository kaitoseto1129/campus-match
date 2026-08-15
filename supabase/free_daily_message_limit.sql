-- Supabase Dashboard > SQL Editor で一度だけ実行してください
-- (このリポジトリでは MCP 経由で適用済み)。
--
-- 無料会員のメッセージ制限を「送信不可」から「1日3人まで」に変更する。
--
-- アプリ側は既に1日3人までの表示・制御になっていたが、RLSは無料会員のINSERTを
-- 全面的に拒否したままだったため、実際には1人にも送れない状態だった。
-- クライアントの表示とサーバーの実際の制限が食い違うと、
-- 「送れるように見えるのに送れない」ことになるため、RLS側を仕様に合わせる。
--
-- 「3人まで」は"今日メッセージを送った相手(match_id)の種類数"で数える。
-- 同じ相手との会話は何通でも続けられ、4人目の相手に送ろうとした時だけ弾かれる。

create or replace function can_send_message_today(p_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    case
      -- 有料会員(premium/vip)は人数制限なし。
      when (select membership_tier from public.profiles where id = auth.uid()) in ('premium', 'vip')
        then true
      -- 今日すでにこの相手へ送っていれば、同じ会話の続きなので常に許可する。
      when exists (
        select 1 from public.messages m
        where m.sender_id = auth.uid()
          and m.match_id = p_match_id
          and m.created_at >= date_trunc('day', now() at time zone 'Asia/Tokyo') at time zone 'Asia/Tokyo'
      ) then true
      -- それ以外は、今日メッセージを送った相手の人数が上限未満のときだけ許可する。
      else (
        select count(distinct m.match_id)
        from public.messages m
        where m.sender_id = auth.uid()
          and m.created_at >= date_trunc('day', now() at time zone 'Asia/Tokyo') at time zone 'Asia/Tokyo'
      ) < 3
    end;
$$;

revoke all on function can_send_message_today(uuid) from public, anon;
grant execute on function can_send_message_today(uuid) to authenticated;

drop policy if exists "Match participants can send messages" on public.messages;
create policy "Match participants can send messages"
on public.messages
for insert
to authenticated
with check (
    sender_id = (select auth.uid())
    and exists (
        select 1 from public.matches m
        where m.id = messages.match_id
          and (m.user_a_id = (select auth.uid()) or m.user_b_id = (select auth.uid()))
    )
    -- 無料会員は1日に3人まで。有料会員は無制限。
    and can_send_message_today(messages.match_id)
    and not exists (
        select 1
        from public.user_actions ua
        join public.matches m on m.id = messages.match_id
        where ua.action = 'block'
          and (
              (ua.actor_id = (select auth.uid()) and ua.target_id = case when m.user_a_id = (select auth.uid()) then m.user_b_id else m.user_a_id end)
              or
              (ua.target_id = (select auth.uid()) and ua.actor_id = case when m.user_a_id = (select auth.uid()) then m.user_b_id else m.user_a_id end)
          )
    )
);

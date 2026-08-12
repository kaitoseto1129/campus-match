-- Supabase Dashboard > SQL Editor で一度だけ実行してください
-- (このリポジトリでは MCP 経由で適用済み)。
--
-- 無料会員はマッチしてもメッセージを送れない、という会員ステータスの制限を
-- クライアント側の出し分けだけに頼らず、RLSでも担保する。
-- 既存の「マッチの当事者であること」「ブロックしていないこと」の条件はそのまま維持し、
-- 「有料会員(premium)またはVIP(vip)であること」を追加する。

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
    and exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.membership_tier in ('premium', 'vip')
    )
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

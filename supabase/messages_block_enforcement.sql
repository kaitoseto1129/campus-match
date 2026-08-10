-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。
-- ブロック関係にある相手とは、実際にメッセージを送信できないようにDB側でも強制する。
drop policy if exists "Match participants can send messages" on public.messages;
create policy "Match participants can send messages"
on public.messages
for insert
to authenticated
with check (
    sender_id = auth.uid()
    and exists (
        select 1 from public.matches m
        where m.id = messages.match_id
          and (m.user_a_id = auth.uid() or m.user_b_id = auth.uid())
    )
    and not exists (
        select 1 from public.user_actions ua
        join public.matches m on m.id = messages.match_id
        where ua.action = 'block'
          and (
            (ua.actor_id = auth.uid() and ua.target_id = (case when m.user_a_id = auth.uid() then m.user_b_id else m.user_a_id end))
            or
            (ua.target_id = auth.uid() and ua.actor_id = (case when m.user_a_id = auth.uid() then m.user_b_id else m.user_a_id end))
          )
    )
);

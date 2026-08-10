-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。

-- 既読(read_at)が更新できるようにUPDATEポリシーを追加。
-- これが無かったため、MessageManager.markRead()のUPDATEがRLSでサイレントに失敗し、既読が一切保存されていなかった。
drop policy if exists "Match participants can update messages" on public.messages;
create policy "Match participants can update messages"
on public.messages
for update
to authenticated
using (
    exists (
        select 1 from public.matches m
        where m.id = messages.match_id
          and (m.user_a_id = auth.uid() or m.user_b_id = auth.uid())
    )
)
with check (
    exists (
        select 1 from public.matches m
        where m.id = messages.match_id
          and (m.user_a_id = auth.uid() or m.user_b_id = auth.uid())
    )
);

-- プロフィール基本情報の拡張項目(飲酒・喫煙・体型・話せる言語・返信ペース・返信時間帯)
alter table public.profiles
    add column if not exists drinking text,
    add column if not exists smoking text,
    add column if not exists body_type text,
    add column if not exists languages text[] not null default '{}',
    add column if not exists reply_pace text,
    add column if not exists reply_time text;

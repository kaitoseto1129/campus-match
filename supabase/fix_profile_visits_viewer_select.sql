-- Supabase Dashboard > SQL Editor で一度だけ実行してください
-- (このリポジトリでは MCP 経由で適用済み)。
--
-- 【デイリーミッション「プロフィールを見よう」が永久に達成できない不具合の修正】
--
-- profile_visits のSELECTポリシーが「visited_id = auth.uid()」(=見られた側)だけだったため、
-- 「自分が今日誰を見たか」を数えるミッションの集計クエリ
--     select id from profile_visits where viewer_id = <自分>
-- が常に0件を返し、プロフィールを何人見ても達成にならなかった。
--
-- あわせて、閲覧を記録する処理は insert().select("id").single() の形で
-- 挿入した行を読み返しているが、そのSELECTも同じ理由で弾かれるため、
-- 足あとの記録自体が失敗していた(実際、直近の足あとが1件も記録されていなかった)。
--
-- 自分自身の閲覧履歴を読めるようにするだけなので、他人の情報が漏れることはない。

drop policy if exists "Viewers can read their own visits" on public.profile_visits;
create policy "Viewers can read their own visits"
on public.profile_visits
for select
to authenticated
using (viewer_id = (select auth.uid()));

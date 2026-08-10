-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。
-- いいね送信のたびに自分自身の remaining_likes を1減らす。target を auth.uid() 固定にすることで
-- 他ユーザーの残いいね数を操作できないようにしている。

create or replace function public.decrement_remaining_likes()
returns integer
language sql
security definer
set search_path = public
as $$
  update public.profiles
  set remaining_likes = greatest(remaining_likes - 1, 0)
  where id = auth.uid()
  returning remaining_likes;
$$;

grant execute on function public.decrement_remaining_likes() to authenticated;

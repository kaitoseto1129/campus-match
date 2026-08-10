-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。
-- 見てね(3いいね消費)やスペシャルいいね(2いいね消費)など、まとめて減算するためのRPC。

create or replace function public.decrement_remaining_likes_by(amount integer)
returns integer
language sql
security definer
set search_path = public
as $$
  update public.profiles
  set remaining_likes = greatest(remaining_likes - amount, 0)
  where id = auth.uid()
  returning remaining_likes;
$$;
grant execute on function public.decrement_remaining_likes_by(integer) to authenticated;

-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。
-- マイページの「退会する」から呼び出す自己退会用RPC。
-- security definer で実行され、呼び出し本人(auth.uid())に紐づく全データを削除したうえで
-- auth.users から本人を削除する。FK制約の都合上、削除順序は依存関係の末端から。

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  delete from public.messages where sender_id = uid or match_id in (
    select id from public.matches where user_a_id = uid or user_b_id = uid
  );
  delete from public.hidden_matches where user_id = uid or match_id in (
    select id from public.matches where user_a_id = uid or user_b_id = uid
  );
  -- call_requests.match_id はON DELETE CASCADEなしでmatchesを参照しているため、
  -- 通話リクエストを一度でもやり取りしたマッチが残っているとmatches削除時に
  -- 外部キー制約違反で退会処理全体が失敗してしまう。先に消しておく。
  delete from public.call_requests where match_id in (
    select id from public.matches where user_a_id = uid or user_b_id = uid
  ) or requester_id = uid;
  delete from public.matches where user_a_id = uid or user_b_id = uid;
  delete from public.likes where from_user_id = uid or to_user_id = uid;
  delete from public.profile_visits where viewer_id = uid or visited_id = uid;
  delete from public.user_actions where actor_id = uid or target_id = uid;
  delete from public.reports where reporter_id = uid or reported_id = uid;
  delete from public.mission_claims where user_id = uid;
  delete from public.profile_photos where user_id = uid;
  delete from public.profiles where id = uid;
  delete from auth.users where id = uid;
end;
$$;

grant execute on function public.delete_own_account() to authenticated;

-- Supabase Dashboard > SQL Editor で一度だけ実行してください(scripts/apply-sql.mjs でも可)。
--
-- 退会RPC(delete_own_account)が「Direct deletion from storage tables is not allowed」で
-- 失敗するようになっていた修正。
--
-- Supabase側で storage.objects に直接DELETEを防ぐトリガー(storage.protect_delete)が
-- 追加され、関数内の `delete from storage.objects` が例外を投げるようになった。
-- 退会そのものが失敗するため、ユーザーがアカウントを削除できない状態だった。
--
-- 写真ファイルの実体は、iOS(AuthManager.deleteAccount)・Web(MyPageSettings)の両方が
-- RPCを呼ぶ前に Storage API で削除している。関数内の削除はその取りこぼしを拾う
-- フォールバックなので、トリガーが用意している回避設定(storage.allow_delete_query)を
-- このトランザクション内だけ有効にして通す。

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  -- 集まり関連: gathering_applications/gathering_messages/gathering_reads は
  -- auth.users へ ON DELETE CASCADE なしで参照しているため先に消しておく
  -- (主催している gatherings は host_id = uid の削除時に cascade で処理される)。
  delete from public.gathering_reads where user_id = uid;
  delete from public.gathering_messages where sender_id = uid;
  delete from public.gathering_applications where applicant_id = uid;
  delete from public.gatherings where host_id = uid;

  delete from public.user_actions where actor_id = uid or target_id = uid;
  delete from public.reports where reporter_id = uid or reported_id = uid;
  delete from public.profile_photos where user_id = uid;

  -- Storage上の実ファイルはクライアント側で先に消している。ここでは残った行だけを
  -- 片付ける。storage.protect_delete トリガーの回避設定をこのトランザクション内でだけ立てる。
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects
  where bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = uid::text;

  delete from public.profiles where id = uid;
  delete from auth.users where id = uid;
end;
$function$;

grant execute on function public.delete_own_account() to authenticated;

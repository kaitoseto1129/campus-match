-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- delete_own_account が profile_photos/chat_photos のDB行しか消しておらず、
-- Storage上の実ファイル(写真URL)が退会後も永久に残ってしまっていたため、
-- 退会時にStorageオブジェクトも一緒に削除するようにする。

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  uid uuid := auth.uid();
  v_match_ids uuid[];
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select array_agg(id) into v_match_ids from public.matches where user_a_id = uid or user_b_id = uid;

  delete from public.messages where sender_id = uid or match_id in (
    select id from public.matches where user_a_id = uid or user_b_id = uid
  );
  delete from public.hidden_matches where user_id = uid or match_id in (
    select id from public.matches where user_a_id = uid or user_b_id = uid
  );
  delete from public.matches where user_a_id = uid or user_b_id = uid;
  delete from public.likes where from_user_id = uid or to_user_id = uid;
  delete from public.profile_visits where viewer_id = uid or visited_id = uid;
  delete from public.user_actions where actor_id = uid or target_id = uid;
  delete from public.reports where reporter_id = uid or reported_id = uid;
  delete from public.mission_claims where user_id = uid;
  delete from public.profile_photos where user_id = uid;

  delete from storage.objects
  where bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = uid::text;

  if v_match_ids is not null then
    delete from storage.objects
    where bucket_id = 'chat_photos'
      and (storage.foldername(name))[1]::uuid = any(v_match_ids);
  end if;

  delete from public.profiles where id = uid;
  delete from auth.users where id = uid;
end;
$function$;

-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- get_advisors(security/performance)で見つかった項目の修正一式。

-- 1) トリガー関数のsearch_pathを固定(検索パス乗っ取り対策)
create or replace function public.check_university_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_domain text;
  v_university_id uuid;
begin
  v_domain := split_part(new.email, '@', 2);
  select id into v_university_id
  from public.universities
  where v_domain = domain or v_domain like ('%.' || domain)
  limit 1;
  if v_university_id is null then
    raise exception '登録されていない大学のメールアドレスです: %', v_domain;
  end if;
  return new;
end;
$function$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_domain text;
  v_university_id uuid;
begin
  v_domain := split_part(new.email, '@', 2);
  select id into v_university_id
  from public.universities
  where v_domain = domain or v_domain like ('%.' || domain)
  limit 1;
  insert into public.profiles (id, university_id, name)
  values (
    new.id,
    v_university_id,
    coalesce(new.raw_user_meta_data->>'display_name', '名無し')
  );
  return new;
end;
$function$;

-- 2) RLSポリシーのauth.uid()を(select auth.uid())でラップ(行ごとの再評価を防ぐ) + reportsの重複ポリシー統合
drop policy if exists "Users can manage their own hidden matches" on public.hidden_matches;
create policy "Users can manage their own hidden matches"
on public.hidden_matches for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "Users can send likes" on public.likes;
create policy "Users can send likes"
on public.likes for insert to authenticated
with check (from_user_id = (select auth.uid()) and from_user_id <> to_user_id);

drop policy if exists "Users can read own likes" on public.likes;
create policy "Users can read own likes"
on public.likes for select to authenticated
using (from_user_id = (select auth.uid()) or to_user_id = (select auth.uid()));

drop policy if exists "Users can update own sent likes" on public.likes;
create policy "Users can update own sent likes"
on public.likes for update to authenticated
using (from_user_id = (select auth.uid()))
with check (from_user_id = (select auth.uid()));

drop policy if exists "Users can create matches they are part of" on public.matches;
create policy "Users can create matches they are part of"
on public.matches for insert to authenticated
with check (user_a_id = (select auth.uid()) or user_b_id = (select auth.uid()));

drop policy if exists "Users can read own matches" on public.matches;
create policy "Users can read own matches"
on public.matches for select to authenticated
using (user_a_id = (select auth.uid()) or user_b_id = (select auth.uid()));

drop policy if exists "Match participants can send messages" on public.messages;
create policy "Match participants can send messages"
on public.messages for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and exists (
    select 1 from matches m
    where m.id = messages.match_id
      and (m.user_a_id = (select auth.uid()) or m.user_b_id = (select auth.uid()))
  )
  and not exists (
    select 1 from user_actions ua
    join matches m on m.id = messages.match_id
    where ua.action = 'block'
      and (
        (ua.actor_id = (select auth.uid()) and ua.target_id = case when m.user_a_id = (select auth.uid()) then m.user_b_id else m.user_a_id end)
        or (ua.target_id = (select auth.uid()) and ua.actor_id = case when m.user_a_id = (select auth.uid()) then m.user_b_id else m.user_a_id end)
      )
  )
);

drop policy if exists "Match participants can read messages" on public.messages;
create policy "Match participants can read messages"
on public.messages for select to authenticated
using (
  exists (
    select 1 from matches m
    where m.id = messages.match_id
      and (m.user_a_id = (select auth.uid()) or m.user_b_id = (select auth.uid()))
  )
);

drop policy if exists "Match participants can update messages" on public.messages;
create policy "Match participants can update messages"
on public.messages for update to authenticated
using (
  exists (
    select 1 from matches m
    where m.id = messages.match_id
      and (m.user_a_id = (select auth.uid()) or m.user_b_id = (select auth.uid()))
  )
)
with check (
  exists (
    select 1 from matches m
    where m.id = messages.match_id
      and (m.user_a_id = (select auth.uid()) or m.user_b_id = (select auth.uid()))
  )
);

drop policy if exists "Users can manage their own mission claims" on public.mission_claims;
create policy "Users can manage their own mission claims"
on public.mission_claims for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "Users can insert own profile photos" on public.profile_photos;
create policy "Users can insert own profile photos"
on public.profile_photos for insert to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "Users can update own profile photos" on public.profile_photos;
create policy "Users can update own profile photos"
on public.profile_photos for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "Users can delete own profile photos" on public.profile_photos;
create policy "Users can delete own profile photos"
on public.profile_photos for delete to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Users can record their own visits" on public.profile_visits;
create policy "Users can record their own visits"
on public.profile_visits for insert to authenticated
with check (viewer_id = (select auth.uid()));

drop policy if exists "Visited users can read their footprints" on public.profile_visits;
create policy "Visited users can read their footprints"
on public.profile_visits for select to authenticated
using (visited_id = (select auth.uid()));

drop policy if exists "Viewers can update their own visit records" on public.profile_visits;
create policy "Viewers can update their own visit records"
on public.profile_visits for update to authenticated
using (viewer_id = (select auth.uid()))
with check (viewer_id = (select auth.uid()));

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

drop policy if exists "Users can manage their own actions" on public.user_actions;
create policy "Users can manage their own actions"
on public.user_actions for all to authenticated
using (actor_id = (select auth.uid()))
with check (actor_id = (select auth.uid()));

drop policy if exists "Users can create and read their own reports" on public.reports;
drop policy if exists "Admins can read all reports" on public.reports;
drop policy if exists "Admins can update reports" on public.reports;

create policy "Reporters can insert their own reports"
on public.reports for insert to authenticated
with check (reporter_id = (select auth.uid()));

create policy "Reporters can delete their own reports"
on public.reports for delete to authenticated
using (reporter_id = (select auth.uid()));

create policy "Reporters or admins can read reports"
on public.reports for select to authenticated
using (
  reporter_id = (select auth.uid())
  or exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.is_admin)
);

create policy "Reporters or admins can update reports"
on public.reports for update to authenticated
using (
  reporter_id = (select auth.uid())
  or exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.is_admin)
)
with check (
  reporter_id = (select auth.uid())
  or exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.is_admin)
);

-- 3) 未索引だった外部キー列に索引を追加
create index if not exists idx_hidden_matches_match_id on public.hidden_matches (match_id);
create index if not exists idx_matches_like_id on public.matches (like_id);
create index if not exists idx_matches_user_b_id on public.matches (user_b_id);
create index if not exists idx_messages_sender_id on public.messages (sender_id);
create index if not exists idx_profile_photos_user_id on public.profile_photos (user_id);
create index if not exists idx_profile_visits_viewer_id on public.profile_visits (viewer_id);
create index if not exists idx_profiles_university_id on public.profiles (university_id);
create index if not exists idx_reports_reported_id on public.reports (reported_id);
create index if not exists idx_reports_reporter_id on public.reports (reporter_id);
create index if not exists idx_user_actions_target_id on public.user_actions (target_id);

-- 4) 未ログイン(anon)からRPCを直接叩けないようにする
revoke execute on function public.activate_boost() from anon;
revoke execute on function public.check_university_email() from anon;
revoke execute on function public.claim_daily_mission(text, integer) from anon;
revoke execute on function public.claim_share_bonus() from anon;
revoke execute on function public.decrement_remaining_likes() from anon;
revoke execute on function public.decrement_remaining_likes_by(integer) from anon;
revoke execute on function public.delete_own_account() from anon;
revoke execute on function public.get_like_count(uuid) from anon;
revoke execute on function public.get_new_footprints_count() from anon;
revoke execute on function public.handle_new_user() from anon;
revoke execute on function public.is_user_online(uuid) from anon;
revoke execute on function public.mark_footprints_viewed() from anon;
revoke execute on function public.purchase_likes_mock() from anon;

-- check_university_email/handle_new_userはトリガー専用(auth.usersへのINSERTで自動実行)なので
-- authenticatedからの直接呼び出しも塞ぐ。
revoke execute on function public.check_university_email() from authenticated;
revoke execute on function public.handle_new_user() from authenticated;

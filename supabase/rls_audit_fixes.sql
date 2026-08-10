-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- RLSポリシー総点検で見つかった3つの穴を塞ぐ。

-- 1) likes.reminded_at (みてね!再アピール) を更新するUPDATEポリシーが存在せず、
--    DiscoverManager.sendReminder / SentLikesManager.sendReminder の更新が
--    RLSにより常にサイレント失敗していた(messages.read_atで過去に見つかったのと同じパターン)。
drop policy if exists "Users can update own sent likes" on public.likes;
create policy "Users can update own sent likes"
on public.likes
for update
to authenticated
using (from_user_id = auth.uid())
with check (from_user_id = auth.uid());

-- 2) public.profile_photos がRLS無効(誰でも他人の写真行を読み書き削除できる状態)だった。
--    profile_photo_policies.sql として控えは用意されていたが未適用だったため、ここで適用する。
alter table public.profile_photos enable row level security;

drop policy if exists "Users can read profile photos" on public.profile_photos;
create policy "Users can read profile photos"
on public.profile_photos
for select
to authenticated
using (true);

drop policy if exists "Users can insert own profile photos" on public.profile_photos;
create policy "Users can insert own profile photos"
on public.profile_photos
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users can update own profile photos" on public.profile_photos;
create policy "Users can update own profile photos"
on public.profile_photos
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Users can delete own profile photos" on public.profile_photos;
create policy "Users can delete own profile photos"
on public.profile_photos
for delete
to authenticated
using (user_id = auth.uid());

-- 3) storage.objects の "Allow all uploads" が bucket_id = 'profile_photos' だけを条件にしており、
--    ロール制限もフォルダ制限もない(未ログインの anon ロールでも任意のパスにアップロードできる)状態だった。
--    正しい「本人のフォルダにのみ authenticated でアップロード/更新/削除できる」ポリシーに置き換える。
drop policy if exists "Allow all uploads" on storage.objects;

drop policy if exists "Users can upload own profile photo objects" on storage.objects;
create policy "Users can upload own profile photo objects"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can update own profile photo objects" on storage.objects;
create policy "Users can update own profile photo objects"
on storage.objects
for update
to authenticated
using (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can delete own profile photo objects" on storage.objects;
create policy "Users can delete own profile photo objects"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
);

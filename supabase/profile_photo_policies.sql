-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- profile_photos バケット内は <user UUID>/<photo UUID>.jpg の構成です。

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

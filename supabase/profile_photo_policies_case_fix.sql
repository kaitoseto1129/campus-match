-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
--
-- 写真アップロードが「写真の保存に失敗しました」で失敗する不具合の修正。
-- Swiftの UUID().uuidString は大文字(例: 905F0398-...)を返すが、
-- auth.uid()::text は小文字(例: 905f0398-...)を返すため、
-- (storage.foldername(name))[1] = auth.uid()::text という文字列比較では
-- 同一ユーザーでも大文字/小文字の違いで一致せず、RLSに弾かれてアップロードが
-- 常に失敗していた(chat_photos側は ::uuid にキャストして比較しており、
-- uuid型の比較は大文字小文字を区別しないためこの問題は起きていなかった)。
-- 同じ ::uuid キャストに合わせることで解消する。

drop policy if exists "Users can upload own profile photo objects" on storage.objects;
create policy "Users can upload own profile photo objects"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'profile_photos'
    and ((storage.foldername(name))[1])::uuid = auth.uid()
);

drop policy if exists "Users can update own profile photo objects" on storage.objects;
create policy "Users can update own profile photo objects"
on storage.objects
for update
to authenticated
using (
    bucket_id = 'profile_photos'
    and ((storage.foldername(name))[1])::uuid = auth.uid()
)
with check (
    bucket_id = 'profile_photos'
    and ((storage.foldername(name))[1])::uuid = auth.uid()
);

drop policy if exists "Users can delete own profile photo objects" on storage.objects;
create policy "Users can delete own profile photo objects"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'profile_photos'
    and ((storage.foldername(name))[1])::uuid = auth.uid()
);

-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- 探す画面のページネーション導入に合わせて、絞り込み・並び替えで使う列に索引を追加する。
-- (それまでprofilesには主キー以外の索引が一つも無く、絞り込み+並び替えが全てシーケンシャルスキャンだった)

create index if not exists idx_profiles_gender_university_last_active
  on public.profiles (gender, university_id, last_active_at desc);

create index if not exists idx_profiles_area on public.profiles (area);
create index if not exists idx_profiles_birthday on public.profiles (birthday);
create index if not exists idx_profiles_height on public.profiles (height);
create index if not exists idx_profiles_nationality on public.profiles (nationality);

create index if not exists idx_profiles_boost_expires_at
  on public.profiles (boost_expires_at)
  where boost_expires_at is not null;

create index if not exists idx_likes_to_user_id on public.likes (to_user_id);

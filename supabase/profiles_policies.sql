-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- 探す/いいね画面で他ユーザーのプロフィール・大学情報を読み取れるようにする。

alter table public.profiles enable row level security;

drop policy if exists "Authenticated users can read all profiles" on public.profiles;
create policy "Authenticated users can read all profiles"
on public.profiles
for select
to authenticated
using (true);

-- 自分自身のプロフィール(名前・自己紹介・各種トグルなど)を更新できるようにする。
-- これが無いとプロフィール編集画面での保存がRLSに阻まれ、すべて失敗する。
drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- ProfileEditView.swift側のminimumAge=18チェックはクライアント側のみのため、
-- 直接API呼び出しでは18歳未満になるbirthdayを設定できてしまう。DB側でも強制する
-- (制約 profiles_birthday_minimum_age_18 として既に本番に適用済み)。
alter table public.profiles
  add constraint profiles_birthday_minimum_age_18
  check (birthday is null or birthday <= (current_date - interval '18 years'));

alter table public.universities enable row level security;

drop policy if exists "Authenticated users can read universities" on public.universities;
create policy "Authenticated users can read universities"
on public.universities
for select
to authenticated
using (true);

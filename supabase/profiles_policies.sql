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

alter table public.universities enable row level security;

drop policy if exists "Authenticated users can read universities" on public.universities;
create policy "Authenticated users can read universities"
on public.universities
for select
to authenticated
using (true);

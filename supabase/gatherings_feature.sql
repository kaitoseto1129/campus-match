-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。
--
-- 「集まり」機能: 恋愛マッチングとは別に、同じ大学の人同士が「ご飯行きませんか」のような
-- 少人数の集まりを募集・応募できる仕組み。性別は問わず、同じ大学の人なら誰でも応募できる。
-- 主催者が応募を承認すると、承認された人たち全員(主催者含む)で自動的にグループトークが
-- 使えるようになる(既存の1対1マッチ・トークとは別の仕組みとして、matchesテーブルは使わない)。

create table public.gatherings (
    id uuid primary key default gen_random_uuid(),
    host_id uuid not null references auth.users(id),
    university_id uuid not null references public.universities(id),
    title text not null,
    description text,
    location text not null,
    scheduled_at timestamptz not null,
    -- 主催者本人を含めた合計人数の上限。
    capacity int not null check (capacity between 2 and 8),
    status text not null default 'open' check (status in ('open', 'closed', 'canceled')),
    created_at timestamptz not null default now()
);
create index idx_gatherings_university_status on public.gatherings (university_id, status, scheduled_at);
create index idx_gatherings_host_id on public.gatherings (host_id);

create table public.gathering_applications (
    id uuid primary key default gen_random_uuid(),
    gathering_id uuid not null references public.gatherings(id) on delete cascade,
    applicant_id uuid not null references auth.users(id),
    comment text,
    status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'canceled')),
    created_at timestamptz not null default now(),
    responded_at timestamptz,
    unique (gathering_id, applicant_id)
);
create index idx_gathering_applications_gathering_id on public.gathering_applications (gathering_id);
create index idx_gathering_applications_applicant_id on public.gathering_applications (applicant_id);

create table public.gathering_messages (
    id uuid primary key default gen_random_uuid(),
    gathering_id uuid not null references public.gatherings(id) on delete cascade,
    sender_id uuid not null references auth.users(id),
    body text not null,
    created_at timestamptz not null default now()
);
create index idx_gathering_messages_gathering_id on public.gathering_messages (gathering_id);

-- 集まり一覧の未読バッジ表示用。gathering_messagesには相手ごとのread_atがないため
-- (グループなので1対1のmessagesのようにread_at単一列では表現できない)、
-- ユーザーごとに「ここまで読んだ」時刻を別テーブルで持つ。
create table public.gathering_reads (
    gathering_id uuid not null references public.gatherings(id) on delete cascade,
    user_id uuid not null references auth.users(id),
    last_read_at timestamptz not null default now(),
    primary key (gathering_id, user_id)
);

alter table public.gatherings enable row level security;
alter table public.gathering_applications enable row level security;
alter table public.gathering_messages enable row level security;
alter table public.gathering_reads enable row level security;

-- gatherings: 自分と同じ大学の集まりだけ見える。
create policy "Same university users can view gatherings"
on public.gatherings for select to authenticated
using (
  university_id = (select university_id from public.profiles where id = (select auth.uid()))
);

create policy "Users can host gatherings at their own university"
on public.gatherings for insert to authenticated
with check (
  host_id = (select auth.uid())
  and university_id = (select university_id from public.profiles where id = (select auth.uid()))
);

create policy "Hosts can update their own gatherings"
on public.gatherings for update to authenticated
using (host_id = (select auth.uid()))
with check (host_id = (select auth.uid()));

-- gathering_applications: 応募者本人と、その集まりの主催者だけが読める。
create policy "Applicant or host can view applications"
on public.gathering_applications for select to authenticated
using (
  applicant_id = (select auth.uid())
  or exists (select 1 from public.gatherings g where g.id = gathering_id and g.host_id = (select auth.uid()))
);

create policy "Users can apply to gatherings"
on public.gathering_applications for insert to authenticated
with check (
  applicant_id = (select auth.uid())
  and exists (
    select 1 from public.gatherings g
    where g.id = gathering_id
      and g.status = 'open'
      and g.host_id != (select auth.uid())
      and g.university_id = (select university_id from public.profiles where id = (select auth.uid()))
  )
);

-- 応募者は自分の「承認待ち」の応募だけ取り消せる。承認・却下はrespond_to_gathering_application経由。
create policy "Applicants can withdraw their own pending application"
on public.gathering_applications for update to authenticated
using (applicant_id = (select auth.uid()) and status = 'pending')
with check (applicant_id = (select auth.uid()) and status = 'canceled');

-- gathering_messages: 主催者、または承認済みの応募者だけが読み書きできる。
create policy "Members can view gathering messages"
on public.gathering_messages for select to authenticated
using (
  exists (
    select 1 from public.gatherings g
    where g.id = gathering_id and g.host_id = (select auth.uid())
  )
  or exists (
    select 1 from public.gathering_applications ga
    where ga.gathering_id = gathering_messages.gathering_id
      and ga.applicant_id = (select auth.uid())
      and ga.status = 'accepted'
  )
);

create policy "Members can send gathering messages"
on public.gathering_messages for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and (
    exists (
      select 1 from public.gatherings g
      where g.id = gathering_id and g.host_id = (select auth.uid())
    )
    or exists (
      select 1 from public.gathering_applications ga
      where ga.gathering_id = gathering_messages.gathering_id
        and ga.applicant_id = (select auth.uid())
        and ga.status = 'accepted'
    )
  )
);

-- gathering_reads: 自分の既読位置だけ読み書きできる。
create policy "Users can manage their own gathering read state"
on public.gathering_reads for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- 応募の承認・却下。定員(主催者含む)を超えて承認できないよう、ここで原子的にチェックする。
-- 満員になった時点でgatherings.statusを'closed'に自動更新する。
create or replace function public.respond_to_gathering_application(p_application_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gathering_id uuid;
  v_host_id uuid;
  v_capacity int;
  v_accepted_count int;
begin
  select ga.gathering_id, g.host_id, g.capacity
    into v_gathering_id, v_host_id, v_capacity
  from public.gathering_applications ga
  join public.gatherings g on g.id = ga.gathering_id
  where ga.id = p_application_id
  for update of ga;

  if v_gathering_id is null then
    raise exception 'application not found';
  end if;
  if v_host_id != auth.uid() then
    raise exception 'only the host can respond to applications';
  end if;

  if not p_accept then
    update public.gathering_applications
    set status = 'declined', responded_at = now()
    where id = p_application_id and status = 'pending';
    return;
  end if;

  select count(*) into v_accepted_count
  from public.gathering_applications
  where gathering_id = v_gathering_id and status = 'accepted';

  -- 主催者自身も定員に含まれるため +1。
  if v_accepted_count + 1 >= v_capacity then
    raise exception 'gathering is full';
  end if;

  update public.gathering_applications
  set status = 'accepted', responded_at = now()
  where id = p_application_id and status = 'pending';

  if v_accepted_count + 1 + 1 >= v_capacity then
    update public.gatherings set status = 'closed' where id = v_gathering_id;
  end if;
end;
$$;
grant execute on function public.respond_to_gathering_application(uuid, boolean) to authenticated;

alter publication supabase_realtime add table public.gatherings;
alter publication supabase_realtime add table public.gathering_applications;
alter publication supabase_realtime add table public.gathering_messages;

-- 2026-08-24: gatherings_image_category_duration マイグレーションで追加。
-- 任意の画像・カテゴリ・所要時間の目安を持てるようにする。
alter table public.gatherings
  add column image_url text,
  add column category text,
  add column duration_hours int;

insert into storage.buckets (id, name, public)
values ('gathering_photos', 'gathering_photos', true)
on conflict (id) do nothing;

create policy "Hosts can upload gathering photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'gathering_photos'
  and exists (
    select 1 from public.gatherings g
    where g.id = ((storage.foldername(objects.name))[1])::uuid
      and g.host_id = auth.uid()
  )
);

create policy "Hosts can update gathering photos"
on storage.objects for update to authenticated
using (
  bucket_id = 'gathering_photos'
  and exists (
    select 1 from public.gatherings g
    where g.id = ((storage.foldername(objects.name))[1])::uuid
      and g.host_id = auth.uid()
  )
)
with check (
  bucket_id = 'gathering_photos'
  and exists (
    select 1 from public.gatherings g
    where g.id = ((storage.foldername(objects.name))[1])::uuid
      and g.host_id = auth.uid()
  )
);

create policy "Hosts can delete gathering photos"
on storage.objects for delete to authenticated
using (
  bucket_id = 'gathering_photos'
  and exists (
    select 1 from public.gatherings g
    where g.id = ((storage.foldername(objects.name))[1])::uuid
      and g.host_id = auth.uid()
  )
);

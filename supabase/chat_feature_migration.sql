-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。
-- チャット機能(既読・画像送信)・絞り込み(身長)・並び替え(ログイン順)のためのスキーマ変更。

-- 1) profiles: 身長・最終アクティブ日時
alter table public.profiles
    add column if not exists height smallint,
    add column if not exists last_active_at timestamptz not null default now();

-- 2) messages: 既読・画像URL(本文がなくても画像だけのメッセージを許可)
alter table public.messages
    add column if not exists read_at timestamptz,
    add column if not exists image_url text,
    alter column body drop not null;

alter table public.messages
    drop constraint if exists messages_body_or_image_present;
alter table public.messages
    add constraint messages_body_or_image_present
    check (body is not null or image_url is not null);

create index if not exists messages_match_id_created_at_idx
    on public.messages (match_id, created_at);

-- 2b) messages: ボイスメッセージ(音声URL・長さ秒)
alter table public.messages
    add column if not exists audio_url text,
    add column if not exists audio_duration double precision;

alter table public.messages
    drop constraint if exists messages_body_or_image_present;
alter table public.messages
    add constraint messages_body_or_image_present
    check (body is not null or image_url is not null or audio_url is not null);

-- 3) Realtime: チャット・マッチ成立をリアルタイムに購読できるようにする
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.matches;

-- 4) chat_photos ストレージバケットとRLS(マッチ当事者のみアップロード/閲覧可)
insert into storage.buckets (id, name, public)
values ('chat_photos', 'chat_photos', true)
on conflict (id) do nothing;

drop policy if exists "Match participants can upload chat photos" on storage.objects;
create policy "Match participants can upload chat photos"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'chat_photos'
    and exists (
        select 1 from public.matches m
        where m.id = ((storage.foldername(name))[1])::uuid
          and (m.user_a_id = auth.uid() or m.user_b_id = auth.uid())
    )
);

drop policy if exists "Match participants can read chat photos" on storage.objects;
create policy "Match participants can read chat photos"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'chat_photos'
    and exists (
        select 1 from public.matches m
        where m.id = ((storage.foldername(name))[1])::uuid
          and (m.user_a_id = auth.uid() or m.user_b_id = auth.uid())
    )
);

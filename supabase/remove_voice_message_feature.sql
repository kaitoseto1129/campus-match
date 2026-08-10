-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- ボイスメッセージ機能を削除したため、関連列も削除する。
alter table public.messages drop column if exists audio_url;
alter table public.messages drop column if exists audio_duration;

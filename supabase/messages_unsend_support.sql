-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。
-- チャットの送信取り消し機能用。
alter table public.messages
    add column if not exists deleted_at timestamptz;

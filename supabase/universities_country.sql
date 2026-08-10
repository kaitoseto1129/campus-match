-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。
-- 絞り込みで「国→大学」の2段階選択をするための国列。
alter table public.universities
    add column if not exists country text not null default '日本';

update public.universities set country = 'アメリカ' where domain = 'andrew.cmu.edu';

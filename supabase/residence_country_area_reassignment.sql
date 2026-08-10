-- Supabase Dashboard > SQL Editor で一度だけ実行してください(このリポジトリでは実際には MCP 経由で適用済み)。
-- 居住地の絞り込みで「アメリカ」を選んだ時にも結果が出るよう、
-- Carnegie Mellon University(実際のピッツバーグ校)所属のダミー数名の居住地をアメリカの州に変更。
update public.profiles set area = 'ペンシルベニア州' where id in (
  '510ad7af-18a1-4395-9d10-ba7deeba294c',
  'e471ce4c-3da9-4e9f-b18a-b30c4fbb30d3',
  '8fc88c89-9315-4367-ab1a-9e631329278a',
  '748e8325-c550-4bf2-8134-0ebf7069bd9c'
);
update public.profiles set area = 'ニューヨーク州' where id = '31d4a4c4-4040-4da3-9c88-b29aeacee935';
update public.profiles set area = 'カリフォルニア州' where id = '62f8f92f-e6bd-4c9a-988a-bc9972de9da7';

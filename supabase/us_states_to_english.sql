-- Supabase Dashboard > SQL Editor で実行してください(MCP接続が切れているため、このセッションでは
-- 直接適用できていません)。
--
-- アプリの利用シーンとして「アメリカの大学に通うアメリカ人がそのまま使う」ケースを想定し、
-- 米国の州名をカタカナ表記(「ペンシルベニア州」等)から英語表記(「Pennsylvania」等)に変更した
-- (usStates定数、Profile.swift)。既存のDBデータ(プロフィールのarea列・universitiesのprefecture列)に
-- 残っているカタカナ州名も、新しい英語表記に合わせて更新する。

with state_map(ja, en) as (
  values
    ('アラバマ州','Alabama'), ('アラスカ州','Alaska'), ('アリゾナ州','Arizona'), ('アーカンソー州','Arkansas'),
    ('カリフォルニア州','California'), ('コロラド州','Colorado'), ('コネチカット州','Connecticut'),
    ('デラウェア州','Delaware'), ('フロリダ州','Florida'), ('ジョージア州','Georgia'), ('ハワイ州','Hawaii'),
    ('アイダホ州','Idaho'), ('イリノイ州','Illinois'), ('インディアナ州','Indiana'), ('アイオワ州','Iowa'),
    ('カンザス州','Kansas'), ('ケンタッキー州','Kentucky'), ('ルイジアナ州','Louisiana'), ('メイン州','Maine'),
    ('メリーランド州','Maryland'), ('マサチューセッツ州','Massachusetts'), ('ミシガン州','Michigan'),
    ('ミネソタ州','Minnesota'), ('ミシシッピ州','Mississippi'), ('ミズーリ州','Missouri'), ('モンタナ州','Montana'),
    ('ネブラスカ州','Nebraska'), ('ネバダ州','Nevada'), ('ニューハンプシャー州','New Hampshire'),
    ('ニュージャージー州','New Jersey'), ('ニューメキシコ州','New Mexico'), ('ニューヨーク州','New York'),
    ('ノースカロライナ州','North Carolina'), ('ノースダコタ州','North Dakota'), ('オハイオ州','Ohio'),
    ('オクラホマ州','Oklahoma'), ('オレゴン州','Oregon'), ('ペンシルベニア州','Pennsylvania'),
    ('ロードアイランド州','Rhode Island'), ('サウスカロライナ州','South Carolina'), ('サウスダコタ州','South Dakota'),
    ('テネシー州','Tennessee'), ('テキサス州','Texas'), ('ユタ州','Utah'), ('バーモント州','Vermont'),
    ('バージニア州','Virginia'), ('ワシントン州','Washington'), ('ウェストバージニア州','West Virginia'),
    ('ウィスコンシン州','Wisconsin'), ('ワイオミング州','Wyoming')
)
update public.profiles p
set area = sm.en
from state_map sm
where p.area = sm.ja;

with state_map(ja, en) as (
  values
    ('アラバマ州','Alabama'), ('アラスカ州','Alaska'), ('アリゾナ州','Arizona'), ('アーカンソー州','Arkansas'),
    ('カリフォルニア州','California'), ('コロラド州','Colorado'), ('コネチカット州','Connecticut'),
    ('デラウェア州','Delaware'), ('フロリダ州','Florida'), ('ジョージア州','Georgia'), ('ハワイ州','Hawaii'),
    ('アイダホ州','Idaho'), ('イリノイ州','Illinois'), ('インディアナ州','Indiana'), ('アイオワ州','Iowa'),
    ('カンザス州','Kansas'), ('ケンタッキー州','Kentucky'), ('ルイジアナ州','Louisiana'), ('メイン州','Maine'),
    ('メリーランド州','Maryland'), ('マサチューセッツ州','Massachusetts'), ('ミシガン州','Michigan'),
    ('ミネソタ州','Minnesota'), ('ミシシッピ州','Mississippi'), ('ミズーリ州','Missouri'), ('モンタナ州','Montana'),
    ('ネブラスカ州','Nebraska'), ('ネバダ州','Nevada'), ('ニューハンプシャー州','New Hampshire'),
    ('ニュージャージー州','New Jersey'), ('ニューメキシコ州','New Mexico'), ('ニューヨーク州','New York'),
    ('ノースカロライナ州','North Carolina'), ('ノースダコタ州','North Dakota'), ('オハイオ州','Ohio'),
    ('オクラホマ州','Oklahoma'), ('オレゴン州','Oregon'), ('ペンシルベニア州','Pennsylvania'),
    ('ロードアイランド州','Rhode Island'), ('サウスカロライナ州','South Carolina'), ('サウスダコタ州','South Dakota'),
    ('テネシー州','Tennessee'), ('テキサス州','Texas'), ('ユタ州','Utah'), ('バーモント州','Vermont'),
    ('バージニア州','Virginia'), ('ワシントン州','Washington'), ('ウェストバージニア州','West Virginia'),
    ('ウィスコンシン州','Wisconsin'), ('ワイオミング州','Wyoming')
)
update public.universities u
set prefecture = sm.en
from state_map sm
where u.prefecture = sm.ja;

-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- カーネギーメロン大学(Carnegie Mellon University)所属・女性のダミープロフィールを20件投入する。
-- profiles.id / likes.from_user_id・to_user_id は auth.users(id) を参照しているため、
-- テスト用の auth.users レコードも合わせて作成する(本物のログインには使わないダミーアカウント)。

create extension if not exists pgcrypto;

-- 1) 大学レコード(既に同名の大学があれば新規作成しない)
insert into public.universities (id, name, domain)
select gen_random_uuid(), 'Carnegie Mellon University', 'andrew.cmu.edu'
where not exists (
    select 1 from public.universities where name = 'Carnegie Mellon University'
);

with cmu as (
    select id from public.universities where name = 'Carnegie Mellon University' limit 1
),
new_users (row_no, email, name, birthday, area, description) as (
    values
    (1,  'cmu.dummy01@example.com', '佐藤 美咲', date '2004-04-12', '東京都',   'カーネギーメロン大学でコンピューターサイエンスを専攻中。コーヒーとハイキングが好きです。'),
    (2,  'cmu.dummy02@example.com', '鈴木 愛',   date '2003-09-03', '大阪府',   'テッパー・ビジネススクールでマーケティングを勉強しています。休日はカフェ巡り。'),
    (3,  'cmu.dummy03@example.com', '高橋 陽菜', date '2005-01-20', '神奈川県', 'ロボティクス専攻。ものづくりとSF映画が大好きです。'),
    (4,  'cmu.dummy04@example.com', '田中 結衣', date '2004-07-08', '愛知県',   'デザイン学部でUXデザインを学んでいます。美術館めぐりが趣味。'),
    (5,  'cmu.dummy05@example.com', '伊藤 さくら', date '2003-11-15', '福岡県', '建築学専攻。旅行して色々な街の建物を見るのが好きです。'),
    (6,  'cmu.dummy06@example.com', '渡辺 美優', date '2005-03-27', '北海道',   'ドラマ学科で演劇を専攻。舞台に立つのが生きがいです。'),
    (7,  'cmu.dummy07@example.com', '山本 花',   date '2004-06-02', '京都府',   '統計・データサイエンス専攻。データ分析とヨガにハマっています。'),
    (8,  'cmu.dummy08@example.com', '中村 葵',   date '2003-12-19', '兵庫県',   '情報システム学専攻。週末はランニングしてます。'),
    (9,  'cmu.dummy09@example.com', '小林 楓',   date '2005-05-30', '宮城県',   'アート専攻。絵を描くこととヴィンテージ古着屋巡りが好き。'),
    (10, 'cmu.dummy10@example.com', '加藤 優奈', date '2004-02-14', '広島県',   '音楽学部でピアノを専攻しています。ジャズが大好き。'),
    (11, 'cmu.dummy11@example.com', '吉田 心美', date '2003-08-09', '埼玉県',   '化学工学専攻。実験が好きで、休日はベーキングもします。'),
    (12, 'cmu.dummy12@example.com', '山田 莉子', date '2005-10-05', '千葉県',   '経済学専攻。読書と映画鑑賞が趣味です。'),
    (13, 'cmu.dummy13@example.com', '佐々木 未来', date '2004-01-23', '静岡県', 'ヒューマン・コンピュータ・インタラクション専攻。ボードゲーム好き。'),
    (14, 'cmu.dummy14@example.com', '松本 凛',   date '2003-06-17', '沖縄県', '機械学習専攻。海が好きでダイビングもします。'),
    (15, 'cmu.dummy15@example.com', '井上 萌',   date '2005-04-11', '新潟県', '土木工学専攻。アウトドアとスノーボードが趣味。'),
    (16, 'cmu.dummy16@example.com', '木村 彩',   date '2004-09-28', '長野県', '材料科学専攻。写真を撮るのが好きです。'),
    (17, 'cmu.dummy17@example.com', '林 千尋',   date '2003-03-06', '岡山県',   '物理学専攻。天体観測とプラネタリウムが好き。'),
    (18, 'cmu.dummy18@example.com', '清水 美月', date '2005-07-19', '石川県', '数学専攻。パズルとチェスが趣味です。'),
    (19, 'cmu.dummy19@example.com', '山口 遥',   date '2004-11-02', '熊本県', '公共政策学専攻。ボランティア活動をよくしています。'),
    (20, 'cmu.dummy20@example.com', '斎藤 麻衣', date '2003-05-25', '岐阜県', '化学専攻。カフェ巡りと猫が好きです。')
),
gen_ids as (
    select gen_random_uuid() as id, row_no, email, name, birthday, area, description
    from new_users
),
inserted_auth as (
    insert into auth.users (
        id, instance_id, aud, role, email, encrypted_password,
        email_confirmed_at, created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data,
        confirmation_token, recovery_token, email_change_token_new, email_change,
        is_sso_user
    )
    select
        id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        email, crypt('DummyPassword123!', gen_salt('bf')),
        now(), now(), now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('display_name', name),
        '', '', '', '',
        false
    from gen_ids
    returning id
),
inserted_profiles as (
    insert into public.profiles (id, university_id, name, description, gender, birthday, area, profile_image_url)
    select
        g.id, cmu.id, g.name, g.description, 'female', g.birthday, g.area,
        'https://picsum.photos/seed/cmu' || g.row_no || '/600/800'
    from gen_ids g, cmu
    returning id
)
insert into public.profile_photos (id, user_id, url, order_number)
select gen_random_uuid(), g.id, 'https://picsum.photos/seed/cmu' || g.row_no || '/600/800', 0
from gen_ids g;

-- Supabase Dashboard > SQL Editor で実行してください(MCP接続が切れているため、このセッションでは
-- 直接適用できていません)。
--
-- 大学の登録数が少なすぎるとのフィードバックを受け、全国の主要な国公立・私立大学を
-- 大幅に追加する。ドメインは各大学の公式ドメインをもとにしており、学籍番号付きの
-- サブドメイン(例: xxxx@g.xxx.ac.jp)からのメールも check_university_email 側の
-- サブドメイン一致ロジックで登録できる。
--
-- 実在しないドメインを誤って登録すると、その大学の学生が一切サインアップできなくなるため、
-- 追加後に実際の学生から「大学のメールアドレスで登録できない」との報告があれば、
-- domain列を実際のドメインに修正してください(university_domain_fixes.sqlと同じ要領)。

insert into public.universities (name, domain, country, prefecture)
select v.name, v.domain, '日本', v.prefecture
from (values
  -- 国立大学(旧帝大・主要国立大)
  ('北海道大学', 'hokudai.ac.jp', '北海道'),
  ('東北大学', 'tohoku.ac.jp', '宮城県'),
  ('東京大学', 'u-tokyo.ac.jp', '東京都'),
  ('名古屋大学', 'nagoya-u.ac.jp', '愛知県'),
  ('京都大学', 'kyoto-u.ac.jp', '京都府'),
  ('大阪大学', 'osaka-u.ac.jp', '大阪府'),
  ('九州大学', 'kyushu-u.ac.jp', '福岡県'),
  ('東京工業大学', 'titech.ac.jp', '東京都'),
  ('一橋大学', 'hit-u.ac.jp', '東京都'),
  ('神戸大学', 'kobe-u.ac.jp', '兵庫県'),
  ('筑波大学', 'tsukuba.ac.jp', '茨城県'),
  ('広島大学', 'hiroshima-u.ac.jp', '広島県'),
  ('東京外国語大学', 'tufs.ac.jp', '東京都'),
  ('東京学芸大学', 'u-gakugei.ac.jp', '東京都'),
  ('東京農工大学', 'tuat.ac.jp', '東京都'),
  ('電気通信大学', 'uec.ac.jp', '東京都'),
  ('東京都立大学', 'tmu.ac.jp', '東京都'),
  ('横浜国立大学', 'ynu.ac.jp', '神奈川県'),
  ('千葉大学', 'chiba-u.jp', '千葉県'),
  ('埼玉大学', 'saitama-u.ac.jp', '埼玉県'),
  ('お茶の水女子大学', 'ocha.ac.jp', '東京都'),
  ('岡山大学', 'okayama-u.ac.jp', '岡山県'),
  ('信州大学', 'shinshu-u.ac.jp', '長野県'),
  ('新潟大学', 'niigata-u.ac.jp', '新潟県'),
  ('金沢大学', 'kanazawa-u.ac.jp', '石川県'),
  ('富山大学', 'u-toyama.ac.jp', '富山県'),
  ('静岡大学', 'shizuoka.ac.jp', '静岡県'),
  ('三重大学', 'mie-u.ac.jp', '三重県'),
  ('滋賀大学', 'shiga-u.ac.jp', '滋賀県'),
  ('和歌山大学', 'wakayama-u.ac.jp', '和歌山県'),
  ('奈良女子大学', 'nara-wu.ac.jp', '奈良県'),
  ('鳥取大学', 'tottori-u.ac.jp', '鳥取県'),
  ('島根大学', 'shimane-u.ac.jp', '島根県'),
  ('山口大学', 'yamaguchi-u.ac.jp', '山口県'),
  ('香川大学', 'kagawa-u.ac.jp', '香川県'),
  ('愛媛大学', 'ehime-u.ac.jp', '愛媛県'),
  ('高知大学', 'kochi-u.ac.jp', '高知県'),
  ('徳島大学', 'tokushima-u.ac.jp', '徳島県'),
  ('佐賀大学', 'saga-u.ac.jp', '佐賀県'),
  ('長崎大学', 'nagasaki-u.ac.jp', '長崎県'),
  ('熊本大学', 'kumamoto-u.ac.jp', '熊本県'),
  ('大分大学', 'oita-u.ac.jp', '大分県'),
  ('宮崎大学', 'miyazaki-u.ac.jp', '宮崎県'),
  ('鹿児島大学', 'kagoshima-u.ac.jp', '鹿児島県'),
  ('琉球大学', 'u-ryukyu.ac.jp', '沖縄県'),
  ('秋田大学', 'akita-u.ac.jp', '秋田県'),
  ('岩手大学', 'iwate-u.ac.jp', '岩手県'),
  ('山形大学', 'yamagata-u.ac.jp', '山形県'),
  ('福島大学', 'fukushima-u.ac.jp', '福島県'),
  ('弘前大学', 'hirosaki-u.ac.jp', '青森県'),
  ('群馬大学', 'gunma-u.ac.jp', '群馬県'),
  ('茨城大学', 'ibaraki.ac.jp', '茨城県'),
  ('宇都宮大学', 'utsunomiya-u.ac.jp', '栃木県'),
  ('山梨大学', 'yamanashi.ac.jp', '山梨県'),
  ('岐阜大学', 'gifu-u.ac.jp', '岐阜県'),
  ('福井大学', 'u-fukui.ac.jp', '福井県'),

  -- 私立大学(関東)
  ('慶應義塾大学', 'keio.ac.jp', '東京都'),
  ('上智大学', 'sophia.ac.jp', '東京都'),
  ('明治大学', 'meiji.ac.jp', '東京都'),
  ('立教大学', 'rikkyo.ac.jp', '東京都'),
  ('中央大学', 'chuo-u.ac.jp', '東京都'),
  ('法政大学', 'hosei.ac.jp', '東京都'),
  ('学習院大学', 'gakushuin.ac.jp', '東京都'),
  ('日本大学', 'nihon-u.ac.jp', '東京都'),
  ('東洋大学', 'toyo.jp', '東京都'),
  ('駒澤大学', 'komazawa-u.ac.jp', '東京都'),
  ('専修大学', 'senshu-u.ac.jp', '東京都'),
  ('成蹊大学', 'seikei.ac.jp', '東京都'),
  ('成城大学', 'seijo.ac.jp', '東京都'),
  ('武蔵大学', 'musashi.ac.jp', '東京都'),
  ('國學院大學', 'kokugakuin.ac.jp', '東京都'),
  ('東京理科大学', 'tus.ac.jp', '東京都'),
  ('芝浦工業大学', 'shibaura-it.ac.jp', '東京都'),
  ('東京女子大学', 'twcu.ac.jp', '東京都'),
  ('日本女子大学', 'jwu.ac.jp', '東京都'),
  ('津田塾大学', 'tsuda.ac.jp', '東京都'),
  ('明治学院大学', 'meijigakuin.ac.jp', '東京都'),
  ('獨協大学', 'dokkyo.ac.jp', '埼玉県'),

  -- 私立大学(関西・東海・九州など)
  ('立命館大学', 'ritsumei.ac.jp', '京都府'),
  ('同志社大学', 'doshisha.ac.jp', '京都府'),
  ('関西大学', 'kansai-u.ac.jp', '大阪府'),
  ('関西学院大学', 'kwansei.ac.jp', '兵庫県'),
  ('近畿大学', 'kindai.ac.jp', '大阪府'),
  ('甲南大学', 'konan-u.ac.jp', '兵庫県'),
  ('龍谷大学', 'ryukoku.ac.jp', '京都府'),
  ('京都産業大学', 'kyoto-su.ac.jp', '京都府'),
  ('佛教大学', 'bukkyo-u.ac.jp', '京都府'),
  ('大阪工業大学', 'oit.ac.jp', '大阪府'),
  ('名城大学', 'meijo-u.ac.jp', '愛知県'),
  ('南山大学', 'nanzan-u.ac.jp', '愛知県'),
  ('中京大学', 'chukyo-u.ac.jp', '愛知県'),
  ('愛知大学', 'aichi-u.ac.jp', '愛知県'),
  ('福岡大学', 'fukuoka-u.ac.jp', '福岡県'),
  ('西南学院大学', 'seinan-gu.ac.jp', '福岡県')
) as v(name, domain, prefecture)
where not exists (
  select 1 from public.universities u where u.domain = v.domain
);

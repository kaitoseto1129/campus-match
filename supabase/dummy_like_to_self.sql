-- テスト用: 自分の実アカウント(複数)宛てに、ダミーアカウントからランダムに5件ずつ「いいね」を送る。
-- いいねタブの「相手から」に表示され、通知や「ありがとう」ボタンでのマッチ成立の動作確認に使える。
--
-- 対象アカウントのメールアドレスは実行のたびに書き換えて使う想定。
-- (毎回すべてのテストアカウントに送るのがデフォルトの使い方)

insert into public.likes (from_user_id, to_user_id, is_special)
select sub.from_id, sub.to_id, false
from (
  select
    p.id as from_id,
    u.id as to_id,
    row_number() over (partition by u.id order by random()) as rn
  from auth.users u
  cross join public.profiles p
  where u.email in (
    'kseto@andrew.cmu.edu',
    '2kseto@andrew.cmu.edu',
    'hiroshi@andrew.cmu.edu',
    'sanae@andrew.cmu.edu'
  )
  and p.id <> u.id
  and not exists (
    select 1 from public.likes l
    where l.from_user_id = p.id and l.to_user_id = u.id
  )
) sub
where sub.rn <= 5
returning from_user_id, to_user_id;

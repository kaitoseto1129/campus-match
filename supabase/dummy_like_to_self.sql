-- Supabase Dashboard > SQL Editor で実行してください(MCP接続が切れているため、このセッションでは
-- 直接適用できていません)。
--
-- テスト用: ダミーアカウントの中からランダムに1人を選び、あなたの実アカウント(ログイン中の
-- メールアドレス)宛てに「いいね」を送った状態を作る。いいねタブの「相手から」に表示され、
-- 通知や「ありがとう」ボタンでのマッチ成立の動作確認に使える。

insert into public.likes (from_user_id, to_user_id, is_special)
select p.id, u.id, false
from public.profiles p
cross join auth.users u
where u.email = 'kaitoseto1129@gmail.com'
  and p.id <> u.id
  and not exists (
    select 1 from public.likes l where l.from_user_id = p.id and l.to_user_id = u.id
  )
order by random()
limit 1
returning from_user_id, to_user_id;

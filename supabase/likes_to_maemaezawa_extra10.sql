-- Supabase Dashboard > SQL Editor で実行してください。
-- まえまえざわ (a9b48b48-14e1-479c-bd3f-d27b4de09fe6) に対して、
-- まだいいねしていないダミー(cmu.dummy%)からランダムに10人、追加でいいねを送る。

with candidates as (
  select p.id from public.profiles p
  join auth.users u on u.id = p.id
  where u.email like 'cmu.dummy%'
    and p.id not in (
      select from_user_id from public.likes where to_user_id = 'a9b48b48-14e1-479c-bd3f-d27b4de09fe6'
    )
  order by random()
  limit 10
)
insert into public.likes (from_user_id, to_user_id)
select id, 'a9b48b48-14e1-479c-bd3f-d27b4de09fe6' from candidates
on conflict (from_user_id, to_user_id) do nothing;

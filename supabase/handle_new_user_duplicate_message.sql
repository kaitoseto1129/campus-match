-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
--
-- 既に登録済みのメールアドレスで再度サインアップしようとした際、
-- profiles への INSERT が主キー重複(unique_violation)で失敗し、
-- クライアントには汎用的な「Database error saving new user」としか
-- 表示されず原因が分かりにくかったため、専用のメッセージを返すようにする。

create or replace function handle_new_user()
returns trigger as $$
declare
  v_domain text;
  v_university_id uuid;
begin
  v_domain := split_part(new.email, '@', 2);

  select id into v_university_id
  from public.universities
  where v_domain = domain or v_domain like ('%.' || domain)
  limit 1;

  insert into public.profiles (id, university_id, name)
  values (
    new.id,
    v_university_id,
    coalesce(new.raw_user_meta_data->>'display_name', '名無し')
  );

  return new;
exception
  when unique_violation then
    raise exception 'このメールアドレスは既に登録されています';
end;
$$ language plpgsql security definer;

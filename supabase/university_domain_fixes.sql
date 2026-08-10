-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
-- 大学メールドメインの実在確認で見つかった2つの問題を修正する。
--
-- 1) 早稲田大学は実際には「@ruri.waseda.jp」のように大学ドメインのサブドメインで
--    メールが発行される(在学生が伝統色から選ぶ)。完全一致だけを見ていた
--    check_university_email / handle_new_user では早稲田生が全員サインアップ不可になっていたため、
--    サブドメイン一致も許可するように変更する。
-- 2) 青山学院大学は @aoyama.ac.jp (Gmail) と @aoyama.jp (M365) の2つのドメインが
--    実際に発行されているが、後者がuniversitiesテーブルに登録されていなかったため追加する。

create or replace function check_university_email()
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

  if v_university_id is null then
    raise exception '登録されていない大学のメールアドレスです: %', v_domain;
  end if;

  return new;
end;
$$ language plpgsql security definer;

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
end;
$$ language plpgsql security definer;

insert into public.universities (name, domain, country)
select '青山学院大学(M365)', 'aoyama.jp', '日本'
where not exists (select 1 from public.universities where domain = 'aoyama.jp');

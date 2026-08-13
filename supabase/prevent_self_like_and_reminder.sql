-- send_like_atomic / send_reminder_atomic はSECURITY DEFINERで実行され、UI経由では自分自身を
-- 対象に選べないため問題にならないが、APIを直接叩けば自分に対していいね/見てねを送れてしまう
-- (自分自身とのマッチ成立など想定外の状態を招きうる)抜け穴があったため、サーバー側でも防止する。
create or replace function public.send_like_atomic(p_to_user_id uuid, p_is_special boolean default false)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cost integer := case when p_is_special then 2 else 1 end;
  v_remaining integer;
begin
  if p_to_user_id = auth.uid() then
    raise exception 'cannot like yourself';
  end if;

  select remaining_likes into v_remaining from public.profiles where id = auth.uid() for update;
  if v_remaining is null or v_remaining < v_cost then
    raise exception 'insufficient likes';
  end if;

  insert into public.likes (from_user_id, to_user_id, is_special)
  values (auth.uid(), p_to_user_id, p_is_special);

  update public.profiles set remaining_likes = remaining_likes - v_cost where id = auth.uid();
end;
$$;

create or replace function public.send_reminder_atomic(p_to_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cost integer := 3;
  v_remaining integer;
  v_updated integer;
begin
  if p_to_user_id = auth.uid() then
    raise exception 'cannot remind yourself';
  end if;

  select remaining_likes into v_remaining from public.profiles where id = auth.uid() for update;
  if v_remaining is null or v_remaining < v_cost then
    raise exception 'insufficient likes';
  end if;

  update public.likes
  set reminded_at = now()
  where from_user_id = auth.uid() and to_user_id = p_to_user_id;
  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'like not found';
  end if;

  update public.profiles set remaining_likes = remaining_likes - v_cost where id = auth.uid();
end;
$$;

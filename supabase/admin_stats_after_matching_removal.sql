-- Supabase Dashboard > SQL Editor で一度だけ実行してください(scripts/apply-sql.mjs でも可)。
--
-- 管理画面(admin-kappa-nine-45.vercel.app)が使う集計RPCを、マッチング機能廃止後の
-- テーブル構成に合わせる。likes / matches / messages を削除したため、以前の定義は
-- 呼び出した瞬間に「relation does not exist」で落ちていた。
--
-- 管理画面側のコードが更新されるまで互換性を保つため、以前のキー(matches_today など)は
-- 残して 0 を返し、集まり機能の集計を新しいキーで追加する。

create or replace function public.admin_get_stats()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  result jsonb;
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and admin_role = 'admin') then
    raise exception 'not authorized';
  end if;

  select jsonb_build_object(
    'total_users', (select count(*) from public.profiles),
    'signups_today', (select count(*) from public.profiles where created_at >= current_date),

    -- 集まり機能の集計
    'gatherings_total', (select count(*) from public.gatherings where status <> 'canceled'),
    'gatherings_today', (select count(*) from public.gatherings where created_at >= current_date),
    'applications_today', (select count(*) from public.gathering_applications where created_at >= current_date),
    'gathering_messages_today', (select count(*) from public.gathering_messages where created_at >= current_date),
    'gatherings_by_category', (
      select coalesce(jsonb_agg(jsonb_build_object('label', category, 'count', cnt)), '[]'::jsonb)
      from (
        select coalesce(category, 'その他') as category, count(*) as cnt
        from public.gatherings where status <> 'canceled'
        group by coalesce(category, 'その他') order by cnt desc
      ) t
    ),
    'gatherings_by_day', (
      select coalesce(jsonb_agg(jsonb_build_object('day', day, 'count', cnt) order by day), '[]'::jsonb)
      from (
        select date_trunc('day', created_at)::date as day, count(*) as cnt
        from public.gatherings
        where created_at >= current_date - interval '29 days'
        group by 1
      ) t
    ),

    -- 廃止した機能のキー。管理画面の旧コードが参照しているため、0 / 空で返して壊さない。
    'matches_today', 0,
    'messages_today', 0,
    'matches_by_day', '[]'::jsonb,
    'by_gender', '[]'::jsonb,
    'by_membership', '[]'::jsonb,

    'by_country', (
      select coalesce(jsonb_agg(jsonb_build_object('label', country, 'count', cnt)), '[]'::jsonb)
      from (
        select coalesce(u.country, '不明') as country, count(*) as cnt
        from public.profiles p left join public.universities u on u.id = p.university_id
        group by coalesce(u.country, '不明') order by cnt desc
      ) t
    ),
    'top_universities', (
      select coalesce(jsonb_agg(jsonb_build_object('label', name, 'count', cnt)), '[]'::jsonb)
      from (
        select u.name, count(*) as cnt
        from public.profiles p join public.universities u on u.id = p.university_id
        group by u.name order by cnt desc limit 10
      ) t
    ),
    'signups_by_day', (
      select coalesce(jsonb_agg(jsonb_build_object('day', day, 'count', cnt) order by day), '[]'::jsonb)
      from (
        select date_trunc('day', created_at)::date as day, count(*) as cnt
        from public.profiles
        where created_at >= current_date - interval '29 days'
        group by 1
      ) t
    )
  ) into result;

  return result;
end;
$function$;

-- 1対1のマッチ・メッセージを覗くRPCは対象が無くなった。管理画面の旧コードから呼ばれても
-- エラーにならないよう、空の結果を返すだけにする(管理画面側を直したら削除してよい)。
drop function if exists public.admin_list_matches_for_user(uuid);
create or replace function public.admin_list_matches_for_user(target_id uuid)
returns table (id uuid, created_at timestamptz, partner_id uuid, partner_name text, message_count bigint)
language sql security definer set search_path to 'public'
as $$ select null::uuid, null::timestamptz, null::uuid, null::text, null::bigint where false; $$;

drop function if exists public.admin_list_messages(uuid);
create or replace function public.admin_list_messages(target_match_id uuid)
returns table (id uuid, created_at timestamptz, sender_id uuid, sender_name text, body text, image_url text, read_at timestamptz, deleted_at timestamptz)
language sql security definer set search_path to 'public'
as $$ select null::uuid, null::timestamptz, null::uuid, null::text, null::text, null::text, null::timestamptz, null::timestamptz where false; $$;

-- 残いいね・会員ステータスを管理者が書き換えるRPC。対象カラム自体は残っているが機能が無いため、
-- 誤操作を防ぐために削除する。
drop function if exists public.admin_update_profile_fields(uuid, integer, text);

grant execute on function public.admin_get_stats() to authenticated;
grant execute on function public.admin_list_matches_for_user(uuid) to authenticated;
grant execute on function public.admin_list_messages(uuid) to authenticated;

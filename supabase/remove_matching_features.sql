-- Supabase Dashboard > SQL Editor で一度だけ実行してください。
--
-- 1対1のマッチング機能(いいね・マッチ・個別トーク)と課金機能を全廃し、
-- 「集まり」機能だけを残すための移行。
--
-- 目的: 出会い系サイト規制法(インターネット異性紹介事業を利用して児童を誘引する行為の
-- 規制等に関する法律)第2条2号の「インターネット異性紹介事業」の要件を満たさない
-- サービス構成にすること。具体的には
--   ・異性交際に関する情報を公衆閲覧できる状態に置かない(性別を表示・検索させない)
--   ・利用者同士が1対1で相互に連絡を取れる仕組みを持たない
-- の2点を、機能そのものを削除することで担保する。
--
-- ※ このスクリプトはテーブルとデータを完全に削除します。実行前に必ずバックアップを取ること。

begin;

-- ---------------------------------------------------------------------------
-- 1. 廃止した機能のRPC・関数を削除
--    (引数違いのオーバーロードが存在しうるため、名前で総当たりして削除する)
-- ---------------------------------------------------------------------------
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        -- いいね・マッチ・メッセージ
        'send_like_atomic', 'send_reminder_atomic', 'get_like_count',
        'can_send_message_today',
        -- 足あと(プロフィール閲覧履歴)
        'get_new_footprints_count', 'mark_footprints_viewed',
        -- デイリーミッション・シェアボーナス・アピール(ブースト)
        'claim_daily_mission', 'claim_share_bonus', 'activate_boost',
        'decrement_remaining_likes', 'decrement_remaining_likes_by',
        -- 課金(いいね購入・有料会員)
        'purchase_likes_mock', 'purchase_membership',
        'grant_purchased_likes', 'grant_purchased_membership',
        'revoke_purchased_membership', 'downgrade_own_membership_to_free',
        'user_id_for_original_transaction'
      )
  loop
    execute format('drop function if exists %s cascade', fn.signature);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. 廃止した機能のテーブルを削除
--    依存(FK・ポリシー・トリガー・インデックス)ごと落とすため cascade を付ける。
--    削除順序は依存関係の末端から。
-- ---------------------------------------------------------------------------
drop table if exists public.messages cascade;        -- 1対1トークの本文
drop table if exists public.hidden_matches cascade;  -- トーク一覧から隠したマッチ
drop table if exists public.call_requests cascade;   -- 1対1の通話リクエスト
drop table if exists public.matches cascade;         -- マッチ成立
drop table if exists public.likes cascade;           -- いいね
drop table if exists public.profile_visits cascade;  -- 足あと(プロフィール閲覧履歴)
drop table if exists public.mission_claims cascade;  -- デイリーミッションの受け取り履歴
drop table if exists public.redeemed_transactions cascade; -- App Store課金の消し込み履歴

-- ---------------------------------------------------------------------------
-- 3. 退会RPCを、残っているテーブルだけを見るように作り直す
--    (削除済みテーブルを参照したままだと退会処理が実行時エラーになる)
-- ---------------------------------------------------------------------------
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  -- 集まり関連: gathering_applications/gathering_messages/gathering_reads は
  -- auth.users へ ON DELETE CASCADE なしで参照しているため先に消しておく
  -- (主催している gatherings は host_id = uid の削除時に cascade で処理される)。
  delete from public.gathering_reads where user_id = uid;
  delete from public.gathering_messages where sender_id = uid;
  delete from public.gathering_applications where applicant_id = uid;
  delete from public.gatherings where host_id = uid;

  delete from public.user_actions where actor_id = uid or target_id = uid;
  delete from public.reports where reporter_id = uid or reported_id = uid;
  delete from public.profile_photos where user_id = uid;

  -- Storage上の実ファイルもここで消す(SQL関数からStorage APIは呼べないため、
  -- storage.objects を直接削除する)。
  delete from storage.objects
  where bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = uid::text;

  delete from public.profiles where id = uid;
  delete from auth.users where id = uid;
end;
$function$;

grant execute on function public.delete_own_account() to authenticated;

commit;

-- ---------------------------------------------------------------------------
-- 【任意・要判断】ここから下は実行前に必ず内容を確認すること。
-- ---------------------------------------------------------------------------
--
-- (A) 1対1トークで送受信した画像は chat_photos バケットに残ったままになる。
--     messages テーブルを消した時点で参照する経路は無くなるが、ファイル自体は
--     残るため、消すなら以下を実行する(復元不可)。
--
-- delete from storage.objects where bucket_id = 'chat_photos';
--
-- (B) profiles には廃止済み機能のカラムが残っている。アプリからは一切読み書き
--     しないので残していても動作に影響はないが、「異性交際に関する情報を保持して
--     いない」状態を明確にしたい場合は gender を含めて落とすことになる。
--     ※ gender を消すと、将来届出を出して機能を戻す際に再取得が必要になる。
--
-- alter table public.profiles
--   drop column if exists show_like_count,
--   drop column if exists remaining_likes,
--   drop column if exists private_mode,
--   drop column if exists share_bonus_claimed,
--   drop column if exists membership_tier,
--   drop column if exists boost_expires_at;
--
-- alter table public.profiles drop column if exists gender;

-- purchase_likes_mock()には引数なし(常に+100いいね、金額バリデーションなし)のオーバーロードが残っており、
-- アプリからは既に呼ばれていないにもかかわらずAPI経由で誰でも直接叩けてしまい、
-- 無制限に無料でいいねを増やせてしまう抜け穴になっていた。
-- アプリはpurchase_likes_mock(p_amount integer)(10/50/100のみ許可)しか使わないため、
-- 引数なし版は削除する。
drop function if exists public.purchase_likes_mock();

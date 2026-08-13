-- 都道府県よりも詳細な市区町村(政令指定都市の区・東京23区など)を保持するための任意カラム。
-- area(都道府県/州/国)の意味は変えず、より細かい絞り込み用の追加情報として持たせる。
alter table public.profiles add column if not exists city text;

import { SupabaseClient } from "@supabase/supabase-js";

// ユーザーIDごとのメイン写真(order_number = 0)のURLをまとめて引く。
// 集まりの一覧・詳細や、非表示/ブロック一覧のサムネイル表示で使う。
export async function loadMainPhotoUrls(
  supabase: SupabaseClient,
  userIds: string[]
): Promise<Record<string, string>> {
  if (userIds.length === 0) return {};
  const { data } = await supabase
    .from("profile_photos")
    .select("user_id, url, order_number")
    .in("user_id", userIds)
    .order("order_number", { ascending: true });
  const result: Record<string, string> = {};
  for (const row of data ?? []) {
    if (!(row.user_id in result)) {
      result[row.user_id] = row.url;
    }
  }
  return result;
}

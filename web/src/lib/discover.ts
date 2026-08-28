import { SupabaseClient } from "@supabase/supabase-js";
import { genderLabelToRawValue, oppositeGenderRawValue } from "./constants";
import { DiscoverFilter, isDiscoverFilterActive, maxBirthdayString } from "./types";

// iOS版 DiscoverManager.applyCandidateFilters と同じ絞り込みロジック。
// 同じ大学・異性(または明示的に選んだ性別)・非プライベートモードのユーザーのみを対象にする。
export function applyCandidateFilters(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  query: any,
  {
    myGender,
    myUniversityId,
    myId,
    excludedIds,
    filter,
  }: {
    myGender: string | null;
    myUniversityId: string;
    myId: string;
    excludedIds: Set<string>;
    filter: DiscoverFilter;
  }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
): any {
  if (filter.genders.length > 0) {
    const rawValues = filter.genders
      .map((label) => genderLabelToRawValue(label))
      .filter((v): v is string => Boolean(v));
    query = query.in("gender", rawValues);
  } else {
    query = query.eq("gender", oppositeGenderRawValue(myGender));
  }

  query = query
    .eq("private_mode", false)
    .neq("id", myId)
    .eq("university_id", myUniversityId);

  if (excludedIds.size > 0) {
    query = query.not("id", "in", `(${Array.from(excludedIds).join(",")})`);
  }
  if (filter.nationalities.length > 0) {
    query = query.overlaps("nationalities", filter.nationalities);
  }
  if (filter.personalities.length > 0) {
    query = query.in("body_type", filter.personalities);
  }
  if (filter.majors.length > 0) {
    query = query.in("major", filter.majors);
  }
  if (isDiscoverFilterActive(filter)) {
    query = query.lte("birthday", maxBirthdayString(filter.ageMin));
  }

  return query;
}

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

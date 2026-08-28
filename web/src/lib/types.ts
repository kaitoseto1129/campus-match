// iOSアプリのProfile.swiftと対応するデータ型。カラム名はDBのsnake_caseをそのまま使う
// (iOS側はCodingKeysで変換しているが、Web側はSupabaseの行を素直な型として扱う)。

export type Gender = "male" | "female" | "other";

export interface University {
  id: string;
  name: string;
  domain: string;
  country: string | null;
  prefecture: string | null;
}

export interface Profile {
  id: string;
  university_id: string;
  name: string;
  description: string | null;
  gender: Gender | null;
  birthday: string | null;
  profile_image_url: string | null;
  area: string | null;
  city: string | null;
  major: string | null;
  nationalities: string[];
  tagline: string | null;
  show_like_count: boolean;
  remaining_likes: number;
  private_mode: boolean;
  show_online_status: boolean;
  drinking: string | null;
  smoking: string | null;
  body_type: string | null; // 「性格」。DBのカラム名は旧仕様のまま(body_type)。
  languages: string[];
  membership_tier: "free" | "premium" | "vip" | null;
  hobby_cards: string[];
  boost_expires_at: string | null;
  last_active_at: string;
}

export function isBoostActive(profile: Profile | null): boolean {
  if (!profile?.boost_expires_at) return false;
  return new Date(profile.boost_expires_at) > new Date();
}

export const membershipTierLabel: Record<string, string> = {
  free: "無料会員",
  premium: "プレミアム会員",
  vip: "VIP会員",
};

export interface ProfilePhoto {
  id: string;
  user_id: string;
  url: string;
  order_number: number;
}

// プロフィールが完成しているか(iOS版 Profile.isProfileComplete と同じ判定)。
export function isProfileComplete(profile: Profile | null): boolean {
  if (!profile) return false;
  return Boolean(profile.gender) && Boolean(profile.birthday) && Boolean(profile.description);
}

export interface Like {
  id: string;
  from_user_id: string;
  to_user_id: string;
  is_special: boolean;
  created_at: string;
}

export interface Message {
  id: string;
  created_at: string;
  match_id: string;
  sender_id: string;
  body: string | null;
  image_url: string | null;
  read_at: string | null;
  deleted_at: string | null;
}

export interface Match {
  id: string;
  user_a_id: string;
  user_b_id: string;
  created_at: string;
}

// 探す画面の絞り込み条件。iOS版 Filtering.swift の DiscoverFilter と対応する。
export interface DiscoverFilter {
  ageMin: number;
  nationalities: string[];
  personalities: string[];
  majors: string[];
  // 空の場合は「自分と異性のみ」という既定の挙動(DiscoverManagerと同じ)。
  genders: string[]; // 日本語ラベル("男性"等)をそのまま値として使う。
}

export const MIN_AGE = 18;

export const defaultDiscoverFilter: DiscoverFilter = {
  ageMin: MIN_AGE,
  nationalities: [],
  personalities: [],
  majors: [],
  genders: [],
};

export function isDiscoverFilterActive(filter: DiscoverFilter): boolean {
  return (
    filter.ageMin > MIN_AGE ||
    filter.nationalities.length > 0 ||
    filter.personalities.length > 0 ||
    filter.majors.length > 0 ||
    filter.genders.length > 0
  );
}

// 「ageMin歳以上」を満たす誕生日の上限(この日以前に生まれていればageMin歳以上)。
export function maxBirthdayString(ageMin: number): string {
  const date = new Date();
  date.setUTCFullYear(date.getUTCFullYear() - ageMin);
  return date.toISOString().slice(0, 10);
}

export interface Gathering {
  id: string;
  host_id: string;
  university_id: string;
  title: string;
  description: string | null;
  location: string;
  scheduled_at: string;
  capacity: number;
  status: "open" | "closed" | "canceled";
  created_at: string;
  image_url: string | null;
  category: string | null;
  duration_hours: number | null;
  deadline_at: string | null;
  deadline_notified: boolean;
}

export interface GatheringApplication {
  id: string;
  gathering_id: string;
  applicant_id: string;
  comment: string | null;
  status: "pending" | "accepted" | "declined" | "canceled";
  created_at: string;
  responded_at: string | null;
}

export interface GatheringMessage {
  id: string;
  gathering_id: string;
  sender_id: string;
  body: string;
  created_at: string;
}

export function isGatheringPastDeadline(gathering: Gathering): boolean {
  return gathering.deadline_at ? new Date(gathering.deadline_at) < new Date() : false;
}

export function ageFromBirthday(birthday: string | null): number | null {
  if (!birthday) return null;
  const birthDate = new Date(birthday);
  const today = new Date();
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age -= 1;
  }
  return age;
}

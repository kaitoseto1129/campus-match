// iOSアプリのProfile.swiftと対応するデータ型。カラム名はDBのsnake_caseをそのまま使う
// (iOS側はCodingKeysで変換しているが、Web側はSupabaseの行を素直な型として扱う)。
//
// 性別(profiles.gender)はDBには残っているが、アプリからは読み書きしない。
// 性別を出したり性別で相手を絞り込めたりすると「異性紹介」の性格を帯びるため、
// 本アプリでは扱わない方針(利用規約の「異性交際目的の利用禁止」と対になっている)。

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
  birthday: string | null;
  profile_image_url: string | null;
  area: string | null;
  city: string | null;
  major: string | null;
  nationalities: string[];
  tagline: string | null;
  show_online_status: boolean;
  drinking: string | null;
  smoking: string | null;
  languages: string[];
  hobby_cards: string[];
  last_active_at: string;
}

export interface ProfilePhoto {
  id: string;
  user_id: string;
  url: string;
  order_number: number;
}

// プロフィールが完成しているか(iOS版 Profile.isProfileComplete と同じ判定)。
export function isProfileComplete(profile: Profile | null): boolean {
  if (!profile) return false;
  return Boolean(profile.birthday) && Boolean(profile.description);
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


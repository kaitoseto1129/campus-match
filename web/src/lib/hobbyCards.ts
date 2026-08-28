// iOS版 HobbyCard.swift の catalog と完全に同じ内容(id・絵文字・カテゴリ)を保つこと。
// profiles.hobby_cards には catalog の id のみを文字列配列で保存する。

export type HobbyCategory =
  | "おでかけ"
  | "エンタメ"
  | "スポーツ"
  | "グルメ"
  | "クリエイティブ"
  | "ライフスタイル";

export interface HobbyCardDef {
  id: string;
  emoji: string;
  title: string;
  category: HobbyCategory;
}

export const hobbyCardCatalog: HobbyCardDef[] = [
  { id: "cafe", emoji: "☕", title: "カフェ巡り", category: "おでかけ" },
  { id: "travel", emoji: "✈️", title: "旅行", category: "おでかけ" },
  { id: "drive", emoji: "🚗", title: "ドライブ", category: "おでかけ" },
  { id: "camp", emoji: "⛺", title: "キャンプ", category: "おでかけ" },
  { id: "festival", emoji: "🎆", title: "お祭り・花火", category: "おでかけ" },
  { id: "movie", emoji: "🎬", title: "映画", category: "エンタメ" },
  { id: "music", emoji: "🎵", title: "音楽・ライブ", category: "エンタメ" },
  { id: "anime", emoji: "📺", title: "アニメ", category: "エンタメ" },
  { id: "game", emoji: "🎮", title: "ゲーム", category: "エンタメ" },
  { id: "karaoke", emoji: "🎤", title: "カラオケ", category: "エンタメ" },
  { id: "reading", emoji: "📚", title: "読書", category: "エンタメ" },
  { id: "gym", emoji: "💪", title: "筋トレ・ジム", category: "スポーツ" },
  { id: "running", emoji: "🏃", title: "ランニング", category: "スポーツ" },
  { id: "sports_watch", emoji: "⚽", title: "スポーツ観戦", category: "スポーツ" },
  { id: "snow", emoji: "🏂", title: "スノボ・スキー", category: "スポーツ" },
  { id: "gourmet", emoji: "🍽️", title: "食べ歩き", category: "グルメ" },
  { id: "cooking", emoji: "🍳", title: "料理", category: "グルメ" },
  { id: "sweets", emoji: "🍰", title: "スイーツ", category: "グルメ" },
  { id: "drinking", emoji: "🍻", title: "お酒", category: "グルメ" },
  { id: "photo", emoji: "📷", title: "写真", category: "クリエイティブ" },
  { id: "art", emoji: "🎨", title: "アート", category: "クリエイティブ" },
  { id: "instrument", emoji: "🎸", title: "楽器", category: "クリエイティブ" },
  { id: "programming", emoji: "💻", title: "プログラミング", category: "クリエイティブ" },
  { id: "fashion", emoji: "👗", title: "ファッション", category: "ライフスタイル" },
  { id: "pet", emoji: "🐶", title: "ペット", category: "ライフスタイル" },
  { id: "study", emoji: "✏️", title: "勉強・資格", category: "ライフスタイル" },
  { id: "language", emoji: "🗣️", title: "語学", category: "ライフスタイル" },
  { id: "shopping", emoji: "🛍️", title: "ショッピング", category: "ライフスタイル" },
];

export const hobbyCategoryOrder: HobbyCategory[] = [
  "おでかけ",
  "エンタメ",
  "スポーツ",
  "グルメ",
  "クリエイティブ",
  "ライフスタイル",
];

export const HOBBY_CARD_MAX_SELECTION = 10;

const catalogById = new Map(hobbyCardCatalog.map((c) => [c.id, c]));

// iOS版 HobbyCard.cards(for:) と同じ: catalogに存在しないidは黙って無視する。
export function hobbyCardsFor(ids: string[]): HobbyCardDef[] {
  return ids.map((id) => catalogById.get(id)).filter((c): c is HobbyCardDef => Boolean(c));
}

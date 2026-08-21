//
//  HobbyCard.swift
//  Matching App
//

import SwiftUI

/// プロフィールに付けられる趣味カード。
/// DBにはidの配列(profiles.hobby_cards)だけを保存し、表示に使う絵文字・色はアプリ側で持つ。
/// こうしておくと、後からラベルや配色を変えてもDBの移行が要らない。
struct HobbyCard: Identifiable, Hashable {
    let id: String
    let emoji: String
    let title: String
    let category: HobbyCategory

    var color: Color { category.color }
}

enum HobbyCategory: String, CaseIterable, Identifiable {
    case outing = "おでかけ"
    case entertainment = "エンタメ"
    case sports = "スポーツ"
    case food = "グルメ"
    case creative = "クリエイティブ"
    case lifestyle = "ライフスタイル"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .outing: return Color.brandTeal
        case .entertainment: return Color.brandPurple
        case .sports: return Color.brandOrange
        case .food: return Color.brandPink
        case .creative: return Color(red: 0.45, green: 0.62, blue: 0.95)
        case .lifestyle: return Color(red: 0.36, green: 0.75, blue: 0.52)
        }
    }
}

extension HobbyCard {
    /// 選択肢の一覧。IDは永続化されるため、一度公開したものは変更しないこと。
    static let catalog: [HobbyCard] = [
        // おでかけ
        HobbyCard(id: "cafe", emoji: "☕️", title: "カフェ巡りが好き", category: .outing),
        HobbyCard(id: "travel", emoji: "✈️", title: "旅行が好き", category: .outing),
        HobbyCard(id: "drive", emoji: "🚗", title: "ドライブが好き", category: .outing),
        HobbyCard(id: "camp", emoji: "⛺️", title: "キャンプ・アウトドアが好き", category: .outing),
        HobbyCard(id: "festival", emoji: "🎪", title: "フェス・イベントが好き", category: .outing),

        // エンタメ
        HobbyCard(id: "movie", emoji: "🎬", title: "映画を見るのが好き", category: .entertainment),
        HobbyCard(id: "music", emoji: "🎧", title: "音楽を聴くのが好き", category: .entertainment),
        HobbyCard(id: "anime", emoji: "📺", title: "アニメ・漫画が好き", category: .entertainment),
        HobbyCard(id: "game", emoji: "🎮", title: "ゲームが好き", category: .entertainment),
        HobbyCard(id: "karaoke", emoji: "🎤", title: "カラオケが好き", category: .entertainment),
        HobbyCard(id: "reading", emoji: "📚", title: "読書が好き", category: .entertainment),

        // スポーツ
        HobbyCard(id: "gym", emoji: "💪", title: "筋トレが好き", category: .sports),
        HobbyCard(id: "running", emoji: "🏃", title: "ランニングが好き", category: .sports),
        HobbyCard(id: "sports_watch", emoji: "⚽️", title: "スポーツ観戦が好き", category: .sports),
        HobbyCard(id: "snow", emoji: "🏂", title: "スノボ・スキーが好き", category: .sports),

        // グルメ
        HobbyCard(id: "gourmet", emoji: "🍽", title: "食べ歩きが好き", category: .food),
        HobbyCard(id: "cooking", emoji: "🍳", title: "料理をするのが好き", category: .food),
        HobbyCard(id: "sweets", emoji: "🍰", title: "スイーツが好き", category: .food),
        HobbyCard(id: "drinking", emoji: "🍻", title: "お酒を飲むのが好き", category: .food),

        // クリエイティブ
        HobbyCard(id: "photo", emoji: "📷", title: "写真を撮るのが好き", category: .creative),
        HobbyCard(id: "art", emoji: "🎨", title: "美術館・アートが好き", category: .creative),
        HobbyCard(id: "instrument", emoji: "🎸", title: "楽器を演奏するのが好き", category: .creative),
        HobbyCard(id: "programming", emoji: "💻", title: "ものづくり・開発が好き", category: .creative),

        // ライフスタイル
        HobbyCard(id: "fashion", emoji: "👗", title: "ファッションが好き", category: .lifestyle),
        HobbyCard(id: "pet", emoji: "🐶", title: "動物が好き", category: .lifestyle),
        HobbyCard(id: "study", emoji: "📝", title: "勉強・資格取得が好き", category: .lifestyle),
        HobbyCard(id: "language", emoji: "🌏", title: "語学・国際交流が好き", category: .lifestyle),
        HobbyCard(id: "shopping", emoji: "🛍", title: "ショッピングが好き", category: .lifestyle)
    ]

    private static let byId: [String: HobbyCard] = Dictionary(
        uniqueKeysWithValues: catalog.map { ($0.id, $0) }
    )

    static func card(for id: String) -> HobbyCard? { byId[id] }

    /// 保存済みのID配列を、カタログ順を保った表示用の配列に変換する。
    /// カタログから消えたIDは無視されるため、選択肢を整理しても表示が壊れない。
    static func cards(for ids: [String]) -> [HobbyCard] {
        catalog.filter { ids.contains($0.id) }
    }
}

/// 趣味カードをそのまま並べるチップ表示。プロフィール表示・マイページで共通利用する。
struct HobbyCardChip: View {
    let card: HobbyCard
    var isSelected: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Text(card.emoji)
            Text(LocalizedStringKey(card.title))
                .font(.caption.bold())
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isSelected ? card.color.opacity(0.16) : Color(.systemGray6),
            in: Capsule()
        )
        .overlay {
            Capsule().stroke(isSelected ? card.color : Color.clear, lineWidth: 1.5)
        }
        .foregroundStyle(isSelected ? card.color : Color.secondary)
    }
}

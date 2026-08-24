//
//  Gathering.swift
//  Matching App
//

import Foundation

/// 集まりのカテゴリ。自由入力ではなく固定リストにして、絞り込みで使いやすくしている。
let gatheringCategoryOptions: [String] = ["ご飯", "カフェ・勉強", "スポーツ・アウトドア", "遊び・観光", "イベント参加", "その他"]

/// 恋愛マッチングとは別の、同じ大学の人同士で「ご飯行きませんか」のような
/// 少人数の集まりを募集・応募できる機能。性別は問わず、同じ大学の人なら誰でも応募できる。
struct Gathering: Codable, Identifiable, Equatable {
    let id: UUID
    let hostId: UUID
    let universityId: UUID
    let title: String
    let description: String?
    let location: String
    let scheduledAtString: String
    /// 主催者本人を含めた合計人数の上限。
    let capacity: Int
    let status: String
    let createdAtString: String
    let imageUrlString: String?
    let category: String?
    /// だいたいの所要時間(時間単位)。任意入力で、未入力の集まりもある。
    let durationHours: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case universityId = "university_id"
        case title, description, location
        case scheduledAtString = "scheduled_at"
        case capacity, status
        case createdAtString = "created_at"
        case imageUrlString = "image_url"
        case category
        case durationHours = "duration_hours"
    }

    var scheduledAt: Date { ISO8601DateFormatter.matchingApp.date(from: scheduledAtString) ?? Date() }
    var isOpen: Bool { status == "open" }
    var isPast: Bool { scheduledAt < Date() }
    var imageURL: URL? { imageUrlString.flatMap(URL.init(string:)) }
}

struct GatheringApplication: Codable, Identifiable, Equatable {
    let id: UUID
    let gatheringId: UUID
    let applicantId: UUID
    let comment: String?
    let status: String
    let createdAtString: String
    let respondedAtString: String?

    enum CodingKeys: String, CodingKey {
        case id
        case gatheringId = "gathering_id"
        case applicantId = "applicant_id"
        case comment, status
        case createdAtString = "created_at"
        case respondedAtString = "responded_at"
    }

    var createdAt: Date { ISO8601DateFormatter.matchingApp.date(from: createdAtString) ?? Date() }
}

struct GatheringMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let gatheringId: UUID
    let senderId: UUID
    let body: String
    let createdAtString: String

    enum CodingKeys: String, CodingKey {
        case id
        case gatheringId = "gathering_id"
        case senderId = "sender_id"
        case body
        case createdAtString = "created_at"
    }

    var createdAt: Date { ISO8601DateFormatter.matchingApp.date(from: createdAtString) ?? Date() }
}

struct GatheringInsertPayload: Encodable {
    let hostId: UUID
    let universityId: UUID
    let title: String
    let description: String?
    let location: String
    let scheduledAtString: String
    let capacity: Int
    let category: String
    let durationHours: Int

    enum CodingKeys: String, CodingKey {
        case hostId = "host_id"
        case universityId = "university_id"
        case title, description, location
        case scheduledAtString = "scheduled_at"
        case capacity, category
        case durationHours = "duration_hours"
    }
}

struct GatheringApplicationInsertPayload: Encodable {
    let gatheringId: UUID
    let applicantId: UUID
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case gatheringId = "gathering_id"
        case applicantId = "applicant_id"
        case comment
    }
}

struct GatheringMessageInsertPayload: Encodable {
    let gatheringId: UUID
    let senderId: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case gatheringId = "gathering_id"
        case senderId = "sender_id"
        case body
    }
}

/// 一覧・詳細表示用に、集まりへ主催者プロフィール・応募状況をまとめたもの。
struct GatheringSummary: Identifiable {
    let gathering: Gathering
    let hostProfile: Profile?
    let hostPhotoURL: URL?
    /// 承認済みの応募者数(主催者は含まない)。
    let acceptedCount: Int
    /// 自分自身の応募(あれば)。
    let myApplication: GatheringApplication?

    var id: UUID { gathering.id }

    /// 主催者を含めた現在の参加人数。
    var currentMemberCount: Int { acceptedCount + 1 }

    var isFull: Bool { currentMemberCount >= gathering.capacity }

    var isHost: Bool
    var isAcceptedMember: Bool { myApplication?.status == "accepted" }
    /// グループトーク・詳細な参加者情報にアクセスできるか。
    var isMember: Bool { isHost || isAcceptedMember }
}

/// 「みんなの募集」タブの絞り込み条件(日付・カテゴリ)。
struct GatheringBrowseFilter: Equatable {
    var dateFrom: Date? = nil
    var dateTo: Date? = nil
    var categories: Set<String> = []

    var isActive: Bool { dateFrom != nil || dateTo != nil || !categories.isEmpty }

    func matches(_ summary: GatheringSummary) -> Bool {
        let calendar = Calendar.current
        if let dateFrom, summary.gathering.scheduledAt < calendar.startOfDay(for: dateFrom) {
            return false
        }
        if let dateTo {
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dateTo)) ?? dateTo
            if summary.gathering.scheduledAt >= endOfDay { return false }
        }
        if !categories.isEmpty {
            guard let category = summary.gathering.category, categories.contains(category) else { return false }
        }
        return true
    }
}

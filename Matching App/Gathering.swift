//
//  Gathering.swift
//  Matching App
//

import Foundation

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

    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case universityId = "university_id"
        case title, description, location
        case scheduledAtString = "scheduled_at"
        case capacity, status
        case createdAtString = "created_at"
    }

    var scheduledAt: Date { ISO8601DateFormatter.matchingApp.date(from: scheduledAtString) ?? Date() }
    var isOpen: Bool { status == "open" }
    var isPast: Bool { scheduledAt < Date() }
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

    enum CodingKeys: String, CodingKey {
        case hostId = "host_id"
        case universityId = "university_id"
        case title, description, location
        case scheduledAtString = "scheduled_at"
        case capacity
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

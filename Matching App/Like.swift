//
//  Like.swift
//  Matching App
//

import Foundation

struct Like: Codable, Identifiable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let remindedAtString: String?
    let isSpecial: Bool
    var isReminded: Bool { remindedAtString != nil }
    var remindedAt: Date? {
        guard let remindedAtString else { return nil }
        return ISO8601DateFormatter.matchingApp.date(from: remindedAtString)
    }
    /// みてねは月1回まで送れる。前回送信から30日以上経っていれば再送可能。
    var canSendReminder: Bool {
        guard let remindedAt else { return true }
        return Date().timeIntervalSince(remindedAt) >= 30 * 24 * 60 * 60
    }

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case remindedAtString = "reminded_at"
        case isSpecial = "is_special"
    }
}

struct LikeInsertPayload: Encodable {
    let fromUserId: UUID
    let toUserId: UUID
    let isSpecial: Bool

    init(fromUserId: UUID, toUserId: UUID, isSpecial: Bool = false) {
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.isSpecial = isSpecial
    }

    enum CodingKeys: String, CodingKey {
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case isSpecial = "is_special"
    }
}

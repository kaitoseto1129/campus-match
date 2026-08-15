//
//  Like.swift
//  Matching App
//

import Foundation

struct Like: Codable, Identifiable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let isSpecial: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
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

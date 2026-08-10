//
//  Match.swift
//  Matching App
//

import Foundation

struct Match: Codable, Identifiable {
    let id: UUID
    let userAId: UUID
    let userBId: UUID
    let createdAtString: String?
    var createdAt: Date? {
        guard let createdAtString else { return nil }
        return ISO8601DateFormatter.matchingApp.date(from: createdAtString)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userAId = "user_a_id"
        case userBId = "user_b_id"
        case createdAtString = "created_at"
    }
}

struct MatchInsertPayload: Encodable {
    let likeId: UUID
    let userAId: UUID
    let userBId: UUID

    enum CodingKeys: String, CodingKey {
        case likeId = "like_id"
        case userAId = "user_a_id"
        case userBId = "user_b_id"
    }
}

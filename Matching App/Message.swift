//
//  Message.swift
//  Matching App
//

import Foundation

struct Message: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAtString: String
    let matchId: UUID
    let senderId: UUID
    let body: String?
    let imageUrlString: String?
    let readAtString: String?
    let deletedAtString: String?

    var isDeleted: Bool { deletedAtString != nil }
    var imageUrl: URL? {
        guard let imageUrlString else { return nil }
        return URL(string: imageUrlString)
    }
    var isRead: Bool { readAtString != nil }
    var createdAt: Date {
        Message.timestampFormatter.date(from: createdAtString) ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAtString = "created_at"
        case matchId = "match_id"
        case senderId = "sender_id"
        case body
        case imageUrlString = "image_url"
        case readAtString = "read_at"
        case deletedAtString = "deleted_at"
    }

    static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

struct MessageInsertPayload: Encodable {
    let matchId: UUID
    let senderId: UUID
    let body: String?
    let imageUrl: String?

    init(matchId: UUID, senderId: UUID, body: String? = nil, imageUrl: String? = nil) {
        self.matchId = matchId
        self.senderId = senderId
        self.body = body
        self.imageUrl = imageUrl
    }

    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case senderId = "sender_id"
        case body
        case imageUrl = "image_url"
    }
}

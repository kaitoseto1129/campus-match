//
//  CallRequest.swift
//  Matching App
//

import Foundation

enum CallRequestStatus: String, Codable, Equatable {
    case pending
    case accepted
    case declined
    case canceled
}

struct CallRequest: Codable, Identifiable, Equatable {
    let id: UUID
    let matchId: UUID
    let requesterId: UUID
    let status: CallRequestStatus
    let createdAtString: String

    enum CodingKeys: String, CodingKey {
        case id
        case matchId = "match_id"
        case requesterId = "requester_id"
        case status
        case createdAtString = "created_at"
    }
}

struct CallRequestInsertPayload: Encodable {
    let matchId: UUID
    let requesterId: UUID
    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case requesterId = "requester_id"
    }
}

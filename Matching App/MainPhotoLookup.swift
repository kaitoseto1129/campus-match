//
//  MainPhotoLookup.swift
//  Matching App
//

import Foundation
import Supabase

private struct PhotoCountRow: Decodable {
    let userId: UUID
    enum CodingKeys: String, CodingKey { case userId = "user_id" }
}

/// ユーザーごとの登録写真枚数。いいね履歴カードの「写真枚数バッジ」表示に使う。
func loadPhotoCounts(userIds: [UUID]) async -> [UUID: Int] {
    guard !userIds.isEmpty else { return [:] }
    do {
        let rows: [PhotoCountRow] = try await supabase()
            .from("profile_photos")
            .select("user_id")
            .in("user_id", values: userIds)
            .execute()
            .value
        return Dictionary(grouping: rows, by: \.userId).mapValues(\.count)
    } catch {
        print("photo count lookup error: \(error)")
        return [:]
    }
}

/// ユーザーごとのオンライン状態(is_user_online RPC)。非表示設定にしている相手はnullを返すため辞書に含めない。
func loadOnlineStatuses(userIds: [UUID]) async -> [UUID: Bool] {
    guard !userIds.isEmpty else { return [:] }
    return await withTaskGroup(of: (UUID, Bool?).self) { group in
        for id in userIds {
            group.addTask {
                let isOnline: Bool?
                do {
                    isOnline = try await supabase()
                        .rpc("is_user_online", params: ["target_user_id": id])
                        .execute()
                        .value
                } catch {
                    isOnline = nil
                }
                return (id, isOnline)
            }
        }
        var result: [UUID: Bool] = [:]
        for await (id, isOnline) in group {
            if let isOnline { result[id] = isOnline }
        }
        return result
    }
}

func loadMainPhotoURLs(userIds: [UUID]) async -> [UUID: URL] {
    guard !userIds.isEmpty else { return [:] }
    do {
        let photos: [ProfilePhoto] = try await supabase()
            .from("profile_photos")
            .select()
            .in("user_id", values: userIds)
            .eq("order_number", value: 0)
            .execute()
            .value
        var result: [UUID: URL] = [:]
        for photo in photos {
            result[photo.userId] = photo.url
        }
        return result
    } catch {
        print("main photo lookup error: \(error)")
        return [:]
    }
}

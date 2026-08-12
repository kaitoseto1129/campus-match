//
//  LikesManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

struct ReceivedLike: Identifiable {
    let like: Like
    let profile: Profile
    let photoURL: URL?
    var photoCount: Int = 0
    var isOnline: Bool?
    var commonPoints: Int = 0
    var id: UUID { like.id }
}

@MainActor
final class LikesManager: ObservableObject {
    @Published var received: [ReceivedLike] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var filter = DiscoverFilter()

    func load() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            let likeRows: [Like] = try await supabase()
                .from("likes")
                .select()
                .eq("to_user_id", value: myId)
                .execute()
                .value

            let matchRows: [Match] = try await supabase()
                .from("matches")
                .select()
                .or("user_a_id.eq.\(myId),user_b_id.eq.\(myId)")
                .execute()
                .value
            let matchedPartnerIds = Set(matchRows.map { $0.userAId == myId ? $0.userBId : $0.userAId })

            let pendingLikes = likeRows.filter { !matchedPartnerIds.contains($0.fromUserId) }
            let likesBySender = Dictionary(uniqueKeysWithValues: pendingLikes.map { ($0.fromUserId, $0) })
            let senderIds = pendingLikes.map(\.fromUserId)
            guard !senderIds.isEmpty else {
                received = []
                isLoading = false
                return
            }

            var query = supabase()
                .from("profiles")
                .select("*")
                .in("id", values: senderIds)
            if !filter.areas.isEmpty {
                query = query.in("area", values: Array(filter.areas))
            }
            if !filter.nationalities.isEmpty {
                query = query.overlaps("nationalities", value: Array(filter.nationalities))
            }
            if filter.isAgeFiltered {
                query = query
                    .gte("birthday", value: filter.minBirthdayString)
                    .lte("birthday", value: filter.maxBirthdayString)
            }
            if filter.isHeightFiltered {
                query = query
                    .gte("height", value: filter.heightMin)
                    .lte("height", value: filter.heightMax)
            }

            let profiles: [Profile] = try await query
                .order("last_active_at", ascending: false)
                .execute()
                .value
            let photoURLs = await loadMainPhotoURLs(userIds: profiles.map(\.id))
            let photoCounts = await loadPhotoCounts(userIds: profiles.map(\.id))
            let onlineStatuses = await loadOnlineStatuses(userIds: profiles.map(\.id))
            let myProfile: Profile? = try? await supabase()
                .from("profiles")
                .select("*")
                .eq("id", value: myId)
                .single()
                .execute()
                .value

            var results = profiles.compactMap { profile -> ReceivedLike? in
                guard let like = likesBySender[profile.id] else { return nil }
                return ReceivedLike(
                    like: like,
                    profile: profile,
                    photoURL: photoURLs[profile.id],
                    photoCount: photoCounts[profile.id] ?? 0,
                    isOnline: onlineStatuses[profile.id],
                    commonPoints: myProfile?.commonPointsCount(with: profile) ?? 0
                )
            }
            // 「見てね」(再アピール)されたものを先頭に表示する。
            results.sort { $0.like.isReminded && !$1.like.isReminded }
            received = results
        } catch {
            errorMessage = "いいねを読み込めませんでした"
            print("likes load error: \(error)")
        }
        isLoading = false
    }

    /// 成立したmatchを返す(呼び出し側でマッチ成立演出をその場で出すために使う。
    /// Realtimeの受信タイミングだけに頼ると、まれに演出が出ないことがあるための保険)。
    @discardableResult
    func sendThanks(for like: Like) async -> Match? {
        guard let myId = supabase().auth.currentUser?.id else { return nil }
        do {
            let (userAId, userBId) = myId.uuidString < like.fromUserId.uuidString
                ? (myId, like.fromUserId)
                : (like.fromUserId, myId)
            let match: Match = try await supabase()
                .from("matches")
                .insert(MatchInsertPayload(likeId: like.id, userAId: userAId, userBId: userBId))
                .select()
                .single()
                .execute()
                .value
            received.removeAll { $0.like.id == like.id }
            return match
        } catch {
            errorMessage = "マッチ処理に失敗しました"
            print("send thanks error: \(error)")
            return nil
        }
    }
}

//
//  SentLikesManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

struct SentLike: Identifiable {
    let like: Like
    let profile: Profile
    let photoURL: URL?
    let isMatched: Bool
    var photoCount: Int = 0
    var isOnline: Bool?
    var commonPoints: Int = 0
    var id: UUID { like.id }
}

@MainActor
final class SentLikesManager: ObservableObject {
    @Published var sent: [SentLike] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            let likeRows: [Like] = try await supabase()
                .from("likes")
                .select()
                .eq("from_user_id", value: myId)
                .execute()
                .value

            let matchRows: [Match] = try await supabase()
                .from("matches")
                .select()
                .or("user_a_id.eq.\(myId),user_b_id.eq.\(myId)")
                .execute()
                .value
            let matchedPartnerIds = Set(matchRows.map { $0.userAId == myId ? $0.userBId : $0.userAId })

            let likesByReceiver = Dictionary(uniqueKeysWithValues: likeRows.map { ($0.toUserId, $0) })
            let receiverIds = likeRows.map(\.toUserId)
            guard !receiverIds.isEmpty else {
                sent = []
                isLoading = false
                return
            }

            let profiles: [Profile] = try await supabase()
                .from("profiles")
                .select("*")
                .in("id", values: receiverIds)
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

            sent = profiles.compactMap { profile in
                guard let like = likesByReceiver[profile.id] else { return nil }
                return SentLike(
                    like: like,
                    profile: profile,
                    photoURL: photoURLs[profile.id],
                    isMatched: matchedPartnerIds.contains(profile.id),
                    photoCount: photoCounts[profile.id] ?? 0,
                    isOnline: onlineStatuses[profile.id],
                    commonPoints: myProfile?.commonPointsCount(with: profile) ?? 0
                )
            }
        } catch {
            errorMessage = "いいね履歴を読み込めませんでした"
            print("sent likes load error: \(error)")
        }
        isLoading = false
    }

}

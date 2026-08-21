//
//  FootprintsManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

struct Footprint: Identifiable {
    let visitId: UUID
    let profile: Profile
    let photoURL: URL?
    var id: UUID { visitId }
}

@MainActor
final class FootprintsManager: ObservableObject {
    @Published var footprints: [Footprint] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// 既にいいね済みの相手のID。足あと画面から重複していいねを送ろうとして
    /// unique制約違反になり、原因不明な「いいねが足りません」表示になっていた不具合の修正用。
    @Published var likedIds: Set<UUID> = []

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
            likedIds = Set(likeRows.map(\.toUserId))
            struct VisitRow: Decodable {
                let id: UUID
                let viewerId: UUID
                let createdAtString: String
                enum CodingKeys: String, CodingKey {
                    case id
                    case viewerId = "viewer_id"
                    case createdAtString = "created_at"
                }
            }
            let visitRows: [VisitRow] = try await supabase()
                .from("profile_visits")
                .select()
                .eq("visited_id", value: myId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let blockedIds = await UserModeration.hiddenOrBlockedIds(actorId: myId)

            // 同じ相手からの複数回の訪問は最新の1件にまとめる
            var latestByViewer: [UUID: VisitRow] = [:]
            for row in visitRows where latestByViewer[row.viewerId] == nil && !blockedIds.contains(row.viewerId) {
                latestByViewer[row.viewerId] = row
            }
            let viewerIds = Array(latestByViewer.keys)
            guard !viewerIds.isEmpty else {
                footprints = []
                isLoading = false
                return
            }

            let profiles: [Profile] = try await supabase()
                .from("profiles")
                .select("*")
                .in("id", values: viewerIds)
                .execute()
                .value
            let photoURLs = await loadMainPhotoURLs(userIds: viewerIds)

            var results = profiles.compactMap { profile -> Footprint? in
                guard let visit = latestByViewer[profile.id] else { return nil }
                return Footprint(visitId: visit.id, profile: profile, photoURL: photoURLs[profile.id])
            }
            results.sort {
                (latestByViewer[$0.profile.id]?.createdAtString ?? "") > (latestByViewer[$1.profile.id]?.createdAtString ?? "")
            }
            footprints = results
        } catch {
            errorMessage = "足あとを読み込めませんでした"
            print("footprints load error: \(error)")
        }
        isLoading = false
    }
}

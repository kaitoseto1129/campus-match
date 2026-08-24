//
//  ChatManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

struct MatchedChat: Identifiable {
    let match: Match
    let profile: Profile
    let photoURL: URL?
    var lastMessage: Message?
    var unreadCount: Int = 0
    var id: UUID { match.id }
}

enum ChatSortMode {
    case recent
    case unreplied
}

@MainActor
final class ChatManager: ObservableObject {
    @Published var matches: [MatchedChat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sortMode: ChatSortMode = .recent {
        didSet { applySort() }
    }

    func load() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            let matchRows: [Match] = try await supabase()
                .from("matches")
                .select()
                .or("user_a_id.eq.\(myId),user_b_id.eq.\(myId)")
                .execute()
                .value

            struct HiddenMatchRow: Decodable {
                let matchId: UUID
                enum CodingKeys: String, CodingKey { case matchId = "match_id" }
            }
            let hiddenRows: [HiddenMatchRow] = try await supabase()
                .from("hidden_matches")
                .select("match_id")
                .eq("user_id", value: myId)
                .execute()
                .value
            let hiddenMatchIds = Set(hiddenRows.map(\.matchId))
            // 自分がブロックした相手・自分をブロックした相手、どちらとのトークも一覧から除外する。
            let blockedIds = await UserModeration.blockedCounterpartIds(myId: myId)
            let visibleMatchRows = matchRows.filter { match in
                let otherId = match.userAId == myId ? match.userBId : match.userAId
                return !hiddenMatchIds.contains(match.id) && !blockedIds.contains(otherId)
            }

            let otherIds = visibleMatchRows.map { $0.userAId == myId ? $0.userBId : $0.userAId }
            guard !otherIds.isEmpty else {
                matches = []
                isLoading = false
                return
            }

            let profiles: [Profile] = try await supabase()
                .from("profiles")
                .select("*")
                .in("id", values: otherIds)
                .execute()
                .value
            let profilesById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            let photoURLs = await loadMainPhotoURLs(userIds: otherIds)

            let messageRows: [Message] = try await supabase()
                .from("messages")
                .select()
                .in("match_id", values: visibleMatchRows.map(\.id))
                .order("created_at", ascending: true)
                .execute()
                .value
            var lastMessageByMatch: [UUID: Message] = [:]
            var unreadCountByMatch: [UUID: Int] = [:]
            for message in messageRows {
                lastMessageByMatch[message.matchId] = message
                if message.senderId != myId && !message.isRead {
                    unreadCountByMatch[message.matchId, default: 0] += 1
                }
            }

            matches = visibleMatchRows.compactMap { match -> MatchedChat? in
                let otherId = match.userAId == myId ? match.userBId : match.userAId
                guard let profile = profilesById[otherId] else { return nil }
                return MatchedChat(
                    match: match,
                    profile: profile,
                    photoURL: photoURLs[otherId],
                    lastMessage: lastMessageByMatch[match.id],
                    unreadCount: unreadCountByMatch[match.id] ?? 0
                )
            }
            applySort()
        } catch {
            errorMessage = "マッチ一覧を読み込めませんでした"
            print("chat load error: \(error)")
        }
        isLoading = false
    }

    private func applySort() {
        switch sortMode {
        case .recent:
            matches.sort { ($0.lastMessage?.createdAt ?? .distantPast) > ($1.lastMessage?.createdAt ?? .distantPast) }
        case .unreplied:
            guard let myId = supabase().auth.currentUser?.id else { return }
            matches.sort { a, b in
                let aUnreplied = a.lastMessage != nil && a.lastMessage?.senderId != myId
                let bUnreplied = b.lastMessage != nil && b.lastMessage?.senderId != myId
                if aUnreplied != bUnreplied { return aUnreplied && !bUnreplied }
                return (a.lastMessage?.createdAt ?? .distantPast) > (b.lastMessage?.createdAt ?? .distantPast)
            }
        }
    }
}

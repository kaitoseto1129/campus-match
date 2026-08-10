//
//  MatchManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

@MainActor
final class MatchManager: ObservableObject {
    @Published var celebratingMatch: MatchedChat?
    @Published var myPhotoURL: URL?

    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    /// 一度演出を出したmatchのIDを覚えておき、Realtime経由での重複表示を防ぐ。
    private var celebratedMatchIds: Set<UUID> = []

    func start() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        let photoURLs = await loadMainPhotoURLs(userIds: [myId])
        myPhotoURL = photoURLs[myId]

        let ch = supabase().channel("matches:\(myId.uuidString)")
        let insertions = ch.postgresChange(InsertAction.self, table: "matches")
        channel = ch
        await ch.subscribe()

        listenTask = Task { [weak self] in
            for await insertion in insertions {
                guard let self else { return }
                guard let match = try? insertion.decodeRecord(as: Match.self, decoder: JSONDecoder()) else { continue }
                guard match.userAId == myId || match.userBId == myId else { continue }
                await self.presentCelebration(for: match, myId: myId)
            }
        }
    }

    func stop() async {
        listenTask?.cancel()
        listenTask = nil
        if let channel {
            await supabase().removeChannel(channel)
        }
        channel = nil
    }

    private func presentCelebration(for match: Match, myId: UUID) async {
        guard !celebratedMatchIds.contains(match.id) else { return }
        let otherId = match.userAId == myId ? match.userBId : match.userAId
        do {
            let profile: Profile = try await supabase()
                .from("profiles")
                .select("*")
                .eq("id", value: otherId)
                .single()
                .execute()
                .value
            let photoURLs = await loadMainPhotoURLs(userIds: [otherId])
            celebratedMatchIds.insert(match.id)
            celebratingMatch = MatchedChat(match: match, profile: profile, photoURL: photoURLs[otherId])
        } catch {
            print("match celebration load error: \(error)")
        }
    }

    /// LikesView側で「ありがとう」を押した直後など、Realtimeの受信を待たずに
    /// その場で確実に演出を出したい時に使う。
    func presentCelebrationImmediately(match: Match, profile: Profile, photoURL: URL?) {
        guard !celebratedMatchIds.contains(match.id) else { return }
        celebratedMatchIds.insert(match.id)
        celebratingMatch = MatchedChat(match: match, profile: profile, photoURL: photoURL)
    }
}

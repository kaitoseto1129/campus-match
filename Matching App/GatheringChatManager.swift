//
//  GatheringChatManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

@MainActor
final class GatheringChatManager: ObservableObject {
    @Published var messages: [GatheringMessage] = []
    @Published var isLoading = true
    @Published var isSending = false
    @Published var errorMessage: String?

    let gatheringId: UUID
    private var channel: RealtimeChannelV2?
    private var insertTask: Task<Void, Never>?

    init(gatheringId: UUID) {
        self.gatheringId = gatheringId
    }

    func load() async {
        do {
            let recent: [GatheringMessage] = try await supabase()
                .from("gathering_messages")
                .select()
                .eq("gathering_id", value: gatheringId)
                .order("created_at", ascending: true)
                .execute()
                .value
            messages = recent
        } catch {
            errorMessage = "メッセージを読み込めませんでした"
            print("gathering chat load error: \(error)")
        }
        isLoading = false
        await markRead()
    }

    func subscribe() async {
        let ch = supabase().channel("gathering_messages:\(gatheringId.uuidString)")
        let insertions = ch.postgresChange(
            InsertAction.self,
            table: "gathering_messages",
            filter: .eq("gathering_id", value: gatheringId.uuidString)
        )
        channel = ch
        await ch.subscribe()

        insertTask = Task { [weak self] in
            for await insertion in insertions {
                guard let self else { return }
                guard let message = try? insertion.decodeRecord(as: GatheringMessage.self, decoder: JSONDecoder()) else { continue }
                if !self.messages.contains(where: { $0.id == message.id }) {
                    self.messages.append(message)
                }
                if message.senderId != supabase().auth.currentUser?.id {
                    await self.markRead()
                }
            }
        }
    }

    func unsubscribe() async {
        insertTask?.cancel()
        insertTask = nil
        if let channel {
            await supabase().removeChannel(channel)
        }
        channel = nil
    }

    @discardableResult
    func send(text: String) async -> Bool {
        guard let myId = supabase().auth.currentUser?.id else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !NGWordFilter.containsNGWord(trimmed) else {
            errorMessage = "使用できない表現が含まれているため送信できません"
            return false
        }
        isSending = true
        defer { isSending = false }
        do {
            try await supabase()
                .from("gathering_messages")
                .insert(GatheringMessageInsertPayload(gatheringId: gatheringId, senderId: myId, body: trimmed))
                .execute()
            return true
        } catch {
            errorMessage = "メッセージの送信に失敗しました"
            print("gathering send message error: \(error)")
            return false
        }
    }

    private func markRead() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        struct Payload: Encodable {
            let gatheringId: UUID
            let userId: UUID
            let lastReadAtString: String
            enum CodingKeys: String, CodingKey {
                case gatheringId = "gathering_id"
                case userId = "user_id"
                case lastReadAtString = "last_read_at"
            }
        }
        do {
            try await supabase()
                .from("gathering_reads")
                .upsert(
                    Payload(gatheringId: gatheringId, userId: myId, lastReadAtString: ISO8601DateFormatter.matchingApp.string(from: Date())),
                    onConflict: "gathering_id,user_id"
                )
                .execute()
        } catch {
            print("gathering mark read error: \(error)")
        }
    }
}

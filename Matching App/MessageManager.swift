//
//  MessageManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine
import UIKit

@MainActor
final class MessageManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var isOtherUserTyping = false
    @Published var hasMoreOlderMessages = true
    @Published var isLoadingOlder = false
    /// 相手から届いた、まだ応答していない通話リクエスト。
    @Published var incomingCallRequest: CallRequest?
    /// 自分が送った通話リクエストの状態(nilなら何も送っていない)。
    @Published var outgoingCallRequestStatus: CallRequestStatus?

    private static let pageSize = 30
    let matchId: UUID
    private var channel: RealtimeChannelV2?
    private var insertTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?
    private var typingTask: Task<Void, Never>?
    private var typingResetTask: Task<Void, Never>?
    private var lastTypingSentAt: Date?
    private var callRequestInsertTask: Task<Void, Never>?
    private var callRequestUpdateTask: Task<Void, Never>?
    private var outgoingCallRequestId: UUID?

    init(matchId: UUID) {
        self.matchId = matchId
    }

    /// 直近分だけを読み込む。古いメッセージは loadOlderMessages() で必要な時だけ取得する。
    func load() async {
        do {
            let recent: [Message] = try await supabase()
                .from("messages")
                .select()
                .eq("match_id", value: matchId)
                .order("created_at", ascending: false)
                .limit(Self.pageSize)
                .execute()
                .value
            messages = recent.reversed()
            hasMoreOlderMessages = recent.count == Self.pageSize
        } catch {
            errorMessage = "メッセージを読み込めませんでした"
            print("message load error: \(error)")
        }
        await markRead()
    }

    /// 表示中の最も古いメッセージより前の分を追加で読み込む。
    func loadOlderMessages() async {
        guard hasMoreOlderMessages, !isLoadingOlder, let oldest = messages.first else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let older: [Message] = try await supabase()
                .from("messages")
                .select()
                .eq("match_id", value: matchId)
                .lt("created_at", value: oldest.createdAtString)
                .order("created_at", ascending: false)
                .limit(Self.pageSize)
                .execute()
                .value
            hasMoreOlderMessages = older.count == Self.pageSize
            messages.insert(contentsOf: older.reversed(), at: 0)
        } catch {
            errorMessage = "過去のメッセージを読み込めませんでした"
            print("load older messages error: \(error)")
        }
    }

    func subscribe() async {
        let ch = supabase().channel("messages:\(matchId.uuidString)")
        let insertions = ch.postgresChange(
            InsertAction.self,
            table: "messages",
            filter: .eq("match_id", value: matchId.uuidString)
        )
        let updates = ch.postgresChange(
            UpdateAction.self,
            table: "messages",
            filter: .eq("match_id", value: matchId.uuidString)
        )
        channel = ch
        await ch.subscribe()

        insertTask = Task { [weak self] in
            for await insertion in insertions {
                guard let self else { return }
                guard let message = try? insertion.decodeRecord(as: Message.self, decoder: JSONDecoder()) else { continue }
                if !self.messages.contains(where: { $0.id == message.id }) {
                    self.messages.append(message)
                }
                if message.senderId != supabase().auth.currentUser?.id {
                    await self.markRead()
                }
            }
        }

        updateTask = Task { [weak self] in
            for await update in updates {
                guard let self else { return }
                guard let message = try? update.decodeRecord(as: Message.self, decoder: JSONDecoder()) else { continue }
                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                    self.messages[index] = message
                }
            }
        }

        let typingEvents = ch.broadcastStream(event: "typing")
        let myId = supabase().auth.currentUser?.id
        typingTask = Task { [weak self] in
            for await payload in typingEvents {
                guard let self else { return }
                guard let senderIdString = payload["user_id"]?.stringValue,
                      let senderId = UUID(uuidString: senderIdString),
                      senderId != myId else { continue }
                let typing = payload["is_typing"]?.boolValue ?? false
                self.isOtherUserTyping = typing
                self.typingResetTask?.cancel()
                if typing {
                    self.typingResetTask = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        guard !Task.isCancelled else { return }
                        self?.isOtherUserTyping = false
                    }
                }
            }
        }

        let callRequestInserts = ch.postgresChange(
            InsertAction.self,
            table: "call_requests",
            filter: .eq("match_id", value: matchId.uuidString)
        )
        let callRequestUpdates = ch.postgresChange(
            UpdateAction.self,
            table: "call_requests",
            filter: .eq("match_id", value: matchId.uuidString)
        )
        callRequestInsertTask = Task { [weak self] in
            for await insertion in callRequestInserts {
                guard let self else { return }
                guard let request = try? insertion.decodeRecord(as: CallRequest.self, decoder: JSONDecoder()) else { continue }
                if request.requesterId != myId {
                    self.incomingCallRequest = request
                }
            }
        }
        callRequestUpdateTask = Task { [weak self] in
            for await update in callRequestUpdates {
                guard let self else { return }
                guard let request = try? update.decodeRecord(as: CallRequest.self, decoder: JSONDecoder()) else { continue }
                if request.requesterId == myId {
                    self.outgoingCallRequestStatus = request.status
                } else if self.incomingCallRequest?.id == request.id {
                    self.incomingCallRequest = request.status == .pending ? request : nil
                }
            }
        }
    }

    /// 入力中インジケーター用。連打を避けるため2秒に1回だけ送信する。
    func sendTypingStatus(isTyping: Bool) async {
        guard let channel, let myId = supabase().auth.currentUser?.id else { return }
        if isTyping, let lastTypingSentAt, Date().timeIntervalSince(lastTypingSentAt) < 2 { return }
        lastTypingSentAt = isTyping ? Date() : nil
        await channel.broadcast(event: "typing", message: [
            "user_id": .string(myId.uuidString),
            "is_typing": .bool(isTyping)
        ])
    }

    func unsubscribe() async {
        insertTask?.cancel()
        updateTask?.cancel()
        typingTask?.cancel()
        typingResetTask?.cancel()
        callRequestInsertTask?.cancel()
        callRequestUpdateTask?.cancel()
        insertTask = nil
        updateTask = nil
        typingTask = nil
        typingResetTask = nil
        callRequestInsertTask = nil
        callRequestUpdateTask = nil
        if let channel {
            await supabase().removeChannel(channel)
        }
        channel = nil
    }

    /// 電話ボタンから、直接発信せず相手に通話リクエストを送る。
    func requestCall() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        do {
            let inserted: CallRequest = try await supabase()
                .from("call_requests")
                .insert(CallRequestInsertPayload(matchId: matchId, requesterId: myId))
                .select()
                .single()
                .execute()
                .value
            outgoingCallRequestId = inserted.id
            outgoingCallRequestStatus = .pending
        } catch {
            errorMessage = "通話リクエストの送信に失敗しました"
            print("call request error: \(error)")
        }
    }

    func cancelCallRequest() async {
        guard let id = outgoingCallRequestId else { return }
        do {
            try await supabase()
                .from("call_requests")
                .update(["status": CallRequestStatus.canceled.rawValue, "responded_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: id)
                .execute()
            outgoingCallRequestStatus = nil
            outgoingCallRequestId = nil
        } catch {
            print("cancel call request error: \(error)")
        }
    }

    /// 相手から届いた通話リクエストに応答する(許可した場合のみ次に進める)。
    func respondToCallRequest(accept: Bool) async {
        guard let request = incomingCallRequest else { return }
        do {
            try await supabase()
                .from("call_requests")
                .update([
                    "status": (accept ? CallRequestStatus.accepted : CallRequestStatus.declined).rawValue,
                    "responded_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: request.id)
                .execute()
            incomingCallRequest = nil
        } catch {
            print("respond call request error: \(error)")
        }
    }

    /// 送信に成功したかを返す。呼び出し側(ChatView)は、失敗時に入力欄へ
    /// テキストを戻せるようこの結果を使う(以前は送信前に入力欄を空にしてしまい、
    /// 通信エラー時に打った文章がそのまま失われていた)。
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
        await sendTypingStatus(isTyping: false)
        do {
            try await supabase()
                .from("messages")
                .insert(MessageInsertPayload(matchId: matchId, senderId: myId, body: trimmed, imageUrl: nil))
                .execute()
            return true
        } catch {
            errorMessage = "メッセージの送信に失敗しました"
            print("send message error: \(error)")
            return false
        }
    }

    func sendImage(_ image: UIImage) async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        guard let data = image.resized(maxDimension: 1080).jpegData(compressionQuality: 0.8) else { return }
        isSending = true
        defer { isSending = false }
        do {
            let filePath = "\(matchId.uuidString)/\(UUID().uuidString).jpg"
            try await supabase().storage.from("chat_photos").upload(filePath, data: data, options: FileOptions(contentType: "image/jpeg"))
            let url = try await supabase().storage.from("chat_photos").getPublicURL(path: filePath)
            try await supabase()
                .from("messages")
                .insert(MessageInsertPayload(matchId: matchId, senderId: myId, body: nil, imageUrl: url.absoluteString))
                .execute()
        } catch {
            errorMessage = "画像の送信に失敗しました"
            print("send image error: \(error)")
        }
    }

    func unsend(_ message: Message) async {
        guard let myId = supabase().auth.currentUser?.id, message.senderId == myId else { return }
        do {
            try await supabase()
                .from("messages")
                .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: message.id)
                .eq("sender_id", value: myId)
                .execute()
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = Message(
                    id: message.id,
                    createdAtString: message.createdAtString,
                    matchId: message.matchId,
                    senderId: message.senderId,
                    body: message.body,
                    imageUrlString: message.imageUrlString,
                    readAtString: message.readAtString,
                    deletedAtString: ISO8601DateFormatter().string(from: Date())
                )
            }
        } catch {
            errorMessage = "送信の取り消しに失敗しました"
            print("unsend message error: \(error)")
        }
    }

    func markRead() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        do {
            try await supabase()
                .from("messages")
                .update(["read_at": ISO8601DateFormatter().string(from: Date())])
                .eq("match_id", value: matchId)
                .neq("sender_id", value: myId)
                .is("read_at", value: nil)
                .execute()
        } catch {
            print("mark read error: \(error)")
        }
    }
}

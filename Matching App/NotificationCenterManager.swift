//
//  NotificationCenterManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

struct MessageToast: Identifiable, Equatable {
    let id: UUID
    let matchId: UUID
    let senderName: String
    let preview: String
}

@MainActor
final class NotificationCenterManager: ObservableObject {
    @Published var unreadCount: Int = 0
    @Published var footprintsCount: Int = 0
    /// マッチ済みの相手を除いた、届いたいいねの件数。いいねタブのバッジ表示に使う。
    @Published var pendingLikesCount: Int = 0
    @Published var activeToast: MessageToast?
    /// 足あとの新着、またはプロフィールの「やることリスト」が残っている場合にtrue。
    /// マイページタブの目立たせ表示(丸バッジ)に使う。
    @Published var hasMyPageTodo: Bool = false

    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var likeListenTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?

    func start() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        await refresh()
        await refreshFootprintsCount()
        await refreshMyPageTodo()
        await refreshPendingLikesCount()

        let ch = supabase().channel("messages:notifications")
        let insertions = ch.postgresChange(InsertAction.self, table: "messages")
        let likeInsertions = ch.postgresChange(
            InsertAction.self,
            table: "likes",
            filter: .eq("to_user_id", value: myId.uuidString)
        )
        channel = ch
        await ch.subscribe()

        listenTask = Task { [weak self] in
            for await insertion in insertions {
                guard let self else { return }
                guard let message = try? insertion.decodeRecord(as: Message.self, decoder: JSONDecoder()) else { continue }
                guard message.senderId != myId else { continue }
                self.unreadCount += 1
                await self.showToast(for: message)
            }
        }
        likeListenTask = Task { [weak self] in
            for await _ in likeInsertions {
                // マッチ済みかどうかの判定も必要なため、増分ではなくまとめて数え直す。
                await self?.refreshPendingLikesCount()
            }
        }
    }

    func stop() async {
        listenTask?.cancel()
        listenTask = nil
        likeListenTask?.cancel()
        likeListenTask = nil
        toastDismissTask?.cancel()
        toastDismissTask = nil
        if let channel {
            await supabase().removeChannel(channel)
        }
        channel = nil
    }

    func refresh() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        do {
            let matchRows: [Match] = try await supabase()
                .from("matches")
                .select()
                .or("user_a_id.eq.\(myId),user_b_id.eq.\(myId)")
                .execute()
                .value
            guard !matchRows.isEmpty else {
                unreadCount = 0
                return
            }
            let unreadMessages: [Message] = try await supabase()
                .from("messages")
                .select()
                .in("match_id", values: matchRows.map(\.id))
                .neq("sender_id", value: myId)
                .is("read_at", value: nil)
                .execute()
                .value
            unreadCount = unreadMessages.count
        } catch {
            print("unread count refresh error: \(error)")
        }
    }

    func refreshFootprintsCount() async {
        do {
            footprintsCount = try await supabase()
                .rpc("get_new_footprints_count")
                .execute()
                .value
        } catch {
            print("footprints count refresh error: \(error)")
        }
        await refreshMyPageTodo()
    }

    /// マッチ済みの相手を除いた、届いたいいねの件数を数え直す。
    func refreshPendingLikesCount() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
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
            pendingLikesCount = likeRows.filter { !matchedPartnerIds.contains($0.fromUserId) }.count
        } catch {
            print("pending likes count refresh error: \(error)")
        }
    }

    /// 足あと・プロフィール充実度の両方を見て、マイページタブを目立たせるべきか判定する。
    func refreshMyPageTodo() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        if footprintsCount > 0 {
            hasMyPageTodo = true
            return
        }
        do {
            let profile: Profile = try await supabase()
                .from("profiles")
                .select("*")
                .eq("id", value: myId)
                .single()
                .execute()
                .value
            let photoCount = try await supabase()
                .from("profile_photos")
                .select("*", head: true, count: .exact)
                .eq("user_id", value: myId)
                .execute()
                .count ?? 0
            hasMyPageTodo = profile.completeness(photoCount: photoCount).percent < 100
        } catch {
            print("mypage todo refresh error: \(error)")
        }
    }

    private func showToast(for message: Message) async {
        do {
            let profile: Profile = try await supabase()
                .from("profiles")
                .select("*")
                .eq("id", value: message.senderId)
                .single()
                .execute()
                .value
            let preview: String
            if let body = message.body, !body.isEmpty {
                preview = body
            } else if message.imageUrl != nil {
                preview = "[画像]"
            } else {
                preview = ""
            }
            let toast = MessageToast(id: message.id, matchId: message.matchId, senderName: profile.name, preview: preview)
            activeToast = toast

            toastDismissTask?.cancel()
            toastDismissTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if self.activeToast?.id == toast.id {
                    self.activeToast = nil
                }
            }
        } catch {
            print("toast profile load error: \(error)")
        }
    }
}

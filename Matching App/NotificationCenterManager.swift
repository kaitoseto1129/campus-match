//
//  NotificationCenterManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

@MainActor
final class NotificationCenterManager: ObservableObject {
    /// 自分が主催している集まりへの、承認待ちの応募件数。集まりタブのバッジ表示に使う。
    @Published var gatheringsActionCount: Int = 0
    /// プロフィールの「やることリスト」が残っている場合にtrue。
    /// マイページタブの目立たせ表示(丸バッジ)に使う。
    @Published var hasMyPageTodo: Bool = false

    private var channel: RealtimeChannelV2?
    private var gatheringApplicationListenTask: Task<Void, Never>?

    func start() async {
        guard supabase().auth.currentUser?.id != nil else { return }
        await refreshMyPageTodo()
        await refreshGatheringsActionCount()

        let ch = supabase().channel("gatherings:notifications")
        let gatheringApplicationInsertions = ch.postgresChange(InsertAction.self, table: "gathering_applications")
        channel = ch
        await ch.subscribe()

        gatheringApplicationListenTask = Task { [weak self] in
            for await _ in gatheringApplicationInsertions {
                // 自分が主催している集まり宛かどうかの判定が必要なため、まとめて数え直す。
                await self?.refreshGatheringsActionCount()
            }
        }
    }

    func stop() async {
        gatheringApplicationListenTask?.cancel()
        gatheringApplicationListenTask = nil
        if let channel {
            await supabase().removeChannel(channel)
        }
        channel = nil
    }

    /// 自分が主催している集まりへの、承認待ちの応募件数を数え直す。
    func refreshGatheringsActionCount() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        struct HostedGatheringRow: Decodable { let id: UUID }
        do {
            let hosted: [HostedGatheringRow] = try await supabase()
                .from("gatherings")
                .select("id")
                .eq("host_id", value: myId)
                .execute()
                .value
            guard !hosted.isEmpty else {
                gatheringsActionCount = 0
                return
            }
            gatheringsActionCount = try await supabase()
                .from("gathering_applications")
                .select("*", head: true, count: .exact)
                .in("gathering_id", values: hosted.map(\.id))
                .eq("status", value: "pending")
                .execute()
                .count ?? 0
        } catch {
            print("gatherings action count refresh error: \(error)")
        }
    }

    /// プロフィール充実度を見て、マイページタブを目立たせるべきか判定する。
    func refreshMyPageTodo() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
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
}

//
//  DailyMissionsManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

struct MissionProgress: Identifiable {
    let key: String
    let title: String
    let reward: Int
    let target: Int
    var current: Int
    var id: String { key }
    var isComplete: Bool { current >= target }

    /// 未達成のときに出す誘導ボタンの文言。何をすれば達成できるかが分かるようにする。
    var actionLabel: String? {
        switch key {
        case "footprint": return String.appLocalized("お相手を見に行く")
        case "like5", "like7": return String.appLocalized("いいねを送りに行く")
        default: return nil
        }
    }
}

private struct ClaimParams: Encodable {
    let mission: String
    let reward: Int
}

private struct MissionClaimRow: Decodable {
    let missionKey: String
    enum CodingKeys: String, CodingKey {
        case missionKey = "mission_key"
    }
}

private struct LastActiveRow: Decodable {
    let lastActiveAtString: String
    enum CodingKeys: String, CodingKey {
        case lastActiveAtString = "last_active_at"
    }
}

private struct IdRow: Decodable {
    let id: UUID
}

@MainActor
final class DailyMissionsManager: ObservableObject {
    @Published var missions: [MissionProgress] = []
    @Published var claimedKeys: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 受け取り可能なミッションが1つでもあるか。探す画面のミッションボタンにバッジを出すために使う。
    var hasClaimableMission: Bool {
        claimableMissionCount > 0
    }

    /// 受け取り可能(達成済み・未受け取り)なミッションの件数。
    /// 以前は小さいドットだけで「何かある」ことしか示せず気づきにくかったため、件数を出せるようにする。
    var claimableMissionCount: Int {
        missions.filter { $0.isComplete && !claimedKeys.contains($0.key) }.count
    }

    /// サーバー側のclaim_daily_mission RPCがclaim_dateを日本時間で記録するのに合わせて、
    /// ここも日本時間で「今日」を判定する。ここがローカル端末TZやUTCのままだと、
    /// 進捗カウンター(ローカル時刻基準)と受け取り済み判定がズレて、
    /// 達成しているのに受け取れない時間帯ができてしまう。
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func load() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            // 端末のローカルタイムゾーンに任せると、TZ設定が日本以外の端末でここだけ
            // claim_date(日本時間固定)とズレてしまうため、進捗カウンターも明示的に
            // 日本時間で「今日」を判定する。
            var calendar = Calendar(identifier: .iso8601)
            calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
            let startOfDay = calendar.startOfDay(for: Date())
            let startOfDayString = ISO8601DateFormatter.matchingApp.string(from: startOfDay)
            let todayString = Self.dayFormatter.string(from: Date())

            let profileRow: LastActiveRow = try await supabase()
                .from("profiles")
                .select("last_active_at")
                .eq("id", value: myId)
                .single()
                .execute()
                .value
            let loggedInToday = ISO8601DateFormatter.matchingApp
                .date(from: profileRow.lastActiveAtString)
                .map { calendar.isDateInToday($0) } ?? false

            let likesToday: [Like] = try await supabase()
                .from("likes")
                .select()
                .eq("from_user_id", value: myId)
                .gte("created_at", value: startOfDayString)
                .execute()
                .value

            let visitsToday: [IdRow] = try await supabase()
                .from("profile_visits")
                .select("id")
                .eq("viewer_id", value: myId)
                .gte("created_at", value: startOfDayString)
                .execute()
                .value

            let claimRows: [MissionClaimRow] = try await supabase()
                .from("mission_claims")
                .select("mission_key")
                .eq("user_id", value: myId)
                .eq("claim_date", value: todayString)
                .execute()
                .value
            claimedKeys = Set(claimRows.map(\.missionKey))

            missions = [
                MissionProgress(key: "login", title: "ログインボーナス", reward: 2, target: 1, current: loggedInToday ? 1 : 0),
                MissionProgress(key: "footprint", title: "気になるお相手のプロフィールを見よう", reward: 1, target: 1, current: min(visitsToday.count, 1)),
                MissionProgress(key: "like5", title: "5人のお相手にいいね!を送ろう", reward: 1, target: 5, current: min(likesToday.count, 5)),
                MissionProgress(key: "like7", title: "7人のお相手にいいね!を送ろう", reward: 2, target: 7, current: min(likesToday.count, 7)),
            ]
        } catch {
            errorMessage = "ミッションを読み込めませんでした"
            print("daily missions load error: \(error)")
        }
        isLoading = false
    }

    func claim(_ mission: MissionProgress) async {
        guard mission.isComplete, !claimedKeys.contains(mission.key) else { return }
        do {
            try await supabase()
                .rpc("claim_daily_mission", params: ClaimParams(mission: mission.key, reward: mission.reward))
                .execute()
            claimedKeys.insert(mission.key)
        } catch {
            errorMessage = "受け取りに失敗しました"
            print("claim mission error: \(error)")
        }
    }

    /// 達成済みでまだ受け取っていないミッションをまとめて受け取る。
    /// 1件ずつ順番にclaim()を呼ぶだけなので、途中で失敗しても受け取れた分はそのまま残る。
    func claimAll() async {
        let claimable = missions.filter { $0.isComplete && !claimedKeys.contains($0.key) }
        for mission in claimable {
            await claim(mission)
        }
    }
}

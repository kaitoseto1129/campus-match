//
//  ModerationAdminManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

struct Report: Codable, Identifiable {
    let id: UUID
    let createdAtString: String
    let reporterId: UUID
    let reportedId: UUID
    let reason: String?
    let resolved: Bool
    let resolvedAtString: String?

    var createdAt: Date {
        Date.fromSupabase(createdAtString) ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAtString = "created_at"
        case reporterId = "reporter_id"
        case reportedId = "reported_id"
        case reason
        case resolved
        case resolvedAtString = "resolved_at"
    }
}

/// 管理者が確認する集まりの募集1件。
/// 利用規約 第5条3項で「募集内容とグループトークを継続的に確認する」と定めているため、
/// 通報を待たずに新しい募集を一覧で見て回れるようにしている。
struct AdminGatheringItem: Identifiable {
    let gathering: Gathering
    let hostProfile: Profile?
    let hostPhotoURL: URL?
    /// 投稿時のフィルタをすり抜けた、あるいはフィルタ導入前に投稿された疑わしい募集に印を付ける。
    let flagged: NGWordFilter.Violation?
    var id: UUID { gathering.id }
}

struct AdminReportItem: Identifiable {
    let report: Report
    let reporterProfile: Profile?
    let reportedProfile: Profile?
    let reportedPhotoURL: URL?
    var id: UUID { report.id }
}

private struct ResolvePayload: Encodable {
    let resolved: Bool
    let resolvedAt: String
    enum CodingKeys: String, CodingKey {
        case resolved
        case resolvedAt = "resolved_at"
    }
}

@MainActor
final class ModerationAdminManager: ObservableObject {
    @Published var items: [AdminReportItem] = []
    @Published var gatheringItems: [AdminGatheringItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let reports: [Report] = try await supabase()
                .from("reports")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            let userIds = Set(reports.flatMap { [$0.reporterId, $0.reportedId] })
            var profilesById: [UUID: Profile] = [:]
            var photoURLs: [UUID: URL] = [:]
            if !userIds.isEmpty {
                let profiles: [Profile] = try await supabase()
                    .from("profiles")
                    .select("*")
                    .in("id", values: Array(userIds))
                    .execute()
                    .value
                profilesById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
                photoURLs = await loadMainPhotoURLs(userIds: Array(userIds))
            }

            var results = reports.map { report in
                AdminReportItem(
                    report: report,
                    reporterProfile: profilesById[report.reporterId],
                    reportedProfile: profilesById[report.reportedId],
                    reportedPhotoURL: photoURLs[report.reportedId]
                )
            }
            // 未対応のものを先頭に表示する。
            results.sort { !$0.report.resolved && $1.report.resolved }
            items = results
        } catch {
            errorMessage = "通報一覧を読み込めませんでした"
            print("admin reports load error: \(error)")
        }
        isLoading = false
    }

    /// 直近の集まりの募集を読み込む。疑わしいものを先頭に並べる。
    func loadGatherings() async {
        isLoading = true
        errorMessage = nil
        do {
            let gatherings: [Gathering] = try await supabase()
                .from("gatherings")
                .select()
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value

            let hostIds = Array(Set(gatherings.map(\.hostId)))
            var profilesById: [UUID: Profile] = [:]
            var photoURLs: [UUID: URL] = [:]
            if !hostIds.isEmpty {
                let profiles: [Profile] = try await supabase()
                    .from("profiles")
                    .select("*")
                    .in("id", values: hostIds)
                    .execute()
                    .value
                profilesById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
                photoURLs = await loadMainPhotoURLs(userIds: hostIds)
            }

            var results = gatherings.map { gathering in
                AdminGatheringItem(
                    gathering: gathering,
                    hostProfile: profilesById[gathering.hostId],
                    hostPhotoURL: photoURLs[gathering.hostId],
                    flagged: NGWordFilter.violation(inAny: [
                        gathering.title, gathering.description ?? "", gathering.location
                    ])
                )
            }
            results.sort { ($0.flagged != nil) && ($1.flagged == nil) }
            gatheringItems = results
        } catch {
            errorMessage = "集まりの一覧を読み込めませんでした"
            print("admin gatherings load error: \(error)")
        }
        isLoading = false
    }

    func markResolved(_ report: Report) async {
        do {
            try await supabase()
                .from("reports")
                .update(ResolvePayload(resolved: true, resolvedAt: ISO8601DateFormatter().string(from: Date())))
                .eq("id", value: report.id)
                .execute()
            await load()
        } catch {
            errorMessage = "対応済みへの更新に失敗しました"
            print("admin report resolve error: \(error)")
        }
    }
}

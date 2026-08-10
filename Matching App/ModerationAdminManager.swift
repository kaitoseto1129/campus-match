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
        ISO8601DateFormatter.matchingApp.date(from: createdAtString) ?? Date()
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

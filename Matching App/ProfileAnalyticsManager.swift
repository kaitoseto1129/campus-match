//
//  ProfileAnalyticsManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

struct ProfileAnalyticsPhotoStat: Identifiable {
    let photo: ProfilePhoto
    let viewCount: Int
    var id: UUID { photo.id }
}

struct ProfileAnalyticsSectionStat: Identifiable {
    let section: ProfileSection
    let reachedCount: Int
    /// 0...1。この段階まで到達した閲覧者の割合。
    let percentage: Double
    var id: String { section.rawValue }
}

@MainActor
final class ProfileAnalyticsManager: ObservableObject {
    @Published var isLoading = false
    @Published var totalVisits = 0
    @Published var trackedVisits = 0
    @Published var totalLikesReceived = 0
    @Published var photoStats: [ProfileAnalyticsPhotoStat] = []
    @Published var sectionStats: [ProfileAnalyticsSectionStat] = []
    @Published var insights: [String] = []
    @Published var errorMessage: String?

    func load() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            let profile: Profile = try await supabase()
                .from("profiles")
                .select("*")
                .eq("id", value: myId)
                .single()
                .execute()
                .value

            let photos: [ProfilePhoto] = try await supabase()
                .from("profile_photos")
                .select()
                .eq("user_id", value: myId)
                .order("order_number", ascending: true)
                .execute()
                .value

            struct VisitRow: Decodable {
                let photoIdsViewed: [UUID]
                let reachedSection: String?
                enum CodingKeys: String, CodingKey {
                    case photoIdsViewed = "photo_ids_viewed"
                    case reachedSection = "reached_section"
                }
            }
            let visits: [VisitRow] = try await supabase()
                .from("profile_visits")
                .select("photo_ids_viewed, reached_section")
                .eq("visited_id", value: myId)
                .execute()
                .value

            let likeRows: [Like] = try await supabase()
                .from("likes")
                .select()
                .eq("to_user_id", value: myId)
                .execute()
                .value

            totalVisits = visits.count
            totalLikesReceived = likeRows.count

            let trackedRows = visits.filter { $0.reachedSection != nil }
            trackedVisits = trackedRows.count

            var photoCounts: [UUID: Int] = [:]
            for visit in visits {
                for id in visit.photoIdsViewed {
                    photoCounts[id, default: 0] += 1
                }
            }
            photoStats = photos.map { ProfileAnalyticsPhotoStat(photo: $0, viewCount: photoCounts[$0.id] ?? 0) }

            var existingSections: [ProfileSection] = [.header]
            if let tagline = profile.tagline, !tagline.isEmpty { existingSections.append(.tagline) }
            if photos.count > 1 { existingSections.append(.subPhotos) }
            existingSections.append(contentsOf: [.nameAgeArea, .about, .basicInfo, .otherProfiles])

            let reachedOrders = trackedRows.compactMap { row -> Int? in
                guard let raw = row.reachedSection, let section = ProfileSection(rawValue: raw) else { return nil }
                return section.order
            }

            sectionStats = existingSections.map { section in
                let reached = trackedVisits == 0 ? 0 : reachedOrders.filter { $0 >= section.order }.count
                let pct = trackedVisits == 0 ? 0 : Double(reached) / Double(trackedVisits)
                return ProfileAnalyticsSectionStat(section: section, reachedCount: reached, percentage: pct)
            }

            insights = Self.generateInsights(
                photoStats: photoStats,
                sectionStats: sectionStats,
                trackedVisits: trackedVisits,
                totalLikesReceived: totalLikesReceived
            )
        } catch {
            errorMessage = "分析データを読み込めませんでした"
            print("profile analytics load error: \(error)")
        }
        isLoading = false
    }

    /// 簡易的なルールベースの「分析コメント」生成。閲覧データの傾向から、
    /// どこで離脱が多いか・どの写真が見られているかを自然な文章にまとめる。
    private static func generateInsights(
        photoStats: [ProfileAnalyticsPhotoStat],
        sectionStats: [ProfileAnalyticsSectionStat],
        trackedVisits: Int,
        totalLikesReceived: Int
    ) -> [String] {
        guard trackedVisits >= 3 else {
            return ["まだ閲覧データが少ないため、分析結果を出すには情報が足りません。プロフィールがもっと見られると、ここに改善ポイントが表示されます。"]
        }
        var result: [String] = []

        if sectionStats.count >= 2 {
            var biggestDropIndex = 0
            var biggestDrop = 0.0
            for i in 1..<sectionStats.count {
                let drop = sectionStats[i - 1].percentage - sectionStats[i].percentage
                if drop > biggestDrop {
                    biggestDrop = drop
                    biggestDropIndex = i
                }
            }
            if biggestDrop >= 0.15 {
                let before = sectionStats[biggestDropIndex - 1]
                let after = sectionStats[biggestDropIndex]
                result.append("「\(before.section.label)」を見た人のうち約\(Int(biggestDrop * 100))%が、そのあとの「\(after.section.label)」まで進まずに離脱しています。この付近の内容を見直すと改善が期待できます。")
            }
        }
        if let last = sectionStats.last, last.percentage >= 0.5 {
            result.append("閲覧者の約\(Int(last.percentage * 100))%が最後の「\(last.section.label)」まで到達しています。プロフィールがしっかり読まれている証拠です!")
        }

        if photoStats.count > 1 {
            let others = Array(photoStats.dropFirst())
            if let leastViewed = others.min(by: { $0.viewCount < $1.viewCount }) {
                let rate = trackedVisits == 0 ? 0 : Double(leastViewed.viewCount) / Double(trackedVisits)
                if rate < 0.3 {
                    let position = (photoStats.firstIndex(where: { $0.id == leastViewed.id }) ?? 0) + 1
                    result.append("\(position)枚目の写真はあまり見られていません(閲覧率\(Int(rate * 100))%)。並び替えるか、別の写真に差し替えてみましょう。")
                }
            }
            if let mostViewed = others.max(by: { $0.viewCount < $1.viewCount }), mostViewed.viewCount > 0 {
                let rate = trackedVisits == 0 ? 0 : Double(mostViewed.viewCount) / Double(trackedVisits)
                if rate >= 0.6 {
                    let position = (photoStats.firstIndex(where: { $0.id == mostViewed.id }) ?? 0) + 1
                    result.append("\(position)枚目の写真がよく見られています(閲覧率\(Int(rate * 100))%)。メイン写真の候補にしてみるのもおすすめです。")
                }
            }
        }

        if totalLikesReceived == 0 && trackedVisits >= 5 {
            result.append("閲覧はあるものの、まだいいねにはつながっていません。自己紹介文や基本情報を充実させると印象が変わるかもしれません。")
        }

        if result.isEmpty {
            result.append("目立った離脱ポイントは見つかりませんでした。今のプロフィールはバランス良く読まれています。")
        }
        return result
    }
}

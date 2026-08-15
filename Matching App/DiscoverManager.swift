//
//  DiscoverManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

@MainActor
final class DiscoverManager: ObservableObject {
    @Published var candidates: [Profile] = []
    @Published var candidatePhotoURLs: [UUID: URL] = [:]
    @Published var totalCandidateCount: Int = 0
    @Published var hasMoreCandidates = true
    @Published var isLoadingMore = false
    @Published var boostedProfiles: [Profile] = []
    @Published var likedIds: Set<UUID> = []
    /// 自分がいまアピール(ブースト)中かどうか。探す画面のバナー表示に使う。
    @Published var isBoostActive = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var filter = DiscoverFilter()

    private static let pageSize = 20
    private var candidatePage = 0
    private var myId: UUID?
    private var myUniversityId: UUID?
    private var oppositeGender: Gender?
    private var excludedIds: Set<UUID> = []

    func load() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        self.myId = myId
        isLoading = true
        errorMessage = nil
        do {
            let myProfile: Profile = try await supabase()
                .from("profiles")
                .select("*")
                .eq("id", value: myId)
                .single()
                .execute()
                .value

            guard let myGender = myProfile.gender else {
                errorMessage = "プロフィールを完成させてください"
                isLoading = false
                return
            }
            myUniversityId = myProfile.universityId
            oppositeGender = myGender == .male ? .female : .male
            isBoostActive = myProfile.isBoosted

            let likeRows: [Like] = try await supabase()
                .from("likes")
                .select()
                .or("from_user_id.eq.\(myId),to_user_id.eq.\(myId)")
                .execute()
                .value
            likedIds = Set(likeRows.filter { $0.fromUserId == myId }.map(\.toUserId))

            let matchRows: [Match] = try await supabase()
                .from("matches")
                .select()
                .or("user_a_id.eq.\(myId),user_b_id.eq.\(myId)")
                .execute()
                .value
            let matchedPartnerIds = Set(matchRows.map { $0.userAId == myId ? $0.userBId : $0.userAId })

            // 自分に届いたいいね・自分が既に送ったいいねの相手は、探すのグリッドには出さない。
            var excludedIds: Set<UUID> = matchedPartnerIds
            for like in likeRows where like.toUserId == myId {
                excludedIds.insert(like.fromUserId)
            }
            excludedIds.formUnion(likedIds)
            excludedIds.formUnion(await UserModeration.hiddenOrBlockedIds(actorId: myId))
            self.excludedIds = excludedIds

            candidatePage = 0
            hasMoreCandidates = true
            candidates = []
            candidatePhotoURLs = [:]
            totalCandidateCount = try await fetchCandidateCount()
            await fetchNextCandidatePage()
            await loadBoostedProfiles()
        } catch {
            errorMessage = "ユーザー一覧を読み込めませんでした"
            print("discover load error: \(error)")
        }
        isLoading = false
    }

    /// 探すグリッドの末尾付近までスクロールしたら次のページを読み込む。
    func loadMoreCandidatesIfNeeded(currentItem: Profile) async {
        guard hasMoreCandidates, !isLoadingMore else { return }
        guard let index = candidates.firstIndex(where: { $0.id == currentItem.id }) else { return }
        if index >= candidates.count - 4 {
            await fetchNextCandidatePage()
        }
    }

    private func candidateQuery() -> PostgrestFilterBuilder {
        applyCandidateFilters(to: supabase().from("profiles").select("*"), filter: nil)
    }

    private func applyCandidateFilters(to base: PostgrestFilterBuilder, filter overrideFilter: DiscoverFilter?) -> PostgrestFilterBuilder {
        let filter = overrideFilter ?? self.filter
        var query = base.eq("gender", value: oppositeGender?.rawValue ?? "")
        // プライベートモード中のユーザーは「探す」に出さない。
        // 相手が自分にいいねを送っている場合は上のexcludedIdsで既にここから外れ、
        // 「いいね」タブ側に出るため、「自分からいいねを送らない限り見つからない」状態になる。
        query = query.eq("private_mode", value: false)
        if let myId {
            query = query.neq("id", value: myId)
        }
        if let universityId = filter.universityId {
            query = query.eq("university_id", value: universityId)
        } else if !filter.showAllUniversities, let myUniversityId {
            query = query.eq("university_id", value: myUniversityId)
        }
        if !excludedIds.isEmpty {
            query = query.notIn("id", values: Array(excludedIds))
        }
        if !filter.areas.isEmpty {
            query = query.in("area", values: Array(filter.areas))
        }
        if !filter.cities.isEmpty {
            query = query.in("city", values: Array(filter.cities))
        }
        if !filter.nationalities.isEmpty {
            query = query.overlaps("nationalities", value: Array(filter.nationalities))
        }
        if !filter.bodyTypes.isEmpty {
            query = query.in("body_type", values: Array(filter.bodyTypes))
        }
        if filter.isAgeFiltered {
            query = query
                .gte("birthday", value: filter.minBirthdayString)
                .lte("birthday", value: filter.maxBirthdayString)
        }
        if filter.isHeightFiltered {
            query = query
                .gte("height", value: filter.heightMin)
                .lte("height", value: filter.heightMax)
        }
        return query
    }

    private func fetchCandidateCount(filter overrideFilter: DiscoverFilter? = nil) async throws -> Int {
        let response = try await applyCandidateFilters(
            to: supabase().from("profiles").select("*", head: true, count: .exact),
            filter: overrideFilter
        ).execute()
        return response.count ?? 0
    }

    /// 絞り込みシートでのライブ人数プレビュー用。draft状態のfilterで件数だけを数える(実際のfilterやcandidatesは変更しない)。
    func previewCount(for draftFilter: DiscoverFilter) async -> Int {
        (try? await fetchCandidateCount(filter: draftFilter)) ?? 0
    }

    private func fetchNextCandidatePage() async {
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let from = candidatePage * Self.pageSize
            let to = from + Self.pageSize - 1
            var results: [Profile] = try await candidateQuery()
                .order("last_active_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
            if filter.sortOrder == .recommended {
                results.shuffle()
            }
            // アピール(ブースト)中のユーザーは、そのページ内で最上部に表示する。
            results.sort { $0.isBoosted && !$1.isBoosted }
            candidatePage += 1
            hasMoreCandidates = results.count == Self.pageSize
            candidates.append(contentsOf: results)
            let newPhotoURLs = await loadMainPhotoURLs(userIds: results.map(\.id))
            candidatePhotoURLs.merge(newPhotoURLs) { _, new in new }
        } catch {
            errorMessage = "ユーザー一覧を読み込めませんでした"
            print("discover load more error: \(error)")
        }
    }

    /// 探す画面上部の「アピール中のユーザー」カルーセル用。ページングとは独立して全件取得する。
    private func loadBoostedProfiles() async {
        do {
            let results: [Profile] = try await candidateQuery()
                .gt("boost_expires_at", value: ISO8601DateFormatter().string(from: Date()))
                .order("boost_expires_at", ascending: false)
                .limit(20)
                .execute()
                .value
            boostedProfiles = results
            let newPhotoURLs = await loadMainPhotoURLs(userIds: results.map(\.id))
            candidatePhotoURLs.merge(newPhotoURLs) { _, new in new }
        } catch {
            print("boosted profiles load error: \(error)")
        }
    }

    /// 残いいねの確認・消費・INSERTを1トランザクションで行う。残いいねが足りない場合はfalseを返す。
    @discardableResult
    func sendLike(to userId: UUID, isSpecial: Bool = false) async -> Bool {
        do {
            try await supabase()
                .rpc("send_like_atomic", params: SendLikeParams(pToUserId: userId, pIsSpecial: isSpecial))
                .execute()
            likedIds.insert(userId)
            return true
        } catch {
            errorMessage = "いいねが足りません"
            print("send like error: \(error)")
            return false
        }
    }

    /// この相手が「人気会員」(受け取ったいいねが多い)かどうかを判定する。
    static let popularMemberThreshold = 100

    func likeCount(for userId: UUID) async -> Int {
        do {
            return try await supabase()
                .rpc("get_like_count", params: ["target_user_id": userId])
                .execute()
                .value
        } catch {
            print("like count check error: \(error)")
            return 0
        }
    }

    /// 非表示にして、その場で一覧からも消す(次回起動時に自動で除外されるのに加え、即時反映する)。
    func hideCandidate(_ userId: UUID) async {
        await UserModeration.hide(userId: userId)
        candidates.removeAll { $0.id == userId }
        boostedProfiles.removeAll { $0.id == userId }
        totalCandidateCount = max(0, totalCandidateCount - 1)
    }

    /// 探す画面のバナーからアピール(ブースト)を発動する。
    /// マイページまで移動しなくてもその場で使えるようにするために用意している。
    @discardableResult
    func activateBoost() async -> Bool {
        do {
            try await supabase().rpc("activate_boost").execute()
            isBoostActive = true
            await load()
            return true
        } catch {
            print("activate boost error: \(error)")
            return false
        }
    }
}

struct SendLikeParams: Encodable {
    let pToUserId: UUID
    let pIsSpecial: Bool
    enum CodingKeys: String, CodingKey {
        case pToUserId = "p_to_user_id"
        case pIsSpecial = "p_is_special"
    }
}

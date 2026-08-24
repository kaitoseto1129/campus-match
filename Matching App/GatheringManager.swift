//
//  GatheringManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine

@MainActor
final class GatheringManager: ObservableObject {
    /// 同じ大学で募集中の集まり(自分が主催・参加しているものも含む)。
    @Published var openSummaries: [GatheringSummary] = []
    /// 自分が主催している、または応募(承認待ち・参加確定)している集まり。
    @Published var mySummaries: [GatheringSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var myId: UUID?
    private var myUniversityId: UUID?

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
            let universityId = myProfile.universityId
            myUniversityId = universityId

            let gatherings: [Gathering] = try await supabase()
                .from("gatherings")
                .select("*")
                .eq("university_id", value: universityId)
                .order("scheduled_at", ascending: true)
                .execute()
                .value

            guard !gatherings.isEmpty else {
                openSummaries = []
                mySummaries = []
                isLoading = false
                return
            }

            let gatheringIds = gatherings.map(\.id)
            let applications: [GatheringApplication] = try await supabase()
                .from("gathering_applications")
                .select("*")
                .in("gathering_id", values: gatheringIds)
                .execute()
                .value

            let hostIds = Array(Set(gatherings.map(\.hostId)))
            let hostProfiles: [Profile] = try await supabase()
                .from("profiles")
                .select("*")
                .in("id", values: hostIds)
                .execute()
                .value
            let hostProfilesById = Dictionary(uniqueKeysWithValues: hostProfiles.map { ($0.id, $0) })
            let hostPhotoURLs = await loadMainPhotoURLs(userIds: hostIds)

            var applicationsByGathering: [UUID: [GatheringApplication]] = [:]
            for application in applications {
                applicationsByGathering[application.gatheringId, default: []].append(application)
            }

            let summaries: [GatheringSummary] = gatherings.map { gathering in
                let gatheringApplications = applicationsByGathering[gathering.id] ?? []
                let acceptedCount = gatheringApplications.filter { $0.status == "accepted" }.count
                let myApplication = gatheringApplications.first { $0.applicantId == myId }
                return GatheringSummary(
                    gathering: gathering,
                    hostProfile: hostProfilesById[gathering.hostId],
                    hostPhotoURL: hostPhotoURLs[gathering.hostId],
                    acceptedCount: acceptedCount,
                    myApplication: myApplication,
                    isHost: gathering.hostId == myId
                )
            }

            openSummaries = summaries
                .filter { $0.gathering.isOpen && !$0.gathering.isPast }
                .sorted { $0.gathering.scheduledAt < $1.gathering.scheduledAt }
            mySummaries = summaries
                .filter { $0.isHost || $0.myApplication != nil }
                .sorted { $0.gathering.scheduledAt < $1.gathering.scheduledAt }
        } catch {
            errorMessage = "集まりを読み込めませんでした"
            print("gathering load error: \(error)")
        }
        isLoading = false
    }

    @discardableResult
    func create(title: String, description: String, location: String, scheduledAt: Date, capacity: Int) async -> Bool {
        guard let myId, let myUniversityId else { return false }
        do {
            try await supabase()
                .from("gatherings")
                .insert(GatheringInsertPayload(
                    hostId: myId,
                    universityId: myUniversityId,
                    title: title,
                    description: description.isEmpty ? nil : description,
                    location: location,
                    scheduledAtString: ISO8601DateFormatter.matchingApp.string(from: scheduledAt),
                    capacity: capacity
                ))
                .execute()
            await load()
            return true
        } catch {
            errorMessage = "集まりを作成できませんでした"
            print("gathering create error: \(error)")
            return false
        }
    }

    /// 応募に成功したら、主催者へプッシュ通知する。
    @discardableResult
    func apply(to gathering: Gathering, comment: String) async -> Bool {
        guard let myId else { return false }
        do {
            try await supabase()
                .from("gathering_applications")
                .insert(GatheringApplicationInsertPayload(gatheringId: gathering.id, applicantId: myId, comment: comment.isEmpty ? nil : comment))
                .execute()
            await load()
            await PushNotifier.notify(userId: gathering.hostId, title: "「\(gathering.title)」に応募がありました", body: "内容を確認して承認するか選びましょう")
            return true
        } catch {
            errorMessage = "応募できませんでした"
            print("gathering apply error: \(error)")
            return false
        }
    }

    /// 承認待ちの自分の応募を取り消す。
    @discardableResult
    func withdraw(_ application: GatheringApplication) async -> Bool {
        do {
            try await supabase()
                .from("gathering_applications")
                .update(["status": "canceled"])
                .eq("id", value: application.id)
                .execute()
            await load()
            return true
        } catch {
            errorMessage = "取り消せませんでした"
            print("gathering withdraw error: \(error)")
            return false
        }
    }

    /// 主催者として応募に応答する(承認/却下)。承認した場合、応募者へプッシュ通知する。
    @discardableResult
    func respond(to application: GatheringApplication, gathering: Gathering, accept: Bool) async -> Bool {
        do {
            try await supabase()
                .rpc("respond_to_gathering_application", params: RespondParams(pApplicationId: application.id, pAccept: accept))
                .execute()
            await load()
            if accept {
                await PushNotifier.notify(userId: application.applicantId, title: "「\(gathering.title)」への参加が決まりました!", body: "グループトークで挨拶してみましょう")
            }
            return true
        } catch {
            errorMessage = accept ? "承認できませんでした(定員に達している可能性があります)" : "却下できませんでした"
            print("gathering respond error: \(error)")
            return false
        }
    }

    /// 応募者一覧(承認待ち・承認済み)をプロフィール付きで取得する。主催者向けの詳細画面で使う。
    func loadApplicantProfiles(for gatheringId: UUID) async -> [(application: GatheringApplication, profile: Profile?, photoURL: URL?)] {
        do {
            let applications: [GatheringApplication] = try await supabase()
                .from("gathering_applications")
                .select("*")
                .eq("gathering_id", value: gatheringId)
                .order("created_at", ascending: true)
                .execute()
                .value
            let applicantIds = applications.map(\.applicantId)
            guard !applicantIds.isEmpty else { return [] }
            let profiles: [Profile] = try await supabase()
                .from("profiles")
                .select("*")
                .in("id", values: applicantIds)
                .execute()
                .value
            let profilesById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            let photoURLs = await loadMainPhotoURLs(userIds: applicantIds)
            return applications.map { ($0, profilesById[$0.applicantId], photoURLs[$0.applicantId]) }
        } catch {
            print("gathering applicant profiles load error: \(error)")
            return []
        }
    }
}

private struct RespondParams: Encodable {
    let pApplicationId: UUID
    let pAccept: Bool
    enum CodingKeys: String, CodingKey {
        case pApplicationId = "p_application_id"
        case pAccept = "p_accept"
    }
}

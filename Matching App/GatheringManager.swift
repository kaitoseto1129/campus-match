//
//  GatheringManager.swift
//  Matching App
//

import Foundation
import Supabase
import Combine
import UIKit

@MainActor
final class GatheringManager: ObservableObject {
    /// 同じ大学で募集中の集まり(自分の主催分は除く。自分が応募済みのものはステータス付きで含む)。
    @Published var openSummaries: [GatheringSummary] = []
    /// 自分が主催している集まり(状態問わず)。
    @Published var hostedSummaries: [GatheringSummary] = []
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
                hostedSummaries = []
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
                let pendingCount = gatheringApplications.filter { $0.status == "pending" }.count
                let myApplication = gatheringApplications.first { $0.applicantId == myId }
                return GatheringSummary(
                    gathering: gathering,
                    hostProfile: hostProfilesById[gathering.hostId],
                    hostPhotoURL: hostPhotoURLs[gathering.hostId],
                    acceptedCount: acceptedCount,
                    pendingCount: pendingCount,
                    myApplication: myApplication,
                    isHost: gathering.hostId == myId
                )
            }

            // 自分が主催した集まりは「自分が主催」タブの方に集約し、「みんなの募集」には出さない
            // (以前は両方に出ていて、自分の投稿に「主催中」バッジをつける必要があり紛らわしかった)。
            // 自分が応募済みのものは、ステータスを確認できるようここに残す。
            openSummaries = summaries
                .filter { !$0.isHost && ($0.myApplication != nil || ($0.gathering.isOpen && !$0.gathering.isPast)) }
                .sorted { $0.gathering.scheduledAt < $1.gathering.scheduledAt }
            hostedSummaries = summaries
                .filter { $0.isHost }
                .sorted { $0.gathering.scheduledAt < $1.gathering.scheduledAt }

            await notifyPassedDeadlinesIfNeeded()
        } catch {
            errorMessage = "集まりを読み込めませんでした"
            print("gathering load error: \(error)")
        }
        isLoading = false
    }

    /// アプリを開いた・集まり一覧を再読み込みしたタイミングで、応募締切を過ぎているのに
    /// まだ通知していない自分主催の集まりがあれば、その場で気づけるようプッシュ通知を送る。
    /// (常駐サーバー側での定時通知ではなく、あくまでアプリを開いた時点でのベストエフォート)
    private func notifyPassedDeadlinesIfNeeded() async {
        guard let myId else { return }
        let due = hostedSummaries.filter {
            $0.gathering.isOpen && !$0.gathering.deadlineNotified && $0.gathering.isPastDeadline
        }
        for summary in due {
            // load()が複数同時に走った場合(例: 手動更新中に自動再読み込みが重なる)、
            // 両方が同じ「まだ通知していない」状態を読んで二重に通知してしまうことがあった。
            // 先にdeadline_notified=falseを条件にUPDATEし、実際に自分の呼び出しが更新できた
            // 場合だけ通知することで、DB側を排他の判定材料として使う。
            struct UpdatedRow: Decodable { let id: UUID }
            let updated: [UpdatedRow] = (try? await supabase()
                .from("gatherings")
                .update(["deadline_notified": true])
                .eq("id", value: summary.gathering.id)
                .eq("deadline_notified", value: false)
                .select("id")
                .execute()
                .value) ?? []
            guard !updated.isEmpty else { continue }

            await PushNotifier.notify(
                userId: myId,
                title: String.appLocalized("「%@」の募集締切になりました", summary.gathering.title),
                body: String.appLocalized("応募状況を確認して参加者を決めましょう")
            )
        }
    }

    @discardableResult
    func create(title: String, description: String, location: String, scheduledAt: Date, capacity: Int, category: String, durationHours: Int, deadlineAt: Date?, image: UIImage?) async -> Bool {
        guard let myId, let myUniversityId else { return false }
        do {
            let inserted: Gathering = try await supabase()
                .from("gatherings")
                .insert(GatheringInsertPayload(
                    hostId: myId,
                    universityId: myUniversityId,
                    title: title,
                    description: description.isEmpty ? nil : description,
                    location: location,
                    scheduledAtString: ISO8601DateFormatter.matchingApp.string(from: scheduledAt),
                    capacity: capacity,
                    category: category,
                    durationHours: durationHours,
                    deadlineAtString: deadlineAt.map { ISO8601DateFormatter.matchingApp.string(from: $0) }
                ))
                .select()
                .single()
                .execute()
                .value
            if let image, let imageURLString = await uploadImage(image, gatheringId: inserted.id) {
                try await supabase()
                    .from("gatherings")
                    .update(["image_url": imageURLString])
                    .eq("id", value: inserted.id)
                    .execute()
            }
            await load()
            return true
        } catch {
            errorMessage = "集まりを作成できませんでした"
            print("gathering create error: \(error)")
            return false
        }
    }

    /// 集まりの画像は任意。アップロードに失敗しても集まり自体の作成は失敗させたくないため、
    /// ここでのエラーは投稿全体の失敗にはせずnilを返すだけにする。
    private func uploadImage(_ image: UIImage, gatheringId: UUID) async -> String? {
        guard let data = image.resized(maxDimension: 1080).jpegData(compressionQuality: 0.8) else { return nil }
        do {
            let filePath = "\(gatheringId.uuidString)/\(UUID().uuidString).jpg"
            try await supabase().storage.from("gathering_photos").upload(filePath, data: data, options: FileOptions(contentType: "image/jpeg"))
            let url = try await supabase().storage.from("gathering_photos").getPublicURL(path: filePath)
            return url.absoluteString
        } catch {
            print("gathering image upload error: \(error)")
            return nil
        }
    }

    /// 応募に成功したら、主催者へプッシュ通知する。
    @discardableResult
    func apply(to gathering: Gathering, comment: String) async -> Bool {
        guard let myId else { return false }
        guard !gathering.isPastDeadline else {
            errorMessage = "応募の締切を過ぎています"
            return false
        }
        do {
            try await supabase()
                .from("gathering_applications")
                .insert(GatheringApplicationInsertPayload(gatheringId: gathering.id, applicantId: myId, comment: comment.isEmpty ? nil : comment))
                .execute()
            await load()
            await PushNotifier.notify(userId: gathering.hostId, title: String.appLocalized("「%@」に応募がありました", gathering.title), body: String.appLocalized("内容を確認して承認するか選びましょう"))
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
                await PushNotifier.notify(userId: application.applicantId, title: String.appLocalized("「%@」への参加が決まりました!", gathering.title), body: String.appLocalized("グループトークで挨拶してみましょう"))
            }
            return true
        } catch {
            errorMessage = accept ? "承認できませんでした(定員に達している可能性があります)" : "却下できませんでした"
            print("gathering respond error: \(error)")
            return false
        }
    }

    /// 主催者が集まりをキャンセルする。承認済みメンバー全員にプッシュ通知する
    /// (グループトークは以後アクセスできなくなる=実質の解体)。
    @discardableResult
    func cancelGathering(_ gathering: Gathering) async -> Bool {
        do {
            let acceptedApplications: [GatheringApplication] = try await supabase()
                .from("gathering_applications")
                .select("*")
                .eq("gathering_id", value: gathering.id)
                .eq("status", value: "accepted")
                .execute()
                .value
            // gatherings.statusの更新と、承認待ち応募の一括却下を1つのRPCで原子的に行う。
            // (却下側はhostによる直接UPDATEを許可するRLSポリシーを持たないため、
            // SECURITY DEFINER関数を経由する必要がある)
            try await supabase()
                .rpc("cancel_gathering", params: CancelGatheringParams(pGatheringId: gathering.id))
                .execute()
            await load()
            for application in acceptedApplications {
                await PushNotifier.notify(userId: application.applicantId, title: String.appLocalized("「%@」がキャンセルされました", gathering.title), body: String.appLocalized("主催者が集まりを取りやめました"))
            }
            return true
        } catch {
            errorMessage = "キャンセルできませんでした"
            print("gathering cancel error: \(error)")
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

private struct CancelGatheringParams: Encodable {
    let pGatheringId: UUID
    enum CodingKeys: String, CodingKey {
        case pGatheringId = "p_gathering_id"
    }
}

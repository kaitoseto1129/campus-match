//
//  OtherUserProfileView.swift
//  Matching App
//

import SwiftUI
import Supabase

private struct ProfileVisitPayload: Encodable {
    let viewerId: UUID
    let visitedId: UUID
    enum CodingKeys: String, CodingKey {
        case viewerId = "viewer_id"
        case visitedId = "visited_id"
    }
}

private struct InsertedProfileVisit: Decodable { let id: UUID }

/// 相手プロフィールの「非表示 / ブロック / 違反報告」メニュー。
/// プロフィール画面本体とスワイプコンテナの両方から使えるよう部品として切り出している。
struct ProfileModerationMenu: View {
    var onHide: () -> Void
    var onBlock: () -> Void
    var onReport: () -> Void

    var body: some View {
        Menu {
            Button {
                onHide()
            } label: {
                Label("非表示にする", systemImage: "eye.slash")
            }
            Button(role: .destructive) {
                onBlock()
            } label: {
                Label("ブロックする", systemImage: "hand.raised.fill")
            }
            Button(role: .destructive) {
                onReport()
            } label: {
                Label("違反報告する", systemImage: "exclamationmark.triangle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("その他の操作")
    }
}

private struct ProfileVisitUpdatePayload: Encodable {
    let photoIdsViewed: [UUID]
    let reachedSection: String?
    enum CodingKeys: String, CodingKey {
        case photoIdsViewed = "photo_ids_viewed"
        case reachedSection = "reached_section"
    }
}

struct OtherUserProfileView<ActionContent: View>: View {
    let profile: Profile
    /// 「非表示/ブロック/違反報告」メニューをこの画面自身のツールバーに出すか。
    /// SwipeableProfileViewのようにこの画面を複数ページ同時に抱えるコンテナでは、
    /// 各ページのツールバーが合成されて「…」が人数分並んでしまうため、
    /// コンテナ側で1つだけ出す場合はfalseにする。
    var showsModerationMenu: Bool = true
    @ViewBuilder var actionContent: () -> ActionContent
    @EnvironmentObject private var tabRouter: TabRouter

    @State private var photos: [ProfilePhoto] = []
    @State private var university: University?
    @State private var likeCount: Int?
    @State private var isOnline: Bool?
    @State private var otherProfiles: [Profile] = []
    @State private var otherProfilePhotoURLs: [UUID: URL] = [:]
    @State private var showingHideConfirm = false
    @State private var showingBlockConfirm = false
    @State private var showingReportSheet = false
    @State private var toastMessage: String?
    @State private var visitRecordId: UUID?
    @State private var viewedPhotoIds: Set<UUID> = []
    @State private var furthestSection: ProfileSection?
    /// 自分の会員ステータス。いいね数の表示の可否を決める。
    @State private var myMembership: MembershipTier = .free
    @State private var myProfile: Profile?

    var body: some View {
        ProfileDisplayView(
            profile: profile,
            university: university,
            photos: photos,
            likeCount: likeCount,
            isOnline: isOnline,
            otherProfiles: otherProfiles,
            otherProfilePhotoURLs: otherProfilePhotoURLs,
            onSectionAppear: { section in
                if furthestSection == nil || section.order > furthestSection!.order {
                    furthestSection = section
                }
            },
            onPhotoAppear: { photoId in
                viewedPhotoIds.insert(photoId)
            }
        ) {
            actionContent()
        }
        .onAppear {
            tabRouter.pushDetailScreen()
        }
        .onDisappear {
            tabRouter.popDetailScreen()
            Task { await flushVisitTracking() }
        }
        .toolbar {
            if showsModerationMenu {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileModerationMenu(
                        onHide: { showingHideConfirm = true },
                        onBlock: { showingBlockConfirm = true },
                        onReport: { showingReportSheet = true }
                    )
                }
            }
        }
        .confirmationDialog("\(profile.name)さんを非表示にしますか?", isPresented: $showingHideConfirm, titleVisibility: .visible) {
            Button("非表示にする", role: .destructive) {
                Task {
                    let succeeded = await UserModeration.hide(userId: profile.id)
                    toastMessage = succeeded ? "非表示にしました" : "非表示にできませんでした"
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今後「探す」画面に表示されなくなります")
        }
        .confirmationDialog("\(profile.name)さんをブロックしますか?", isPresented: $showingBlockConfirm, titleVisibility: .visible) {
            Button("ブロックする", role: .destructive) {
                Task {
                    let succeeded = await UserModeration.block(userId: profile.id)
                    toastMessage = succeeded ? "ブロックしました" : "ブロックできませんでした"
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ブロックするとお互いにメッセージが送れなくなり、トーク一覧からも消えます")
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportReasonSheet(targetName: profile.name) { reason in
                Task {
                    let succeeded = await UserModeration.report(userId: profile.id, reason: reason)
                    toastMessage = succeeded ? "報告しました" : "報告できませんでした"
                }
            }
        }
        .actionToast($toastMessage)
        .task {
            await load()
        }
    }

    private func load() async {
        do {
            photos = try await supabase()
                .from("profile_photos")
                .select()
                .eq("user_id", value: profile.id)
                .order("order_number", ascending: true)
                .execute()
                .value
        } catch {
            print("other user photos load error: \(error)")
        }
        do {
            university = try await supabase()
                .from("universities")
                .select("*")
                .eq("id", value: profile.universityId)
                .single()
                .execute()
                .value
        } catch {
            print("other user university load error: \(error)")
        }
        // いいね数の表示は有料会員以上の特典。無料会員には出さない。
        myMembership = await MembershipLookup.myTier()
        if profile.showLikeCount && myMembership.canSeeLikeCount {
            do {
                likeCount = try await supabase()
                    .rpc("get_like_count", params: ["target_user_id": profile.id])
                    .execute()
                    .value
            } catch {
                print("like count load error: \(error)")
            }
        }
        do {
            isOnline = try await supabase()
                .rpc("is_user_online", params: ["target_user_id": profile.id])
                .execute()
                .value
        } catch {
            print("online status load error: \(error)")
        }
        await recordVisitIfNeeded()
        await loadOtherProfiles()
    }

    private func loadOtherProfiles() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        do {
            let myProfile: Profile = try await supabase()
                .from("profiles")
                .select("*")
                .eq("id", value: myId)
                .single()
                .execute()
                .value
            // 性別条件を使った「他のユーザーも見てみる」の取得に使うため保持しておく。
            self.myProfile = myProfile
            guard let myGender = myProfile.gender else { return }
            let oppositeGender: Gender = myGender == .male ? .female : .male

            var excludedIds = await UserModeration.hiddenOrBlockedIds(actorId: myId)
            excludedIds.insert(myId)
            excludedIds.insert(profile.id)

            let results: [Profile] = try await supabase()
                .from("profiles")
                .select("*")
                .eq("university_id", value: myProfile.universityId)
                .eq("gender", value: oppositeGender.rawValue)
                // プライベートモード中のユーザーはおすすめにも出さない。
                .eq("private_mode", value: false)
                .notIn("id", values: Array(excludedIds))
                .order("last_active_at", ascending: false)
                .limit(6)
                .execute()
                .value
            otherProfiles = results
            otherProfilePhotoURLs = await loadMainPhotoURLs(userIds: results.map(\.id))
        } catch {
            print("other profiles load error: \(error)")
        }
    }

    private func recordVisitIfNeeded() async {
        guard let myId = supabase().auth.currentUser?.id, myId != profile.id else { return }
        do {
            let myProfile: Profile = try await supabase()
                .from("profiles")
                .select("*")
                .eq("id", value: myId)
                .single()
                .execute()
                .value
            guard !myProfile.privateMode else { return }
            let inserted: InsertedProfileVisit = try await supabase()
                .from("profile_visits")
                .insert(ProfileVisitPayload(viewerId: myId, visitedId: profile.id))
                .select("id")
                .single()
                .execute()
                .value
            visitRecordId = inserted.id
        } catch {
            print("record visit error: \(error)")
        }
    }

    /// 閲覧中に見た写真・到達したセクションを、画面を離れるタイミングでまとめて記録する。
    private func flushVisitTracking() async {
        guard let visitRecordId else { return }
        do {
            try await supabase()
                .from("profile_visits")
                .update(ProfileVisitUpdatePayload(
                    photoIdsViewed: Array(viewedPhotoIds),
                    reachedSection: furthestSection?.rawValue
                ))
                .eq("id", value: visitRecordId)
                .execute()
        } catch {
            print("flush visit tracking error: \(error)")
        }
    }
}

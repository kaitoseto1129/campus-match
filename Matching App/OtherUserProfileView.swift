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
    @State private var visitRecordId: UUID?
    @State private var viewedPhotoIds: Set<UUID> = []
    @State private var furthestSection: ProfileSection?

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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingHideConfirm = true
                    } label: {
                        Label("非表示にする", systemImage: "eye.slash")
                    }
                    Button(role: .destructive) {
                        showingBlockConfirm = true
                    } label: {
                        Label("ブロックする", systemImage: "hand.raised.fill")
                    }
                    Button(role: .destructive) {
                        showingReportSheet = true
                    } label: {
                        Label("違反報告する", systemImage: "exclamationmark.triangle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("\(profile.name)さんを非表示にしますか?", isPresented: $showingHideConfirm, titleVisibility: .visible) {
            Button("非表示にする", role: .destructive) {
                Task { await UserModeration.hide(userId: profile.id) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今後「探す」画面に表示されなくなります")
        }
        .confirmationDialog("\(profile.name)さんをブロックしますか?", isPresented: $showingBlockConfirm, titleVisibility: .visible) {
            Button("ブロックする", role: .destructive) {
                Task { await UserModeration.block(userId: profile.id) }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportReasonSheet(targetName: profile.name) { reason in
                Task { await UserModeration.report(userId: profile.id, reason: reason) }
            }
        }
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
        if profile.showLikeCount {
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

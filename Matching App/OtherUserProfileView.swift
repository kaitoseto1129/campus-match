//
//  OtherUserProfileView.swift
//  Matching App
//

import SwiftUI
import Supabase

/// 相手プロフィールの「非表示 / ブロック / 違反報告」メニュー。
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

/// 他ユーザーのプロフィールを読み取り専用で表示する。
/// 通報の確認(ModerationAdminView)からのみ開く画面で、一般利用者がプロフィールを
/// 一覧で見て回るための導線は持たない。
struct OtherUserProfileView<ActionContent: View>: View {
    let profile: Profile
    var showsModerationMenu: Bool = true
    @ViewBuilder var actionContent: () -> ActionContent
    @EnvironmentObject private var tabRouter: TabRouter

    @State private var photos: [ProfilePhoto] = []
    @State private var university: University?
    @State private var isOnline: Bool?
    @State private var showingHideConfirm = false
    @State private var showingBlockConfirm = false
    @State private var showingReportSheet = false
    @State private var toastMessage: String?

    var body: some View {
        ProfileDisplayView(
            profile: profile,
            university: university,
            photos: photos,
            isOnline: isOnline
        ) {
            actionContent()
        }
        .onAppear {
            tabRouter.pushDetailScreen()
        }
        .onDisappear {
            tabRouter.popDetailScreen()
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
            Text("今後、集まりの一覧などに表示されなくなります")
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
            Text("ブロックするとお互いの集まりに参加できなくなります")
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
        do {
            isOnline = try await supabase()
                .rpc("is_user_online", params: ["target_user_id": profile.id])
                .execute()
                .value
        } catch {
            print("online status load error: \(error)")
        }
    }
}

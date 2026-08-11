//
//  PrivateModeBanner.swift
//  Matching App
//

import SwiftUI
import Supabase

/// プライベートモードがONのときだけ表示される帯。タップで設定シートを開く。
struct PrivateModeBanner: View {
    @State private var isPrivate = false
    @State private var showingSettings = false

    var body: some View {
        Group {
            if isPrivate {
                Button {
                    showingSettings = true
                } label: {
                    HStack {
                        Text("プライベートモード中")
                        Spacer()
                        Text("設定する")
                            .underline()
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.brandBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await loadStatus()
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                PrivacySettingsView()
            }
            .onDisappear {
                Task { await loadStatus() }
            }
        }
    }

    private func loadStatus() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        do {
            let profile: Profile = try await supabase()
                .from("profiles")
                .select("*")
                .eq("id", value: myId)
                .single()
                .execute()
                .value
            isPrivate = profile.privateMode
        } catch {
            print("private mode banner load error: \(error)")
        }
    }
}

struct PrivacySettingsView: View {
    @StateObject private var profileManager = ProfileManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            PrivacyToggleRows(profileManager: profileManager)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()
        }
        .navigationTitle("プライバシー設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("閉じる") { dismiss() }
            }
        }
        .task {
            await profileManager.load()
        }
    }
}

/// いいね数表示・プライベートモード・オンライン表示の3トグル。
/// マイページの設定欄とプライベートモードバナーのシートの両方から使う共通部品(重複実装の解消)。
struct PrivacyToggleRows: View {
    @ObservedObject var profileManager: ProfileManager

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Toggle(isOn: Binding(
                    get: { profileManager.profile?.showLikeCount ?? true },
                    set: { newValue in
                        Task { await profileManager.updateShowLikeCount(newValue) }
                    }
                )) {
                    Text("受け取ったいいね数を他のユーザーに表示する")
                        .font(.subheadline)
                }
                .tint(Color.brandBlue)
            }
            .padding()

            Divider().padding(.leading, 16)

            VStack(alignment: .leading, spacing: 2) {
                Toggle(isOn: Binding(
                    get: { profileManager.profile?.privateMode ?? false },
                    set: { newValue in
                        Task { await profileManager.updatePrivateMode(newValue) }
                    }
                )) {
                    Text("プライベートモード")
                        .font(.subheadline)
                }
                .tint(Color.brandBlue)
                Text("ONにすると他ユーザーのプロフィールを見ても足あとが付きません")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider().padding(.leading, 16)

            VStack(alignment: .leading, spacing: 2) {
                Toggle(isOn: Binding(
                    get: { profileManager.profile?.showOnlineStatus ?? true },
                    set: { newValue in
                        Task { await profileManager.updateShowOnlineStatus(newValue) }
                    }
                )) {
                    Text("オンライン状態を表示する")
                        .font(.subheadline)
                }
                .tint(Color.brandBlue)
                Text("OFFにすると他ユーザーからオンライン/オフラインが見えなくなります")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    PrivateModeBanner()
}

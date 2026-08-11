//
//  ModerationListView.swift
//  Matching App
//

import SwiftUI
import Supabase

/// 非表示リスト・ブロックリスト共通の画面。
struct ModerationListView: View {
    let action: String
    let title: String
    let emptyMessage: String

    @State private var profiles: [Profile] = []
    @State private var photoURLs: [UUID: URL] = [:]
    @State private var isLoading = false

    var body: some View {
        Group {
            if profiles.isEmpty && !isLoading {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)
                    .frame(maxWidth: .infinity)
            } else {
                List(profiles) { profile in
                    HStack(spacing: 12) {
                        IconImage(url: photoURLs[profile.id], size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.subheadline.bold())
                            Text(profile.ageLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("解除する") {
                            Task { await remove(profile) }
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Color.brandBlue)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func load() async {
        guard let myId = supabase().auth.currentUser?.id else { return }
        isLoading = true
        let ids = await UserModeration.actedUserIds(actorId: myId, action: action)
        guard !ids.isEmpty else {
            profiles = []
            isLoading = false
            return
        }
        do {
            profiles = try await supabase()
                .from("profiles")
                .select("*")
                .in("id", values: ids)
                .execute()
                .value
            photoURLs = await loadMainPhotoURLs(userIds: ids)
        } catch {
            print("moderation list load error: \(error)")
        }
        isLoading = false
    }

    private func remove(_ profile: Profile) async {
        await UserModeration.removeAction(userId: profile.id, action: action)
        profiles.removeAll { $0.id == profile.id }
    }
}

#Preview {
    NavigationStack {
        ModerationListView(action: "hide", title: "非表示リスト", emptyMessage: "非表示にしたユーザーはいません")
    }
}

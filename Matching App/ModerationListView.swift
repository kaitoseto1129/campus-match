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
    @State private var isLoading = true

    var body: some View {
        // 以前はScrollViewに直接.backgroundを付けていたため、読み込み中で中身が空のときに
        // 背景のグラデーションが中身の幅にしぼんで「縦線が1本あるだけ」の画面に見えていた。
        // ZStackの最背面に敷いて常に全画面を覆い、読み込み中はスピナーを出す。
        ZStack {
            Color.appListBackground.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(Color.brandPurple)
            } else if profiles.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(profiles) { profile in
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
                                Button {
                                    Task { await remove(profile) }
                                } label: {
                                    Text("解除する")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.brandPurple, in: Capsule())
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

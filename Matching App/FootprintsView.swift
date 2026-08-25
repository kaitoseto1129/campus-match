//
//  FootprintsView.swift
//  Matching App
//

import SwiftUI
import Supabase

struct FootprintsView: View {
    @StateObject private var footprintsManager = FootprintsManager()
    @EnvironmentObject private var notificationManager: NotificationCenterManager

    var body: some View {
        ScrollView {
            if footprintsManager.footprints.isEmpty && !footprintsManager.isLoading {
                VStack(spacing: 12) {
                    Text(LocalizedStringKey(footprintsManager.errorMessage ?? "まだ足あとはありません"))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    if footprintsManager.errorMessage != nil {
                        Button("再読み込み") { Task { await footprintsManager.load() } }
                            .font(.subheadline.bold())
                    }
                }
                .padding(.top, 60)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(footprintsManager.footprints.enumerated()), id: \.element.id) { index, footprint in
                        FootprintCardView(
                            footprint: footprint,
                            allProfiles: footprintsManager.footprints.map(\.profile),
                            startIndex: index,
                            alreadyLiked: footprintsManager.likedIds.contains(footprint.profile.id)
                        )
                    }
                }
                .padding()
            }
        }
        .refreshable {
            await footprintsManager.load()
        }
        .navigationTitle("足あと")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await footprintsManager.load()
            try? await supabase().rpc("mark_footprints_viewed").execute()
            await notificationManager.refreshFootprintsCount()
        }
    }
}

private struct FootprintCardView: View {
    let footprint: Footprint
    let allProfiles: [Profile]
    let startIndex: Int
    let alreadyLiked: Bool
    @State private var isSending = false
    @State private var didSend = false
    @State private var showingInsufficientLikesAlert = false
    @State private var showingSentConfirmation = false
    @State private var alertMessage = "マイページからいいねを増やしてください。"

    var body: some View {
        VStack(spacing: 8) {
            NavigationLink {
                SwipeableProfileView(profiles: allProfiles, startIndex: startIndex) { profile in
                    FootprintLikeButton(profile: profile, alreadyLiked: alreadyLiked)
                }
            } label: {
                AsyncImage(url: footprint.photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color(.systemGray6)
                    }
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            Text(footprint.profile.name.displayNameForCurrentLanguage)
                .font(.subheadline.bold())
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Text(footprint.profile.ageLabel)
                    .font(.caption.bold())
                if let major = footprint.profile.major, !major.isEmpty {
                    Text(major)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                // Task{}内で最初にisSendingを立てると、その反映より先に連打が処理されてしまう
                // (=何度でも押せてしまう)ことがあるため、タップの時点で同期的に立てる。
                guard !isSending else { return }
                isSending = true
                Task {
                    await sendLike()
                    isSending = false
                }
            } label: {
                Text((didSend || alreadyLiked) ? "いいね送信済み" : "いいねを送る")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background((didSend || alreadyLiked) ? Color.gray : Color.brandPurple)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .disabled(isSending || didSend || alreadyLiked)
        }
        .alert("いいねを送れませんでした", isPresented: $showingInsufficientLikesAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(alertMessage))
        }
        .sentConfirmationCover(isPresented: $showingSentConfirmation, message: "いいねを送りました", icon: "hand.thumbsup.fill")
    }

    private func sendLike() async {
        // 既にいいね済みの相手にもう一度送ろうとするとDB側のunique制約違反になり、
        // それが「いいねが足りません」という不正確なエラーとして表示されてしまっていた。
        // 送信前にalreadyLikedで弾くことでこのケース自体を回避する。
        guard !alreadyLiked else { return }
        do {
            try await supabase()
                .rpc("send_like_atomic", params: SendLikeParams(pToUserId: footprint.profile.id, pIsSpecial: false))
                .execute()
            await PushNotifier.notify(userId: footprint.profile.id, title: String.appLocalized("いいねが届きました!"), body: String.appLocalized("誰かがあなたのプロフィールにいいねしました"))
            didSend = true
            showingSentConfirmation = true
            try? await Task.sleep(nanoseconds: 900_000_000)
            showingSentConfirmation = false
        } catch {
            alertMessage = "残いいねが足りないか、通信に失敗した可能性があります。マイページからいいねを増やしてから、もう一度お試しください。"
            showingInsufficientLikesAlert = true
            print("footprint like error: \(error)")
        }
    }
}

private struct FootprintLikeButton: View {
    let profile: Profile
    let alreadyLiked: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isSending = false
    @State private var didSend = false
    @State private var showingInsufficientLikesAlert = false
    @State private var showingSentConfirmation = false

    var body: some View {
        Button {
            guard !isSending else { return }
            isSending = true
            Task {
                let success = await sendLike()
                isSending = false
                if success {
                    showingSentConfirmation = true
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    showingSentConfirmation = false
                    dismiss()
                } else {
                    showingInsufficientLikesAlert = true
                }
            }
        } label: {
            HStack {
                Image(systemName: "hand.thumbsup.fill")
                Text((didSend || alreadyLiked) ? "いいね送信済み" : "いいねを送る")
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background((didSend || alreadyLiked) ? Color.gray : Color.brandPurple)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .disabled(isSending || didSend || alreadyLiked)
        .alert("いいねを送れませんでした", isPresented: $showingInsufficientLikesAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("残いいねが足りないか、通信に失敗した可能性があります。マイページからいいねを増やしてから、もう一度お試しください。")
        }
        .sentConfirmationCover(isPresented: $showingSentConfirmation, message: "いいねを送りました", icon: "hand.thumbsup.fill")
    }

    private func sendLike() async -> Bool {
        guard !alreadyLiked else { return false }
        do {
            try await supabase()
                .rpc("send_like_atomic", params: SendLikeParams(pToUserId: profile.id, pIsSpecial: false))
                .execute()
            await PushNotifier.notify(userId: profile.id, title: String.appLocalized("いいねが届きました!"), body: String.appLocalized("誰かがあなたのプロフィールにいいねしました"))
            didSend = true
            return true
        } catch {
            print("footprint like error: \(error)")
            return false
        }
    }
}

#Preview {
    NavigationStack {
        FootprintsView()
    }
    .environmentObject(NotificationCenterManager())
}

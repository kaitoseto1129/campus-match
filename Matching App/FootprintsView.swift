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
                Text("まだ足あとはありません")
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(footprintsManager.footprints.enumerated()), id: \.element.id) { index, footprint in
                        FootprintCardView(
                            footprint: footprint,
                            allProfiles: footprintsManager.footprints.map(\.profile),
                            startIndex: index
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
    @State private var isSending = false
    @State private var didSend = false
    @State private var showingInsufficientLikesAlert = false

    var body: some View {
        VStack(spacing: 8) {
            NavigationLink {
                SwipeableProfileView(profiles: allProfiles, startIndex: startIndex) { profile in
                    FootprintLikeButton(profile: profile)
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
                Task {
                    isSending = true
                    await sendLike()
                    isSending = false
                }
            } label: {
                Text(didSend ? "いいねを送りました" : "いいねを送る")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(didSend ? Color.gray : Color.brandRed)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .disabled(isSending || didSend)
        }
        .alert("いいねが足りません", isPresented: $showingInsufficientLikesAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("マイページからいいねを増やしてください。")
        }
    }

    private func sendLike() async {
        do {
            try await supabase()
                .rpc("send_like_atomic", params: SendLikeParams(pToUserId: footprint.profile.id, pIsSpecial: false))
                .execute()
            didSend = true
        } catch {
            showingInsufficientLikesAlert = true
            print("footprint like error: \(error)")
        }
    }
}

private struct FootprintLikeButton: View {
    let profile: Profile
    @Environment(\.dismiss) private var dismiss
    @State private var isSending = false
    @State private var didSend = false
    @State private var showingInsufficientLikesAlert = false

    var body: some View {
        Button {
            Task {
                isSending = true
                let success = await sendLike()
                isSending = false
                if success {
                    dismiss()
                } else {
                    showingInsufficientLikesAlert = true
                }
            }
        } label: {
            HStack {
                Image(systemName: "heart.fill")
                Text(didSend ? "いいねを送りました" : "いいねを送る")
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.brandRed)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .disabled(isSending || didSend)
        .alert("いいねが足りません", isPresented: $showingInsufficientLikesAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("マイページからいいねを増やしてください。")
        }
    }

    private func sendLike() async -> Bool {
        do {
            try await supabase()
                .rpc("send_like_atomic", params: SendLikeParams(pToUserId: profile.id, pIsSpecial: false))
                .execute()
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

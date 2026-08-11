//
//  LikesView.swift
//  Matching App
//

import SwiftUI

struct LikesView: View {
    @StateObject private var likesManager = LikesManager()
    @StateObject private var profileManager = ProfileManager()
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var showingFilterSheet = false
    @State private var navPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                PrivateModeBanner()

                HStack(spacing: 8) {
                    FilterMenuButton(isActive: likesManager.filter.isActive) {
                        showingFilterSheet = true
                    }
                    if !likesManager.received.isEmpty {
                        Text("\(likesManager.received.count)人")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    SortMenuButton(sortOrder: $likesManager.filter.sortOrder)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if likesManager.received.isEmpty && !likesManager.isLoading {
                    emptyState
                } else {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(likesManager.received.enumerated()), id: \.element.id) { index, received in
                            LikeCardView(likesManager: likesManager, received: received, startIndex: index)
                        }
                    }
                    .padding()
                }
            }
            .background(Color.appListBackground.ignoresSafeArea())
            .refreshable {
                await likesManager.load()
            }
            .navigationTitle("いいね")
            .task {
                await likesManager.load()
                await profileManager.load()
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheetView(filter: $likesManager.filter)
            }
            .onChange(of: likesManager.filter) { _, _ in
                Task { await likesManager.load() }
            }
            .onChange(of: tabRouter.popToRootTokens[.likes]) { _, _ in
                navPath = NavigationPath()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.thumbsup")
                .font(.system(size: 56))
                .foregroundStyle(Color(.systemGray3))

            Text("新着いいねはありません")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("プロフィールを充実させると\nいいねが届きやすくなります")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))

            NavigationLink {
                ProfileEditView(profileManager: profileManager)
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("プロフィールを編集する")
                }
                .bold()
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(.systemGray6))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            .padding(.horizontal, 40)

            HStack(spacing: 10) {
                Button {
                    tabRouter.selectedTab = .discover
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("探す")
                    }
                    .bold()
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.brandBlue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                Button {
                    tabRouter.selectedTab = .myPage
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("アピールを使う")
                    }
                    .bold()
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.brandOrange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                }
            }
            .padding(.horizontal, 40)

            NavigationLink {
                SentLikesView()
            } label: {
                HStack(spacing: 4) {
                    Text("いいね!履歴を見る")
                    Image(systemName: "chevron.right")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 60)
    }
}

private struct LikeCardView: View {
    @ObservedObject var likesManager: LikesManager
    let received: ReceivedLike
    let startIndex: Int
    @EnvironmentObject private var matchManager: MatchManager
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 8) {
            NavigationLink {
                SwipeableProfileView(profiles: likesManager.received.map(\.profile), startIndex: startIndex) { profile in
                    ThanksButton(likesManager: likesManager, profile: profile)
                }
            } label: {
                AsyncImage(url: received.photoURL) { phase in
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
                .overlay {
                    if received.like.isReminded {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.purple, lineWidth: 3)
                    }
                }
            }
            .buttonStyle(.plain)

            if received.like.isReminded {
                Text("見てね!")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple, in: Capsule())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(received.profile.name)
                    .font(.subheadline.bold())
                Text(received.profile.ageLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task {
                    isSending = true
                    if let match = await likesManager.sendThanks(for: received.like) {
                        matchManager.presentCelebrationImmediately(match: match, profile: received.profile, photoURL: received.photoURL)
                    }
                    isSending = false
                }
            } label: {
                Text("ありがとう")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.brandBlue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .disabled(isSending)
        }
    }
}

struct ThanksButton: View {
    @ObservedObject var likesManager: LikesManager
    let profile: Profile
    @EnvironmentObject private var matchManager: MatchManager
    @Environment(\.dismiss) private var dismiss
    @State private var isSending = false

    var body: some View {
        Button {
            guard let matched = likesManager.received.first(where: { $0.profile.id == profile.id }) else { return }
            Task {
                isSending = true
                if let match = await likesManager.sendThanks(for: matched.like) {
                    matchManager.presentCelebrationImmediately(match: match, profile: matched.profile, photoURL: matched.photoURL)
                }
                isSending = false
                dismiss()
            }
        } label: {
            Text("ありがとう")
                .bold()
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.brandBlue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .disabled(isSending)
    }
}

#Preview {
    LikesView()
        .environmentObject(TabRouter())
        .environmentObject(MatchManager())
}

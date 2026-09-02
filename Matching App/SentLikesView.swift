//
//  SentLikesView.swift
//  Matching App
//

import SwiftUI

/// 送ったいいねの一覧。以前は「相手から/自分から」の切り替えがあったが、
/// 相手から届いたいいねはDiscoverのカードにバッジ表示する方式に一本化したため、
/// このビューは自分が送ったいいねだけを表示する(Web版の/profile/sent-likesと同じ整理)。
struct SentLikesView: View {
    @StateObject private var sentLikesManager = SentLikesManager()

    var body: some View {
        ScrollView {
            if sentLikesManager.sent.isEmpty && !sentLikesManager.isLoading {
                emptyState(message: "まだ誰にもいいねしていません", error: sentLikesManager.errorMessage) {
                    Task { await sentLikesManager.load() }
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(sentLikesManager.sent.enumerated()), id: \.element.id) { index, sentLike in
                        sentCard(sentLike, index: index)
                    }
                }
                .padding()
            }
        }
        .background(Color.appListBackground.ignoresSafeArea())
        .navigationTitle("送ったいいね")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await sentLikesManager.load()
        }
        .refreshable {
            await sentLikesManager.load()
        }
    }

    /// errorがある場合は「0件」ではなく読み込みエラーだと分かるようにし、再読み込みできるようにする。
    private func emptyState(message: String, error: String? = nil, retry: (() -> Void)? = nil) -> some View {
        VStack(spacing: 12) {
            Text(LocalizedStringKey(error ?? message))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            if error != nil, let retry {
                Button("再読み込み") { retry() }
                    .font(.subheadline.bold())
            }
        }
        .padding(.top, 60)
    }

    @ViewBuilder
    private func sentCard(_ sentLike: SentLike, index: Int) -> some View {
        LikeHistoryCardView(
            profile: sentLike.profile,
            photoURL: sentLike.photoURL,
            photoCount: sentLike.photoCount,
            isOnline: sentLike.isOnline,
            commonPoints: sentLike.commonPoints,
            ribbonLabel: sentLike.isMatched ? String.appLocalized("マッチ済み") : sentLike.profile.joinBadgeLabel,
            ribbonColor: sentLike.isMatched ? Color.brandPurple : Color.brandOrange,
            destination: AnyView(
                SwipeableProfileView(profiles: sentLikesManager.sent.map(\.profile), startIndex: index) { _ in EmptyView() }
            )
        ) {
            SentLikeStatusLabel(sentLike: sentLike)
        }
    }
}

/// いいね履歴カードの共通デザイン。写真(オンラインドット+写真枚数バッジ付き)+基本情報+共通点バッジ+アクションボタン。
private struct LikeHistoryCardView<Action: View>: View {
    let profile: Profile
    let photoURL: URL?
    let photoCount: Int
    let isOnline: Bool?
    let commonPoints: Int
    let ribbonLabel: String?
    let ribbonColor: Color
    let destination: AnyView
    @ViewBuilder var action: () -> Action

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                NavigationLink(destination: destination) {
                    ZStack(alignment: .topTrailing) {
                        AsyncImage(url: photoURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Color(.systemGray6)
                            }
                        }
                        .frame(width: 92, height: 92)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        HStack(spacing: 2) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 8))
                            Text("\(photoCount)")
                                .font(.system(size: 9).bold())
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(4)

                        if let isOnline {
                            Circle()
                                .fill(isOnline ? Color.green : Color(.systemGray3))
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                .padding(4)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    if let ribbonLabel {
                        Text(ribbonLabel)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(ribbonColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    HStack(spacing: 6) {
                        Text(profile.name.displayNameForCurrentLanguage)
                            .font(.subheadline.bold())
                        Text(profile.ageLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(profile.areaLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if commonPoints > 0 {
                        Text("共通点\(commonPoints)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.brandPurple.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.brandPurple)
                    }
                    if let tagline = profile.tagline, !tagline.isEmpty {
                        Text(tagline)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            action()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.pastelAccent(for: profile.id).opacity(0.4), lineWidth: 1.5)
        }
        .shadow(color: Color.pastelAccent(for: profile.id).opacity(0.18), radius: 8, y: 3)
    }
}

/// 送ったいいねの状態表示。いいねは1人につき1回なので、ここに操作ボタンは置かない。
private struct SentLikeStatusLabel: View {
    let sentLike: SentLike

    var body: some View {
        let isMatched = sentLike.isMatched
        HStack(spacing: 4) {
            Image(systemName: isMatched ? "checkmark.circle.fill" : "paperplane.fill")
            Text(isMatched ? "マッチ済み" : "いいね送信済み")
        }
        .font(.subheadline.bold())
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(isMatched ? Color.brandPurple.opacity(0.12) : Color(.systemGray6))
        .foregroundStyle(isMatched ? Color.brandPurple : Color.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

#Preview {
    NavigationStack {
        SentLikesView()
            .environmentObject(MatchManager())
    }
}

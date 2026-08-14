//
//  DiscoverView.swift
//  Matching App
//

import SwiftUI

struct DiscoverView: View {
    @StateObject private var discoverManager = DiscoverManager()
    @StateObject private var missionsManager = DailyMissionsManager()
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var showingFilterSheet = false
    @State private var showingMissions = false
    @State private var navPath = NavigationPath()
    @AppStorage("hasSeenDiscoverTutorial") private var hasSeenDiscoverTutorial = false
    @State private var tutorialStep: DiscoverTutorialStep?
    @State private var tutorialAnchors: [String: Anchor<CGRect>] = [:]

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .top) {
                // appListBackgroundは下の方で真っ白(systemGroupedBackground)に近づいてしまい、
                // スクロールすると単調に見えるため、探す画面だけは画面全体でうっすら色みが続く
                // 専用の背景にしている。
                discoverBackground.ignoresSafeArea()

                // 他の一覧画面より少しだけ色みを強くした、探す画面専用のトップウォッシュ。
                LinearGradient(
                    colors: [Color.brandPurple.opacity(0.35), Color.brandTeal.opacity(0.22), Color.brandPink.opacity(0.12), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
                .ignoresSafeArea(edges: .top)

                ScrollView {
                PrivateModeBanner()

                missionsBanner

                appealBanner

                boostedSection

                HStack(spacing: 8) {
                    FilterMenuButton(isActive: discoverManager.filter.isActive) {
                        showingFilterSheet = true
                    }
                    Text("\(discoverManager.totalCandidateCount)人")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.brandPurple)
                    Spacer()
                    SortMenuButton(sortOrder: $discoverManager.filter.sortOrder)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .tutorialAnchor("filter")

                if discoverManager.candidates.isEmpty && !discoverManager.isLoading {
                    Text("表示できるユーザーがいません")
                        .foregroundStyle(.secondary)
                        .padding(.top, 60)
                } else {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
                    let firstBatch = Array(discoverManager.candidates.prefix(4))
                    let restBatch = Array(discoverManager.candidates.dropFirst(4))

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(firstBatch.enumerated()), id: \.element.id) { index, candidate in
                            candidateCard(candidate: candidate, index: index)
                        }
                    }
                    .padding()

                    // 一番上には出さず、少しスクロールしてから見えるようにする。
                    remindableSection

                    if !restBatch.isEmpty {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Array(restBatch.enumerated()), id: \.element.id) { offset, candidate in
                                candidateCard(candidate: candidate, index: offset + firstBatch.count)
                            }
                        }
                        .padding()
                    }

                    if discoverManager.isLoadingMore {
                        ProgressView()
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                    }
                }
                }
                .refreshable {
                    await discoverManager.load()
                }

                if let tutorialStep {
                    DiscoverTutorialOverlay(
                        step: $tutorialStep,
                        anchors: tutorialAnchors,
                        onGoToMyPage: { tabRouter.selectedTab = .myPage }
                    ) {
                        hasSeenDiscoverTutorial = true
                    }
                    .zIndex(1)
                }
            }
            .onPreferenceChange(TutorialAnchorKey.self) { tutorialAnchors = $0 }
            .navigationTitle("探す")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingMissions = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "list.bullet.clipboard.fill")
                            if missionsManager.hasClaimableMission {
                                Circle()
                                    .fill(Color.brandOrange)
                                    .frame(width: 9, height: 9)
                                    .offset(x: 8, y: -6)
                            }
                        }
                    }
                }
            }
            .task {
                await discoverManager.load()
                await missionsManager.load()
                if !hasSeenDiscoverTutorial {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    withAnimation { tutorialStep = .missions }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheetView(filter: $discoverManager.filter, showsTutorialHint: tutorialStep == .filter) { draft in
                    await discoverManager.previewCount(for: draft)
                }
            }
            .onChange(of: showingFilterSheet) { _, isShowing in
                if !isShowing, tutorialStep == .filter {
                    withAnimation { tutorialStep = .candidate }
                }
            }
            .sheet(isPresented: $showingMissions, onDismiss: {
                Task { await missionsManager.load() }
                if tutorialStep == .missions {
                    withAnimation { tutorialStep = .filter }
                }
            }) {
                DailyMissionsView(showsTutorialHint: tutorialStep == .missions)
            }
            .onChange(of: discoverManager.filter) { _, _ in
                Task { await discoverManager.load() }
            }
            .onChange(of: tabRouter.popToRootTokens[.discover]) { _, _ in
                navPath = NavigationPath()
            }
        }
    }

    /// デイリーミッション画面への導線バナー。初回チュートリアルの最初のスポットライト対象。
    /// 探す画面専用の背景。真っ白にならないよう、画面全体でうっすらブランドカラーが続くようにしている。
    private var discoverBackground: some View {
        ZStack {
            Color(.systemGroupedBackground)
            LinearGradient(
                colors: [Color.brandPurple.opacity(0.06), Color.brandTeal.opacity(0.05), Color.brandPink.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var missionsBanner: some View {
        Button {
            showingMissions = true
        } label: {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundStyle(Color.brandPurple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日のミッションを確認しよう")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("ログインするだけでいいねがもらえます")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if missionsManager.hasClaimableMission {
                    Circle()
                        .fill(Color.brandOrange)
                        .frame(width: 9, height: 9)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.brandPurple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
        .tutorialAnchor("missions")
    }

    /// 探す画面から直接アピール(ブースト)機能への導線を出す。実際の発動はマイページで行う。
    private var appealBanner: some View {
        Button {
            tabRouter.selectedTab = .myPage
        } label: {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Color.brandOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("アピールを使う")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("10いいねで1時間、この画面のトップに表示されます")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.brandOrange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }

    private var boostedSection: some View {
        Group {
            if !discoverManager.boostedProfiles.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(Color.brandOrange)
                        Text("アピール中のユーザー")
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(discoverManager.boostedProfiles) { profile in
                                let index = discoverManager.candidates.firstIndex(where: { $0.id == profile.id }) ?? 0
                                candidateCard(candidate: profile, index: index, width: 130, height: 160)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.brandOrange.opacity(0.15), Color.brandPink.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
    }

    private func candidateCard(candidate: Profile, index: Int, width: CGFloat? = nil, height: CGFloat = 180) -> some View {
        NavigationLink {
            SwipeableProfileView(profiles: discoverManager.candidates, startIndex: index) { profile, advance in
                DiscoverLikeButton(discoverManager: discoverManager, candidate: profile, onHidden: advance)
            }
        } label: {
            DiscoverCardView(profile: candidate, photoURL: discoverManager.candidatePhotoURLs[candidate.id], photoHeight: height)
                .frame(width: width)
        }
        .buttonStyle(.plain)
        .onAppear {
            Task { await discoverManager.loadMoreCandidatesIfNeeded(currentItem: candidate) }
        }
    }

    private var remindableSection: some View {
        Group {
            if !discoverManager.remindableProfiles.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("みてね!で気になるお相手に再アプローチしよう!")
                        .font(.subheadline.bold())
                        .padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(discoverManager.remindableProfiles.enumerated()), id: \.element.id) { index, profile in
                                RemindableCardView(discoverManager: discoverManager, profile: profile, startIndex: index)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.12), Color.brandPink.opacity(0.12)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.top, 12)
            }
        }
    }
}

private struct RemindableCardView: View {
    @ObservedObject var discoverManager: DiscoverManager
    let profile: Profile
    let startIndex: Int
    @State private var isSending = false
    @State private var showingSentConfirmation = false
    @State private var showingInsufficientLikesAlert = false

    private var alreadyReminded: Bool { discoverManager.remindedIds.contains(profile.id) }

    var body: some View {
        VStack(spacing: 6) {
            NavigationLink {
                SwipeableProfileView(profiles: discoverManager.remindableProfiles, startIndex: startIndex) { p, advance in
                    DiscoverLikeButton(discoverManager: discoverManager, candidate: p, onHidden: advance)
                }
            } label: {
                AsyncImage(url: discoverManager.remindablePhotoURLs[profile.id]) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color(.systemGray6)
                    }
                }
                .frame(width: 130, height: 160)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button {
                guard !isSending else { return }
                isSending = true
                Task {
                    let success = await discoverManager.sendReminder(to: profile.id)
                    isSending = false
                    if success {
                        showingSentConfirmation = true
                        try? await Task.sleep(nanoseconds: 900_000_000)
                        showingSentConfirmation = false
                    } else {
                        showingInsufficientLikesAlert = true
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: alreadyReminded ? "checkmark" : "eye.fill")
                    Text(alreadyReminded ? "送信済み" : "みてね!")
                }
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(alreadyReminded ? Color.gray : Color.purple)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .disabled(isSending || alreadyReminded)
        }
        .frame(width: 130)
        .sentConfirmationCover(isPresented: $showingSentConfirmation, message: "\(DiscoverManager.reminderLikeCost)いいね使いました", icon: "bell.fill")
        .alert("いいねが足りません", isPresented: $showingInsufficientLikesAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("マイページからいいねを増やしてください。")
        }
    }
}

private struct DiscoverCardView: View {
    let profile: Profile
    let photoURL: URL?
    var photoHeight: CGFloat = 180

    /// カードごとに一貫した淡い差し色をつけて、グリッド全体の色みを増やす。
    private var accent: Color { Color.pastelAccent(for: profile.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color(.systemGray6)
                    }
                }
                .frame(height: photoHeight)
                .frame(maxWidth: .infinity)
                .clipped()

                if profile.isBoosted {
                    RibbonBadge(text: "アピール中", color: Color.brandOrange)
                        .padding(.top, 10)
                } else if let badge = profile.joinBadgeLabel {
                    RibbonBadge(text: badge, color: Color.brandPurple)
                        .padding(.top, 10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(accent.opacity(0.55), lineWidth: 2)
            }
            .shadow(color: accent.opacity(0.25), radius: 6, y: 3)

            Text(profile.name)
                .font(.subheadline.bold())
                .lineLimit(1)
                .padding(.horizontal, 2)

            HStack(spacing: 6) {
                Text(profile.ageLabel)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accent, in: Capsule())
                if let major = profile.major, !major.isEmpty {
                    Text(major)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

private struct DiscoverLikeButton: View {
    @ObservedObject var discoverManager: DiscoverManager
    let candidate: Profile
    var onHidden: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var isSending = false
    @State private var showingPopularSheet = false
    @State private var showingSentConfirmation = false
    @State private var confirmationMessage = "いいねを送りました"
    @State private var confirmationIcon = "hand.thumbsup.fill"
    @State private var showingInsufficientLikesAlert = false
    @State private var showingReminderConfirm = false

    private var alreadyLiked: Bool { discoverManager.likedIds.contains(candidate.id) }
    private var alreadyReminded: Bool { discoverManager.remindedIds.contains(candidate.id) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await discoverManager.hideCandidate(candidate.id)
                    advanceOrDismiss()
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "eye.slash.fill")
                        .font(.callout)
                    Text("非表示")
                        .font(.caption2)
                }
                .frame(width: 60, height: 54)
                .background(Color(.systemGray5))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button {
                if alreadyLiked {
                    // 見てねはいいねを消費するため、送る前に必ず確認する。
                    showingReminderConfirm = true
                    return
                }
                guard !isSending else { return }
                isSending = true
                Task {
                    let count = await discoverManager.likeCount(for: candidate.id)
                    isSending = false
                    if count >= DiscoverManager.popularMemberThreshold {
                        showingPopularSheet = true
                    } else {
                        await sendAndConfirm(isSpecial: false)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: alreadyReminded ? "checkmark" : (alreadyLiked ? "bell.fill" : "hand.thumbsup.fill"))
                    Text(alreadyReminded ? "見てね送信済み" : (alreadyLiked ? "見てね" : "いいねを送る"))
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(alreadyReminded ? Color.gray : (alreadyLiked ? Color.purple : Color.brandPurple))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            .disabled(isSending || alreadyReminded)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .confirmationDialog(
            "見てねを送りますか?",
            isPresented: $showingReminderConfirm,
            titleVisibility: .visible
        ) {
            Button("送る(\(DiscoverManager.reminderLikeCost)いいね消費)") {
                Task { await sendReminderAndConfirm() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("いいねを\(DiscoverManager.reminderLikeCost)つ消費して、\(candidate.name)さんにもう一度アピールします。よろしいですか?")
        }
        .sheet(isPresented: $showingPopularSheet) {
            PopularMemberSheet(profile: candidate, photoURL: discoverManager.candidatePhotoURLs[candidate.id]) { useSpecial in
                showingPopularSheet = false
                Task { await sendAndConfirm(isSpecial: useSpecial) }
            }
        }
        .sentConfirmationCover(isPresented: $showingSentConfirmation, message: confirmationMessage, icon: confirmationIcon)
        .alert("いいねが足りません", isPresented: $showingInsufficientLikesAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("マイページからいいねを増やしてください。")
        }
    }

    private func sendAndConfirm(isSpecial: Bool) async {
        isSending = true
        let success = await discoverManager.sendLike(to: candidate.id, isSpecial: isSpecial)
        isSending = false
        guard success else {
            showingInsufficientLikesAlert = true
            return
        }
        confirmationMessage = "いいねを送りました"
        confirmationIcon = "hand.thumbsup.fill"
        showingSentConfirmation = true
        try? await Task.sleep(nanoseconds: 900_000_000)
        showingSentConfirmation = false
        // いいね送信後は自動で次のお相手に移らず、この画面に留まる(離脱するまでは消えない)。
        // 非表示にした時だけ、明示的にadvanceOrDismiss()で次へ進む。
    }

    private func sendReminderAndConfirm() async {
        isSending = true
        let success = await discoverManager.sendReminder(to: candidate.id)
        isSending = false
        guard success else {
            showingInsufficientLikesAlert = true
            return
        }
        confirmationMessage = "\(DiscoverManager.reminderLikeCost)いいね使いました"
        confirmationIcon = "bell.fill"
        showingSentConfirmation = true
        try? await Task.sleep(nanoseconds: 900_000_000)
        showingSentConfirmation = false
    }

    /// 非表示にした時、スワイプで見ている途中なら次のお相手へ自動で送り、
    /// 単体で開いている場合はこれまで通り閉じる。
    private func advanceOrDismiss() {
        if let onHidden {
            onHidden()
        } else {
            dismiss()
        }
    }
}

#Preview {
    DiscoverView()
}

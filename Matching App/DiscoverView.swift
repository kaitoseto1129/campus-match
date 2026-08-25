//
//  DiscoverView.swift
//  Matching App
//

import SwiftUI
import Combine

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
    @State private var showingBoostConfirm = false
    @State private var showingBoostFailedAlert = false
    @State private var showingBoostedToast = false
    @State private var isBoosting = false

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

                if discoverManager.candidates.isEmpty && discoverManager.isLoading {
                    ProgressView()
                        .padding(.top, 60)
                } else if discoverManager.candidates.isEmpty && !discoverManager.isLoading {
                    Text("表示できるユーザーがいません")
                        .foregroundStyle(.secondary)
                        .padding(.top, 60)
                } else {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
                    let firstBatch = Array(discoverManager.candidates.prefix(4))
                    let restBatch = Array(discoverManager.candidates.dropFirst(4))

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(firstBatch, id: \.id) { candidate in
                            candidateCard(candidate: candidate)
                        }
                    }
                    .padding()

                    if !restBatch.isEmpty {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(restBatch, id: \.id) { candidate in
                                candidateCard(candidate: candidate)
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

                // confirmationDialog自体の暗転だけでは、カラフルな候補カードが透けて
                // 読みづらいという声があったため、ダイアログ表示中は下地をしっかり暗くする。
                if showingBoostConfirm {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showingBoostConfirm)
            .onPreferenceChange(TutorialAnchorKey.self) { tutorialAnchors = $0 }
            .navigationTitle("探す")
            // ミッションへの導線は画面上部のバナー(missionsBanner)にまとめている。
            // 以前はツールバーにも同じ導線があり、同じ画面に入口が2つ並んでいた。
            .task {
                await discoverManager.load()
                await missionsManager.load()
                // 「サインアップ直後」の対象者だけに絞る(既存ユーザーがログインし直した時や、
                // 再インストール後にセッションが復元された時には出さないようにするため)。
                let isEligible = UserDefaults.standard.bool(forKey: AuthManager.eligibleForOnboardingTutorialKey)
                if isEligible && !hasSeenDiscoverTutorial {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    withAnimation { tutorialStep = .missions }
                }
            }
            // アピール(ブースト)は約1時間で自動的に切れるが、この画面を開いたまま
            // 何も操作せずにいると、期限が過ぎても「アピール中」の表示とボタンのdisabledが
            // 残ったままになってしまっていた(load()し直すまで気づけない)。
            // 通信を伴わない軽い再判定を1分おきに行い、切れたら自動でボタンを再度押せるようにする。
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                discoverManager.refreshBoostStatus()
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
                // sheetは別の階層に出るため、EnvironmentObjectを明示的に引き継ぐ必要がある。
                DailyMissionsView(showsTutorialHint: tutorialStep == .missions)
                    .environmentObject(tabRouter)
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
                    Text("\(missionsManager.claimableMissionCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(Color.brandOrange, in: Circle())
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

    /// 探す画面のアピール(ブースト)導線。
    /// 以前はマイページへ飛ばすだけだったが、目的の操作までが遠かったため、
    /// この場で確認ダイアログを出してそのまま発動できるようにしている。
    private var appealBanner: some View {
        Button {
            showingBoostConfirm = true
        } label: {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Color.brandOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(discoverManager.isBoostActive ? "アピール中" : "アピールを使う")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(discoverManager.isBoostActive
                         ? "いまこの画面のトップに表示されています"
                         : "10いいねで1時間、この画面のトップに表示されます")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !discoverManager.isBoostActive {
                    Text("使う")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.brandOrange, in: Capsule())
                }
            }
            .padding()
            .background(Color.brandOrange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
        .disabled(discoverManager.isBoostActive || isBoosting)
        .confirmationDialog("アピールしますか?", isPresented: $showingBoostConfirm, titleVisibility: .visible) {
            Button("アピールする(10いいね消費)") {
                Task {
                    isBoosting = true
                    let success = await discoverManager.activateBoost()
                    isBoosting = false
                    if success {
                        showingBoostedToast = true
                        try? await Task.sleep(nanoseconds: 900_000_000)
                        showingBoostedToast = false
                    } else {
                        showingBoostFailedAlert = true
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("残いいねを10消費して、1時間だけ探す画面のトップに表示されるようになります。")
        }
        .alert("アピールを利用できませんでした", isPresented: $showingBoostFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("残いいねが10未満の可能性があります。")
        }
        .sentConfirmationCover(isPresented: $showingBoostedToast, message: "アピールを開始しました!", icon: "bolt.fill")
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
                                candidateCard(candidate: profile, width: 130, height: 160)
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

    private func candidateCard(candidate: Profile, width: CGFloat? = nil, height: CGFloat = 180) -> some View {
        // アピール中カードは、まだ「探す」グリッド側のページングに読み込まれていない
        // ユーザーのこともある。その場合candidates内を検索してもヒットせず、以前は
        // 見つからない時のフォールバックとして先頭(index 0)の全く別人を開いてしまっていた。
        // タップした本人が必ず開かれるよう、見つからない場合はこの1人だけのリストにする。
        let index = discoverManager.candidates.firstIndex(where: { $0.id == candidate.id })
        let profiles = index != nil ? discoverManager.candidates : [candidate]
        return NavigationLink {
            SwipeableProfileView(profiles: profiles, startIndex: index ?? 0) { profile, advance in
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

            Text(profile.name.displayNameForCurrentLanguage)
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
    @State private var isHiding = false
    @State private var showingPopularSheet = false
    @State private var showingSentConfirmation = false
    @State private var confirmationMessage = "いいねを送りました"
    @State private var confirmationIcon = "hand.thumbsup.fill"
    @State private var showingInsufficientLikesAlert = false
    @State private var toastMessage: String?

    private var alreadyLiked: Bool { discoverManager.likedIds.contains(candidate.id) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                // いいねボタンと違ってガードが無く、非表示の通信中に連打すると
                // advanceOrDismiss()が2回呼ばれてお相手が1人分余計に飛ばされる不具合があったため追加。
                guard !isHiding else { return }
                isHiding = true
                Task {
                    let succeeded = await discoverManager.hideCandidate(candidate.id)
                    isHiding = false
                    // 以前は非表示にすると自動で次のお相手へ切り替わっていたが、
                    // 勝手に画面が進むのが分かりづらいという声があったため、
                    // 次へ進むかどうかは本人がスワイプするまで待つようにした。
                    // ただし何の反応もないと「ボタンが反応していない」ように見えるため、
                    // 一瞬だけ完了トーストを出す。
                    toastMessage = succeeded ? "非表示にしました" : "非表示にできませんでした"
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
            .disabled(isHiding)

            Button {
                guard !isSending, !alreadyLiked else { return }
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
                    Image(systemName: alreadyLiked ? "checkmark" : "hand.thumbsup.fill")
                    Text(alreadyLiked ? "いいね送信済み" : "いいねを送る")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(alreadyLiked ? AnyShapeStyle(Color.gray) : AnyShapeStyle(Color.brandPurple))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            .disabled(isSending || alreadyLiked)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .sheet(isPresented: $showingPopularSheet) {
            PopularMemberSheet(profile: candidate, photoURL: discoverManager.candidatePhotoURLs[candidate.id]) { useSpecial in
                showingPopularSheet = false
                Task { await sendAndConfirm(isSpecial: useSpecial) }
            }
        }
        .sentConfirmationCover(isPresented: $showingSentConfirmation, message: confirmationMessage, icon: confirmationIcon)
        .alert("いいねを送れませんでした", isPresented: $showingInsufficientLikesAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("残いいねが足りないか、通信に失敗した可能性があります。マイページからいいねを増やしてから、もう一度お試しください。")
        }
        .actionToast($toastMessage)
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
        // 以前はいいね送信後に自動で次のお相手へ切り替えていたが、勝手に画面が進むのが
        // 分かりづらいという声があったため、次へ進むかどうかは本人がスワイプするまで待つ。
    }

    /// 非表示・いいね送信のあと、スワイプで見ている途中なら次のお相手へ自動で送り、
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

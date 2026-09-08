//
//  MyPageHomeView.swift
//  Matching App
//

import SwiftUI

struct MyPageHomeView: View {
    @StateObject private var profileManager = ProfileManager()
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var notificationManager: NotificationCenterManager
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var navPath = NavigationPath()
    @State private var showingWithdrawConfirm = false
    @State private var showingLogoutConfirm = false
    @AppStorage("appLanguage") private var appLanguageRaw = AppLanguage.system.rawValue
    @State private var showingWithdrawFailedAlert = false
    @State private var isWithdrawing = false
    @State private var showingHobbyCardPicker = false
    @State private var showingShareSheet = false
    /// マイページを初めて開いた時だけ、主要機能を簡単に紹介するガイドを一度出す。
    /// 画面中央に説明カードを出すだけでなく、実際のセクションをスポットライトで指し示し、
    /// 実際にタップ・操作してもらいながら紹介する。
    @AppStorage("hasSeenMyPageTutorial") private var hasSeenMyPageTutorial = false
    @State private var myPageTutorialStep: MyPageTutorialStep? = nil
    @State private var myPageTutorialAnchors: [String: Anchor<CGRect>] = [:]

    /// プロフィールが既に100%完成している場合は「充実度」ステップを飛ばす。
    private var myPageTutorialSteps: [MyPageTutorialStep] {
        var steps = MyPageTutorialStep.allCases
        let isComplete = profileManager.profile.map { $0.completeness(photoCount: profileManager.photos.count).percent >= 100 } ?? false
        if isComplete {
            steps.removeAll { $0 == .completeness }
        }
        return steps
    }

    private func advanceMyPageTutorial(from step: MyPageTutorialStep) {
        let steps = myPageTutorialSteps
        guard let index = steps.firstIndex(of: step) else { return }
        let nextIndex = steps.index(after: index)
        withAnimation {
            myPageTutorialStep = nextIndex < steps.endIndex ? steps[nextIndex] : nil
        }
        if nextIndex >= steps.endIndex {
            hasSeenMyPageTutorial = true
        }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .top) {
                // 以前は上部260pt分にしかグラデーションが無く、スクロールして設定欄あたりまで来ると
                // 色味が完全に無くなって寂しく見えていたため、ベースを画面全体で色みのあるappListBackgroundにした。
                Color.appListBackground.ignoresSafeArea()
                LinearGradient(
                    colors: [Color.brandPurple.opacity(0.5), Color.brandTeal.opacity(0.28), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
                .ignoresSafeArea(edges: .top)

                ScrollView {
                    VStack(spacing: 20) {
                        header
                        profileCompletenessCard
                        shareAppButton
                        // 趣味カードは「後からゆっくり整える」項目なので、下のほうに置く。
                        hobbyCardsCard
                        VStack(spacing: 0) {
                            menuRow(icon: "checkmark.shield.fill", iconColor: Color.brandTeal, title: "安心・安全ガイド") {
                                SafetyGuideView()
                            }
                            Divider().padding(.leading, 66)
                            menuRow(icon: "eye.slash.fill", iconColor: Color(.systemGray), title: "非表示リスト") {
                                ModerationListView(action: "hide", title: "非表示リスト", emptyMessage: "非表示にしたユーザーはいません")
                            }
                            Divider().padding(.leading, 66)
                            menuRow(icon: "hand.raised.fill", iconColor: .black, title: "ブロックリスト") {
                                ModerationListView(action: "block", title: "ブロックリスト", emptyMessage: "ブロックしたユーザーはいません")
                            }
                            if profileManager.profile?.isAdmin == true {
                                Divider().padding(.leading, 66)
                                menuRow(icon: "shield.lefthalf.filled", iconColor: .red, title: "通報管理(管理者)") {
                                    ModerationAdminView()
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        supportSection
                        settingsSection
                    }
                    .padding(.top)
                    .padding(.bottom, 100)
                }

                if let myPageTutorialStep {
                    MyPageTutorialOverlay(
                        step: myPageTutorialStep,
                        anchors: myPageTutorialAnchors,
                        onNext: { advanceMyPageTutorial(from: myPageTutorialStep) },
                        onSkipAll: {
                            self.myPageTutorialStep = nil
                            hasSeenMyPageTutorial = true
                        }
                    )
                    .zIndex(1)
                }

            }
            .onPreferenceChange(TutorialAnchorKey.self) { myPageTutorialAnchors = $0 }
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await profileManager.load()
                // 「サインアップ直後」の対象者だけに絞る(既存ユーザーがログインし直した時や、
                // 再インストール後にセッションが復元された時には出さないようにするため)。
                let isEligible = UserDefaults.standard.bool(forKey: AuthManager.eligibleForOnboardingTutorialKey)
                if isEligible && !hasSeenMyPageTutorial {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    withAnimation { myPageTutorialStep = myPageTutorialSteps.first }
                }
            }
            .onChange(of: tabRouter.popToRootTokens[.myPage]) { _, _ in
                navPath = NavigationPath()
            }
            // 趣味カードのシートを実際に開いて閉じたら、チュートリアルを自動で次のステップへ進める。
            .onChange(of: showingHobbyCardPicker) { wasShowing, isShowing in
                if !isShowing, myPageTutorialStep == .hobbyCards {
                    advanceMyPageTutorial(from: .hobbyCards)
                }
            }
            .confirmationDialog(
                "本当に退会しますか?",
                isPresented: $showingWithdrawConfirm,
                titleVisibility: .visible
            ) {
                Button("退会する", role: .destructive) {
                    Task {
                        isWithdrawing = true
                        let success = await auth.deleteAccount()
                        isWithdrawing = false
                        if !success {
                            showingWithdrawFailedAlert = true
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("プロフィール、参加した集まり、グループトークの履歴などすべてのデータが削除され、元に戻せません。")
            }
            .alert("退会処理に失敗しました", isPresented: $showingWithdrawFailedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("通信環境を確認してもう一度お試しください。")
            }
            .disabled(isWithdrawing)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            IconImage(url: profileManager.mainPhoto?.url, size: 90)
                .overlay(Circle().stroke(.white, lineWidth: 4))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
            NavigationLink {
                ProfileView(profileManager: profileManager)
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("プロフィールを確認・編集")
                        .bold()
                }
                .font(.subheadline)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.brandPurple)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }
        }
    }

    /// 登録済みの趣味カードの一覧と、追加・編集の導線。
    private var hobbyCardsCard: some View {
        let cards = HobbyCard.cards(for: profileManager.profile?.hobbyCards ?? [])
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("趣味カード")
                    .font(.subheadline.bold())
                Spacer()
                if !cards.isEmpty {
                    Text("\(cards.count)個")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if cards.isEmpty {
                Text("趣味カードを登録すると、集まりで話のきっかけになります")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(cards) { card in
                            HobbyCardChip(card: card)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Button {
                showingHobbyCardPicker = true
            } label: {
                HStack {
                    Image(systemName: cards.isEmpty ? "plus.circle.fill" : "square.and.pencil")
                    Text(cards.isEmpty ? "趣味カードを追加する" : "趣味カードを編集する")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.brandPurple.opacity(0.12))
                .foregroundStyle(Color.brandPurple)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .tutorialAnchor("myPageHobbyCards")
        .sheet(isPresented: $showingHobbyCardPicker) {
            HobbyCardPickerView(profileManager: profileManager)
        }
    }

    private var profileCompletenessCard: some View {
        Group {
            if let profile = profileManager.profile {
                let completeness = profile.completeness(photoCount: profileManager.photos.count)
                if completeness.percent < 100 {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("プロフィール充実度")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(completeness.percent)%")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.brandPurple)
                            }
                            ProgressView(value: Double(completeness.percent), total: 100)
                                .tint(Color.brandPurple)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 0) {
                            Text("やることリスト")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 6)
                            ForEach(completeness.missingItems) { item in
                                HStack {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                    Text(item.display)
                                        .font(.subheadline)
                                    Spacer()
                                    // 趣味カードだけはプロフィール編集画面ではなく専用の選択画面で設定する。
                                    if item.key.contains("趣味カード") {
                                        Button {
                                            showingHobbyCardPicker = true
                                        } label: {
                                            Text("設定する")
                                                .font(.caption.bold())
                                                .foregroundStyle(Color.brandPurple)
                                        }
                                    } else {
                                        NavigationLink {
                                            ProfileEditView(profileManager: profileManager, initialFocusSectionId: ProfileEditView.sectionId(for: item.key))
                                        } label: {
                                            Text("編集する")
                                                .font(.caption.bold())
                                                .foregroundStyle(Color.brandPurple)
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
                                if item != completeness.missingItems.last {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .tutorialAnchor("myPageCompleteness")
                }
            }
        }
    }

    /// アプリの紹介。
    private var shareAppButton: some View {
        Button {
            showingShareSheet = true
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("アプリを紹介する")
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.brandTeal)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 23))
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [Self.shareMessage]) { _ in
                showingShareSheet = false
            }
        }
    }

    private static let shareMessage = "キャンマッチ、使ってみて!大学の友達と集まりを立てられる、学生限定のアプリです。"

    /// お問い合わせ・利用規約・プライバシーポリシーへの導線。App Storeの審査要件として、
    /// ユーザーが運営への連絡手段や規約を確認できるようにしている。
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("サポート")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            // 以前は外部URL/mailtoを開く実装だったが、公開前のURLは404になり、
            // mailtoもメール未設定の端末では無反応だったため、すべてアプリ内画面に置き換えた。
            VStack(spacing: 0) {
                languageRow
                Divider().padding(.leading, 66)
                menuRow(icon: "envelope.fill", iconColor: Color.brandTeal, title: "お問い合わせ") {
                    ContactView()
                }
                Divider().padding(.leading, 66)
                menuRow(icon: "doc.text.fill", iconColor: Color.brandPurple, title: "利用規約") {
                    LegalDocumentView(document: .terms)
                }
                Divider().padding(.leading, 66)
                menuRow(icon: "lock.doc.fill", iconColor: Color(.systemGray), title: "プライバシーポリシー") {
                    LegalDocumentView(document: .privacy)
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }

    /// 端末の言語設定に関わらず、アプリ内の表示言語を固定できる。
    private var languageRow: some View {
        Menu {
            Picker("", selection: $appLanguageRaw) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.label).tag(language.rawValue)
                }
            }
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.brandOrange)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "globe")
                            .foregroundStyle(.white)
                    }
                Text("言語 / Language")
                    .foregroundStyle(.primary)
                Spacer()
                Text((AppLanguage(rawValue: appLanguageRaw) ?? .system).label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func linkRow(icon: String, iconColor: Color, title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                Circle()
                    .fill(iconColor)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: icon)
                            .foregroundStyle(.white)
                    }
                Text(LocalizedStringKey(title))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("設定")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            PrivacyToggleRows(profileManager: profileManager)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Button {
                showingLogoutConfirm = true
            } label: {
                Text("ログアウト")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.top, 12)

            Button {
                showingWithdrawConfirm = true
            } label: {
                Text("退会する")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.top, 8)
        }
        .padding(.horizontal)
        .confirmationDialog("ログアウトしますか?", isPresented: $showingLogoutConfirm, titleVisibility: .visible) {
            Button("ログアウト", role: .destructive) {
                Task { await auth.signOut() }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func menuRow<Destination: View>(
        icon: String,
        iconColor: Color,
        title: String,
        badgeCount: Int = 0,
        anchorId: String? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(iconColor)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: icon)
                            .foregroundStyle(.white)
                    }
                Text(LocalizedStringKey(title))
                    .foregroundStyle(.primary)
                if badgeCount > 0 {
                    Text("\(badgeCount)件")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.brandPurple, in: Capsule())
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(OptionalTutorialAnchor(id: anchorId))
        .simultaneousGesture(TapGesture().onEnded { onTap?() })
    }
}

/// anchorIdがnilの場合は何もしない(tutorialAnchorはIDが必須のため、条件分岐をViewModifierにまとめている)。
private struct OptionalTutorialAnchor: ViewModifier {
    let id: String?
    func body(content: Content) -> some View {
        if let id {
            content.tutorialAnchor(id)
        } else {
            content
        }
    }
}

#Preview {
    MyPageHomeView()
        .environmentObject(NotificationCenterManager())
}

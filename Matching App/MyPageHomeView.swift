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
    @State private var showingWithdrawFailedAlert = false
    @State private var isWithdrawing = false
    @State private var showingShareBonusToast = false
    @State private var isBoosting = false
    @State private var showingBoostFailedAlert = false
    @State private var showingBoostConfirm = false
    @State private var showingPurchaseSheet = false
    @State private var showingHobbyCardPicker = false

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
                        hobbyCardsCard
                        profileCompletenessCard
                        boostButton
                        remainingLikesCard
                        purchaseLikesButton
                        shareAppButton
                        VStack(spacing: 0) {
                            menuRow(icon: "chart.bar.fill", iconColor: .indigo, title: "分析") {
                                ProfileAnalyticsView()
                            }
                            Divider().padding(.leading, 66)
                            menuRow(icon: "shoeprints.fill", iconColor: Color.brandOrange, title: "足あと", badgeCount: notificationManager.footprintsCount) {
                                FootprintsView()
                            }
                            Divider().padding(.leading, 66)
                            menuRow(icon: "hand.thumbsup.fill", iconColor: Color.brandPurple, title: "いいね!履歴") {
                                SentLikesView()
                            }
                            Divider().padding(.leading, 66)
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
            }
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await profileManager.load()
            }
            .onChange(of: tabRouter.popToRootTokens[.myPage]) { _, _ in
                navPath = NavigationPath()
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
                Text("プロフィール、いいね、マッチ、トーク履歴などすべてのデータが削除され、元に戻せません。")
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
            membershipButton
        }
    }

    /// 現在の会員ステータスを表示しつつ、会員ステータス画面へ入る導線。
    private var membershipButton: some View {
        let tier = profileManager.profile?.membership ?? .free
        return NavigationLink {
            MembershipStatusView(profileManager: profileManager)
        } label: {
            HStack {
                Image(systemName: tier == .free ? "person.fill" : "crown.fill")
                Text("会員ステータス")
                    .bold()
                Text(tier.label)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.25), in: Capsule())
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .font(.subheadline)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(tier == .free ? AnyShapeStyle(Color.brandNavy) : AnyShapeStyle(Color.brandGradient))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
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
                Text("趣味カードを登録すると、共通の話題があるお相手に見つけてもらいやすくなります")
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
                            ForEach(completeness.missingLabels, id: \.self) { label in
                                HStack {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                    Text(LocalizedStringKey(label))
                                        .font(.subheadline)
                                    Spacer()
                                    NavigationLink {
                                        ProfileEditView(profileManager: profileManager, initialFocusSectionId: ProfileEditView.sectionId(for: label))
                                    } label: {
                                        Text("編集する")
                                            .font(.caption.bold())
                                            .foregroundStyle(Color.brandPurple)
                                    }
                                }
                                .padding(.vertical, 6)
                                if label != completeness.missingLabels.last {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
            }
        }
    }

    private var boostButton: some View {
        Group {
            if let expiresAt = profileManager.profile?.boostExpiresAt, expiresAt > Date() {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color.brandOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("アピール中")
                            .font(.subheadline.bold())
                        Text("\(expiresAt, style: .relative)後に終了")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.brandOrange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.brandOrange, lineWidth: 1.5)
                }
                .padding(.horizontal)
            } else {
                Button {
                    showingBoostConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(Color.brandOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("アピールを使う")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.brandOrange)
                            Text("10いいねで1時間、探す画面のトップに表示!")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.brandOrange, lineWidth: 1.5)
                    }
                }
                .disabled(isBoosting)
                .padding(.horizontal)
            }
        }
        .confirmationDialog(
            "アピールしますか?",
            isPresented: $showingBoostConfirm,
            titleVisibility: .visible
        ) {
            Button("アピールする(10いいね消費)") {
                Task {
                    isBoosting = true
                    let success = await profileManager.activateBoost()
                    isBoosting = false
                    if !success { showingBoostFailedAlert = true }
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
    }

    private var remainingLikesCard: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.thumbsup.fill")
                .foregroundStyle(Color.brandPurple)
            Text("残いいね!")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(profileManager.profile?.remainingLikes ?? 0)")
                .font(.title2.bold())
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        .padding(.horizontal)
    }

    private var purchaseLikesButton: some View {
        Button {
            showingPurchaseSheet = true
        } label: {
            HStack {
                Image(systemName: "cart.fill")
                Text("いいねを購入する")
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.brandPurple)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 23))
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingPurchaseSheet) {
            LikesPurchaseSheet(profileManager: profileManager)
        }
    }

    private var shareAppButton: some View {
        ShareLink(item: "キャンパスマッチ、使ってみて!学生限定のマッチングアプリです。") {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text(profileManager.profile?.shareBonusClaimed == true ? "アプリを紹介する(特典は受け取り済み)" : "アプリを紹介して50いいねゲット")
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
        .simultaneousGesture(TapGesture().onEnded {
            Task {
                let alreadyClaimed = profileManager.profile?.shareBonusClaimed ?? false
                let success = await profileManager.claimShareBonus()
                if success && !alreadyClaimed {
                    showingShareBonusToast = true
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    showingShareBonusToast = false
                }
            }
        })
        .sentConfirmationCover(isPresented: $showingShareBonusToast, message: "50いいねを獲得しました!", icon: "gift.fill")
    }

    /// お問い合わせ・利用規約・プライバシーポリシーへの導線。App Storeの審査要件として、
    /// ユーザーが運営への連絡手段や規約を確認できるようにしている。
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("サポート")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                linkRow(icon: "envelope.fill", iconColor: Color.brandTeal, title: "お問い合わせ", url: URL(string: "mailto:kaitoseto1129@gmail.com")!)
                Divider().padding(.leading, 66)
                linkRow(icon: "doc.text.fill", iconColor: Color.brandPurple, title: "利用規約", url: LegalLinks.terms)
                Divider().padding(.leading, 66)
                linkRow(icon: "lock.doc.fill", iconColor: Color(.systemGray), title: "プライバシーポリシー", url: LegalLinks.privacy)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
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
    }
}

#Preview {
    MyPageHomeView()
        .environmentObject(NotificationCenterManager())
}

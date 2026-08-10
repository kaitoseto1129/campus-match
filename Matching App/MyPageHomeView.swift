//
//  MyPageHomeView.swift
//  Matching App
//

import SwiftUI

struct MyPageHomeView: View {
    @StateObject private var profileManager = ProfileManager()
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var notificationManager: NotificationCenterManager
    @State private var showingWithdrawConfirm = false
    @State private var showingWithdrawFailedAlert = false
    @State private var isWithdrawing = false
    @State private var showingShareBonusToast = false
    @State private var isBoosting = false
    @State private var showingBoostFailedAlert = false
    @State private var showingBoostConfirm = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                LinearGradient(
                    colors: [Color.brandPink.opacity(0.55), Color(.systemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
                .ignoresSafeArea(edges: .top)

                ScrollView {
                    VStack(spacing: 20) {
                        header
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
                            menuRow(icon: "bell.fill", iconColor: .purple, title: "お知らせ") {
                                AnnouncementsView()
                            }
                            Divider().padding(.leading, 66)
                            menuRow(icon: "hand.thumbsup.fill", iconColor: Color.brandRed, title: "いいね!履歴") {
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

                        settingsSection
                    }
                    .padding(.top)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await profileManager.load()
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
                .padding(.vertical, 10)
                .background(.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            }
        }
    }

    private var profileCompletenessCard: some View {
        Group {
            if let profile = profileManager.profile {
                let completeness = profile.completeness(photoCount: profileManager.photos.count)
                if completeness.percent < 100 {
                    NavigationLink {
                        ProfileEditView(profileManager: profileManager)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("プロフィール充実度")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(completeness.percent)%")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.brandRed)
                            }
                            ProgressView(value: Double(completeness.percent), total: 100)
                                .tint(Color.brandRed)
                            if let firstMissing = completeness.missingLabels.first {
                                Text("「\(firstMissing)」を入力すると魅力度がアップします")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
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
                .foregroundStyle(Color.brandRed)
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
            Task { await profileManager.purchaseLikesMock() }
        } label: {
            HStack {
                Image(systemName: "cart.fill")
                Text("いいねを購入(100円で100いいね)")
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.brandRed)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 23))
        }
        .padding(.horizontal)
    }

    private var shareAppButton: some View {
        ShareLink(item: "キャンパスマッチ、使ってみて!学生限定のマッチングアプリです。") {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text(profileManager.profile?.shareBonusClaimed == true ? "アプリを紹介する" : "アプリを紹介して10いいねゲット")
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
        .sentConfirmationCover(isPresented: $showingShareBonusToast, message: "10いいねを獲得しました!", icon: "gift.fill")
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
            .padding(.top, 12)
        }
        .padding(.horizontal)
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
                Text(title)
                    .foregroundStyle(.primary)
                if badgeCount > 0 {
                    Text("\(badgeCount)件")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.brandRed, in: Capsule())
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

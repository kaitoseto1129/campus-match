//
//  MembershipStatusView.swift
//  Matching App
//

import SwiftUI
import StoreKit

/// 現在の会員ステータスと、プランの特典を確認・契約できる画面。
/// 1ユーザーは無料会員 / 有料会員のいずれか1つに属する。
/// (以前は有料会員とVIPオプションの2プランだったが、分かりやすさのため1プランに統合した。
/// DB上のmembership_tier列はpremium/vipの2値が残っているが、UI上はどちらも「有料会員」として扱う)
/// 契約はApp StoreのIn-App Purchase(自動更新サブスクリプション)を通して行う。
struct MembershipStatusView: View {
    @ObservedObject var profileManager: ProfileManager
    @StateObject private var store = StoreManager()
    @State private var showingPurchaseConfirm = false
    @State private var showingManageSubscriptions = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showingFailedAlert = false
    @State private var showingPurchasedToast = false
    @State private var purchasedMessage = ""

    private var currentTier: MembershipTier { profileManager.profile?.membership ?? .free }
    private var isPaidMember: Bool { currentTier != .free }

    var body: some View {
        ZStack {
            Color.appListBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    currentStatusCard
                    paidPlanCard
                    freePlanBenefitsCard
                    manageSubscriptionButton
                    noteText
                }
                .padding(.vertical)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("会員ステータス")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await profileManager.load()
            await store.loadProducts()
            await store.syncMembershipEntitlement()
            await profileManager.load()
        }
        .confirmationDialog(
            "有料会員を契約しますか?",
            isPresented: $showingPurchaseConfirm,
            titleVisibility: .visible
        ) {
            Button("契約する") {
                Task { await purchase() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(subscriptionDisclosureText)
        }
        .alert("プランを変更できませんでした", isPresented: $showingFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(store.errorMessage ?? "通信環境を確認してもう一度お試しください。"))
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .sentConfirmationCover(isPresented: $showingPurchasedToast, message: purchasedMessage, icon: "crown.fill")
        .disabled(isPurchasing)
    }

    /// Appleが自動更新サブスクリプションの購入導線の近くに表示することを求めている開示文言
    /// (期間・料金・自動更新される旨・解約方法)。
    private var subscriptionDisclosureText: String {
        let price = store.membershipProduct?.displayPrice ?? "¥\(MembershipTier.vip.monthlyPriceYen.formatted())"
        return String.appLocalized("月額%@の自動更新サブスクリプションです。契約と同時に30いいね!が付与されます。期間終了の24時間前までに解約しない限り自動的に更新され、料金はApple IDのアカウントに請求されます。契約はいつでもこの画面の「サブスクリプションを管理」から解約できます。", price)
    }

    private func purchase() async {
        isPurchasing = true
        let wasFree = currentTier == .free
        let success = await store.purchaseMembership()
        isPurchasing = false
        guard success else {
            if store.errorMessage != nil {
                showingFailedAlert = true
            }
            return
        }
        await profileManager.load()
        purchasedMessage = wasFree ? "有料会員になりました!30いいね!を付与しました" : "有料会員になりました!"
        showingPurchasedToast = true
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        showingPurchasedToast = false
    }

    // MARK: - 現在のステータス

    private var currentStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("現在の会員ステータス")
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: isPaidMember ? "crown.fill" : "person.fill")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(isPaidMember ? AnyShapeStyle(Color.brandGradient) : AnyShapeStyle(Color(.systemGray3)), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentTier.label)
                        .font(.title3.bold())
                    Text(currentTierDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private var currentTierDescription: String {
        isPaidMember
            ? String.appLocalized("メッセージし放題・いいね数表示など全特典が使えます")
            : String.appLocalized("プロフィール閲覧といいね!が使えます。メッセージは1日%lld人まで送れます", MembershipTier.freeDailyMessagePartnerLimit)
    }

    // MARK: - 無料会員でできること

    private var freePlanBenefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("無料会員でできること")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                freeBenefitRow(icon: "person.crop.circle", text: "プロフィール閲覧")
                freeBenefitRow(icon: "hand.thumbsup.fill", text: "いいねを送る")
                freeBenefitRow(icon: "bubble.left.and.bubble.right", text: "メッセージ(1日\(MembershipTier.freeDailyMessagePartnerLimit)人まで)")
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func freeBenefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.brandTeal)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }

    // MARK: - 有料プラン(1本化)

    private var paidPlanCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("有料会員")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.brandGradient, in: Capsule())
                Spacer()
                Text(isPaidMember ? "契約中" : "未契約")
                    .font(.caption.bold())
                    .foregroundStyle(isPaidMember ? Color.brandPurple : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .overlay(Capsule().stroke(isPaidMember ? Color.brandPurple : Color(.systemGray3), lineWidth: 1))
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                // 実際の請求額はストアフロントごとに異なるため、StoreKitが返すローカライズ済み価格を優先して表示する。
                Text(store.membershipProduct?.displayPrice ?? "¥\(MembershipTier.vip.monthlyPriceYen.formatted())")
                    .font(.title2.bold())
                Text("/月")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(paidBenefits, id: \.title) { benefit in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: benefit.icon)
                            .foregroundStyle(Color.brandPurple)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(benefit.caption))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(LocalizedStringKey(benefit.title))
                                .font(.subheadline.bold())
                        }
                        Spacer()
                    }
                }
            }

            Button {
                showingPurchaseConfirm = true
            } label: {
                if isPurchasing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text(isPaidMember ? "契約中" : "このプランにする")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isPaidMember ? AnyShapeStyle(Color(.systemGray3)) : AnyShapeStyle(Color.brandGradient))
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                }
            }
            .disabled(isPaidMember || store.membershipProduct == nil)
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(isPaidMember ? Color.brandPurple : Color.clear, lineWidth: 2)
        }
        .padding(.horizontal)
    }

    /// サブスクリプションの解約はAppleの規約上、必ずApple自身の管理画面(Manage Subscriptions)を
    /// 経由する必要があるため、アプリ側でDBのステータスを直接書き換えることはしない。
    /// 解約が確定すると、次回このアプリを開いた時にsyncMembershipEntitlement()が
    /// 自動的に無料会員へ反映する。
    private var manageSubscriptionButton: some View {
        Group {
            if isPaidMember {
                Button {
                    showingManageSubscriptions = true
                } label: {
                    Text("サブスクリプションを管理")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            } else {
                Button {
                    Task {
                        isRestoring = true
                        await store.restorePurchases()
                        await profileManager.load()
                        isRestoring = false
                    }
                } label: {
                    HStack {
                        if isRestoring {
                            ProgressView()
                        } else {
                            Text("購入を復元")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .disabled(isRestoring)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }

    private var noteText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("プランはいつでも「サブスクリプションを管理」から解約できます。解約後も、現在の請求期間の終了までは有料会員の特典をご利用いただけます。")
            Text("[利用規約](\(LegalLinks.terms.absoluteString)) ・ [プライバシーポリシー](\(LegalLinks.privacy.absoluteString))")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .tint(Color.brandPurple)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private struct Benefit {
        let icon: String
        let caption: String
        let title: String
    }

    /// 以前の有料会員+VIPオプションの特典をすべて含む。
    private var paidBenefits: [Benefit] {
        [
            Benefit(icon: "bubble.left.and.bubble.right.fill", caption: "人数制限なく", title: "メッセージし放題!"),
            Benefit(icon: "hand.thumbsup.fill", caption: "お相手の人気度が分かる", title: "いいね!数表示"),
            Benefit(icon: "eye.slash.fill", caption: "身バレ防止", title: "プライベートモード"),
            Benefit(icon: "checkmark.message.fill", caption: "トークの", title: "既読がわかる機能"),
            Benefit(icon: "gift.fill", caption: "契約と同時に", title: "30いいね!を付与!")
        ]
    }
}

#Preview {
    NavigationStack {
        MembershipStatusView(profileManager: .preview)
    }
}

//
//  MembershipStatusView.swift
//  Matching App
//

import SwiftUI

/// 現在の会員ステータスと、プランの特典を確認・切り替えできる画面。
/// 1ユーザーは無料会員 / 有料会員のいずれか1つに属する。
/// (以前は有料会員とVIPオプションの2プランだったが、分かりやすさのため1プランに統合した。
/// DB上のmembership_tier列はpremium/vipの2値が残っているが、UI上はどちらも「有料会員」として扱う)
struct MembershipStatusView: View {
    @ObservedObject var profileManager: ProfileManager
    @State private var pendingTier: MembershipTier?
    @State private var isPurchasing = false
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
                    freePlanCard
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
        }
        .confirmationDialog(
            pendingTier.map { $0 == .free ? "無料会員に戻しますか?" : "有料会員を契約しますか?" } ?? "",
            isPresented: Binding(get: { pendingTier != nil }, set: { if !$0 { pendingTier = nil } }),
            titleVisibility: .visible
        ) {
            if let tier = pendingTier {
                Button(tier == .free ? "無料会員に戻す" : "有料会員を契約する") {
                    Task { await purchase(tier) }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let tier = pendingTier {
                Text(confirmationMessage(for: tier))
            }
        }
        .alert("プランを変更できませんでした", isPresented: $showingFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("通信環境を確認してもう一度お試しください。")
        }
        .sentConfirmationCover(isPresented: $showingPurchasedToast, message: purchasedMessage, icon: "crown.fill")
        .disabled(isPurchasing)
    }

    private func confirmationMessage(for tier: MembershipTier) -> String {
        if tier == .free {
            return "無料会員に戻すと、メッセージは1日\(MembershipTier.freeDailyMessagePartnerLimit)人までの制限がかかり、いいね数の表示・プライベートモード・既読表示・マッチ度の表示が使えなくなります。"
        }
        return "月額¥\(tier.monthlyPriceYen.formatted())で契約と同時に30いいね!が付与されます。(このアプリでは実際の課金は発生しません)"
    }

    private func purchase(_ tier: MembershipTier) async {
        isPurchasing = true
        let wasFree = currentTier == .free
        let success = await profileManager.purchaseMembership(tier)
        isPurchasing = false
        guard success else {
            showingFailedAlert = true
            return
        }
        guard tier != .free else { return }
        purchasedMessage = wasFree ? "\(tier.label)になりました!30いいね!を付与しました" : "\(tier.label)になりました!"
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
            ? "メッセージし放題・いいね数表示など全特典が使えます"
            : "プロフィール閲覧といいね!が使えます。メッセージは1日\(MembershipTier.freeDailyMessagePartnerLimit)人まで送れます"
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
                Text("¥\(MembershipTier.vip.monthlyPriceYen.formatted())")
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
                            Text(benefit.caption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(benefit.title)
                                .font(.subheadline.bold())
                        }
                        Spacer()
                    }
                }
            }

            Button {
                pendingTier = .vip
            } label: {
                Text(isPaidMember ? "契約中" : "このプランにする")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isPaidMember ? AnyShapeStyle(Color(.systemGray3)) : AnyShapeStyle(Color.brandGradient))
                    .clipShape(RoundedRectangle(cornerRadius: 25))
            }
            .disabled(isPaidMember)
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(isPaidMember ? Color.brandPurple : Color.clear, lineWidth: 2)
        }
        .padding(.horizontal)
    }

    private var freePlanCard: some View {
        Group {
            if isPaidMember {
                Button {
                    pendingTier = .free
                } label: {
                    Text("無料会員に戻す")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }

    private var noteText: some View {
        Text("※ 現在は開発中のため、実際の課金は発生しません。プランはいつでも切り替えられます。")
            .font(.caption2)
            .foregroundStyle(.secondary)
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
            Benefit(icon: "percent", caption: "お相手との", title: "マッチ度の表示"),
            Benefit(icon: "gift.fill", caption: "契約と同時に", title: "30いいね!を付与!")
        ]
    }
}

#Preview {
    NavigationStack {
        MembershipStatusView(profileManager: .preview)
    }
}

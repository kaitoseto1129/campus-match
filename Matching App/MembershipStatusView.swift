//
//  MembershipStatusView.swift
//  Matching App
//

import SwiftUI

/// 現在の会員ステータスと、各プランの特典を確認・切り替えできる画面。
/// 1ユーザーは無料会員 / 有料会員 / VIPオプションのいずれか1つに属し、上位プランは下位の特典をすべて含む。
struct MembershipStatusView: View {
    @ObservedObject var profileManager: ProfileManager
    @State private var pendingTier: MembershipTier?
    @State private var isPurchasing = false
    @State private var showingFailedAlert = false
    @State private var showingPurchasedToast = false
    @State private var purchasedMessage = ""

    private var currentTier: MembershipTier { profileManager.profile?.membership ?? .free }

    var body: some View {
        ZStack {
            Color.appListBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    currentStatusCard
                    planCard(.premium)
                    planCard(.vip)
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
            pendingTier.map { "\($0.label)に変更しますか?" } ?? "",
            isPresented: Binding(get: { pendingTier != nil }, set: { if !$0 { pendingTier = nil } }),
            titleVisibility: .visible
        ) {
            if let tier = pendingTier {
                Button(tier == .free ? "無料会員に戻す" : "\(tier.label)を契約する") {
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
        switch tier {
        case .free:
            return "無料会員に戻すと、メッセージの送信・いいね数の表示・プライベートモード・既読表示が使えなくなります。"
        case .premium:
            return currentTier == .free
                ? "契約と同時に30いいね!が付与されます。(このアプリでは実際の課金は発生しません)"
                : "有料会員に変更します。VIP限定の特典は使えなくなります。"
        case .vip:
            return currentTier == .free
                ? "有料会員のすべての特典に加えてVIP特典が使えるようになり、契約と同時に30いいね!が付与されます。(このアプリでは実際の課金は発生しません)"
                : "VIPオプションに変更します。"
        }
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
                Image(systemName: currentTier == .free ? "person.fill" : "crown.fill")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(currentTier == .free ? AnyShapeStyle(Color(.systemGray3)) : AnyShapeStyle(Color.brandGradient), in: Circle())
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
        switch currentTier {
        case .free: return "プロフィール閲覧といいね!が使えます"
        case .premium: return "メッセージし放題・いいね!数表示が使えます"
        case .vip: return "有料会員の特典 + VIP特典がすべて使えます"
        }
    }

    // MARK: - 各プラン

    private func planCard(_ tier: MembershipTier) -> some View {
        let isCurrent = currentTier == tier
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(tier.label)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(tier == .vip ? AnyShapeStyle(Color.brandGradient) : AnyShapeStyle(Color.brandPurple), in: Capsule())
                Spacer()
                Text(isCurrent ? "契約中" : "未契約")
                    .font(.caption.bold())
                    .foregroundStyle(isCurrent ? Color.brandPurple : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .overlay(Capsule().stroke(isCurrent ? Color.brandPurple : Color(.systemGray3), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(benefits(for: tier), id: \.title) { benefit in
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

            if tier == .vip && currentTier == .premium {
                Text("有料会員の特典もすべて含まれます")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                pendingTier = tier
            } label: {
                Text(isCurrent ? "契約中" : "このプランにする")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isCurrent ? AnyShapeStyle(Color(.systemGray3)) : AnyShapeStyle(Color.brandGradient))
                    .clipShape(RoundedRectangle(cornerRadius: 25))
            }
            .disabled(isCurrent)
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(isCurrent ? Color.brandPurple : Color.clear, lineWidth: 2)
        }
        .padding(.horizontal)
    }

    private var freePlanCard: some View {
        Group {
            if currentTier != .free {
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

    private func benefits(for tier: MembershipTier) -> [Benefit] {
        switch tier {
        case .free:
            return []
        case .premium:
            return [
                Benefit(icon: "bubble.left.and.bubble.right.fill", caption: "マッチング相手と", title: "メッセージし放題!"),
                Benefit(icon: "hand.thumbsup.fill", caption: "お相手の人気度が分かる", title: "いいね!数表示"),
                Benefit(icon: "gift.fill", caption: "契約と同時に", title: "30いいね!を付与!")
            ]
        case .vip:
            return [
                Benefit(icon: "eye.slash.fill", caption: "身バレ防止", title: "プライベートモード"),
                Benefit(icon: "checkmark.message.fill", caption: "トークの", title: "既読がわかる機能"),
                Benefit(icon: "percent", caption: "お相手との", title: "マッチ度の表示")
            ]
        }
    }
}

#Preview {
    NavigationStack {
        MembershipStatusView(profileManager: .preview)
    }
}

//
//  LikesPurchaseSheet.swift
//  Matching App
//

import SwiftUI

private struct LikePlan: Identifiable {
    let likes: Int
    let priceYen: Int
    let icon: String
    let isBestValue: Bool
    var id: Int { likes }
}

private let likePlans: [LikePlan] = [
    LikePlan(likes: 10, priceYen: 1_000, icon: "hand.thumbsup.fill", isBestValue: false),
    LikePlan(likes: 50, priceYen: 5_000, icon: "hand.thumbsup.fill", isBestValue: false),
    LikePlan(likes: 100, priceYen: 10_000, icon: "star.fill", isBestValue: true),
]

/// いいね購入時に、金額の異なる複数プランから選べるシート。
struct LikesPurchaseSheet: View {
    @ObservedObject var profileManager: ProfileManager
    @Environment(\.dismiss) private var dismiss
    @State private var purchasingLikes: Int?
    @State private var showingFailedAlert = false
    @State private var showingSuccessToast = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                            .frame(width: 76, height: 76)
                            .background(Color.brandPurple, in: Circle())
                        Text("いいねを購入")
                            .font(.title3.bold())
                        Text("プランを選んでください(実際の決済はまだ行われません)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    VStack(spacing: 12) {
                        ForEach(likePlans) { plan in
                            Button {
                                Task { await purchase(plan) }
                            } label: {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(plan.isBestValue ? Color.brandOrange.opacity(0.15) : Color.brandPurple.opacity(0.12))
                                            .frame(width: 46, height: 46)
                                        Image(systemName: plan.icon)
                                            .foregroundStyle(plan.isBestValue ? Color.brandOrange : Color.brandPurple)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text("\(plan.likes)いいね")
                                                .font(.headline)
                                            if plan.isBestValue {
                                                Text("お得")
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(Color.brandOrange, in: Capsule())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        Text("¥\(plan.priceYen.formatted())")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if purchasingLikes == plan.likes {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(plan.isBestValue ? Color.brandOrange.opacity(0.5) : Color.clear, lineWidth: 2)
                                }
                                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                            }
                            .buttonStyle(.plain)
                            .disabled(purchasingLikes != nil)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .background(Color.appListBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("購入に失敗しました", isPresented: $showingFailedAlert) {
                Button("OK", role: .cancel) {}
            }
            .sentConfirmationCover(isPresented: $showingSuccessToast, message: "購入が完了しました", icon: "hand.thumbsup.fill")
        }
    }

    private func purchase(_ plan: LikePlan) async {
        purchasingLikes = plan.likes
        let success = await profileManager.purchaseLikes(amount: plan.likes)
        purchasingLikes = nil
        if success {
            showingSuccessToast = true
            try? await Task.sleep(nanoseconds: 900_000_000)
            showingSuccessToast = false
            dismiss()
        } else {
            showingFailedAlert = true
        }
    }
}

#Preview {
    LikesPurchaseSheet(profileManager: .preview)
}

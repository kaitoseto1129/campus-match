//
//  LikesPurchaseSheet.swift
//  Matching App
//

import SwiftUI

private struct LikePlan: Identifiable {
    let likes: Int
    let priceYen: Int
    var id: Int { likes }
}

private let likePlans: [LikePlan] = [
    LikePlan(likes: 10, priceYen: 1_000),
    LikePlan(likes: 50, priceYen: 5_000),
    LikePlan(likes: 100, priceYen: 10_000),
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
            VStack(spacing: 16) {
                Text("いいねを購入")
                    .font(.title3.bold())
                    .padding(.top, 12)
                Text("プランを選んでください(実際の決済はまだ行われません)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    ForEach(likePlans) { plan in
                        Button {
                            Task { await purchase(plan) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(plan.likes)いいね")
                                        .font(.headline)
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
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(purchasingLikes != nil)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
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

//
//  LikesPurchaseSheet.swift
//  Matching App
//

import SwiftUI
import StoreKit

/// いいね購入時に、金額の異なる複数プランから選べるシート。
/// App StoreのIn-App Purchaseを通して実際に決済し、成功したらいいねを付与する。
struct LikesPurchaseSheet: View {
    @ObservedObject var profileManager: ProfileManager
    @StateObject private var store = StoreManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showingFailedAlert = false
    @State private var showingSuccessToast = false

    private static let likeAmounts = [10, 50, 100]
    private static let bestValueAmount = 100

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
                        Text("プランを選んでください")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    if store.isLoadingProducts && store.products.isEmpty {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else if store.products.isEmpty {
                        Text("現在購入できる商品がありません")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Self.likeAmounts, id: \.self) { amount in
                                if let product = store.likeProduct(forAmount: amount) {
                                    planRow(amount: amount, product: product)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
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
            } message: {
                Text(store.errorMessage ?? "もう一度お試しください。")
            }
            .sentConfirmationCover(isPresented: $showingSuccessToast, message: "購入が完了しました", icon: "hand.thumbsup.fill")
            .task {
                await store.loadProducts()
            }
        }
    }

    private func planRow(amount: Int, product: Product) -> some View {
        let isBestValue = amount == Self.bestValueAmount
        let unitPrice = product.price / Decimal(amount)
        let baseUnitPrice = (store.likeProduct(forAmount: Self.likeAmounts[0])?.price ?? product.price) / Decimal(Self.likeAmounts[0])
        let discountPercent = baseUnitPrice > 0 ? Int((((baseUnitPrice - unitPrice) / baseUnitPrice) * 100).doubleValue.rounded()) : 0

        return Button {
            Task { await purchase(amount: amount) }
        } label: {
            HStack {
                ZStack {
                    Circle()
                        .fill(isBestValue ? Color.brandOrange.opacity(0.15) : Color.brandPurple.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: isBestValue ? "star.fill" : "hand.thumbsup.fill")
                        .foregroundStyle(isBestValue ? Color.brandOrange : Color.brandPurple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(amount)いいね")
                            .font(.headline)
                        if discountPercent > 0 {
                            Text("\(discountPercent)%OFF")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.brandOrange, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(product.displayPrice)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.purchasingProductID == product.id {
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
                    .stroke(isBestValue ? Color.brandOrange.opacity(0.5) : Color.clear, lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(store.purchasingProductID != nil)
    }

    private func purchase(amount: Int) async {
        let success = await store.purchaseLikes(amount: amount)
        if success {
            await profileManager.load()
            showingSuccessToast = true
            try? await Task.sleep(nanoseconds: 900_000_000)
            showingSuccessToast = false
            dismiss()
        } else if store.errorMessage != nil {
            showingFailedAlert = true
        }
    }
}

private extension Decimal {
    var doubleValue: Double { (self as NSDecimalNumber).doubleValue }
}

#Preview {
    LikesPurchaseSheet(profileManager: .preview)
}

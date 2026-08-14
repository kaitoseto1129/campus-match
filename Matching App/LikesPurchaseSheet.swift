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
                    balanceHeader

                    VStack(alignment: .leading, spacing: 4) {
                        Text("いいねを購入")
                            .font(.title3.bold())
                        Text("プランを選んでください")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    if store.isLoadingProducts && store.products.isEmpty {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else if store.products.isEmpty {
                        Text("現在購入できる商品がありません")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(Self.likeAmounts, id: \.self) { amount in
                                if let product = store.likeProduct(forAmount: amount) {
                                    planCard(amount: amount, product: product)
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
                Text(LocalizedStringKey(store.errorMessage ?? "もう一度お試しください。"))
            }
            .sentConfirmationCover(isPresented: $showingSuccessToast, message: "購入が完了しました", icon: "hand.thumbsup.fill")
            .task {
                await store.loadProducts()
            }
        }
    }

    private var balanceHeader: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup.fill")
                        .foregroundStyle(Color.brandPurple)
                    Text("いいね!残数")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                Text("\(profileManager.profile?.remainingLikes ?? 0)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.brandPurple)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .padding(.horizontal)
    }

    private func planCard(amount: Int, product: Product) -> some View {
        let isBestValue = amount == Self.bestValueAmount
        let unitPrice = product.price / Decimal(amount)
        let baseUnitPrice = (store.likeProduct(forAmount: Self.likeAmounts[0])?.price ?? product.price) / Decimal(Self.likeAmounts[0])
        let savedYen = max(0, (baseUnitPrice - unitPrice) * Decimal(amount))
        let discountPercent = baseUnitPrice > 0 ? Int((((baseUnitPrice - unitPrice) / baseUnitPrice) * 100).doubleValue.rounded()) : 0

        return VStack(spacing: 0) {
            if isBestValue {
                Text("人気No.1!")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.brandOrange, in: Capsule())
                    .offset(y: 12)
                    .zIndex(1)
            }

            Button {
                Task { await purchase(amount: amount) }
            } label: {
                HStack(spacing: 0) {
                    ZStack {
                        LinearGradient(
                            colors: isBestValue
                                ? [Color.brandOrange, Color.brandPink]
                                : [Color.brandPurple, Color.brandPurple.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        VStack(spacing: 0) {
                            Text("\(amount)")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                            Text("いいね")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.white)
                    }
                    .frame(width: 120)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(product.displayPrice)
                            .font(.title3.bold())
                        if discountPercent > 0 {
                            Text(savedYen > 0
                                 ? "\(NSDecimalNumber(decimal: savedYen).intValue.formatted())円お得! (\(discountPercent)%OFF)"
                                 : "\(discountPercent)%OFF")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.brandOrange, in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)

                    if store.purchasingProductID == product.id {
                        ProgressView()
                            .padding(.trailing)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .padding(.trailing)
                    }
                }
                .frame(height: 84)
                .background(Color(.systemBackground))
            }
            .buttonStyle(.plain)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(isBestValue ? Color.brandOrange : Color.clear, lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
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

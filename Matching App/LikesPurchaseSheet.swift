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

                    promoBanner

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
                        VStack(spacing: 10) {
                            Image(systemName: "cart.badge.questionmark")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("現在購入できる商品がありません")
                                .font(.subheadline.bold())
                            Text("しばらくしてから、もう一度お試しください")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
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

                    usageExplainerSection
                }
                .padding(.bottom, 20)
            }
            .background(
                ZStack {
                    Color.appListBackground
                    LinearGradient(
                        colors: [Color.brandPurple.opacity(0.08), Color.brandOrange.opacity(0.05), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 280)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .ignoresSafeArea()
            )
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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: "hand.thumbsup.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("現在の残いいね!")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(profileManager.profile?.remainingLikes ?? 0)")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(colors: [Color.brandPurple, Color.brandTeal], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .shadow(color: Color.brandPurple.opacity(0.25), radius: 12, y: 6)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// いいねの使い道を強くイメージさせるための短い訴求バナー。
    private var promoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.brandOrange)
            Text("いいねが多いほど、素敵な出会いのチャンスが広がります")
                .font(.caption.bold())
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(Color.brandOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
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
                        // ストアフロントによって通貨が変わる(円とは限らない)ため、
                        // 「円」を決め打ちせず商品自体の通貨で整形する。
                        Text("1いいね \(unitPrice.formatted(product.priceFormatStyle))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if discountPercent > 0 {
                            Text(savedYen > 0
                                 ? "\(savedYen.formatted(product.priceFormatStyle))お得! (\(discountPercent)%OFF)"
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

    /// 「いいね」を購入して何に使えるのかが伝わるよう、用途を短くまとめて紹介する。
    private var usageExplainerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("いいねは何に使うの?")
                .font(.subheadline.bold())
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                usageRow(icon: "hand.thumbsup.fill", iconColor: Color.brandPurple, title: "気になるお相手にいいねを送る", detail: "1いいねで1人に送れます。マッチすればトークができます")
                usageRow(icon: "bolt.fill", iconColor: Color.brandOrange, title: "「アピール」で目立つ", detail: "10いいねで1時間、探す画面のトップに表示されます")
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func usageRow(icon: String, iconColor: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(iconColor.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
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

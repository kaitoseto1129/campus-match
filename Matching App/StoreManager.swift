//
//  StoreManager.swift
//  Matching App
//

import Foundation
import StoreKit
import Supabase
import Combine

/// App Store In-App Purchaseの商品ID。実際にApp Store Connect側で同じIDの商品を
/// 作成しないと本番では購入できない(Xcodeでのローカルテストは Products.storekit で可能)。
enum StoreProductID {
    static let likes10 = "project.Matching-App.likes10"
    static let likes50 = "project.Matching-App.likes50"
    static let likes100 = "project.Matching-App.likes100"
    static let membershipMonthly = "project.Matching-App.membership.monthly"

    static var likeProductIDs: [String] { [likes10, likes50, likes100] }
    static var allProductIDs: [String] { likeProductIDs + [membershipMonthly] }

    static func likeProductID(forAmount amount: Int) -> String? {
        switch amount {
        case 10: return likes10
        case 50: return likes50
        case 100: return likes100
        default: return nil
        }
    }
}

enum StoreError: Error {
    case failedVerification
    case productNotFound
}

/// App Store経由の課金(いいね購入・有料会員)を扱う。
/// これまでの「モック課金」(サーバー側RPCを直接叩くだけで実際の決済がない)を置き換え、
/// 実際にAppleのStoreKitで購入フローを完了させたうえで、検証が取れてからサーバー側の
/// 特典付与RPC(purchase_likes_mock/purchase_membership)を呼ぶ。
/// RPC自体はいいね数・会員ステータスを更新するだけの単純な処理なので、
/// 「本物の決済の後に呼ぶ」ようにするだけで安全に流用できる。
@MainActor
final class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoadingProducts = false
    @Published var purchasingProductID: String?
    @Published var errorMessage: String?

    private var transactionListenerTask: Task<Void, Never>?

    init() {
        transactionListenerTask = listenForTransactionUpdates()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: StoreProductID.allProductIDs)
        } catch {
            errorMessage = "商品情報を読み込めませんでした"
            print("store load products error: \(error)")
        }
    }

    func likeProduct(forAmount amount: Int) -> Product? {
        guard let id = StoreProductID.likeProductID(forAmount: amount) else { return nil }
        return products.first { $0.id == id }
    }

    var membershipProduct: Product? {
        products.first { $0.id == StoreProductID.membershipMonthly }
    }

    /// いいねを購入する。成功したら残いいねはRPC内で加算され、trueを返す。
    @discardableResult
    func purchaseLikes(amount: Int) async -> Bool {
        guard let product = likeProduct(forAmount: amount) else {
            errorMessage = "商品が見つかりませんでした"
            return false
        }
        return await purchase(product) {
            try await supabase().rpc("purchase_likes_mock", params: ["p_amount": amount]).execute()
        }
    }

    /// 有料会員を購入(契約)する。
    @discardableResult
    func purchaseMembership() async -> Bool {
        guard let product = membershipProduct else {
            errorMessage = "商品が見つかりませんでした"
            return false
        }
        return await purchase(product) {
            try await supabase().rpc("purchase_membership", params: ["p_tier": "vip"]).execute()
        }
    }

    /// 機種変更・再インストール後に、既に購入済みの有料会員を復元する
    /// (Appleが自動更新サブスクリプションに対して必須としている導線)。
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await syncMembershipEntitlement()
        } catch {
            errorMessage = "復元に失敗しました"
            print("restore purchases error: \(error)")
        }
    }

    /// 現在有効な購入(サブスクリプション)の状態と、サーバー側の会員ステータスを突き合わせる。
    /// サブスクリプションが失効しているのにサーバー側が有料会員のままだった場合は無料会員に戻す。
    /// (このアプリには専用バックエンドがなく、App Store Server通知を受け取る仕組みがないため、
    /// アプリ起動時にこの簡易的な同期を行う)
    func syncMembershipEntitlement() async {
        var hasActiveMembership = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == StoreProductID.membershipMonthly {
                hasActiveMembership = true
            }
        }
        if !hasActiveMembership {
            let currentTier = await MembershipLookup.myTier()
            if currentTier != .free {
                do {
                    try await supabase().rpc("purchase_membership", params: ["p_tier": "free"]).execute()
                } catch {
                    print("membership sync error: \(error)")
                }
            }
        }
    }

    private func purchase(_ product: Product, grantBenefit: @escaping () async throws -> Void) async -> Bool {
        purchasingProductID = product.id
        defer { purchasingProductID = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                try await grantBenefit()
                await transaction.finish()
                return true
            case .userCancelled:
                return false
            case .pending:
                errorMessage = "承認待ちです(ファミリー共有の承認などが完了すると反映されます)"
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "購入に失敗しました"
            print("purchase error: \(error)")
            return false
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    /// サブスクリプションの自動更新など、アプリ外で発生した取引を検知して完了させる。
    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
            }
        }
    }
}

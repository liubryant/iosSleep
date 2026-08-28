import Foundation
import StoreKit

@MainActor
final class SleepStoreKitService {
    static let shared = SleepStoreKitService()

    static let productIDs = [
        "cn.sleep.vip.week",   // Apple ID: 6806154887
        "cn.sleep.vip.month",  // Apple ID: 6805426537
        "cn.sleep.vip.year"    // Apple ID: 6805424822
    ]

    enum StoreError: LocalizedError {
        case productNotFound
        case notEntitled
        case failedVerification
        case pending
        case unknown

        var errorDescription: String? {
            switch self {
            case .productNotFound: return "未找到对应的 App Store 订阅商品，请确认商品已可供销售"
            case .notEntitled: return "支付未完成"
            case .failedVerification: return "Apple 交易凭证校验失败，请重试"
            case .pending: return "支付正在等待确认，确认完成后会员将自动开通"
            case .unknown: return "支付失败，请稍后重试"
            }
        }
    }

    struct SignedTransaction {
        let transactionID: String
        let originalID: String
        let productID: String
        let jws: String
    }

    private var productsCache: [String: Product] = [:]
    private var updatesListener: Task<Void, Never>?

    private init() {}

    @discardableResult
    func loadProducts() async -> [Product] {
        do {
            let products = try await Product.products(for: Self.productIDs)
            products.forEach { productsCache[$0.id] = $0 }
            return Self.productIDs.compactMap { productsCache[$0] }
        } catch {
            print("[SleepIAP] loadProducts failed: \(error)")
            return []
        }
    }

    func purchase(productID: String) async throws -> SignedTransaction {
        await finishExpiredUnfinishedTransactions()
        let product: Product
        if let cached = productsCache[productID] {
            product = cached
        } else if let fetched = try? await Product.products(for: [productID]).first {
            productsCache[productID] = fetched
            product = fetched
        } else {
            throw StoreError.productNotFound
        }

        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            guard isCurrentlyActive(transaction) else {
                await transaction.finish()
                throw StoreError.notEntitled
            }
            return signed(transaction: transaction, jws: verification.jwsRepresentation)
        case .userCancelled:
            throw CancellationError()
        case .pending:
            throw StoreError.pending
        @unknown default:
            throw StoreError.unknown
        }
    }

    func restore() async throws -> [SignedTransaction] {
        await finishExpiredUnfinishedTransactions()
        try await AppStore.sync()
        return await currentEntitlements()
    }

    func currentEntitlements() async -> [SignedTransaction] {
        var transactions: [SignedTransaction] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID) else { continue }
            guard isCurrentlyActive(transaction) else {
                await transaction.finish()
                continue
            }
            transactions.append(signed(transaction: transaction, jws: result.jwsRepresentation))
        }
        return transactions
    }

    func finish(transactionID: String) async {
        for await result in Transaction.all {
            if case .verified(let transaction) = result,
               String(transaction.id) == transactionID,
               Self.productIDs.contains(transaction.productID) {
                await transaction.finish()
                return
            }
        }
    }

    func startObservingUpdates(onSigned: @escaping @MainActor (SignedTransaction) async -> Void) {
        updatesListener?.cancel()
        updatesListener = Task { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                if Task.isCancelled { return }
                guard case .verified(let transaction) = result,
                      Self.productIDs.contains(transaction.productID) else { continue }
                guard isCurrentlyActive(transaction) else {
                    await transaction.finish()
                    continue
                }
                await onSigned(signed(transaction: transaction, jws: result.jwsRepresentation))
            }
        }
    }

    private func signed(transaction: Transaction, jws: String) -> SignedTransaction {
        SignedTransaction(
            transactionID: String(transaction.id),
            originalID: String(transaction.originalID),
            productID: transaction.productID,
            jws: jws
        )
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
        }
    }

    private func isCurrentlyActive(_ transaction: Transaction) -> Bool {
        guard transaction.revocationDate == nil, !transaction.isUpgraded else { return false }
        return transaction.expirationDate.map { $0 > Date() } ?? true
    }

    private func finishExpiredUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID) else { continue }
            if !isCurrentlyActive(transaction) {
                await transaction.finish()
            }
        }
    }
}

@MainActor
enum SleepIAPBootstrap {
    private static var hasStarted = false

    static func startObservingTransactions() {
        guard !hasStarted else { return }
        hasStarted = true
        SleepStoreKitService.shared.startObservingUpdates { signed in
            await submit(signed)
        }
        Task {
            let transactions = await SleepStoreKitService.shared.currentEntitlements()
            for signed in transactions { await submit(signed) }
            SleepMembershipSession.shared.refreshSilently()
        }
    }

    private static func submit(_ signed: SleepStoreKitService.SignedTransaction) async {
        do {
            let session = SleepMembershipSession.shared
            let verified = try await SleepMembershipService.shared.verifyApplePurchase(
                token: session.userAccessToken,
                appleProductID: signed.productID,
                transactionID: signed.transactionID,
                jws: signed.jws
            )
            session.apply(verified)
            await SleepStoreKitService.shared.finish(transactionID: signed.transactionID)
        } catch {
            // 服务端未确认时不 finish，下次启动、交易更新或恢复购买会继续补交。
            print("[SleepIAP] server verification failed: \(error)")
        }
    }
}

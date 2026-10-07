//
//  StoreKitPurchases.swift
//  Maqr
//
//  The App Store behind MaqrDashboard's `StorePurchasing`: StoreKit 2, and the
//  listener that redeems transactions the app did not see finish — a purchase
//  interrupted by a crash, Ask to Buy approved later, a renewal bought on
//  another device. Every transaction is finished only after the server has
//  granted it (handlers/appstore.ts), so nothing paid for can be lost.
//

import MaqrDashboard
import StoreKit

final class StoreKitPurchases: StorePurchasing, @unchecked Sendable {
    private let client: MaqrClient
    private let isSignedIn: @Sendable () async -> Bool
    private var products: [String: Product] = [:]
    private var listener: Task<Void, Never>?

    init(client: MaqrClient, isSignedIn: @escaping @Sendable () async -> Bool) {
        self.client = client
        self.isSignedIn = isSignedIn
    }

    deinit { listener?.cancel() }

    // MARK: StorePurchasing

    func displayPrices(for productIds: [String]) async -> [String: String] {
        guard let loaded = try? await Product.products(for: productIds) else { return [:] }
        for product in loaded { products[product.id] = product }
        return Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0.displayPrice) })
    }

    func purchase(productId: String, appAccountToken: UUID) async throws -> PurchaseOutcome {
        let product: Product
        if let known = products[productId] {
            product = known
        } else if let fetched = try await Product.products(for: [productId]).first {
            products[productId] = fetched
            product = fetched
        } else {
            throw PurchaseError(String(localized: "That plan isn't available in the App Store right now."))
        }

        switch try await product.purchase(options: [.appAccountToken(appAccountToken)]) {
        case let .success(result):
            let transaction = try Self.verified(result)
            return .purchased(signedTransaction: result.jwsRepresentation, finish: { await transaction.finish() })
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restorableTransactions() async throws -> [String] {
        try await AppStore.sync()
        var signed: [String] = []
        // `all` rather than `currentEntitlements`: non-renewing passes never
        // count as entitlements, and they are most of what is sold.
        for await result in Transaction.all {
            if case .verified = result { signed.append(result.jwsRepresentation) }
        }
        return signed
    }

    // MARK: Transactions that arrive on their own

    /// Starts redeeming transactions the purchase flow did not finish. Call
    /// once at launch; again after signing in is harmless.
    func startListening() {
        guard listener == nil else { return }
        listener = Task.detached(priority: .background) { [weak self] in
            await self?.redeemUnfinished()
            for await update in Transaction.updates {
                await self?.redeem(update)
            }
        }
    }

    /// The ones left over from before this launch — a purchase interrupted
    /// before the server answered.
    func redeemUnfinished() async {
        for await result in Transaction.unfinished { await redeem(result) }
    }

    private func redeem(_ result: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = result else { return }
        // Without an account there is nobody to grant it to; it stays
        // unfinished and is redeemed after the next sign-in.
        guard await isSignedIn() else { return }
        do {
            _ = try await client.redeemAppStore(signedTransaction: result.jwsRepresentation)
            await transaction.finish()
        } catch {
            // Left unfinished: StoreKit offers it again next launch.
        }
    }

    private static func verified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case let .verified(transaction): return transaction
        case .unverified: throw PurchaseError(String(localized: "The App Store couldn't confirm this purchase. You haven't been charged twice — please try again."))
        }
    }
}

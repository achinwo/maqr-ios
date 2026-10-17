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
//  Offer codes redeemed in Apple's sheet (`.offerCodeRedemption`) arrive here
//  too, without our appAccountToken. They are sent with the experience the
//  sheet was opened for, and the outcome is handed back to the dashboard for
//  that screen to follow — see Purchasing.swift.
//

import MaqrDashboard
import StoreKit

final class StoreKitPurchases: StorePurchasing, @unchecked Sendable {
    private let client: MaqrClient
    private let isSignedIn: @Sendable () async -> Bool
    private let offerCodeExperience: @Sendable () async -> String?
    private let offerCodeRedeemed: @Sendable (AppStoreRedemption) async -> Void
    private var products: [String: Product] = [:]
    private var listener: Task<Void, Never>?

    init(client: MaqrClient,
         isSignedIn: @escaping @Sendable () async -> Bool,
         offerCodeExperience: @escaping @Sendable () async -> String?,
         offerCodeRedeemed: @escaping @Sendable (AppStoreRedemption) async -> Void) {
        self.client = client
        self.isSignedIn = isSignedIn
        self.offerCodeExperience = offerCodeExperience
        self.offerCodeRedeemed = offerCodeRedeemed
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

    func signedTransaction(id: String) async -> String? {
        // A renewal of a subscription bought with a code has a new id; the
        // server matches it on the original one, so any of them will do.
        var renewal: String?
        for await result in Transaction.all {
            guard case let .verified(transaction) = result else { continue }
            if String(transaction.id) == id { return result.jwsRepresentation }
            if String(transaction.originalID) == id { renewal = result.jwsRepresentation }
        }
        return renewal
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
        // Every purchase the app starts carries our token; one without it is
        // an offer code redeemed in Apple's sheet, here or in the App Store.
        let offerCode = transaction.appAccountToken == nil
        let experience = offerCode ? await offerCodeExperience() : nil
        do {
            let redemption = try await client.redeemAppStore(signedTransaction: result.jwsRepresentation, experience: experience)
            // Finished even when the server kept it unassigned: the pass is
            // on the account, and Transaction.all still holds it to spend.
            await transaction.finish()
            if offerCode { await offerCodeRedeemed(redemption) }
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

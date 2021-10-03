//
//  StoreKitHelper.swift
//  Joli
//
//  Created by Anthony Chinwo on 02/10/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import Foundation
import StoreKit
import Combine

public struct ProductIdentifier: Hashable, Equatable, RawRepresentable {
    
    public var rawValue: String
    
    public init(_ rawValue: String){
        self.init(rawValue: rawValue)
    }
    
    public init(rawValue: String){
        self.rawValue = rawValue
    }
    
}

public extension Notification.Name {
    static let storeKitHelperPurchaseNotification = Notification.Name("storeKitHelperPurchaseNotification")
}

public extension Collection where Element == ProductIdentifier {
    
    var rawValues: [String] {
        return self.map() { $0.rawValue }
    }
    
}

public final class StoreKitHelper: NSObject, ObservableObject, SKProductsRequestDelegate {
    
    public typealias Response = (request: SKProductsRequest, response: SKProductsResponse)
    public let productResponse = PassthroughSubject<Response, Never>()
    
    public override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    
    @discardableResult
    public func request(_ productIdentifiers: Set<ProductIdentifier>) -> SKProductsRequest {
        let request = SKProductsRequest(productIdentifiers: productIdentifiers.rawValues.uniq)
        request.delegate = self
        request.start()
        return request
    }
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async(){
            self.productResponse.send((request, response))
        }
    }
    
    public func buyProduct(_ product: SKProduct) {
        print("Buying \(product.productIdentifier)...")
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    private var purchasedProductIdentifiers: Set<ProductIdentifier> = []
    
    public func isProductPurchased(_ productIdentifier: ProductIdentifier) -> Bool {
        return purchasedProductIdentifiers.contains(productIdentifier)
    }
    
    public class func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    public func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    public func retreiveReceipt() -> String? {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            return nil
        }
        
        do {
            let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
            print(receiptData)
            
            let receiptString = receiptData.base64EncodedString(options: [])
            print("[RECEIPT] \(receiptString)")
                // Read receiptData
            return receiptString
        } catch {
            print("Couldn't read receipt data with error: " + error.localizedDescription)
            return nil
        }
    }
    
}

extension StoreKitHelper: SKPaymentTransactionObserver {
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            print("[StoreKitHelper] transaction: \(transaction) - \(transaction.transactionState.rawValue) - \(transaction.payment.productIdentifier)")
            switch transaction.transactionState {
                case .purchased:
                    complete(transaction)
                case .failed:
                        //fail(transaction)
                    break
                case .restored:
                        //restore(transaction)
                    break
                case .deferred:
                    break
                case .purchasing:
                    break
                @unknown default:
                    break
            }
        }
    }
    
    private func complete(_ transaction: SKPaymentTransaction) {
        print("complete...")
        //persistPurchase(identifier: transaction.payment.productIdentifier)
        dispatchPurchaseNotificationFor(identifier: transaction.payment.productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, didRevokeEntitlementsForProductIdentifiers productIdentifiers: [String]) {
        for identifier in productIdentifiers {
                //purchasedProductIdentifiers.remove(identifier)
            UserDefaults.standard.removeObject(forKey: identifier)
            dispatchPurchaseNotificationFor(identifier: identifier)
        }
    }
    
    private func dispatchPurchaseNotificationFor(identifier: String?) {
        guard let identifier = identifier else { return }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .storeKitHelperPurchaseNotification, object: identifier)
        }
            //purchaseCompletionHandler?(true)
    }
    
}

extension SKProduct: Identifiable {
    
    public var id: String {
        return productIdentifier
    }
    
    public var isSubscription: Bool {
        return subscriptionGroupIdentifier != nil
    }
    
}

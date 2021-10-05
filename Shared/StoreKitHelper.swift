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

public struct Product: Hashable, Equatable, Identifiable {
    
    public struct Identifier: Hashable, Equatable, RawRepresentable, Identifiable {
        
        public var rawValue: String
        
        public init(_ rawValue: String){
            self.init(rawValue: rawValue)
        }
        
        public init(rawValue: String){
            self.rawValue = rawValue
        }
        
        public var id: String {
            return rawValue
        }
        
        public var productIds: Set<Identifier> = []
        
    }
    
    let product: SKProduct
    
    public var id: String {
        return product.id
    }
    
}


public extension Notification.Name {
    static let storeKitHelperPurchaseNotification = Notification.Name("storeKitHelperPurchaseNotification")
}

public extension Collection where Element == Product.Identifier {
    
    var rawValues: [String] {
        return self.map() { $0.rawValue }
    }
    
}

public final class StoreKitHelper: NSObject, ObservableObject, SKProductsRequestDelegate, SKRequestDelegate {
    
    public typealias Response = (request: SKProductsRequest, response: SKProductsResponse)
    public let productResponse = PassthroughSubject<Response, Never>()
    
    private var currentRequest: SKRequest? = nil {
        didSet {
            DispatchQueue.main.async {
                self.isLoadingProducts = self.currentRequest != nil
            }
        }
    }
    
    @Published public var products: [SKProduct] = []
    @Published public var isLoadingProducts: Bool = false
    
    public override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    
    @discardableResult
    public func request(_ productIdentifiers: Set<Product.Identifier>) -> SKProductsRequest {
        
        self.currentRequest?.cancel()
        self.currentRequest?.delegate = nil
        
        let request = SKProductsRequest(productIdentifiers: productIdentifiers.rawValues.uniq)
        request.delegate = self
        request.start()
        self.currentRequest = request
        
        return request
    }
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async(){
            self.products = response.products
            self.productResponse.send((request, response))
        }
    }
    
    public func requestDidFinish(_ request: SKRequest) {
        print("[\(Self.self)] request finished: \(request)]")
        self.currentRequest = nil
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        print("[\(Self.self)] request errored: \(request) - \(error)")
        self.currentRequest = nil
    }
    
    public func buyProduct(_ product: SKProduct) {
        print("Buying \(product.productIdentifier)...")
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    private var purchasedProductIdentifiers: Set<Product.Identifier> = []
    
    public func isProductPurchased(_ productIdentifier: Product.Identifier) -> Bool {
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

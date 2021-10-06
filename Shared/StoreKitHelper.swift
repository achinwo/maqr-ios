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
//
//open class SKProductSubscriptionPeriod : NSObject {
//
//
//    @available(iOS 11.2, *)
//    open var numberOfUnits: Int { get }
//
//
//    @available(iOS 11.2, *)
//    open var unit: SKProduct.PeriodUnit { get }
//}

extension SKProductSubscriptionPeriod {
    
    public static func period(_ periodUnit: SKProduct.PeriodUnit, numberOfUnits: Int = 1) -> SKProductSubscriptionPeriod {
        let periodObj = SKProductSubscriptionPeriod()
        periodObj.setValue(numberOfUnits, forKey: "numberOfUnits")
        periodObj.setValue(periodUnit.rawValue, forKey: "unit")
        
        return periodObj
    }
    
    public var timeInterval: TimeInterval? {
        switch self.unit {
            case .day:
                return 24.0 * Double(self.numberOfUnits) * 60 * 60
            case .week:
                return 24.0 * 60 * 60 * 7 * Double(self.numberOfUnits)
            default:
                return nil
        }
    }
    
    public var formatted: String? {
        
        guard let timeInterval = timeInterval else { return nil }
        
        let formatter = DateComponentsFormatter()
        
        formatter.allowedUnits = self.unit == .day && self.numberOfUnits == 1 ? [.hour] : [.hour, .day]
        formatter.unitsStyle = .brief
        
        return formatter.string(from: timeInterval)
    }
    
}

@dynamicMemberLookup
public struct Product: Hashable, Equatable, Identifiable {
    
    public enum IdComponent: Equatable, Hashable, Identifiable {
        
        case oneoff(`prefix`: String, name: String, period: SKProductSubscriptionPeriod)
        case subscription(`prefix`: String, name: String)
        case fixed(`prefix`: String, name: String)
        
        static let prefixes: (oneoff: String, subscription: String, fixed: String) = (
            oneoff: "oneoff",
            subscription: "subscription",
            fixed: "fixed"
        )
        
        public var id: String {
            switch self {
                case .fixed(let prefix, let name):
                    return "\(prefix).\(Self.prefixes.fixed).\(name)"
                case .oneoff(let prefix, let name, _):
                    return "\(prefix).\(Self.prefixes.oneoff).\(name)"
                case .subscription(let prefix, let name):
                    return "\(prefix).\(Self.prefixes.subscription).\(name)"
            }
        }
        
    }
    
    public struct Identifier: Hashable, Equatable, RawRepresentable, Identifiable {
        
        public var rawValue: IdComponent
        
        public init(_ rawValue: IdComponent){
            self.init(rawValue: rawValue)
        }
        
        public init(rawValue: IdComponent){
            self.rawValue = rawValue
        }
        
        public var id: String {
            return rawValue.id
        }
        
        public static var productIds: Set<Product.Identifier> = []
        
    }
    
    public let product: SKProduct
    
    public var id: String {
        return product.productIdentifier
    }
    
    public var subscriptionPeriod: SKProductSubscriptionPeriod? {
        guard product.subscriptionPeriod == nil else {
            return product.subscriptionPeriod
        }
        
        guard case let .oneoff(_, _, period) = self.identifier?.rawValue else { return nil }
        
        return period
    }
    
    public var identifier: Identifier? {
        return Identifier.productIds.first() { $0.rawValue.id == product.productIdentifier }
    }
    
    public var isOneoff: Bool {
        guard case .oneoff(_, _, _) = self.identifier?.rawValue else { return false }
        return true
    }
    
    public var isSubscription: Bool {
        guard case .subscription(_, _) = self.identifier?.rawValue else { return false }
        return true
    }
    
    public var isFixed: Bool {
        guard case .fixed(_, _) = self.identifier?.rawValue else { return false }
        return true
    }
    
    public subscript<T>(dynamicMember keyPath: KeyPath<SKProduct, T>) -> T {
        product[keyPath: keyPath]
    }
    
}

public extension Notification.Name {
    static let storeKitHelperPurchaseNotification = Notification.Name("storeKitHelperPurchaseNotification")
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
    
    @Published public var products: [Product] = []
    @Published public var isLoadingProducts: Bool = false
    
    public override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    
    @discardableResult
    public func request(_ productIdentifiers: Set<Product.Identifier>) -> SKProductsRequest {
        
        self.currentRequest?.cancel()
        self.currentRequest?.delegate = nil
        
        let request = SKProductsRequest(productIdentifiers: productIdentifiers.ids.uniq)
        request.delegate = self
        request.start()
        self.currentRequest = request
        
        return request
    }
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async(){
            self.products = response.products.map() { Product(product: $0) }
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
    
    public func buyProduct(_ product: Product) {
        print("Buying \(product.product.productIdentifier)...")
        let payment = SKPayment(product: product.product)
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

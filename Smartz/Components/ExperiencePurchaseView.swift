//
//  ExperiencePurchaseView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 05/10/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import class StoreKit.SKPaymentTransaction
import JoliCore
import AlertToast

struct GeometryGetter: View {
    
    @Binding var size: CGSize?
    
    var body: some View {
        GeometryReader { geometry in
            self.dispatchViewUpdate(geometry)
        }
    }
    
    private func dispatchViewUpdate(_ proxy: GeometryProxy) -> some View {
        DispatchQueue.main.async {
            self.size = proxy.size
            //print("New Size: \(proxy.size)")
        }
        return Color.clear
    }
    
}

extension View {
    
    func exportFrame(_ size: Binding<CGSize?>) -> some View {
        return self.background(GeometryGetter(size: size))
    }
    
}

struct GrowingButton: ButtonStyle {
    
    @Environment(\.isEnabled) var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(isEnabled ? Color.blue : Color.fixedLightGray)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ExperiencePurchaseView: JoliView {
    
    let onPurchased: (SKPaymentTransaction) -> Void
    @State var products: [Product] = []
    @State var invalidProductIds: [String]? = nil
    @State var isLoadingProducts: Bool = false
    
    @State var selectedProductId: String? = nil
    @State var selectedProduct: Product? = nil
    @State var frameSize: CGSize? = nil
    @State var scrollProxy: ScrollViewProxy? = nil
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    private let shouldShowTnC: Bool
    
    init(_ callback: @escaping (SKPaymentTransaction) -> Void){
        self.onPurchased = callback
        self.shouldShowTnC = !UserDefaults.standard.bool(forKey: AppStorageKey.isTcAccepted.rawValue)
    }
    
    func oneoffProductView(_ product: Product) -> some View {
        let isActive = product.productIdentifier == self.selectedProductId
        return VStack(){
            Text(product.subscriptionPeriod?.formatted ?? product.localizedTitle)
                .font(.largeTitle)
                .fixedSize()
                .padding()
            
            if isActive {
                Divider().padding(.horizontal)
            }
            
            Text(product.price  ?? "Unable to determine price")
                .foregroundColor(.secondary)
                .font(isActive ? .title2.weight(.semibold) : .title2)
                .padding()
        }
        .frame(minHeight: screenWidth * 0.3)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(product.productIdentifier == self.selectedProductId ? 0.6 : 0), lineWidth: 1)
        )
        .overlay(
            HStack(spacing: .zero){
                Spacer()
                
                VStack(alignment: .trailing, spacing: .zero){
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(isActive ? .green : Color.secondaryLabel)
                        //.padding(.horizontal)
                        .font(.title2.weight(.light))
                        .scaleEffect(x: isActive ? 1.5 : 1, y: isActive ? 1.5 : 1)
                        .animation(.easeInOut, value: isActive)
                        .disabled(!isActive)
                    
                    Spacer()
                }//.backgroundColor(.yellow)
            }
                .opacity(product.productIdentifier == self.selectedProductId ? 1 : 0)
        )
    }
    
    var oneoffProductsView: some View {
        let oneoffProducts = products.filter() { $0.isOneoff }
        return VStack(){
        
            GridChooserView(items: .constant(oneoffProducts), selection: $selectedProductId, layout: .grid(oneoffProducts.count), cornerRadius: nil) { (product: Product) in
                
                withImpact(.light, animated: Animation.easeInOut) {
                    print("selected: \(product) - \(String(describing: self.selectedProductId))")
                }
            } content: { product in
                self.oneoffProductView(product)
            }
            //.backgroundColor(.green)
            
            if invalidProductIds != nil, oneoffProducts.isEmpty {
                Text("Seems there's been an issue loading product information...")
                    .frame(maxWidth: screenWidth - 100, minHeight: screenWidth / 4)
                    .padding(.horizontal)
                    .lineLimit(5)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .foregroundColor(.secondary)
            }
        }
        .frame(minHeight: screenWidth * 0.4)
    }
    
    var subscriptionProductsView: some View {
        let subscriptionProducts = products.filter() { $0.isSubscription }
        let width = screenWidth - 150
        return ScrollView(.horizontal, showsIndicators: false){
            VStack(){
                GridChooserView(items: .constant(subscriptionProducts), selection: $selectedProductId, layout: .grid(subscriptionProducts.count), cornerRadius: nil) { (product: Product) in
                    
                    withImpact(.rigid) {
                            //scrollProxy?.scrollTo(product.productIdentifier, anchor: .leading)
                        print("selected: \(product) - \(String(describing: self.selectedProductId)) - \(String(describing: scrollProxy))")
                    }
                } content: { product in
                    let isActive = product.productIdentifier == self.selectedProductId
                    
                    VStack(){
                        Spacer()
                        Text(product.localizedTitle).font(.headline)
                        Text(product.localizedDescription).font(.subheadline).foregroundColor(.secondary)
                        Text(product.price  ?? "Unable to determine price")
                            .foregroundColor(.secondary)
                            .font(isActive ? .title2.weight(.semibold) : .title2)
                            .padding()
                        Spacer()
                    }
                    .frame(minHeight: screenWidth * 0.5)
                    .frame(width: width)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke((isActive ? Color.green : Color.fixedGray).opacity(isActive ? 0.6 : 0.2), lineWidth: 1)
                    )
                    .overlay(
                        HStack(spacing: .zero){
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: .zero){
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(isActive ? .green : Color.secondaryLabel)
                                    //.padding(.horizontal)
                                    .font(.title2.weight(.light))
                                    .scaleEffect(x: isActive ? 1.5 : 1, y: isActive ? 1.5 : 1)
                                    .animation(.easeInOut, value: isActive)
                                    .disabled(!isActive)
                                
                                Spacer()
                            }//.backgroundColor(.yellow)
                        }
                            .opacity(isActive ? 1 : 0)
                    )
                    .padding()
                    .padding(.horizontal)
                    .id(product.id)
                }
                
                if invalidProductIds != nil, subscriptionProducts.isEmpty {
                    Label(){
                        Text("Seems there's been an issue loading product information...")
                            .frame(maxWidth: screenWidth - 100, minHeight: screenWidth / 4)
                            .lineLimit(5)
                            .multilineTextAlignment(.center)
                            .fixedSize()
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "circle.slash")
                    }
                    .padding(.horizontal)
                }
            }
            .frame(minWidth: width * CGFloat(subscriptionProducts.count) * 1.1)
            .padding(.horizontal)
        }
        
    }
    
    @AppStorage(key: .isTcAccepted) var isAgreed: Bool = false
    @AppStorage(key: .purchasesIdsForTesting) var purchasesIdsForTesting: String = .empty
    @State var toastInfo: (alert: AlertToast, onDismiss: (Bool) -> Void)? = nil
    
    var aggrementView: some View {
        return HStack(){
            VStack(alignment: .leading){
                Text("I've read and accept the").font(.subheadline.weight(.light)).padding(.trailing)
                Link("Terms and Conditions", destination: URL(staticString: "https://smartstikr.com/uk/legal/terms_and_conditions/"))
            }
            Spacer()
            Toggle(isOn: self.$isAgreed){
                Text("agreed")
            }
            .labelsHidden()
        }
    }
    
    var contentView: some View {
        
        let isPresentingToast = Binding<Bool>(){
            return toastInfo != nil
        } set: { newValue in
            print("\(tag) setting presenting to: \(newValue)")
            guard toastInfo != nil, !newValue else {
                return
            }
            
            self.toastInfo = nil
        }
        
        return ScrollView(){
            ScrollViewReader(){ scrollProxy in
                VStack(){
                    if isLoadingProducts {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding()
                    } else {
                        Text("Publish an Experince Anytime")
                            .font(.title.weight(.semibold))
                            .padding([.horizontal, .top])
                        (Text("Get an always-on publishing plan - perfect for ") + Text("hobbyists").fontWeight(.semibold) + Text(" and ") + Text("small businesses").fontWeight(.semibold))
                            .padding()
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        self.subscriptionProductsView
                        Divider().padding()
                            .animation(.easeInOut, value: isLoadingProducts)
                        Text("Don't need a subscription?").font(.title2.weight(.semibold)).padding(.horizontal)
                        (Text("We've got you covered, use a one-off fixed duration plan - perfect for trailing, or ") + Text("planning events").fontWeight(.semibold))                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        self.oneoffProductsView
                            .padding()
                            .animation(.easeInOut, value: isLoadingProducts)
                            .padding(.bottom)
                        
                        if shouldShowTnC {
                            Divider().padding(.horizontal)
                            
                            self.aggrementView
                                .padding()
                                .padding(.horizontal)
                        }
                        
                        Button(){
                            guard let product = selectedProduct else { return }
                            
//                            if let invalidProductIds = invalidProductIds, invalidProductIds.contains(product.productIdentifier) {
//                                self.presentToast("Pay Unsuccessful", subTitle: "App Store did not respond on time, try again later", type: .error(.red), displayMode: .alert, tapToDismiss: true){ _ in
//                                    print("Pay aborted!")
//                                }
//                                return
//                            }
                            
                            appCoordinator.storeKitHelper.buyProduct(product) { (transaction: SKPaymentTransaction, error: Error?) in
                                
                                var currentPurchases = Set(purchasesIdsForTesting.components(separatedBy: ","))
                                currentPurchases.insert(product.productIdentifier)
                                
                                self.purchasesIdsForTesting = currentPurchases.joined(separator: ",")
                                
                                let msg = "[\(Self.self)] attempting to buy: \(product.localizedDescription), pruchases: \(purchasesIdsForTesting)"
                                appCoordinator.serverLogDestination.send(.info, msg: msg, thread: Thread.current.description,
                                                                       file: #file, function: #function, line: #line)
                                
                                if let error = error {
                                    let subtitle = "App Store transaction will retry in background"
                                        //((error as NSError).userInfo["NSUnderlyingError"] as? Error)?.localizedDescription ?? error.localizedDescription
                                    self.presentToast("Processing...", subTitle: subtitle, type: .systemImage("exclamationmark.arrow.circlepath", .yellow.opacity(0.7)), displayMode: .alert, tapToDismiss: true){ _ in
                                        print("Pay error: \(error)")
                                        onPurchased(transaction)
                                    }
                                } else {
                                    onPurchased(transaction)
                                }
                                
                            }
                        } label: {
                            Group(){
                                let cartIconName = self.selectedProduct == nil || !self.isAgreed ? "cart" : "cart.fill"
                                let iconName = self.invalidProductIds != nil && products.isEmpty ? "circle.slash" : cartIconName
                                
                                if let product = self.selectedProduct, product.isSubscription, self.isAgreed {
                                    let txt = "Subscribe" //to \(product.localizedTitle)"
                                    Label(txt, systemImage: iconName)
                                } else if let product = self.selectedProduct, self.isAgreed {
                                    Label("Buy \(product.localizedTitle) - \(product.price ?? "No Price")", systemImage: iconName)
                                } else{
                                    let txt = self.invalidProductIds != nil && products.isEmpty ? "Unable to load products" : "Select a product"
                                    let prodSelectTxt = self.isAgreed ? txt : "Review and accept terms"
                                    Label(prodSelectTxt, systemImage: iconName)
                                }
                            }
                            .frame(width: frameSize == nil ? nil : abs(frameSize!.width - 100))
                            .id("button-buy")
                            
                        }
                        .buttonStyle(GrowingButton())
                        .padding()
                        .disabled(self.selectedProduct == nil || !self.isAgreed)
                    }
                }
                .exportFrame($frameSize)
                .onAppear(){
                    self.scrollProxy = scrollProxy
                }
                .frame(maxWidth: screenWidth, maxHeight: screenHeight * 1.4)
            }
        }
        .overlay(
            GeometryReader(){ proxy in
                HStack(alignment: .top) {
                    Spacer()
                        .padding(.top, 200)
                        .ifLet(self.toastInfo) { view, alertToast in
                            return view.toast(isPresenting: isPresentingToast) {
                                alertToast.alert
                            } completion: {
                                print("[\(Self.self)] toast completion")
                                alertToast.onDismiss(true)
                            }
                        }
                }
                .frame(width: proxy.size.width, height: proxy.size.height / 2)
                .padding(.top, proxy.safeAreaInsets.top)
            }
        )
        .onReceive(appCoordinator.storeKitHelper.$products, assign: \.products, target: self)
        .onReceive(appCoordinator.storeKitHelper.$invalidProductIds, assign: \.invalidProductIds, target: self)
        .onReceive(appCoordinator.storeKitHelper.$isLoadingProducts) { isLoadingProducts in
            guard let invalidProductIds = self.invalidProductIds, !isLoadingProducts, !invalidProductIds.isEmpty, products.isEmpty else { return }
            
            print("Falling back to database products...")
            
            DispatchQueue.main.async() {
                Task() {
                    guard let summaries = try? await ProductSummary.all(baseUrl: api.baseUrlHttp, urlSession: api.urlSession) else { return }
                    
                    self.products = summaries.sorted(by: { $0.id < $1.id }).compactMap(){ Product.fromProductSummary($0) }
                }
            }
            
        }
        .onReceive(appCoordinator.storeKitHelper.$isLoadingProducts, assign: \.isLoadingProducts, target: self)
//        .onReceive(appCoordinator.storeKitHelper.$products) { products in
//            print("Got products: \(products)")
//            for product in products {
//                product.toProductInfo().save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
//                    .then(){ prod in
//                        print("saved: \(prod)")
//                    }
//                    .catch(){ error in
//                        print("error: \(error)")
//                    }
//            }
//        }
        .onReceive(appCoordinator.globalToastInfo) { info in
            self.toastInfo = info
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0){
                self.toastInfo = nil
            }
        }
        .onChange(of: self.selectedProductId){ productId in
            let product = products.first() { $0.productIdentifier == productId }
            self.selectedProduct = product
            
            guard let product = product else { return }
            print("SELECTED PRODUCT: \(product.id) -- \(product.subscriptionPeriod?.numberOfUnits)/\(product.subscriptionPeriod?.unit)")
            
            withAnimation(){
                scrollProxy?.scrollTo("button-buy", anchor: .bottom)
            }
        }
        .onAppear(){
            print("[\(Self.self)] purchases: \(purchasesIdsForTesting)")
            appCoordinator.storeKitHelper.request(Product.Identifier.productIds)
        }
    }
}

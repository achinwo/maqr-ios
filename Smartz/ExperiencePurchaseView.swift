//
//  ExperiencePurchaseView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 05/10/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
//import StoreKit

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
    
    let onPurchased: () -> Void
    @State var products: [Product] = []
    @State var invalidProductIds: [String]? = nil
    @State var isLoadingProducts: Bool = false
    
    @State var selectedProductId: String? = nil
    @State var selectedProduct: Product? = nil
    @State var frameSize: CGSize? = nil
    @State var scrollProxy: ScrollViewProxy? = nil
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
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
                        .animation(.easeInOut)
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
                    print("selected: \(product) - \(self.selectedProductId)")
                }
            } content: { product in
                self.oneoffProductView(product)
            }
            //.backgroundColor(.green)
            
            if let invalidIds = invalidProductIds, oneoffProducts.isEmpty {
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
                    print("selected: \(product) - \(self.selectedProductId) - \(scrollProxy)")
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
                                .animation(.easeInOut)
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
                if let invalidIds = invalidProductIds, subscriptionProducts.isEmpty {
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
//            .ifLet(self.invalidProductIds){ view, ids in
//                Group(){
//                    if subscriptionProducts.isEmpty {
//                        view.overlay(Text("Seems there's been an issue loading product information"))
//                    }
//                }
//            }
        }
        
    }
    
    var contentView: some View {
        ScrollViewReader(){ scrollProxy in
            ScrollView(){
            
            
                VStack(){
                    if isLoadingProducts {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding()
                    } else {
                        Text("Publish an Experince Anytime")
                            .font(.title.weight(.semibold))
                            .padding([.horizontal, .top])
                        (Text("Get an always-on publishing plan - perfect for ") + Text("hobbyists").fontWeight(.semibold) + Text(" and ") + Text("small business").fontWeight(.semibold)).padding()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        self.subscriptionProductsView
                        Divider().padding()
                            .animation(.easeInOut)
                        Text("Don't need a subscription?").font(.title2.weight(.semibold)).padding(.horizontal)
                        (Text("We've got you covered, use a one-off fixed duration plan - perfect for trailing, or ") + Text("planning events").fontWeight(.semibold) + Text("."))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        self.oneoffProductsView
                            .padding()
                            .animation(.easeInOut)
                            .padding(.bottom)
                        
                        Button(){
                            guard let product = selectedProduct else { return }
                            
                            appCoordinator.storeKitHelper.buyProduct(product)
                        } label: {
                            Group(){
                                let cartIconName = self.selectedProduct == nil ? "cart" : "cart.fill"
                                let iconName = self.invalidProductIds != nil && products.isEmpty ? "circle.slash" : cartIconName
                                
                                if let product = self.selectedProduct, product.isSubscription {
                                    let txt = "Subscribe" //to \(product.localizedTitle)"
                                    Label(txt, systemImage: iconName)
                                } else if let product = self.selectedProduct {
                                    Label("Buy \(product.localizedTitle) - \(product.price ?? "No Price")", systemImage: iconName)
                                } else{
                                    let txt = self.invalidProductIds != nil && products.isEmpty ? "Unable to load products" : "Select a product"
                                    Label(txt, systemImage: iconName)
                                }
                            }
                            .ifLet(frameSize){ view, value in
                                view.frame(width: abs(value.width - 100))
                            }
                            .id("button-buy")
                            
                        }
                        .buttonStyle(GrowingButton())
                        .padding()
                        .disabled(self.selectedProduct == nil)
                    }
                }
                .exportFrame($frameSize)
                .onAppear(){
                    self.scrollProxy = scrollProxy
                }
            }
        }
        .onReceive(appCoordinator.storeKitHelper.$products, assign: \.products, target: self)
        .onReceive(appCoordinator.storeKitHelper.$invalidProductIds, assign: \.invalidProductIds, target: self)
        .onReceive(appCoordinator.storeKitHelper.$isLoadingProducts, assign: \.isLoadingProducts, target: self)
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
            for x in Product.Identifier.productIds {
                print("ID: \(x.rawValue.id)")
            }
            
            appCoordinator.storeKitHelper.request(Product.Identifier.productIds)
        }
    }
}

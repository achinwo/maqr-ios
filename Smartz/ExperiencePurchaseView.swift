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
    @State var isLoadingProducts: Bool = false
    
    @State var selectedProductId: String? = nil
    @State var selectedProduct: Product? = nil
    @State var frameSize: CGSize? = nil
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var oneoffProductsView: some View {
        let oneoffProducts = products.filter() { $0.isOneoff }
        return VStack(){
        
            GridChooserView(items: .constant(oneoffProducts), selection: $selectedProductId, layout: .grid(oneoffProducts.count), cornerRadius: nil) { (product: Product) in
                print("selected: \(product) - \(self.selectedProductId)")
            } content: { product in
                let isActive = product.productIdentifier == self.selectedProductId
                
                VStack(){
                    Text(product.subscriptionPeriod?.formatted ?? product.localizedTitle)
                        .font(.largeTitle)
                        .fixedSize()
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
            //.backgroundColor(.green)
        }
        .frame(minHeight: screenWidth * 0.4)
    }
    
    var subscriptionProductsView: some View {
        let subscriptionProducts = products.filter() { $0.isSubscription }
        let width = screenWidth - 150
        return ScrollView(.horizontal, showsIndicators: false){
            GridChooserView(items: .constant(subscriptionProducts), selection: $selectedProductId, layout: .grid(subscriptionProducts.count), cornerRadius: nil) { (product: Product) in
                print("selected: \(product) - \(self.selectedProductId)")
            } content: { product in
                let isActive = product.productIdentifier == self.selectedProductId
                
                VStack(){
                    Text(product.localizedTitle).font(.headline)
                    Text(product.localizedDescription).font(.subheadline)
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
            .frame(minWidth: width * CGFloat(subscriptionProducts.count) * 1.1)
            .padding(.horizontal)
        }
    }
    
    var contentView: some View {
        ScrollView(){
            VStack(){
                if isLoadingProducts {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding()
                } else {
                    self.oneoffProductsView.padding()
                        .animation(.easeInOut)
                    Divider().padding()
                    self.subscriptionProductsView
                        .animation(.easeInOut)
                    
                    Button(){
                            //appCoordinator.storeKitHelper.buyProduct(product)
                    } label: {
                        Label("Buy", systemImage: self.selectedProduct == nil ? "cart" : "cart.fill")
                            .ifLet(frameSize){ view, value in
                                view.frame(width: abs(value.width - 100))
                            }
                    }
                    .buttonStyle(GrowingButton())
                    .padding(.top)
                    .disabled(self.selectedProduct == nil)
                }
            }
            .exportFrame($frameSize)
        }
        .onReceive(appCoordinator.storeKitHelper.$products, assign: \.products, target: self)
        .onReceive(appCoordinator.storeKitHelper.$isLoadingProducts, assign: \.isLoadingProducts, target: self)
        .onChange(of: self.selectedProductId){ productId in
            let product = products.first() { $0.productIdentifier == productId }
            self.selectedProduct = product
            
            guard let product = product else { return }
            print("SELECTED PRODUCT: \(product.id) -- \(product.subscriptionPeriod?.numberOfUnits)/\(product.subscriptionPeriod?.unit)")
        }
        .onAppear(){
            for x in Product.Identifier.productIds {
                print("ID: \(x.rawValue.id)")
            }
            
            appCoordinator.storeKitHelper.request(Product.Identifier.productIds)
        }
    }
}

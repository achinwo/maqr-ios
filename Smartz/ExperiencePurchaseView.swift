//
//  ExperiencePurchaseView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 05/10/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import StoreKit

struct GrowingButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ExperiencePurchaseView: JoliView {
    
    let onPurchased: () -> Void
    @State var products: [SKProduct] = []
    @State var isLoadingProducts: Bool = false
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var contentView: some View {
        VStack(){
            if isLoadingProducts {
                ProgressView().progressViewStyle(.circular)
            } else {
                ForEach(products) { product in
                    HStack(){
                        Text(product.localizedTitle)
                        Spacer()
                        Button(){
                            appCoordinator.storeKitHelper.buyProduct(product)
                        } label: {
                            Text("Buy")
                        }
                        .buttonStyle(GrowingButton())
                    }
                    .padding()
                }
            }
        }
        .padding()
        .animation(.easeInOut)
        .onReceive(appCoordinator.storeKitHelper.$products, assign: \.products, target: self)
        .onReceive(appCoordinator.storeKitHelper.$isLoadingProducts, assign: \.isLoadingProducts, target: self)
        .onAppear(){
            appCoordinator.storeKitHelper.request(Product.Identifier.productIds)
        }
    }
}

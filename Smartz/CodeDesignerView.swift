//
//  CodeDesignerView.swift
//  Joli
//
//  Created by Anthony Chinwo on 17/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground

public struct CodeDesignerView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @State var selectedTab = 0
    
    @State var selectedExperience: Experience.Type? = nil {
        didSet {
            self.selectedTab = 1
        }
    }
    
    static func experienceClasses() -> [Experience.Type] {
        return [
            RestaurantView.self,
            TvShowPromoView.self
        ]
    }
    
    var tabNames: [String] {
        return [
            "Pick a Brand Experience",
            "Customise Experience",
            "Customise Code",
            "Confirm & Pay",
        ]
    }
    
    var pickExperienceView: some View {
        //VStack(){
            
            //Divider().padding(.vertical)
            
//            let heeader = HStack(){
//                Image(systemName: "qrcode.viewfinder")
//                Text("Brand Experiences")
//                Spacer()
//            }
//            .font(.title2.weight(.light)).foregroundColor(.secondaryLabel)
//            .padding(.vertical)
            
            VStack(){
                ForEach(products) { product in
                    
                    VStack(alignment: .leading){
                        
                        HStack(){
                            Group(){
                                if let name = product.companyLogoName {
                                    Image(name)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } else {
                                    let iconName = product.iconName ?? "calendar.circle.fill"
                                    Image(systemName: iconName)
                                        .resizable()
                                        .renderingMode(.original)
                                        .aspectRatio(contentMode: .fit)
                                        .font(.title3)
                                        .if(iconName != "calendar.circle.fill") { view in
                                            view.padding()
                                        }
                                }
                            }
                            .frame(width: 64, height: 64)
                            .background(Color.fixedWhite)
                            .clipShape(Circle())
                            .padding(.trailing, 2)
                            
                            VStack(alignment: .leading){
                                Text(product.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(4)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.vertical, 2)
                                
                                HStack(){
                                    Label(product.companyName, systemImage: "building.2.crop.circle")
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.secondaryLabel)
                                        .fixedSize(horizontal: true, vertical: true)
                                    Label(product.companyDescription, systemImage: "tag")
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .foregroundColor(.secondaryLabel)
                                        .fixedSize(horizontal: true, vertical: true)
                                }
                            }
                        }
                        
                        HStack(){
                            Spacer()
                            
                            Button(){
                                guard !product.isComingSoon else {
                                    return
                                }
                                appCoordinator.currentLocation = product.location
                            } label: {
                                Text(product.isComingSoon ? "Coming\nSoon" : "Try It!")
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .font(product.isComingSoon ? .caption : .subheadline.weight(.semibold))
                                    .foregroundColor(product.isComingSoon ? .secondaryLabel : .blue)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding()
                                    .background(Color.secondarySystemGroupedBackground)
                            }
                            .disabled(product.isComingSoon)
                            .clipShape(RoundedRectangle(cornerRadius: 32))
                            
                            Button(){
                                self.selectedExperience = product.experienceCls
                            } label: {
                                Text("Select")
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .font(product.isComingSoon ? .caption : .subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding()
                            }
                            .disabled(product.isComingSoon)
                            .clipShape(RoundedRectangle(cornerRadius: 32))
                        }
                    }
                    .padding()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(product.experienceCls == selectedExperience ? 0.6 : 0), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
            
            
//            Button(){
//                selectedExperience = RestaurantView.self
//                selectedTab = selectedTab + 1
//
//                let x = ExperienceData()
//                x.brandName = "My brand"
//
//                //let k: PartialKeyPath<ExperienceData> = (\ExperienceData.companyName)
//
//                for dt in RestaurantView.allDataKeys {
//                    print("Children: \(String(describing: dt.meta))")
//                }
//            } label: {
//                Text("Next").font(.title).foregroundColor(.fixedWhite)
//            }
          //  Spacer()
        //}
    }
    
    func customiseExperienceView(_ experienceClass: Experience.Type) -> some View {
        VStack(){
            Text("Customise Experience")
        }
    }
    
    var customiseCodeView: some View {
        VStack(){
            Text("Customise Code")
        }
    }
    
    var confirmAndPayView: some View {
        VStack(){
            Text("Confirm & Pay")
        }
    }
    
    var views: [(view: AnyView, index: Int)] {
        var vs: [(view: AnyView, index: Int)] = [
         (pickExperienceView
            .background(Color.blue)
            .eraseToAnyView(), 0),
        ]
        
        if let selectedExperience = selectedExperience {
            vs.append((
                customiseExperienceView(selectedExperience)
                    .background(Color.green)
                    .eraseToAnyView(), 1
            ))
        }
        
        if let selectedExperience = selectedExperience {
            vs.append((
                customiseCodeView
                    .background(Color.purple)
                    .eraseToAnyView(), 2
            ))
        }
        
        if let selectedExperience = selectedExperience {
            vs.append((
                confirmAndPayView
                    .background(Color.purple)
                    .eraseToAnyView(), 3
            ))
        }
        
        print("Views count: \(vs.count)")
        return vs
    }
    
    public var contentView: some View {
        ZStack(alignment: .top){
            TabView(selection: $selectedTab) {
                ForEach(self.views, id: \.index){ item in
                    item.view
                        .tag(item.index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .interactive))
            
            HStack(){
                VStack(alignment: .leading){
                    Text(tabNames[selectedTab])
                        .font(.title)
                        .padding([.trailing, .leading, .top])
                    Text("Step \(selectedTab + 1) of \(tabNames.count)")
                        .font(.caption)
                        .foregroundColor(.secondaryLabel)
                        .padding([.trailing, .leading, .bottom])
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(minHeight: screenHeight)
        .background(Color.pink)
    }
    
}

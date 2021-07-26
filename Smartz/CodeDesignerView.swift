//
//  CodeDesignerView.swift
//  Joli
//
//  Created by Anthony Chinwo on 17/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground
import Combine

extension PartialKeyPath.Metadata: View where Root == ExperienceData {
    
    public var body: some View {
        Text("\(self.name)")
    }
    
}

extension ExperienceData {
    
    static func unwrap(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        
        if mirror.displayStyle != .optional {
            return value
        }
        
        if let child = mirror.children.first {
            return child.value
        } else {
            return nil
        }
    }
    
    public func isValid(for dataKeys: [ExperienceDataKeyPath]) -> Bool {
        var missingValues: [ExperienceDataKeyPath.Metadata] = []
        
        for dataKey in Set(dataKeys) {
            guard let meta = dataKey.meta else {
                continue
            }
            
            let value = Self.unwrap(self[keyPath: meta.keypath])
            
            
            guard value == nil else { continue }
            
            missingValues.append(meta)
        }
        
        print("missingValues: \(missingValues.map(\.name))")
        
        return missingValues.isEmpty
    }
    
}

extension Array where Element == ExperienceDataKeyPath.Metadata {
    
    public func first(keypath: ExperienceDataKeyPath) -> Element? {
        return self.first() { $0.keypath == keypath }
    }
    
}

public struct CodeDesignerView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @State var selectedTab = 0
    
    @Binding var selectedExperience: Experience.Type? {
        didSet {
            self.selectedTab = 1
        }
    }
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Binding var experienceData: ExperienceData?
    
    @AppStorage("cd-brand-name") var brandName: String = .empty
    @AppStorage("cd-brand-landingpagetext") var landingPageText: MultilineString = .empty
    
    public init(_ experienceType: Binding<Experience.Type?>, _ data: Binding<ExperienceData?>){
        self._experienceData = data
        self._selectedExperience = experienceType
    }
    
    static func experienceClasses() -> [Experience.Type] {
        return [
            RestaurantView.self,
            TvShowPromoView.self,
            MealboxView.self,
            ReorderNowView.self,
        ]
    }
    
    var tabNames: [String] {
        var names = ["Pick a Brand Experience"]
        
        if let expCls = self.selectedExperience {
            names.append("Customise \(expCls.title) Experience")
        } else {
            names.append("Customise Experience")
        }
        
        names.append(contentsOf: ["Customise Code", "Confirm & Pay"])
        return names
    }
    
    var pickExperienceView: some View {
        VStack(){
            ForEach(products) { product in
                
                let onTap: () -> Void = {
                    guard !product.isComingSoon else {
                        return
                    }
                    
                    self.selectedExperience = product.experienceCls
                }
                
                VStack(alignment: .leading, spacing: .zero){
                    
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
                            
                            
                            Button(){
                                guard !product.isComingSoon else {
                                    return
                                }
                                appCoordinator.currentLocation = product.location
                            } label: {
                                Text(product.isComingSoon ? "Coming Soon" : "Try It!")
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .font(product.isComingSoon ? .caption : .subheadline.weight(.semibold))
                                    .foregroundColor(product.isComingSoon ? .secondaryLabel : .blue)
                                    .fixedSize(horizontal: true, vertical: true)
                                    .padding(.vertical, 4)
                                //.background(Color.secondarySystemGroupedBackground)
                            }
                            .disabled(product.isComingSoon)
                            .clipShape(RoundedRectangle(cornerRadius: 32))
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(product.experienceCls == selectedExperience ? 0.6 : 0), lineWidth: 1)
                )
                .onTapGesture(perform: onTap)
                .overlay(
                    HStack(){
                        Spacer()
                        
                        VStack(){
                            let isActive = product.experienceCls == selectedExperience
                            
                            Button() {
                                onTap()
                            } label: {
                                Image(systemName: isActive ? "checkmark.circle.fill" : "circle.dashed")
                                    .foregroundColor(isActive ? .green : Color.secondaryLabel)
                                    .padding()
                                    .font(.title.weight(.light))
                                    .scaleEffect(x: isActive ? 1.5 : 1, y: isActive ? 1.5 : 1)
                                    .animation(.easeInOut)
                            }
                            
                            Spacer()
                        }
                    }
                    .opacity(product.isComingSoon ? 0 : 1)
                )
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, safeAreaInsets.top)
    }
    
    @State var isLandingPageTapped = false
    
    private func updateBrandName() {
        let brandName = brandName.trimmingCharacters(in: .whitespacesAndNewlines)
        let landingPageText = landingPageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !brandName.isEmpty && !landingPageText.isEmpty else { return }
        
        self.experienceData = ExperienceData(brandName: brandName, landingPageText: landingPageText)
    }
    
    func customiseExperienceView(_ experienceClass: Experience.Type) -> some View {
        //ScrollView(.vertical){
        VStack(){
            if let experienceData = self.experienceData {
                ExperienceDataView(experienceClass, experienceData) { data in
                    self.experienceData = data
                    self.selectedTab = 2
                    
                    self.brandName = data.brandName
                }
                .padding(.bottom, safeAreaInsets.bottom * 2)
                //.padding(.top, safeAreaInsets.top)
            } else {
                VStack(){
                    Text("What's Your Brand Name?")
                        .font(.title.weight(.light))
                        .padding(.top, safeAreaInsets.top)
                        .padding()
                    
                    TextField("Enter your brand name", text: self.$brandName) { editing in
                        
                    } onCommit: {
                        self.updateBrandName()
                    }
                    .padding([.horizontal, .bottom])
                    .multilineTextAlignment(.center)
                    
                    Text("Welcome Page Message")
                        .font(.title.weight(.light))
                        .padding()
                    TextEditor(text: self.$landingPageText)
                        .frame(height: screenWidth / 2)
                        .padding()
                        .overlay(
                            GeometryReader(){ proxy in
                                VStack(alignment: .leading){
                                    if landingPageText.isEmpty, !isLandingPageTapped {
                                        Text("Enter a message for your \(experienceClass.title) experience's landing page")
                                            .padding()
                                            .foregroundColor(.tertiaryLabel)
                                        Spacer()
                                    }
                                }
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .padding()
                            }
                        )
                        .multilineTextAlignment(.center)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondaryLabel, lineWidth: 1))
                        .padding([.horizontal, .bottom])
                        .onTapGesture {
                            isLandingPageTapped = true
                        }
                    
                    Button(){
                        self.updateBrandName()
                    } label: {
                        Label("Save & Continue", systemImage: "arrow.forward")
                    }
                    .disabled(brandName.isEmpty || landingPageText.isEmpty)
                    .padding()
                    .padding(.top)
                }
                .padding()
            }
            Spacer()
        }
//        .simultaneousGesture(
//            TapGesture()
//                .onEnded() { value in
//                    guard appCoordinator.keyboardHeight > 0 else {
//                        return
//                    }
//
//                    appCoordinator.dismissKeyboard()
//                }
//        )
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
            //.background(Color.blue)
            .eraseToAnyView(), 0),
        ]
        
        if let selectedExperience = selectedExperience {
            vs.append((
                customiseExperienceView(selectedExperience)
                    //.background(Color.green)
                    .eraseToAnyView(), 1
            ))
        }
        
        if let selectedExperience = selectedExperience,
           let expData = experienceData, expData.isValid(for: selectedExperience.allDataKeys) {
            vs.append((
                customiseCodeView
                    //.background(Color.purple)
                    .eraseToAnyView(), 2
            ))
        }
        
        if let selectedExperience = selectedExperience,
           let expData = experienceData, expData.isValid(for: selectedExperience.allDataKeys) {
            vs.append((
                confirmAndPayView
                    //.background(Color.purple)
                    .eraseToAnyView(), 3
            ))
        }
        
        print("Views count: \(vs.count)")
        return vs
    }
    
    public var contentView: some View {
        //return //ZStack(alignment: .top){
        return TabView(selection: $selectedTab) {
                ForEach(self.views, id: \.index){ item in
                    item.view
                        .tag(item.index)
                        .id("code-designer-tabview-\(item.index)")
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .interactive))
            .frame(idealHeight: screenHeight)
            .id("code-designer-tabview")
            
//            HStack(){
//                VStack(alignment: .leading){
//                    Text(tabNames[selectedTab])
//                        .font(.title)
//                        .padding([.trailing, .leading, .top])
//                    Text("Step \(selectedTab + 1) of \(tabNames.count)")
//                        .font(.caption)
//                        .foregroundColor(.secondaryLabel)
//                        .padding([.trailing, .leading, .bottom])
//                    Spacer()
//                }
//                Spacer()
//            }
       // }
        //.background(Color.pink)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { // <2>
            ToolbarItem(placement: .navigationBarLeading) { // <3>
                VStack(alignment: .leading) {
                    Text(tabNames[selectedTab])
                        .font(.headline)
                    Text("Step \(selectedTab + 1) of \(tabNames.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondaryLabel)
                }
            }
        }
        .onAppear() {
            self.selectedTab = selectedExperience == nil ? 0 : 1
            self.updateBrandName()
        }
        //.navigationBarTitle(Text(tabNames[selectedTab]).multilineTextAlignment(.leading))
    }
    
}

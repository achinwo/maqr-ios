//
//  CodeDesignerView.swift
//  Joli
//
//  Created by Anthony Chinwo on 17/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground

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
        
        for dataKey in dataKeys {
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

public struct ExperienceDataView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    let data: ExperienceData
    let experienceType: Experience.Type
    let completionCallback: (ExperienceData) -> Void
    
    @State private var enableLogging = false
    @State private var selectedColor = "Red"
    @State private var colors = ["Red", "Green", "Blue"]
    @State var isUploadingImage = false
    
    init(_ dataType: Experience.Type, _ data: ExperienceData, callback: @escaping (ExperienceData) -> Void) {
        self.data = data
        self.experienceType = dataType
        self.completionCallback = callback
        self._socialInstagramUsername = State(initialValue: data.socialInstagramUsername ?? .empty)
    }
    
    public var allDataKeys: [ExperienceDataKeyPath.Metadata] {
        return experienceType.allDataKeys.compactMap() { $0.meta }
    }
    
    func imagePickerFrom(meta: ExperienceDataKeyPath.Metadata) -> some View {
        print("test: \(meta)")
        
        let imageCallback = { (img: UIImage?, error: Error?) in
            print("image: \(String(describing: img)), error: \(String(describing: error))")
            
            guard let image = img?.resizeImage(CGSize(width: 640, height: 640)), error == nil else {
                return
            }
            
            isUploadingImage = true
            
            self.api.upload(image)
                .then() { (res: URL) in
                    print("Result: \(res.absoluteString)")
                    
                    let imageUrl = URL(string: "/images/\(res.lastPathComponent)", relativeTo: appCoordinator.api.baseUrlHttp)
                    
                    guard let keyPath = meta.keypath as? ReferenceWritableKeyPath<ExperienceData, URL?> else {
                        print("Unable to produce writeable keypath for: \(meta)")
                        return
                    }
                    
                    self.data[keyPath: keyPath] = imageUrl
                    print("Updated \(meta.name): \(self.data[keyPath: keyPath])")
                }
                .catch { error in
                    print("uploadImage: \(error)")
                }
                .always() {
                    isUploadingImage = false
                }
        }
        
        return HStack(){
            VStack(alignment: .leading){
                Text(meta.title).font(.headline)
                Text(meta.description).font(.subheadline).multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            ImageView(url: data[keyPath: meta.keypath] as? URL, isCircular: false, onSelected: imageCallback) { (image, error) in
                
            } content: {
                VStack(alignment: .center){
                    Button(){
                        print("pick image")
                    } label: {
                        Image(systemName: "camera.fill")
                        
                    }
                }
            }
            .frame(width: screenWidth / 3, height: screenWidth / 3)
            .overlay(
                Group() {
                    if isUploadingImage {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .foregroundColor(.primary)
                    } else {
                        EmptyView()
                    }
                }
            )
        }
        .id(meta.name)
    }
    
    @State var socialInstagramUsername: String = .empty
    @State var fieldSize: CGSize = .zero
    
    public var contentView: some View {
        Form {
            
            Section() {
                
                if let logoMeta = allDataKeys.first(keypath: \ExperienceData.logoImageUrl) {
                    self.imagePickerFrom(meta: logoMeta)
                }
                
                if let bannerMeta = allDataKeys.first(keypath: \ExperienceData.bannerImageUrl) {
                    self.imagePickerFrom(meta: bannerMeta)
                }
                
                if let bgMeta = allDataKeys.first(keypath: \ExperienceData.backgroundImageUrl) {
                    self.imagePickerFrom(meta: bgMeta)
                }
                
            }
            
            if let instaMeta = allDataKeys.first(keypath: \ExperienceData.socialInstagramUsername) {
                
                Section(header: Text("Social")) {
                
                    TextField(instaMeta.description, text: $socialInstagramUsername, onEditingChanged: {_ in }) {
                        let insta = socialInstagramUsername.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        guard !insta.isEmpty else { return }
                        
                        data.socialInstagramUsername = insta
                    }
                    .padding(.leading, fieldSize.height * 2.5)
                    .overlay(
                        GeometryReader(){ proxy in
                            HStack(){
                                Image("instagram_logo")
                                    .resizable()
                                    .frame(width: proxy.size.height, height: proxy.size.height)
                                Image(systemName: "at")
                                    .resizable()
                                    .frame(width: proxy.size.height * 0.8, height: proxy.size.height * 0.8)
                                    .foregroundColor(.secondaryLabel)
                                Spacer()
                            }
                            .frame(height: proxy.size.height)
                            //.padding(.leading, -1 * fieldSize.height * 2)
                            .onAppear(){
                                self.fieldSize = proxy.size
                            }
                        }
                    )
                }
                //                Picker("Select a color", selection: $selectedColor) {
                //                    ForEach(colors, id: \.self) {
                //                        Text($0)
                //                    }
                //                }
                //                .pickerStyle(SegmentedPickerStyle())
                //
                //                Toggle("Enable Logging", isOn: $enableLogging)
            }
            
            Section(footer: Text("Note: Enabling logging may slow down the app")) {
//                Picker("Select a color", selection: $selectedColor) {
//                    ForEach(colors, id: \.self) {
//                        Text($0)
//                    }
//                }
//                .pickerStyle(SegmentedPickerStyle())
//
//                Toggle("Enable Logging", isOn: $enableLogging)
            }
            
            Section {
                HStack(){
                    Spacer()
                    Button(){
                        print("hit continue!")
                        
                        guard data.isValid(for: experienceType.allDataKeys) else {
                            return
                        }
                        
                        self.completionCallback(data)
                        
                    } label: {
                        // activate theme!
                        Label("Save & Continue", systemImage: "arrow.forward")
                    }
                    .disabled(!data.isValid(for: experienceType.allDataKeys))
                    Spacer()
                }
            }
        }
//        VStack(){
//            ForEach(allDataKeys) { dataKey in
//                dataKey
//            }
//        }
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
    
    @Binding var experienceData: ExperienceData?
    @AppStorage("cd-brand-name") var brandName: String = .empty
    
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
    
    private func updateBrandName() {
        let brandName = brandName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !brandName.isEmpty else { return }
        
        self.experienceData = ExperienceData(brandName: brandName)
    }
    
    func customiseExperienceView(_ experienceClass: Experience.Type) -> some View {
        VStack(){
            if let experienceData = self.experienceData {
                ExperienceDataView(experienceClass, experienceData) { data in
                    self.experienceData = data
                    self.selectedTab = 2
                }
            } else {
                TextField("What's Your Brand Name", text: self.$brandName) { editing in
                    
                } onCommit: {
                    self.updateBrandName()
                }
                .padding()
                .padding(.top, 200)
            }
            Spacer()
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
        
        if let selectedExperience = selectedExperience,
           let expData = experienceData, expData.isValid(for: selectedExperience.allDataKeys) {
            vs.append((
                customiseCodeView
                    .background(Color.purple)
                    .eraseToAnyView(), 2
            ))
        }
        
        if let selectedExperience = selectedExperience,
           let expData = experienceData, expData.isValid(for: selectedExperience.allDataKeys) {
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
        return ZStack(alignment: .top){
            TabView(selection: $selectedTab) {
                ForEach(self.views, id: \.index){ item in
                    item.view
                        .tag(item.index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .interactive))
            
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
        }
        .frame(idealHeight: screenHeight)
        .background(Color.pink)
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

//
//  CodeDesignerView.swift
//  Joli
//
//  Created by Anthony Chinwo on 17/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import Combine
import os
import Foundation
import JoliCore
import JoliApi

extension Array where Element == ExperienceDataKeyPath.Metadata {
    
    public func first(keypath: ExperienceDataKeyPath) -> Element? {
        return self.first() { $0.keypath == keypath }
    }
    
}

public struct LocalExperienceData: Codable {
    let appVersion: String
    let experienceData: ExperienceData
}

extension AppStorageKey {
    
    static let experienceDataCache = AppStorageKey("experience-data-cache")//"cd-brand-name"
    static let codeDesignerBrandName = AppStorageKey("cd-brand-name")
    static let codeDesignerLandingText = AppStorageKey("cd-brand-landingpagetext")
    static let activeTab = AppStorageKey("active-tab")
    static let activeAccessLevel = AppStorageKey("active-access-level")
}

public struct CodeDesignerView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @State var selectedTab = 0
    
    @AppStorage(key: .experienceDataCache) public var storedData: Data = .empty
    
    @State var selectedExperience: (any Experience.Type)? = nil {
        didSet {
            
            guard selectedExperience != nil else { return }
            
            DispatchQueue.main.async {
                self.selectedTab = 1
            }
        }
    }
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @State var experienceData: ExperienceData? = nil
    
    @AppStorage(key: .codeDesignerBrandName) var brandName: String = .empty
    @AppStorage(key: .codeDesignerLandingText) var landingPageText: MultilineString = .empty
    
    @State var isLandingPageTapped = false
    
    @Environment(\.colorScheme) var colorScheme
    @State var showBadge = true
    @State var readyToDownload = true
    
    let trialActivateCallback: (ExperienceData) -> Void
    let persistenceEnabled: Bool = true
    
    
    @State public var scrollProxy: ScrollViewProxy? = nil
    @AppStorage(key: .purchasesIdsForTesting) var purchasesIdsForTesting: String = .empty
    
    @Debounced(delay: 0.3) public var requestStoredExperienceRefreshAt: Date? = nil
    @Debounced(delay: 1.3) public var requestExperiencePersistAt: Date? = nil
    
    @State public var submitting = false {
        didSet {
            self.submitEnabled = !submitting
        }
    }
    
    @State public var visualCode = VisualCodeRecord(properties: [.logo: Logo.badge.rawValue as AnyObject, .interactionType: InteractionType.cam.rawValue as AnyObject])
    
    @State var submitEnabled = true
    
    public var isNewExperience: Bool {
        return self.experienceData?.isNew ?? true
    }
    
    public init(persistenceEnabled: Bool? = nil, onActiveTrial: @escaping (ExperienceData) -> Void){
        self.trialActivateCallback = onActiveTrial
        //self.persistenceEnabled = persistenceEnabled ?? (data.wrappedValue?.uuid == nil)
    }
    
    var tabNames: [String] {
        var names = ["Pick a Brand Experience"]
        
        let verb = isNewExperience ? "Customise" : "Edit"
        
        if let expCls = self.selectedExperience {
            names.append("\(verb) \(expCls.title) Experience")
        } else {
            names.append("\(verb) Experience")
        }
        
        names.append("\(verb) Code") //, "Get Your Assets"])
        return names
    }
    
    func productView(_ product: ProductOffering) -> some View {
        let onTap: () -> Void = {
            guard !product.isComingSoon else {
                return
            }
            
            let setupExperienceType = {
                self.selectedExperience = product.experienceCls
                
                guard let expData = experienceData else { return }
                
                expData.uuid = nil
                expData.stored = nil
            }
            
            guard appCoordinator.activeAuth == nil else {
                setupExperienceType()
                return
            }
            
            appCoordinator.withAlert("Sign In With Apple", message: "It ensures your experience can be saved correctly", dismissLabel: "Cancel", label: "Sign In") {
                self.appCoordinator.requestedSignIn.send(.apple() { success in
                    if success {
                        setupExperienceType()
                    }
                })
            }
        }
        
        let productBody = VStack(alignment: .leading){
            Text(product.name)
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                //.padding(.bottom, 1)
            
            Text(product.description)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)
                .foregroundColor(.secondaryLabel)
            
            HStack(){
//                Label(product.companyName, systemImage: "building.2.crop.circle")
//                    .font(.caption)
//                    .lineLimit(1)
//                    .foregroundColor(.tertiaryLabel)
//                    .fixedSize(horizontal: true, vertical: true)
                Label(product.companyDescription, systemImage: "tag")
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.tertiaryLabel)
                    .fixedSize(horizontal: true, vertical: true)
            }
            .padding(.top, 2)
            
        }
         
        return VStack(alignment: .leading, spacing: .zero){
            
            HStack(alignment: .top){
                
                
                Button(){
                    guard !product.isComingSoon else {
                        return
                    }
                    
                    appCoordinator.dismissKeyboard()
                    appCoordinator.currentLocation = product.location
                } label: {
                    VStack(){
                        Group(){
                            if let name = product.companyLogoName {
                                Image(name)
                                    .resizable()
                                    .frame(width: Sizing.xxLarge * 1.5, height: Sizing.xxLarge * 1.5)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Image(systemName: product.experienceCls.iconName)
                                    .renderingMode(.original)
                            }
                        }
                        .aspectRatio(contentMode: .fit)
                        .font(.largeTitle)
                        .frame(maxWidth: screenWidth / 5)
                        //.clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        Text(product.isComingSoon ? "Coming Soon" : "Try It!")
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .font(product.isComingSoon ? .caption2 : .subheadline.weight(.semibold))
                            .foregroundColor(product.isComingSoon ? .secondaryLabel : .blue)
                            .fixedSize(horizontal: true, vertical: true)
                            .padding(.vertical, 4)
                            //.background(Color.secondarySystemGroupedBackground)
                    }
                        //.clipShape(RoundedRectangle(cornerRadius: 32))
                }
                .disabled(product.isComingSoon)
                .padding(.leading, 2)
                
                productBody
                
                Spacer()
            }
        }
        .padding(4)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(product.experienceCls == selectedExperience && experienceData?.uuid == nil ? 0.6 : 0), lineWidth: 1)
        )
        .onTapGesture(perform: onTap)
        .overlay(
            HStack(){
                Spacer()
                
                VStack(){
                    let isActive = product.experienceCls == selectedExperience && experienceData?.uuid == nil
                    
                    Button() {
                        onTap()
                    } label: {
                        Image(systemName: isActive ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundColor(isActive ? .green : Color.secondaryLabel)
                            .padding(.horizontal)
                            .font(.title.weight(.light))
                            .scaleEffect(x: isActive ? 1.5 : 1, y: isActive ? 1.5 : 1)
                            .animation(.easeInOut)
                    }
                    .disabled(!isActive)
                    
                    Spacer()
                }
            }
            .opacity(product.isComingSoon ? 0 : 1)
        )
    }
    
    var pickExperienceView: some View {
        VStack(){
            ForEach(products) { product in
                self.productView(product)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, safeAreaInsets.top)
    }
    
    private func updateBrandName() {
        let brandName = brandName.trimmingCharacters(in: .whitespacesAndNewlines)
        let landingPageText = landingPageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let typeName = self.selectedExperience, let exp = Experiences(rawValue: typeName), !brandName.isEmpty && !landingPageText.isEmpty, self.experienceData == nil else { return }
        
        self.experienceData = ExperienceData(exp, brandName: brandName, landingPageText: landingPageText)
    }
    
    func customiseExperienceView(_ experienceClass: any Experience.Type) -> some View {
        VStack(){
            if let experienceData = self.experienceData {
                ExperienceDataView(experienceData) { data in
                    self.experienceData = data
                    self.selectedTab = 2
                    
                    self.brandName = data.brandName
                }
                //.padding(.bottom, safeAreaInsets.bottom * 2)
                .layoutPriority(20)
            } else {
                ScrollView() {
                    self.brandDataView(experienceClass)
                }
            }
            Spacer()
        }
    }
    
    func brandDataView(_ experienceClass: any Experience.Type) -> some View {
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
            //.focusedLegacy($focusedField, equals: .brandName)
            
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
        .task {
            print("Task ran correctly")
            //focusedField = .brandName
        }
    }
    
    @discardableResult
    @MainActor
    func submitExperience(_ expData: ExperienceData, codes: [VisualCodeRecord] = []) async throws -> StikrExperienceData {
        self.submitting = true
        
        defer {
            self.submitting = false
            self.requestStoredExperienceRefreshAt = Date()
        }
        
        do {
            let saved = try await expData.save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            print("SAVE experience: \(saved)")
            
            for var code in codes {
                    // temporarily hardcoding user id until sign in is implemented
                code.createdById = appCoordinator.activeAuth?.user.id ?? 17
                code.updatedById = appCoordinator.activeAuth?.user.id ?? 17
                
                code.url = JoliApi.BaseUrl.prod.rawValue.http.appendingPathComponent(expData.experienceTypeInfo.rawValue.basePath).appendingPathComponent(saved.uuid).standardized.absoluteString
                code.experienceId = saved.id
                code.style = code.style ?? Style.appclip.rawValue
                let _ = try await code.save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            }
            
            defer {
                DispatchQueue.main.async(){
                    self.experienceData = ExperienceData.fromExperienceData(saved, baseUrl: api.baseUrlHttp)
                    onExperinceDataChanged(self.experienceData)
                }
            }
            
            
            return saved
        } catch {
            print("Save error: \(error)")
            throw error
        }
        
        
    }
    
    var viewCount: Int {
        var vs = 1
        
        guard selectedExperience != nil else { return vs }
        
        vs += 1
        
        guard experienceData != nil else { return vs }
        
        return vs + 1
    }
    
    func visualCodeView(_ expData: ExperienceData) -> some View {
        VisualCodeView(code: $visualCode, submitEnabled: $submitEnabled){ visualCode in
            print("Submitting: \(visualCode.properties)")
            Task() { await self.submitOrPurchase(expData, codes: [visualCode]) }
        } label: {
            if expData.uuid == nil {
                let newTxt: (String, String) = appCoordinator.isPaymentEnabled && !self.hasSubscription ? ("Purchase", "cart") : ("Submit", "arrow.up")
                Label(newTxt.0, systemImage: newTxt.1)
            } else {
                Text("Save Changes")
            }
        }
        .id("\(String(describing: expData.uuid))-\(String(describing: expData.stored?.updatedAt))-\(String(describing: expData.stored?.visualcodes?.last?.updatedAt))")
    }
    
    private func onExperinceDataChanged(_ value: ExperienceData?) {
        self.requestExperiencePersistAt = Date()
        self.brandName = value?.brandName ?? self.brandName
        self.landingPageText = value?.landingPageText ?? self.landingPageText
        
        print("[Experience#onChange] \(String(describing: value))")
        
        guard let expTypeName = value?.experienceTypeName, let expCls = Experiences(typeName: expTypeName)?.rawValue else { return }
        
        self.selectedExperience = expCls
        self.visualCode = value?.stored?.visualcodes?.last?.builder() ?? self.visualCode
        
        print("[Experience#onChange] EXP: \(String(describing: self.selectedExperience))")
    }
    
    @State var userEntitlements: [Entitlement] = []
    
    var hasSubscription: Bool {
        
        if let user = appCoordinator.activeAuth?.user, self.userEntitlements.first(where: { $0.type == "subscription_account" && $0.userId == user.id }) != nil {
            return true
        }
        
        guard Date(timeIntervalSince1970: 1_640_993_136) > Date() else { return false } // disable testing purchase flow end of 2021
        
        let existingPurchaseIds = purchasesIdsForTesting.components(separatedBy: ",")
        let subscriptionPurchases = Product.Identifier.productIds.filter() { existingPurchaseIds.contains($0.id) && $0.isSubscription }
        
        return !subscriptionPurchases.isEmpty
    }
    
    public func clearStored() {
        for key in [AppStorageKey.codeDesignerLandingText, AppStorageKey.codeDesignerBrandName, AppStorageKey.experienceDataCache] {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }
        print("[\(Self.self)] cleared stored data")
    }
    
    public func submitOrPurchase(_ expData: ExperienceData, codes: [VisualCodeRecord] = []) async {
        
        guard let expCls = selectedExperience else {
            return
        }
        
        let backToHome = { (clear: Bool) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5){
                withAnimation(){
                    self.selectedTab = 0
                    
                    if clear {
                        self.selectedExperience = nil
                        self.experienceData = nil
                        self.clearStored()
                    }
                }
            }
        }
        
        guard appCoordinator.isPaymentEnabled, !self.hasSubscription, expData.uuid == nil else {
            let res = try? await self.submitExperience(expData, codes: codes)
            backToHome(res != nil)
            return
        }
        
        let view: AppPreview = .view2(){
            NavigationView(){
                ExperiencePurchaseView() { _ in
                    self.appCoordinator.modal.close()
                    
                    Task() {
                        let res = try? await self.submitExperience(expData, codes: codes)
                        backToHome(res != nil)
                    }
                }
                .navigationBarTitle(Text("Purchase \(expCls.title) Experience"), displayMode: .inline)
            }
            .eraseToAnyView()
        }
        
        self.appCoordinator.modal.present() {
            view
        }
    }
    
    @ViewBuilder func viewForIndex(_ index: Int) -> some View {
        if index == 0 {
            ScrollView() {
                VStack(){
                    Divider()
                        .padding(.bottom)
                    VStack(){
                        Text(tabNames[selectedTab])
                            .font(.largeTitle.weight(.light))
                        Text("Design an engaging branded experience in \(tabNames.count) easy steps")
                            .font(.subheadline)
                            .foregroundColor(.secondaryLabel)
                            //.padding()
                        pickExperienceView
                    }
                }
                //.backgroundColor(.blue)
                .padding(.bottom, 250)
            }
            //.frame(height: screenHeight * 2)
            //.backgroundColor(.pink)
        } else if let selectedExperience = self.selectedExperience, index == 1 {
            customiseExperienceView(selectedExperience)
                .edgesIgnoringSafeArea(.bottom)
        } else if let expData = self.experienceData, index == 2 {
            visualCodeView(expData)
        }
    }
    
    public var contentView: some View {
        TabView(selection: $selectedTab) {
            ForEach(0 ..< self.viewCount, id: \.self){ index in
                self.viewForIndex(index)
                    .frame(width: screenWidth)
                    .tag(index)
                    //.id("code-designer-tabview-\(index)")
            }
        }
        //.layoutPriority(100)
        //.backgroundColor(.green)
        .edgesIgnoringSafeArea(.bottom)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .interactive))
            //.frame(minHeight: screenHeight)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar() {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedTab > 0 {
                        VStack(alignment: .leading) {
                            Text(tabNames[selectedTab])
                                .font(.headline)
                            Text("Step \(selectedTab + 1) of \(tabNames.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondaryLabel)
                                .font(.headline)
                        }
                    } else {
                        EmptyView()
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    VStack(alignment: .center) {
                        if selectedTab == 0 {
                            Text("Code Designer")
                                .font(.headline)
                            Text("Create custom QR and App Clip codes")
                                .font(.subheadline)
                                .foregroundColor(.secondaryLabel)
                        }
                    }
                    .frame(minWidth: screenWidth / 1.5)
                    .id(selectedTab)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab > 0 {
                        
                        let isLastTab = selectedTab == tabNames.count - 1
                        
                        Button(){

                            let msg = "[\(Self.self)] attempting to submit: isLastTab=\(isLastTab), brandName=\(String(describing: experienceData?.brandName)), purchases: \(purchasesIdsForTesting), hasSubscription: \(hasSubscription)"
                            appCoordinator.serverLogDestination.send(.info, msg: msg, thread: Thread.current.description,
                                                                     file: #file, function: #function, line: #line)
                            
                            guard let expData = experienceData else {
                                return
                            }
                            
                            guard isLastTab else {
                                self.readyToDownload = true
                                self.appCoordinator.dismissKeyboard()
                                self.trialActivateCallback(expData)
                                return
                            }
                            
                            Task() { await self.submitOrPurchase(expData, codes: [visualCode]) }
                            
                        } label: {
                            
                            if isLastTab && submitting {
                                ProgressView().progressViewStyle(CircularProgressViewStyle())
                            } else if isLastTab {
                                let isNew = experienceData?.uuid == nil
                                let newTxt: String = isNew && appCoordinator.isPaymentEnabled && !self.hasSubscription ? "Purchase" : "Submit"
                                
                                Text(isNew ? newTxt : "Save Changes")
                            } else {
                                Text("Try It")
                            }
                            
                            //Label("Try It", systemImage: "arrow.forward")
                        }
                        .disabled(brandName.isEmpty || landingPageText.isEmpty || submitting)
                    }
                }
            }
            .id("code-designer-tabview-\(String(describing: self.experienceData?.uuid))")
            .onChange(of: self.experienceData) { value in
                self.updateStoredExperience()
                print("[Experience#onChange] \(String(describing: value))")
                
                guard let expTypeName = value?.experienceTypeName else { return }
                
                self.selectedExperience = Experiences(typeName: expTypeName)?.rawValue
            }
            .ifLet(self.experienceData) { view, experience in
                view.onReceive(experience.objectWillChange) { value in
                    DispatchQueue.main.async {
                        requestExperiencePersistAt = Date()
                    }
                }
            }
            .onReceive(self.$requestExperiencePersistAt) { persistRequestedAt in
                guard persistRequestedAt != nil else { return }
                self.updateStoredExperience()
                self.requestExperiencePersistAt = nil
            }
            .onReceive(appCoordinator.authSubject) { activeAuth in
                
                guard let auth = activeAuth else {
                    self.userEntitlements = []
                    return
                }
                
                Task() {
                    let entitlements = try? await Entitlement.all(where: [.userId: auth.user.id.description as AnyObject, .type: "subscription_account" as AnyObject],
                                                                  baseUrl: api.baseUrlHttp, urlSession: api.urlSession, on: .main)
                    self.userEntitlements = entitlements ?? []
                    //print("[CodeDesigner] user \(auth.user.id) entitlements: \(entitlements ?? [])")
                }
            }
            .onAppear() {
                
                //            let fileManager = FileManager.default
                //            let documentsURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                //            do {
                //                let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                //                // process files
                //                for u in fileURLs {
                //                    print("file: \(u)")
                //                }
                //            } catch {
                //                print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
                //            }
                self.requestStoredExperienceRefreshAt = Date()
                    
                defer {
                    self.selectedTab = selectedExperience != nil && isNewExperience ? 1 : 0
                    self.updateBrandName()
                }
                
                guard storedData != .empty else {
                    return
                }
                
                let decoder = Musicroom.jsonDecoder()
                let exp: LocalExperienceData
                
                do {
                    exp = try decoder.decode(LocalExperienceData.self, from: storedData)
                } catch {
                    print("[CodeDesignerView] unable to load stored experience: \(error)")
                    self.appCoordinator.globalErrorHandler()(error)
                    return
                }
                
                let expData = exp.experienceData
                
                self.selectedExperience = expData.experienceTypeInfo.rawValue
                
                expData.logoImageUrl = exp.experienceData.logoImageUrl?.cached
                expData.bannerImageUrl = exp.experienceData.bannerImageUrl?.cached
                expData.bannerVideoUrl = exp.experienceData.bannerVideoUrl?.cached
                expData.backgroundImageUrl = exp.experienceData.backgroundImageUrl?.cached
                expData.productImageUrl = exp.experienceData.productImageUrl?.cached
                
                expData.items = expData.items.map() { item -> ExperienceData.Item in
                    
                    guard let imageUrl = item.imageName, let url = URL(string: imageUrl) else {
                        return item
                    }
                    
                    var newItem = item
                    newItem.imageName = url.cached.absoluteString
                    
                    return newItem
                }
                
                self.brandName = expData.brandName
                self.landingPageText = expData.landingPageText
                
                self.experienceData = expData
                self.onExperinceDataChanged(expData)
                
                //let encode = exp.experienceData.jsonEncoder
                //let data = try! encode.encode(exp.experienceData)
                //print("[Experience Changed] loaded experience data") //: \(String(data: data, encoding: .utf8)!)")
                
                //            var string = "SVG File Name,URL,Background Color,Foreground Color,Type,Logo\n"
                //            let url = "https://smartstikr.com/s/shows/iacw"
                //            for item in appClipsStyles {
                //                string += "preview_appclip_\(item.index)_cam_badge.svg,\(url),\(item.backgroundColor.hexString.suffix(6)),\(item.foregroundColor.hexString.suffix(6)),cam,badge\n"
                //                string += "preview_appclip_\(item.index)_cam_none.svg,\(url),\(item.backgroundColor.hexString.suffix(6)),\(item.foregroundColor.hexString.suffix(6)),cam,none\n"
                //                string += "preview_appclip_\(item.index)_nfc_badge.svg,\(url),\(item.backgroundColor.hexString.suffix(6)),\(item.foregroundColor.hexString.suffix(6)),nfc,badge\n"
                //                string += "preview_appclip_\(item.index)_nfc_none.svg,\(url),\(item.backgroundColor.hexString.suffix(6)),\(item.foregroundColor.hexString.suffix(6)),nfc,none\n"
                //
                //                let s2 = AppClipCodeStyle(index: item.index + 1, foregroundColor: item.backgroundColor, backgroundColor: item.foregroundColor)
                //
                //                string += "preview_appclip_\(s2.index)_cam_badge.svg,\(url),\(s2.backgroundColor.hexString.suffix(6)),\(s2.foregroundColor.hexString.suffix(6)),cam,badge\n"
                //                string += "preview_appclip_\(s2.index)_cam_none.svg,\(url),\(s2.backgroundColor.hexString.suffix(6)),\(s2.foregroundColor.hexString.suffix(6)),cam,none\n"
                //                string += "preview_appclip_\(s2.index)_nfc_badge.svg,\(url),\(s2.backgroundColor.hexString.suffix(6)),\(s2.foregroundColor.hexString.suffix(6)),nfc,badge\n"
                //                string += "preview_appclip_\(s2.index)_nfc_none.svg,\(url),\(s2.backgroundColor.hexString.suffix(6)),\(s2.foregroundColor.hexString.suffix(6)),nfc,none\n"
                //            }
                //
                //            print(string)
            }
        //.navigationBarTitle(Text(tabNames[selectedTab]).multilineTextAlignment(.leading))
    }
    
    func updateStoredExperience() {
        
        guard let experience = self.experienceData, persistenceEnabled else { return }
        
        let localData = LocalExperienceData(appVersion: AppCoordinator.version.description, experienceData: experience)
        
        let encoder = experience.jsonEncoder
        guard let val = try? encoder.encode(localData) else {
            print("[Experience Changed] unable to encode experience")
            return
        }
        
        self.storedData = val
        
        print("[Experience#updateStoredExperience] updated stored experience")
    }
    
}

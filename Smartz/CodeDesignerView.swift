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
import os
import Foundation

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
    
    let trialActivateCallback: () -> Void
    
    public init(_ experienceType: Binding<Experience.Type?>, _ data: Binding<ExperienceData?>, onActiveTrial: @escaping () -> Void){
        self._experienceData = data
        self._selectedExperience = experienceType
        self.trialActivateCallback = onActiveTrial
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
        
        names.append(contentsOf: ["Customise Code", "Get Your Assets"])
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
                    
                    HStack(alignment: .top){
                        
                        
                        Button(){
                            guard !product.isComingSoon else {
                                return
                            }
                            appCoordinator.currentLocation = product.location
                        } label: {
                            VStack(){
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
                                            .aspectRatio(contentMode: .fill)
                                            .font(.title3)
                                            .if(iconName != "calendar.circle.fill") { view in
                                                view.padding()
                                            }
                                            .if(iconName == "calendar.circle.fill") { view in
                                                view.padding(-10)
                                            }
                                    }
                                }
                                .frame(width: 64, height: 64)
                                .background(Color.fixedWhite)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                
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
                        
                        
                        
                        VStack(alignment: .leading){
                            Text(product.name)
                                .font(.body.weight(.semibold))
                                .foregroundColor(.primary)
                                .lineLimit(4)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            //.padding(.bottom, 1)
                            
                            Text(product.description).font(.caption).padding(.top, 1).foregroundColor(.secondaryLabel)
                            
                            HStack(){
                                Label(product.companyName, systemImage: "building.2.crop.circle")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(.tertiaryLabel)
                                    .fixedSize(horizontal: true, vertical: true)
                                Label(product.companyDescription, systemImage: "tag")
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .foregroundColor(.tertiaryLabel)
                                    .fixedSize(horizontal: true, vertical: true)
                            }
                            .padding(.top, 2)
                            
                        }
                        
                        Spacer()
                    }
                }
                .padding(4)
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
                                    .padding(.horizontal)
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
                    
                    //                    Button(){
                    //                        self.readyToDownload = true
                    //                        self.trialActivateCallback()
                    //                    } label: {
                    //                        Label("Try It", systemImage: "arrow.forward")
                    //                    }
                    //                    .disabled(brandName.isEmpty || landingPageText.isEmpty)
                    //                    .padding()
                    //                    .padding(.top)
                }
                .padding()
//                .simultaneousGesture(
//                    TapGesture()
//                        .onEnded() { value in
//                            guard appCoordinator.keyboardHeight > 0 else {
//                                return
//                            }
//
//                            appCoordinator.dismissKeyboard()
//                        }
//                )
            }
            Spacer()
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    @State var showBadge = true
    @State var readyToDownload = true
    
    func iCloudDirectoryCreate(_ completionHanlder: (() -> Void)? = nil) {
        //let line = "Hello World"
        let url = api.baseUrlHttp.appendingPathComponent("/downloads/codes.zip")
        let fileName = "codes-\(UUID().uuidString).zip"
        let localDocsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        
        let localFile = localDocsURL.appendingPathComponent(fileName)
        ///downloads/code.zip
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        
        let task = api.urlSession.dataTask(with: req) { data, response, error in
            
            guard error == nil else {
                print("[code fetch] error: \(String(describing: error))")
                return
            }
            
            guard let data = data else {
                print("[code fetch] no data returned")
                return
            }
            
            do {
                //try line.write(to: localFile, atomically: true, encoding: .utf8)
                //let data = try Data(contentsOf: URL(staticString: "https://192.168.1.233:8080/downloads/codes.zip"))
                try data.write(to: localFile)
            } catch {
                os_log("Failed to export...", log: OSLog.default, type: .error)
            }
            
            guard let iCloudDocsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
                print("Unable to obtain documents path url")
                return
            }
            
            let iCloudFile = iCloudDocsURL.appendingPathComponent(fileName)
            
            if !FileManager.default.fileExists(atPath: iCloudDocsURL.path, isDirectory: nil) {
                try? FileManager.default.createDirectory(at: iCloudDocsURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            do {
                try FileManager.default.copyItem(at: localFile, to: iCloudFile)
            } catch {
                os_log("Failed to move to iCloud...", log: OSLog.default, type: .error)
            }
            
            
            print("saved: \(iCloudFile)")
            completionHanlder?()
        }
        
        task.resume()
    }
    
    @State var downloaded = false
    
    var confirmAndPayView: some View {
        VStack(){
            
            VStack(){
                
                (Text("Download ") + Text("Stikrs ").italic() + Text("to iCloud Drive"))
                    .font(.title.weight(.light))
                    .foregroundColor(.secondary)
                    .padding()
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                
                
                Divider().padding(.bottom)
                
                Image(systemName: "externaldrive.fill.badge.icloud")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: screenWidth / 2.4)
                    .padding([.bottom, .horizontal])
                    .padding(.vertical)
                
                Button(){
                    
                    guard !downloaded else {
                        appCoordinator.share(text: "Your file", url: URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/austin-chan-ukzHlkoz1IE-unsplash.jpg"))
                        return
                    }
                    
                    self.iCloudDirectoryCreate() {
                        self.presentToast("Done", subTitle: "Saved to iCloud Drive", type: .complete(.green)) { _ in
                            self.downloaded = true
                        }
                    }
                } label: {
                    HStack(){
                        Spacer()
                        Label(downloaded ? "Share .zip File" : "Save .zip to iCloud", systemImage: downloaded ? "square.and.arrow.up" : "icloud.and.arrow.down")
                            .font(.title3)
                            .foregroundColor(downloaded ? .white : .secondarySystemGroupedBackground)
                        Spacer()
                    }
                }
                .background(downloaded ? .systemIndigo : Color.white)
                .clipShape(RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                ))
                .frame(width: screenWidth - 100, height: 60)
                .accentColor(downloaded ? .systemIndigo.opacity(0.6) : .secondary)
                .buttonStyle(OutlineButton())
            }
            .frame(width: screenWidth - 100)
            .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
            .fixedSize(horizontal: false, vertical: true)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.bottom)
            .padding(.top, safeAreaInsets.top * 2)
            (Text("Note: ") + Text("Code Designer ").fontWeight(.semibold) + Text("is in beta and subject to change with future updates"))
                .frame(width: screenWidth - 100)
                .multilineTextAlignment(.center)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            Spacer()
        }
    }
    
    var views: [(view: AnyView, index: Int)] {
        var vs: [(view: AnyView, index: Int)] = [
            (pickExperienceView
                //.background(Color.blue)
                .eraseToAnyView(), 0),
        ]
        
        guard let selectedExperience = selectedExperience else { return vs }
        
        vs.append((
            customiseExperienceView(selectedExperience)
                //.background(Color.green)
                .eraseToAnyView(), 1
        ))
        
        //if let expData = experienceData, expData.isValid(for: selectedExperience.allDataKeys) {
        vs.append((
            VisualCodeView()
                //.background(Color.purple)
                .eraseToAnyView(), 2
        ))
        //}
        
        if readyToDownload {
            vs.append((
                confirmAndPayView
                    //.background(Color.purple)
                    .eraseToAnyView(), 3
            ))
        }
        //UIImageWriteToSavedPhotosAlbum
        //print("Views count: \(vs.count)")
        return vs
    }
    
    @State public var scrollProxy: ScrollViewProxy? = nil
    
    public var historyView: some View {
        Text("View History")
    }
    
    public var contentView: some View {
        //return //ZStack(alignment: .top){
        return TabView(selection: $selectedTab) {
            ForEach(self.views, id: \.index){ item in
                
                Group(){
                    if item.index == 0 {
                        ScrollView(.vertical, showsIndicators: true) {
                            ScrollViewReader() { proxy in
                                //creator
                                VStack(){
                                    historyView.frame(height: screenHeight)
                                    
                                    VStack(){
                                        Divider()
                                            .padding(.bottom)
                                        VStack(){
                                            Text(tabNames[selectedTab])
                                                .font(.largeTitle.weight(.light))
                                            Text("Step \(selectedTab + 1) of \(tabNames.count)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondaryLabel)
                                                //.padding()
                                            item.view
                                        }
                                    }
                                    .id("section-creator")
                                    Spacer()
                                }
                                .frame(minHeight: screenHeight * 2.2)
                                .onAppear(){
                                    self.scrollProxy = proxy
                                }
                            }
                        }
                    } else {
                        item.view
                    }
                }
                .frame(maxWidth: screenWidth)
                .tag(item.index)
                .id("code-designer-tabview-\(item.index)")
//                    .overlay(
//                        VStack(){
//                            Spacer()
//
//                            Button("Save to image") {
//                                let image = item.view.environmentObject(appCoordinator).snapshot(.systemBackground)
//
//                                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
//                            }
//                            Spacer()
//                        }
//                        .environmentObject(appCoordinator)
//                    )
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .interactive))
        .frame(idealHeight: screenHeight)
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
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab > 0 {
                    Button(){
                        self.readyToDownload = true
                        self.trialActivateCallback()
                    } label: {
                        Text("Try It")
                        //Label("Try It", systemImage: "arrow.forward")
                    }
                    .disabled(brandName.isEmpty || landingPageText.isEmpty)
                } else {
                    Button(){
                        withAnimation(){
                            self.scrollProxy?.scrollTo("section-creator", anchor: .top)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .id("code-designer-tabview")
        .onAppear() {
            self.selectedTab = selectedExperience == nil ? 0 : 1
            self.updateBrandName()
            
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
    
}



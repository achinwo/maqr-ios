//
//  ExperienceDataView.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground

public struct ExperienceDataView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @StateObject var data: ExperienceData
    let experienceType: Experience.Type
    let completionCallback: (ExperienceData) -> Void
    @State var isUploadingImage = false
    
    init(_ dataType: Experience.Type, _ data: ExperienceData, callback: @escaping (ExperienceData) -> Void) {
        self._data = StateObject(wrappedValue: data)
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
                    //print("Updated \(meta.name): \(self.data[keyPath: keyPath])")
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
                EmptyView()
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
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    @State var helloColor: Color = .green
    
    public var contentView: some View {
        Form() {
            
            Section(header: Text("Brand Name & Welcome Message").padding(.top, safeAreaInsets.top * 2)) {
                if let brandMeta = allDataKeys.first(keypath: \ExperienceData.brandName) {
                    TextField(brandMeta.description, text: $data.brandName, onEditingChanged: {_ in })
                }
                
                if allDataKeys.first(keypath: \ExperienceData.landingPageText) != nil {
                    TextEditor(text: $data.landingPageText)
                        .frame(height: screenWidth / 2.5)
                }
            }
            
            Section(header: Text("Brand Colors")) {
                HStack(){
                    Spacer()
                    if let primaryMeta = allDataKeys.first(keypath: \ExperienceData.brandColorPrimary) {
                        VStack(){
                            ColorPicker(primaryMeta.description.capitalized, selection: $helloColor)
                                .labelsHidden()
                                .font(.largeTitle)
                                .id(primaryMeta.id)
                            Text(primaryMeta.title).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    if let secondaryMeta = allDataKeys.first(keypath: \ExperienceData.brandColorSecondary) {
                        VStack(){
                            ColorPicker(secondaryMeta.description.capitalized, selection: $data.brandColorSecondary)
                                .labelsHidden()
                                .font(.largeTitle)
                                .id(secondaryMeta.id)
                            Text(secondaryMeta.title).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    if let accentMeta = allDataKeys.first(keypath: \ExperienceData.brandColorAccent) {
                        VStack(){
                            ColorPicker(accentMeta.description.capitalized, selection: $data.brandColorAccent)
                                .labelsHidden()
                                .font(.largeTitle)
                                .id(accentMeta.id)
                            Text(accentMeta.title).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding()
            }
            
            Section(header: Text("Brand Images")) {
                
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
            
            Section(header: Text("Social")) {
                if let instaMeta = allDataKeys.first(keypath: \ExperienceData.socialInstagramUsername) {
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
                                    .foregroundColor(.tertiaryLabel)
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
            }
            
//            Section(footer: Text("Note: Enabling logging may slow down the app")) {
//                //                Picker("Select a color", selection: $selectedColor) {
//                //                    ForEach(colors, id: \.self) {
//                //                        Text($0)
//                //                    }
//                //                }
//                //                .pickerStyle(SegmentedPickerStyle())
//                //
//                //                Toggle("Enable Logging", isOn: $enableLogging)
//            }
            
            let onTap: () -> Void = {
                print("hit continue!")
                
                guard data.isValid(for: experienceType.allDataKeys) else {
                    return
                }
                
                self.completionCallback(data)
            }
            
            Section(footer: Spacer().padding(.bottom, max(safeAreaInsets.bottom, 100) * 4)) {
                HStack(){
                    Spacer()
                    Button(){
                        onTap()
                    } label: {
                        // activate theme!
                        Label("Save & Continue", systemImage: "arrow.forward").padding()
                    }
                    .disabled(!data.isValid(for: experienceType.allDataKeys))
                    Spacer()
                }
            }
            .onTapGesture(perform: onTap)
        }
        .background(Color.pink)
        .gesture(
            TapGesture()
                .onEnded() { value in
                    print("tapped!")
                    guard appCoordinator.keyboardHeight > 0 else {
                        return
                    }

                    appCoordinator.dismissKeyboard()
                }, including: .subviews)
    }
    
}

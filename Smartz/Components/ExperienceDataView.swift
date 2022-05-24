//
//  ExperienceDataView.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import JoliCore

public func createImageCb(_ setter: @escaping (URL) -> Void) -> (UIImage?, String?, Error?) -> Void {
    return { (img: UIImage?, imgName: String?, error: Error?) in
        
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first, let img = img else {
            return
        }
        
        let ext = URL(fileURLWithPath: imgName ?? "image.jpg").pathExtension.lowercased()
        let cacheFilename = "\(UUID().uuidString).\(ext)"
        let cacheUrl = cachesDirectory.appendingPathComponent(cacheFilename)
        
        Task(){
            let data = ext == "png" ? img.pngData() : (await ImageCompressor.compress(image: img, maxByte: 1_000_000)?.jpegData(compressionQuality: 1.0))
            
            guard let imgageData = data, error == nil else {
                return
            }
            
            try? imgageData.write(to: cacheUrl)
            
            print("Wrote image to caches dir: \(cacheUrl) [isLocal=\(cacheUrl.isFileURL)]")
            
            DispatchQueue.main.async {
                setter(cacheUrl)
            }
        }
    }
}

public struct ExperienceDataView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @StateObject var data: ExperienceData
    @State var isUploadingImage = false
    
    @State var socialInstagramUsername: String = .empty
    @State var productDescription: MultilineString = .empty
    @State var bannerVideoUrl: String = .empty
    
    @State var fieldSizeIg: CGSize = .zero
    @State var fieldSizeYt: CGSize = .zero
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    let experienceType: Experience.Type?
    let completionCallback: (ExperienceData) -> Void
    
    init(_ data: ExperienceData, callback: @escaping (ExperienceData) -> Void) {
        self._data = StateObject(wrappedValue: data)
        self.experienceType = Experiences.fromTypeName(data.experienceTypeName)?.rawValue
        self.completionCallback = callback
        self._socialInstagramUsername = State(initialValue: data.socialInstagramUsername ?? .empty)
        self._productDescription = State(initialValue: data.productDescription ?? .empty)
        self._bannerVideoUrl = State(initialValue: data.bannerVideoUrl?.absoluteString ?? .empty)
    }
    
    public var allDataKeys: [ExperienceDataKeyPath.Metadata] {
        return experienceType?.allDataKeys.compactMap() { $0.meta } ?? []
    }
    
    func imagePickerFrom(meta: ExperienceDataKeyPath.Metadata) -> some View {
        
        let imageCallback = createImageCb() { url in
            guard let keyPath = meta.keypath as? ReferenceWritableKeyPath<ExperienceData, URL?> else { return }
            self.data[keyPath: keyPath] = url
        }
        
        return HStack(){
            VStack(alignment: .leading){
                Text(meta.title).font(.headline)
                Text(meta.description).font(.subheadline).multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            ImageView(url: data[keyPath: meta.keypath] as? URL, isCircular: false, onSelected: imageCallback) { (image, imgName, error) in
                
            } content: {
                Color.clear
            }
            .frame(width: screenWidth / 3, height: screenWidth / 3)
            .overlay(
                Group() {
                    if isUploadingImage {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .foregroundColor(.primary)
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .id(meta.name)
    }
    
    public func itemTypeSectionItemViewNew(_ element: ExperienceData.Item, index: Int) -> some View {
        NavigationLink() {
            ExperienceDataItemView(item: element, index: index, data: data)
                .navigationTitle("Edit \(element.experienceItemType.label)")
        } label: {
            ExperienceDataItemSummaryView(item: element, index: index)
                .id("\(String(describing: element.title))-\(String(describing: element.subtitle))-\(element.uuid)")
        }
    }
    
    public func itemTypeSectionView(_ expItemType: ExperienceItemType) -> some View {
        
        let header = HStack(){
            Text(expItemType.label)
            Spacer()
            
        }
        
        let filteredItems = Array(data.items.filter({ $0.experienceItemType == expItemType }))
        let items = filteredItems.sorted(by: { ($0.itemNo ?? filteredItems.count) < ($1.itemNo ?? filteredItems.count) })
        
        return Section(header: header) {
            
            List(Array(items.enumerated()), id: \.element.id){ itm in
                self.itemTypeSectionItemViewNew(itm.element, index: itm.offset)
                    .id("\(itm.element.id)-\(itm.offset)")
            }
            
            Button(){
                let itm: ExperienceData.Item = ExperienceData.Item(experienceItemType: expItemType, itemNo: self.data.items.count, identifier: nil)
                print("Adding Item...\(itm.uuid)")
                self.data.items.append(itm)
            } label: {
                HStack(){
                    Spacer()
                    Label("Add \(expItemType.label.capitalized)", systemImage: "plus")
                    Spacer()
                }
            }
        }
    }
    
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
                            ColorPicker(primaryMeta.description.capitalized, selection: $data.brandColorPrimary)
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
                
                if let prodctMeta = allDataKeys.first(keypath: \ExperienceData.productImageUrl) {
                    self.imagePickerFrom(meta: prodctMeta)
                }
                
            }
            
            if let bannerVideoMeta = allDataKeys.first(keypath: \ExperienceData.bannerVideoUrl) {
                Section(header: Text("Banner Video")) {
                    TextField(bannerVideoMeta.description, text: $bannerVideoUrl, onEditingChanged: {_ in }) {
                        print("[YT Bannervideo] commited")
                    }
                    .padding(.leading, fieldSizeYt.height * 1.5)
                    .onChange(of: bannerVideoUrl) { urlStr in
                        let ytUrl = bannerVideoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        guard let url = URL(string: ytUrl), !ytUrl.isEmpty else { return }
                        
                        data.bannerVideoUrl = url
                    }
                    .overlay(
                        GeometryReader(){ proxy in
                            HStack(){
                                Image("logo_icon_youtube")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: proxy.size.height, height: proxy.size.height)
                                Spacer()
                            }
                            .frame(height: proxy.size.height)
                            .onAppear(){
                                self.fieldSizeYt = proxy.size
                            }
                        }
                    )
                }
            }
            
            if let productMeta = allDataKeys.first(keypath: \ExperienceData.productDescription) {
                Section(header: Text(productMeta.title)) {
                    TextEditor(text: $productDescription)
                        .frame(height: screenWidth / 2.5)
                        .onChange(of: productDescription) { descr in
                            let description = descr.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            guard !description.isEmpty else { return }
                            
                            data.productDescription = description
                        }
                 
                }
            }
            
            Section(header: Text("Social")) {
                if let instaMeta = allDataKeys.first(keypath: \ExperienceData.socialInstagramUsername) {
                    TextField(instaMeta.description, text: $socialInstagramUsername, onEditingChanged: {_ in }) {
                        print("[Insta username] commited")
                    }
                    .padding(.leading, fieldSizeIg.height * 2.5)
                    .onChange(of: socialInstagramUsername) { urlStr in
                        let insta = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        guard !insta.isEmpty else { return }
                        
                        data.socialInstagramUsername = insta
                    }
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
                            .onAppear(){
                                self.fieldSizeIg = proxy.size
                            }
                        }
                    )
                }
            }
            
            let items = Array(experienceType?.supportedItemTypes ?? []).sorted(by: { $0.rawValue < $1.rawValue }).filter({ $0 != ExperienceItemType.menuFoodNutrition })
            ForEach(items) { expItemType in
                self.itemTypeSectionView(expItemType)
            }
            .animation(.easeInOut)
            
            let isNew = data.isNew
            
            let onTap: () -> Void = {
                print("hit continue!")
                
                guard (isNew && data.isValid(for: experienceType?.allDataKeys ?? [])) || !isNew else {
                    return
                }
                
                self.completionCallback(data)
            }
            
            let paddedFooter = Spacer().if(data.isNew) { spacer in
                spacer.padding(.bottom, max(safeAreaInsets.bottom, 100) * 2)
            }
            
            Section(footer: paddedFooter) {
                HStack(){
                    Spacer()
                    Button(){
                        onTap()
                    } label: {
                        // activate theme!
                        Label(isNew ? "Save & Continue" : "Save Changes", systemImage: "arrow.forward").padding()
                    }
                    .disabled(isNew && !data.isValid(for: experienceType?.allDataKeys ?? []))
                    Spacer()
                }
            }
            .onTapGesture(perform: onTap)
            
            if !data.isNew {
                Section(footer: Spacer().padding(.bottom, max(safeAreaInsets.bottom, 100) * 2)){
                    HStack(){
                        Spacer()
                        self.deleteButton(data)
                        Spacer()
                    }
                }
            }
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
    
    func deleteButton(_ data: ExperienceData) -> some View {
        
        let deleteExperience = {
            
            appCoordinator.withAlert("Delete Experience?", message: "Confirm delete of \"\(data.brandName)\" experience", destructive: true, dismissLabel: "Cancel", label: "Delete") {
                print("[ExperienceDataView] delete: \(String(describing: data.uuid))")
                
                Task(){
                    let deleted = try await data.delete(hard: false, baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
                    print("[ExperienceDataView#deleteButton] deleted=\(deleted)")
                    data.stored = deleted
                    
                    self.completionCallback(data)
                }
            }
        }
        
        let label = Label("Delete", systemImage: "trash").foregroundColor(.red)
        
        return Group(){
            if #available(iOS 15.0, *) {
                Button(role: .destructive, action: deleteExperience) {
                    label
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
            } else {
                Button(action: deleteExperience) { label }
                .foregroundColor(.red)
            }
        }
    }
    
}

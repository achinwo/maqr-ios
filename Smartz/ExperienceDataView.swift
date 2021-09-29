//
//  ExperienceDataView.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import CoreML
import JoliCore

// Don't forget to add to the project:
// 1. DeepLabV3 - https://developer.apple.com/machine-learning/models/
// 2. CoreMLHelpers - https://github.com/hollance/CoreMLHelpers

enum RemoveBackroundResult {
    case background
    case finalImage
}

extension UIImage {
    
    func removeBackground(returnResult: RemoveBackroundResult) -> UIImage? {
        guard let model = getDeepLabV3Model() else { return nil }
        let width: CGFloat = 513
        let height: CGFloat = 513
        let resizedImage = resized(to: CGSize(width: height, height: height), scale: 1)
        guard let pixelBuffer = resizedImage.pixelBuffer(width: Int(width), height: Int(height)),
              let outputPredictionImage = try? model.prediction(image: pixelBuffer),
              let outputImage = outputPredictionImage.semanticPredictions.image(min: 0, max: 1, axes: (0, 0, 1)),
              let outputCIImage = CIImage(image: outputImage),
              let maskImage = outputCIImage.removeWhitePixels(),
              let maskBlurImage = maskImage.applyBlurEffect() else { return nil }
        
        switch returnResult {
            case .finalImage:
                guard let resizedCIImage = CIImage(image: resizedImage),
                      let compositedImage = resizedCIImage.composite(with: maskBlurImage) else { return nil }
                let finalImage = UIImage(ciImage: compositedImage)
                    .resized(to: CGSize(width: size.width, height: size.height))
                return finalImage
            case .background:
                let finalImage = UIImage(
                    ciImage: maskBlurImage,
                    scale: scale,
                    orientation: self.imageOrientation
                ).resized(to: CGSize(width: size.width, height: size.height))
                return finalImage
        }
    }
    
    private func getDeepLabV3Model() -> DeepLabV3? {
        do {
            let config = MLModelConfiguration()
            return try DeepLabV3(configuration: config)
        } catch {
            print("Error loading model: \(error)")
            return nil
        }
    }
    
}

extension CIImage {
    
    func removeWhitePixels() -> CIImage? {
        let chromaCIFilter = chromaKeyFilter()
        chromaCIFilter?.setValue(self, forKey: kCIInputImageKey)
        return chromaCIFilter?.outputImage
    }
    
    func composite(with mask: CIImage) -> CIImage? {
        return CIFilter(
            name: "CISourceOutCompositing",
            parameters: [
                kCIInputImageKey: self,
                kCIInputBackgroundImageKey: mask
            ]
        )?.outputImage
    }
    
    func applyBlurEffect() -> CIImage? {
        let context = CIContext(options: nil)
        let clampFilter = CIFilter(name: "CIAffineClamp")!
        clampFilter.setDefaults()
        clampFilter.setValue(self, forKey: kCIInputImageKey)
        
        guard let currentFilter = CIFilter(name: "CIGaussianBlur") else { return nil }
        currentFilter.setValue(clampFilter.outputImage, forKey: kCIInputImageKey)
        currentFilter.setValue(2, forKey: "inputRadius")
        guard let output = currentFilter.outputImage,
              let cgimg = context.createCGImage(output, from: extent) else { return nil }
        
        return CIImage(cgImage: cgimg)
    }
    
    // modified from https://developer.apple.com/documentation/coreimage/applying_a_chroma_key_effect
    private func chromaKeyFilter() -> CIFilter? {
        let size = 64
        var cubeRGB = [Float]()
        
        for z in 0 ..< size {
            let blue = CGFloat(z) / CGFloat(size - 1)
            for y in 0 ..< size {
                let green = CGFloat(y) / CGFloat(size - 1)
                for x in 0 ..< size {
                    let red = CGFloat(x) / CGFloat(size - 1)
                    let brightness = getBrightness(red: red, green: green, blue: blue)
                    let alpha: CGFloat = brightness == 1 ? 0 : 1
                    cubeRGB.append(Float(red * alpha))
                    cubeRGB.append(Float(green * alpha))
                    cubeRGB.append(Float(blue * alpha))
                    cubeRGB.append(Float(alpha))
                }
            }
        }
                
        var data = Data()
        cubeRGB.withUnsafeBufferPointer() { ptr in
            data = Data(buffer: ptr)
        }
        
        let colorCubeFilter = CIFilter(
            name: "CIColorCube",
            parameters: [
                "inputCubeDimension": size,
                "inputCubeData": data
            ]
        )
        return colorCubeFilter
    }
    
    // modified from https://developer.apple.com/documentation/coreimage/applying_a_chroma_key_effect
    private func getBrightness(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        let color = UIColor(red: red, green: green, blue: blue, alpha: 1)
        var brightness: CGFloat = 0
        color.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        return brightness
    }
    
}

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
        self._bannerVideoUrl = State(initialValue: data.bannerVideoUrl?.absoluteString ?? .empty)
    }
    
    public var allDataKeys: [ExperienceDataKeyPath.Metadata] {
        return experienceType.allDataKeys.compactMap() { $0.meta }
    }
    
    public func createImageCb(_ setter: @escaping (URL) -> Void) -> (UIImage?, String?, Error?) -> Void {
        return { (img: UIImage?, imgName: String?, error: Error?) in
            
            guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return
            }
            
            let ext = URL(fileURLWithPath: imgName ?? "image.jpg").pathExtension.lowercased()
            let cacheFilename = "\(UUID().uuidString).\(ext)"
            let cacheUrl = cachesDirectory.appendingPathComponent(cacheFilename)
            
            let data = ext == "png" ? img?.pngData() : img?.jpegData(compressionQuality: 0.8)
            
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
    
    func imagePickerFrom(meta: ExperienceDataKeyPath.Metadata) -> some View {
        
        let imageCallback = self.createImageCb() { url in
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
    @State var bannerVideoUrl: String = .empty
    
    @State var fieldSizeIg: CGSize = .zero
    @State var fieldSizeYt: CGSize = .zero
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    public func itemTypeSectionItemView(_ element: ExperienceData.Item, index: Int) -> some View {
        
        let setter = { (newValue: String, keyPath: WritableKeyPath<ExperienceData.Item, String?>) in
            var element = element
            element[keyPath: keyPath] = newValue
            data.items = data.items.filter({ $0.id != element.id }) + [element]
        }
        
        let makeBinding = { (item: ExperienceData.Item, keyPath: WritableKeyPath<ExperienceData.Item, String?>) -> Binding<String> in
            return Binding<String>(){
                return element[keyPath: keyPath] ?? .empty
            } set: { newValue in
                setter(newValue, keyPath)
            }
        }
        
        let onSelected = self.createImageCb() { url in
            setter(url.absoluteString, \ExperienceData.Item.imageName)
        }
        
        return HStack(){
            
            if element.experienceItemType.isNumbered {
                VStack(alignment: .leading){
                    Text("\(index + 1).")
                        .font(.headline.weight(.light))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ImageView(urlString: element.imageName, isCircular: false, onSelected: onSelected) { (image, imgName, error) in
                    
                } content: {
                    EmptyView()
                }
                .frame(width: screenWidth / 5, height: screenWidth / 5)
            }
            
            VStack(alignment: .leading){
                TextField("Title", text: makeBinding(element, \.title))
                TextField("Subtitle", text: makeBinding(element, \.subtitle))
                Spacer()
            }
        }
        .overlay(HStack(){
            Spacer()
            Button(){
                self.appCoordinator.withAlert("Remove \(element.experienceItemType.label) Item?", message: "Permanent delete this item", destructive: true, label: "Remove") {
                    self.data.items = self.data.items.filter() { $0.id != element.id }
                }
            } label: {
                Image(systemName: "minus")
            }
            .frame(width: 24, height: 24)
            .backgroundColor(.red.opacity(0.7))
            .foregroundColor(.fixedWhite)
            .font(.body.weight(.bold))
            .clipShape(Circle())
        })
        .id(element.id)
    }
    
    public func itemTypeSectionView(_ expItemType: ExperienceItemType) -> some View {
        
        let header = HStack(){
            Text(expItemType.label)
            Spacer()
            
        }
        
        let items = Array(data.items.filter({ $0.experienceItemType == expItemType }))
        
        return Section(header: header) {
            
            ForEach(Array(items.sorted().enumerated()), id: \.element.id){ itm in
                self.itemTypeSectionItemView(itm.element, index: itm.offset)
            }
            
            Button(){
                print("Adding Item...")
                let itm: ExperienceData.Item = ExperienceData.Item(experienceItemType: expItemType, identifier: nil)
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
            
            let items = Array(experienceType.supportedItemTypes).sorted(by: { $0.rawValue < $1.rawValue }).filter({ $0 != ExperienceItemType.menuFoodNutrition })
            ForEach(items) { expItemType in
                self.itemTypeSectionView(expItemType)
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
//        .overlay(
//            VStack(){
//                Spacer()
//                if let img = image {
//                    Image(platformImage: img)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: screenWidth - 100, height: screenWidth - 100, alignment: .center)
//                }
//                Spacer()
//            }
//        )
    }
    
}

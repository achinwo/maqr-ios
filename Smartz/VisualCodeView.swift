//
//  VisualCodeView.swift
//  Joli
//
//  Created by Anthony Chinwo on 07/08/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import Combine
import JoliCore

public struct AppClipCodeStyle: Identifiable {
    public let index: Int
    public let foregroundColor: Color
    public let backgroundColor: Color
    
    public var id: Int {
        return index
    }
}

public let appClipsTypes: [AppClipCodeStyle] = [
    AppClipCodeStyle(index: 0, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "000000")),
    AppClipCodeStyle(index: 2, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "777777")),
    AppClipCodeStyle(index: 4, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "FF3B30")),
    AppClipCodeStyle(index: 6, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "EE7733")),
    AppClipCodeStyle(index: 8, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "33AA22")),
    AppClipCodeStyle(index: 10, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "00A6A1")),
    AppClipCodeStyle(index: 12, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "007AFF")),
    AppClipCodeStyle(index: 14, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "5856D6")),
    AppClipCodeStyle(index: 16, foregroundColor: .init(hex: "FFFFFF"), backgroundColor: .init(hex: "CC73E1")),
]

public struct DualColorTokenView: JoliView {
    
    @State var primaryColor: Color
    @State var secondaryColor: Color
    @State var width: CGFloat? = nil
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public var contentView: some View {
        let size = CGFloat(width ?? screenWidth / 6)
        return Circle()
            .foregroundColor(primaryColor)
            .overlay(
                GeometryReader() { proxy in
                    Rectangle()
                        .foregroundColor(secondaryColor)
                        .offset(x: proxy.size.width / 2, y: proxy.size.height / 3.2)
                        .rotationEffect(.degrees(-45), anchor: .bottomTrailing)
                }
            )
            .frame(width: size, height: size)
            .clipShape(Circle())
        
    }
    
}

public struct VisualCodeView: JoliView {
    
    public class AppClipCodeModel: ObservableObject {
        
        public enum Logo: String {
            case none
            case badge
        }
        
        public enum CodeType: Int, Identifiable, CaseIterable {
            case cam
            case nfc
            
            public var id: Int {
                rawValue
            }
            
            var label: String {
                switch self {
                    case .cam:
                        return "cam"
                    case .nfc:
                        return "nfc"
                }
            }
            
            var title: String {
                switch self {
                    case .cam:
                        return "Camera"
                    case .nfc:
                        return "NFC"
                }
            }
        }
        
        @Published public var urlPath = URLComponents(string: "/images/preview_appclip_12_cam_badge.svg?format=png")
        
        @Published public var codeType = CodeType.cam {
            didSet {
                self.updateUrl()
            }
        }
        
        @Published public var logo = Logo.badge {
            didSet {
                self.updateUrl()
            }
        }
        
        @Published public var lastUpdatedAt = Date()
        
        public var index: Int = 12 {
            didSet {
                self.updateUrl()
            }
        }
        
        private func updateUrl(){
            let fileName = "images/preview_appclip_\(index)_\(codeType.label)_\(logo.rawValue).svg?format=png"
            //let urlString = URL(string: "https://storage.googleapis.com/joli-app-bucket/images/preview_appclip_\(index)_\(logo.rawValue)_\(codeType.label).svg")
            //let newComp = URLComponents(string: "https://192.168.1.233:8080/\(fileName)") //templates/\(index).png?url=\(urlString)&logo=\(logo.rawValue)&type=\(codeType.label)")
            
            //guard let newUrl = newComp?.url else { return }
            
            self.urlPath = URLComponents(string: fileName)
            //print("NEW URL: \(self.requestUrl)")
            self.lastUpdatedAt = Date()
        }
        
        lazy var allCodeStyles: [AppClipCodeStyle] = {
            var appClipsStyles: [AppClipCodeStyle] = []
            
            for item in appClipsTypes {
                let inv = AppClipCodeStyle(index: item.index + 1, foregroundColor: item.backgroundColor, backgroundColor: item.foregroundColor)
                appClipsStyles.append(contentsOf: [item, inv])
            }
            
            return appClipsStyles
        }()
        
        var visualCode: VisualCodeRecord? {
            
            guard let style = allCodeStyles.first(where: { $0.index == index }) else { return nil }
            
            var code = VisualCodeRecord()
            code.backgroundColor = style.backgroundColor.hexString
            code.foregroundColor = style.foregroundColor.hexString
            code.index = style.index
            code.interactionType = codeType.label
            code.logo = logo.rawValue
            
            return code
        }
        
    }
    
    @Binding var code: VisualCodeRecord
    @Binding var submitEnabled: Bool
    let onSubmit: (VisualCodeRecord) -> Void
    
    
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @Environment(\.colorScheme) var colorScheme
    @State var showBadge = true
    @State var readyToDownload = true
    
    @State var selectedThemeIndex = 12
    @State var invertThemeColor = false
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    public var contentView: some View {
        let size = screenWidth / 8
        return ZStack(){
            Form(){
                
                Section(header: Spacer().padding(.top, screenWidth * 0.7 + 16)){
                    Picker("Interaction Type", selection: $appClipCodeType) {
                        ForEach(AppClipCodeModel.CodeType.allCases) { codeType in
                            Text(codeType.title)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    Toggle("Show Badge", isOn: $showBadge).padding()
                    
                }
                
                Section(header: Text("Color Themes")){
                    VStack(){
                        ForEach([0, 3, 6], id: \.self){ row in
                            HStack(){
                                Spacer()
                                ForEach(row..<(row + 3), id: \.self) { colIdx in
                                    let appclipStyle = appClipsStyles[colIdx]
                                    
                                    DualColorTokenView(primaryColor: appclipStyle.foregroundColor, secondaryColor: appclipStyle.backgroundColor, width: size)
                                        .onTapGesture() {
                                            self.selectedThemeIndex = appclipStyle.index
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(selectedThemeIndex == appclipStyle.index ? Color.primary : Color.tertiaryLabel.opacity(0.7),
                                                        lineWidth: selectedThemeIndex == appclipStyle.index ? 2 : 1)
                                                .frame(width: size + 2.6, height: size + 2.6)
                                        )
                                        .animation(.easeInOut)
                                        .id(appclipStyle.index)
                                    Spacer()
                                }
                            }
                        }
                        Divider().padding(.vertical)
                        Toggle("Inverted Colors", isOn: $invertThemeColor)//.padding(.horizontal)
                        
                    }
                    .padding()
                }
                
                Section(footer: Spacer().padding(.bottom, safeAreaInsets.bottom * 6)){
                    HStack(){
                        Spacer()
                        Button(){
                            //self.readyToDownload = true
                            //self.trialActivateCallback()
                            
                            guard let vizCode = model.visualCode, submitEnabled else { return }
                            
                            self.code = vizCode
                            onSubmit(self.code)
                        } label: {
                            Label("Submit", systemImage: "arrow.up")
                                .font(.headline)
                        }
                        .disabled(!submitEnabled)
                        .padding()
                        //.padding(.top)
                        Spacer()
                    }
                }
            }
            
            
            VStack(spacing: .zero){
                VStack(spacing: .zero){
                    ZStack(){
                        NetworkImage(url: model.urlPath?.url(relativeTo: api.baseUrlHttp)){ img, error in
                            self.initialImageLoaded = img != nil
                        } content: {
                            Group(){
                                if initialImageLoaded {
                                    VStack(){
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                        Text("Refreshing...")
                                            .font(.headline.weight(.light))
                                            .foregroundColor(.secondary)
                                            .padding()
                                    }
                                } else {
                                    Image(platformImage: Self.SAMPLE_APPCLIP)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                }
                            }
                        }
                        .id(model.urlPath)
                        .aspectRatio(contentMode: .fit)
                    }
                    .frame(width: screenWidth / 2)
                    .frame(minHeight: screenWidth * 0.5)
                    .overlay(
                        GeometryReader() { proxy in
                            Text("Preview")
                                .fixedSize(horizontal: true, vertical: true)
                                .frame(width: proxy.size.width * 1.1, alignment: .center)
                                .font(.title.weight(.light))
                                .foregroundColor(.fixedWhite)
                                .padding()
                                .background(Color.fixedGray.opacity(0.98))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .offset(x: proxy.size.width / 2 * -1, y: proxy.size.height / 4)
                                .rotationEffect(.degrees(-45), anchor: .leading)
                        }
                    )
                    .animation(.easeInOut)
                    .clipped()
                }
                .frame(width: screenWidth, height: screenWidth * 0.7)
                .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                Divider()
                Spacer()
            }
        }
        .onChange(of: selectedThemeIndex) { idx in
            self.model.index = idx
        }
        .onChange(of: showBadge) { badge in
            self.model.logo = badge ? .badge : .none
        }
        .onChange(of: appClipCodeType) { codeTypeIdx in
            guard let codeType = AppClipCodeModel.CodeType.init(rawValue: codeTypeIdx) else { return }
            
            self.model.codeType = codeType
        }
        .onReceive(model.$lastUpdatedAt){ _ in
            self.code = model.visualCode ?? code
            print("[\(Self.self)] Code updated!!")
        }
        .onAppear(){
            //updateSubscriptions()
            self.code = model.visualCode ?? code
        }
    }
    
    
    @StateObject var model = AppClipCodeModel()
    
    @State var appClipCode: UIImage = UIImage(named: "appclipcode_with_logo")!
    
    @State var appClipCodeType: Int = AppClipCodeModel.CodeType.cam.rawValue
    
    @State var codeFetchCancel: AnyCancellable? = nil
    
    @State var initialImageLoaded = false
    
    
    static let SAMPLE_APPCLIP = UIImage(named: "appclipcode_with_logo")!
    
    private func updateSubscriptions() {
        if let cancel = self.codeFetchCancel {
            cancel.cancel()
            print("[\(Self.self)] cancelled: \(cancel)")
        }
        
        self.codeFetchCancel = model.$urlPath
            .removeDuplicates()
            .debounce(for: 0.3, scheduler: DispatchQueue.global(qos: .userInteractive))
            .map() { urlPath -> AnyPublisher<UIImage, Never> in
                print("fetching code for: \(String(describing: urlPath))")
                
                return Future<UIImage, Never>() { promise in
                    
                    guard let urlString = urlPath?.string, let url = URL(string: urlString, relativeTo: api.baseUrlHttp) else {
                        print("X fetching code for: \(self.api.baseUrlHttp)")
                        promise(.success(Self.SAMPLE_APPCLIP))
                        return
                    }
                    
                    print("2. fetching code for: \(url)")
                    
                    let task = self.api.urlSession.dataTask(with: url) { data, response, error in
                        if let error = error {
                            print("Error fetching: \(error)")
                            promise(.success(Self.SAMPLE_APPCLIP))
                            return
                        }
                        
                        guard let httpResponse = response as? HTTPURLResponse,
                              (200...299).contains(httpResponse.statusCode) else {
                            print("Error fetching: bad response code \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                            promise(.success(Self.SAMPLE_APPCLIP))
                            return
                        }
                        
                        guard let data = data, let realImage = UIImage(data: data) else {
                            
                            print("Error fetching: unable to convert data")
                            promise(.success(Self.SAMPLE_APPCLIP))
                            return
                        }
                        
                        promise(.success(realImage))
                    }
                    task.resume()
                }
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: RunLoop.main)
            .assign(to: \.appClipCode, on: self)
    }
    
    var appClipsStyles: [AppClipCodeStyle] {
        if invertThemeColor {
            return appClipsTypes.map() { item in
                AppClipCodeStyle(index: item.index + 1, foregroundColor: item.backgroundColor, backgroundColor: item.foregroundColor)
            }
        } else {
            return appClipsTypes
        }
    }
    
}

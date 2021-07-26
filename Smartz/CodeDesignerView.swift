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

public struct AppClipCodeStyle: Identifiable {
    public let index: Int
    public let foregroundColor: Color
    public let backgroundColor: Color
    
    public var id: Int {
        return index
    }
}

public extension Color {
    
    init(hex: String){
        self.init(UIColor.init(hex: hex))
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
    
    @State var selectedThemeIndex = 12
    @State var invertThemeColor = false
    
    var appClipsStyles: [AppClipCodeStyle] {
        if invertThemeColor {
            return appClipsTypes.map() { item in
                AppClipCodeStyle(index: item.index + 1, foregroundColor: item.backgroundColor, backgroundColor: item.foregroundColor)
            }
        } else {
            return appClipsTypes
        }
    }
    
    @State var codeFetchCancel: AnyCancellable? = nil
    
    class AppClipCodeModel: ObservableObject {
        
        public enum Logo: String {
            case none
            case badge
        }
        
        public enum CodeType: String {
            case cam
            case nfc
        }
        
        @Published public var requestUrl = URL(string: "/templates/", relativeTo: URL(string: "https://192.168.1.233:8084"))!
        
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
        
        public var index: Int = 12 {
            didSet {
                self.updateUrl()
            }
        }
        
        private func updateUrl(){
            let urlString = "https://smartstikr.com/s/shows/iacw"
            let newComp = URLComponents(string: "https://192.168.1.233:8084/templates/\(index).png?url=\(urlString)&logo=\(logo.rawValue)&type=\(codeType.rawValue)")
            
            guard let newUrl = newComp?.url else { return }
            
            self.requestUrl = newUrl
            print("NEW URL: \(self.requestUrl)")
        }
    }
    
    @StateObject var model = AppClipCodeModel()
    @State var appClipCode: UIImage = UIImage(named: "appclipcode_with_logo")!
    
    private func updateSubscriptions() {
        if let cancel = self.codeFetchCancel {
            cancel.cancel()
            print("[\(Self.self)] cancelled: \(cancel)")
        }
        
        self.codeFetchCancel = model.$requestUrl
            .removeDuplicates()
            .debounce(for: 0.3, scheduler: DispatchQueue.global(qos: .userInteractive))
            .map() { url -> AnyPublisher<UIImage, Never> in
                print("fetching code for: \(url)")
                let img = UIImage(named: "appclipcode_with_logo")!
                
                return Future<UIImage, Never>() { promise in
                    let task = self.api.urlSession.dataTask(with: url) { data, response, error in
                        if let error = error {
                            print("Error fetching: \(error)")
                            promise(.success(img))
                            return
                        }
                        
                        guard let httpResponse = response as? HTTPURLResponse,
                              (200...299).contains(httpResponse.statusCode) else {
                            print("Error fetching: bad response code \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                            promise(.success(img))
                            return
                        }
                        
                        guard let data = data, let realImage = UIImage(data: data) else {
                            
                            print("Error fetching: unable to convert data")
                            promise(.success(img))
                            return
                        }
                        
                        promise(.success(realImage))
                    }
                    task.resume()
                }
                .eraseToAnyPublisher()
                
//                guard let imageData = try? Data(contentsOf: url), let img = UIImage(data: imageData) else {
//                    print("Unable to fetch: \(url)")
//                    return Just(UIImage(named: "appclipcode_with_logo")!).eraseToAnyPublisher()
//                }
//
//                return Just(img).eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: RunLoop.main)
            .assign(to: \.appClipCode, on: self)
    }
    
    var customiseCodeView: some View {
        let size = screenWidth / 8
        return ZStack(){
            Form(){
                Section(header: Text("Color Themes").padding(.top, screenWidth * 0.7 + 16)){
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
                    Toggle("Show Badge", isOn: $showBadge).padding()
                }
            }
            
            
            VStack(spacing: .zero){
                VStack(spacing: .zero){
                    Image(platformImage: appClipCode)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: screenWidth / 2)
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
        .onAppear(){
            updateSubscriptions()
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    @State var showBadge = true
    
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
        
        guard let selectedExperience = selectedExperience else { return vs }
        
        vs.append((
            customiseExperienceView(selectedExperience)
                //.background(Color.green)
                .eraseToAnyView(), 1
        ))
        
        //if let expData = experienceData, expData.isValid(for: selectedExperience.allDataKeys) {
        vs.append((
            customiseCodeView
                //.background(Color.purple)
                .eraseToAnyView(), 2
        ))
        //}
        
        if let expData = experienceData, expData.isValid(for: selectedExperience.allDataKeys) {
            vs.append((
                confirmAndPayView
                    //.background(Color.purple)
                    .eraseToAnyView(), 3
            ))
        }
        
        //print("Views count: \(vs.count)")
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

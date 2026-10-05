//
//  SiseMealboxView.swift
//  Joli
//
//  Created by Anthony Chinwo on 06/06/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import Combine
import MaqrApi
import AlertToast

#if os(macOS)
import AppKit
#else
import SharedUI
import UIKit
#endif

struct SiseMealboxView: JoliContentView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    
    var websocket: Socket
    
    
    @State var toastInfo: (alert: AlertToast, onDismiss: (Bool) -> Void)? = nil
    
    @Binding var currentUser: User?
    @State var experienceData: ExperienceData?
    
    public init(_ experienceData: ExperienceData? = nil, currentUser: Binding<User?>, websocket: Socket){
        self._currentUser = currentUser
        self.websocket = websocket
        self._experienceData = State(initialValue: experienceData)
    }
    
    var contentView: some View {
        MealboxView(self.experienceData)
    }
    
}
    
public struct MealboxView: Experience, JoliView {
    
    public static var title: String = "Mealbox Prep"
    public static var subtitle: String = "Interactive meal preparation guides"
    public static var basePath = "ecook"
    public static var iconName: String = "fork.knife"
    
    @State public var dataModel: ExperienceData?
    
    public let dataModelDefault = ExperienceData.Defaults()
    
    @State public var editMode: EditingState
    
    public static var dataKeys: [PartialKeyPath<ExperienceData>] {
        return [
            \ExperienceData.bannerImageUrl,
            \ExperienceData.backgroundImageUrl,
            \ExperienceData.productName,
            \ExperienceData.brandContactEmail,
            \ExperienceData.socialInstagramUsername,
            \ExperienceData.productImageUrl,
            \ExperienceData.productDescription,
        ]
    }
    
    public static var supportedItemTypes: Set<ExperienceItemType> {
        return [.mealPrepStep, .mealPrepIngredient]
    }
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    @State var userRating: Int = .zero
    @AppStorage(key: AppStorageKey.expMealprepRating) var userRatingStored: Int = .zero
    
    public init(_ data: ExperienceData? = nil) {
        self._editMode = State(initialValue: .inactive)
        self.startDate = Date(timeIntervalSinceNow: 0)
        self._deliveryDate = State(initialValue: startDate)
        self._dataModel = State(initialValue: data)
        
        self._requestRatingAt = State(initialValue: steps.count > 4 ? Int(Double(steps.count) * 0.7) : nil)
        
//        #if DEBUG
//        self.userRatingStored = .zero
//        #endif
        
        print("User rating: \(self.userRatingStored)")
        self._userRating = State(initialValue: self.userRatingStored)
    }
    
    enum Tab: Int, Identifiable, CaseIterable {
        case information
        case steps
        //case gallery
        case help
        
        var id: Int {
            rawValue
        }
        
        var label: String {
            switch self {
//                case .gallery:
//                    return "Gallery"
                case .help:
                    return "Help"
                case .steps:
                    return "Steps"
                case .information:
                    return "Info"
            }
        }
        
        var color: Color {
            switch self {
//                case .gallery:
//                    return .orange
                case .help:
                    return Color.systemIndigo
                case .steps:
                    return .pink
                case .information:
                    return .green
            }
        }
        
        var emoji: (default: String, active: String) {
            switch self {
//                case .gallery:
//                    return (default: "photo.on.rectangle", active: "photo.on.rectangle.angled")
                case .help:
                    return (default: "questionmark.circle", active: "questionmark.circle.fill")
                case .steps:
                    return (default: "list.dash", active: "list.number")
                case .information:
                    return (default: "info", active: "info")
            }
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("active-tab-mealprep") var selectedTab = Tab.information
    
    
    
    var autoResetting = AutoResetSubject<Int?, Never, DispatchQueue>(nil, delay: 0.3, scheduler: DispatchQueue.main)
    
    @State var tappedStepId: Int? = nil
    @State var lastStepId: Int = -1
    
    
    @State var deliveryDate: Date
    let startDate: Date
    @State var completed = false
    @State var helpText: String = .empty
    
    var userRatingView: some View {
        
        VStack(){
            Text("How is our digital experience so far?")
                .font(.headline.weight(.light))
                .padding(.top)
            Divider()
                .padding(.horizontal)
            RatingView(rating: self.$userRating)
                .padding()
            
            if self.userRating > .zero {
                Button(){
                    self.userRatingStored = self.userRating
                    self.isRatingVisible = false
                    
                    guard let uuid = dataModel?.uuid, let deviceUid = resolveAppInfo().uuid else { return }
                    
                    Task() {
                        let userRating = try await api.submitRating(self.userRatingStored, tag: "\(Self.basePath)/\(uuid)", deviceUid: deviceUid)
                        
                        print("posted rating for: \(userRating)")
                    }
                } label: {
                    Text("Submit Feedback")
                }
                .padding(.bottom)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondarySystemBackground))
        .padding()
        
    }
    
    @State var requestRatingAt: Int?
    
    var helpView: some View {
        ScrollView(showsIndicators: false){
            VStack(){
                VStack(){
                    
                    
                    Section(header: Text("Get in Touch").font(.title)) {
                        Text("Our team of highly trained food technicians are here to help!")
                            .font(.subheadline.weight(.light))
                            .multilineTextAlignment(.center)
                            .lineLimit(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom)
                        TextEditor(text: self.$helpText)
                            .frame(height: screenWidth / 2)
                            .overlay(
                                VStack(alignment: .leading){
                                    if helpText.isEmpty {
                                        Text("Enter your message here").padding().foregroundColor(.tertiaryLabel)
                                        Spacer()
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                    }
                    .padding()
                    
                    Button(){
                        print("submitted help!")
                        let subject = "Sísè Food Help - \(AppCoordinator.version)"
                        self.appCoordinator.modal.presentMailComposer(.init(subject: subject, recipients: ["order@sisefood.com"], body: helpText))
                    } label: {
                        HStack(){
                            Spacer()
                            Text("Send Message")
                                .font(.title3)
                                .foregroundColor(.label)
                            Spacer()
                        }
                    }
                    .background(Color.systemIndigo)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    ))
                    .frame(width: screenWidth - 150, height: 60)
                    .accentColor(.white)
                    .buttonStyle(OutlineButton())
                    .padding()
                }
                .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.bottom)
                
                .overlay(
                    GeometryReader(){ _ in
                        VStack(){
                            NetworkImage(url: dataModel?.logoImageUrl ?? dataModelDefault.logoImageUrl) {
                                    ProgressView()
                                }
                                .frame(width: screenWidth / 6, height: screenWidth / 6)
                                .background(Color.white)
                                .clipShape(Circle())
                                .overlay(Circle()
                                            .stroke(Color.secondaryLabel, lineWidth: 1))
                                .offset(x: 0, y: (screenWidth / 24) * -1)
                                .shadow(radius: 1)
                            Spacer()
                        }
                    }
                )
                
                VStack(){
                    Spacer()
                    HStack(){
                        Text("Powered by").font(.caption).foregroundColor(.secondary).shadow(color: .white, radius: 0.2, x: 0.2, y: 0.2)
                        Image("smartz_logo")
                            .resizable()
                            .frame(width: 38, height: 38)
                        Text("Maqr").font(.subheadline.weight(.semibold))
                    }
                }
                .padding()
                Spacer()
            }
            .frame(width: screenWidth - 100)
            .padding(.vertical, max(40, safeAreaInsets.top) * 2)
        }
        .frame(width: screenWidth, height: screenHeight)
        .background(
            Group(){
                NetworkImage(url: dataModel?.backgroundImageUrl){
                    Image("bg_white") // colorScheme == .dark ? "bg_dark" : "bg_white"
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                }
            }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded() { value in
                    
                    guard appCoordinator.keyboardHeight > 0 else {
                        return
                    }
                    
                    appCoordinator.dismissKeyboard()
                }
        )
        
    }
    
    var steps: [ExperienceData.Item] {
        return (dataModel?.items ?? []).filter { $0.experienceItemType == .mealPrepStep }
    }
    
    var stepsView: some View {
        
        let ingredientsView = VStack(){
            
            let header = HStack(){
                Image(systemName: "list.bullet.rectangle")//.renderingMode(.original)
                Text("Ingredients")
                Spacer()
            }
            .font(.title2)
            .padding()
            
            Section(header: header){
                VStack(alignment: .leading){
                    ForEach((dataModel?.items ?? []).filter { $0.experienceItemType == .mealPrepIngredient }) { ing in

                        HStack(){
                            NetworkImage(string: ing.imageName){
                                ProgressView()
                            }
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                                //.resizable()
                            VStack(alignment: .leading){
                                Text(ing.title ?? "").font(.subheadline)
                                Text(ing.subtitle ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondaryLabel)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    //.fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        
        let shareView = VStack(){
            VStack(){
                Text("Would you mind doing us a favour?").font(.title2.weight(.light))
                Text("Post your fine dish, it only takes a tap")
                    .lineLimit(3)
                    .font(.body.weight(.light))
                    .foregroundColor(.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(){
                    Spacer()
                    
                    let instaUser = SocialLink.instagramUser(dataModel?.socialInstagramUsername ?? dataModelDefault.socialInstagramUsername)
                    let instaHashtag = SocialLink.instagramHashtag("https://www.instagram.com/explore/tags/madewithsise/")
                    
                    Link(destination: instaUser.url) {
                        VStack(){
                            Image("instagram_logo").resizable().frame(width: screenWidth / 6, height: screenWidth / 6)
                            Text("Tag us").font(.caption2.weight(.light)).foregroundColor(.secondaryLabel)
                            Text(instaUser.description).font(.body.weight(.semibold)).foregroundColor(.primary)
                        }
                    }
                    .padding()
                    //https://www.instagram.com/explore/tags/madewithsise/
                    
                    Link(destination: instaHashtag.url) {
                        VStack(){
                            Image("fbk_logo").resizable().frame(width: screenWidth / 6, height: screenWidth / 6)
                            Text("Share us").font(.caption2.weight(.light)).foregroundColor(.secondaryLabel)
                            Text(instaHashtag.description).font(.body.weight(.semibold)).foregroundColor(.primary)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .padding()
        }
        .id("share-section")
        
//        let reorderView = VStack(){
//            VStack(){
//                Text("Schedule a re-order?").font(.title2.weight(.light))
//                Text("Scheduling a re-delivery of Ofada sauce is effortless with Apple Pay")
//                    .lineLimit(3)
//                    .font(.body.weight(.light))
//                    .foregroundColor(.secondaryLabel)
//                    .padding()
//                    .multilineTextAlignment(.center)
//                    .fixedSize(horizontal: false, vertical: true)
//
//                VStack(){
//                    DatePicker("Pick an arrival date", selection: $deliveryDate, displayedComponents: [.date])
//                        .padding(.bottom)
//                        .padding(.bottom)
//
//                    if let deliveryDay = Calendar.current.dateComponents([.day], from: deliveryDate).day,
//                       let today = Calendar.current.dateComponents([.day], from: Date()).day, deliveryDay != today {
//                        VStack(){
//                            PaymentButton()
//                            Label("Apple Pay is coming soon!", systemImage: "creditcard.fill")
//                                .foregroundColor(.secondaryLabel)
//                                .font(.caption)
//                                .multilineTextAlignment(.center)
//                        }
//                    }
//                }
//                .padding()
//                .animation(.easeInOut)
//            }
//            .padding()
//        }
        
        return NavigationView(){
            ZStack(){
                
                if lastStepId >= 0 {
                    let currentValue = lastStepId + 1
                    let percentage = Double(currentValue) / Double(steps.count) * 100.0
                    
                    VStack(){
                        Group(){
                            ProgressView(value: percentage, total: 100) {
                                Group(){
                                    if percentage >= 100 {
                                        Text("All done, enjoy your meal! 🥘")
                                    } else {
                                        Text("\(lastStepId + 1)").font(.subheadline.weight(.semibold)) +
                                            Text(" of ") +
                                            Text("\(steps.count) ").font(.subheadline.weight(.semibold)) +
                                            Text("steps completed")
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 2)
                            }
                            .progressViewStyle(LinearProgressViewStyle())
                            .labelsHidden()
                            .accentColor(.green)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .animation(.easeInOut)
                            .padding(.top)
                        }
                        .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                        Spacer()
                    }
                    .zIndex(1000)
                    
                }
                
                ScrollViewReader() { proxy in
                    ScrollView(){
                        VStack(){
                            //Image("food_ofada").data(url: dataModel?.productImageUrl ?? URL(string: "https://picsum.photos/200")!)
                            NetworkImage(url: dataModel?.productImageUrl ?? dataModelDefault.productImageUrl){
                                    ProgressView()
                                }
                                //.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: screenWidth - 100, height: screenWidth - 100)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.top)
                            
                            Text(dataModel?.productDescription ??  dataModelDefault.productDescription) //.fontWeight(.semibold) )
                                .padding()
                                .padding(.horizontal)
                                .font(.body.weight(.light))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Divider().padding()
                            ingredientsView
                            Divider().padding()
                            
                            stepItemsView(proxy)
                            
                            Group(){
                                if completed {
    
                                    Divider().padding(.vertical)
                                    shareView
                                    
                                    //Divider().padding()
                                    //reorderView
                                }
                            }
                            .padding(.bottom, safeAreaInsets.bottom)
                            
                        }
                        .frame(maxWidth: screenWidth)
                        .padding(.bottom, max(100, safeAreaInsets.bottom))
                    }
                }
            }
            .navigationTitle("Preparing \(dataModel?.productName ?? dataModelDefault.productName)")
        }
        .frame(maxWidth: screenWidth)
        .onReceive(self.autoResetting) { value in
            self.tappedStepId = value
        }
#if !os(macOS)
        .navigationViewStyle(.stack)
#endif
    }
    
    func stepItemsView(_ proxy: ScrollViewProxy) -> some View {
        
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.allowedUnits = [.minute]
        
        return ForEach(Array(steps.enumerated()), id: \.element) { itm in
            let isChecked = self.lastStepId >= itm.offset
            
            let onCheck = {
                self.lastStepId = self.lastStepId == 0 && itm.offset == 0 ? -1 : itm.offset
                
                let feeback: FeedbackStyle = self.lastStepId == steps.count - 1 ? .heavy : .light
                
                withImpact(feeback, animated: .easeInOut){
                    self.autoResetting.send(itm.offset)
                    
                    if let reqIndex = self.requestRatingAt, reqIndex == itm.offset, self.lastStepId == reqIndex {
                        isRatingVisible = userRating == .zero
                    } else {
                        isRatingVisible = false
                    }
                    
                    guard self.lastStepId == steps.count - 1 else { return }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3){
                        withAnimation(){
                            self.completed = true
                            
                            guard selectedTab == .steps else { return }
                            
                            proxy.scrollTo("share-section", anchor: .center)
                        }
                    }
                    
                    self.presentToast("All done!", subTitle: "Enjoy your meal", type: .image("confetti", .clear), displayMode: .alert) { _ in }
                }
                
            }
            
            HStack(alignment: .top){
                VStack(){
                    Text(itm.offset.advanced(by: 1).description) + Text(".")
                    Spacer()
                }
                .foregroundColor(.tertiaryLabel)
                
                VStack(alignment: .leading){
                    
                    if let text = itm.element.title ?? itm.element.subtitle {
                        Text(text)
                            .fontWeight(itm.offset == self.lastStepId + 1 ? .semibold : nil)
                            .strikethrough(isChecked, color: .secondaryLabel)
                            .lineLimit(nil)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(isChecked ? .secondaryLabel : .primary)
                    }
                    
                    if let subtitle = itm.element.subtitle, itm.offset == self.lastStepId + 1 {
                        Text(subtitle)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .font(.caption)
                            .foregroundColor(.secondaryLabel)
                            .padding(.bottom, 1)
                    }
                    
                    HStack() {
                        
                        if itm.element.isOptional ?? false {
                            Label("Optional", systemImage: "info.circle")
                                .font(.footnote).foregroundColor(Color.systemIndigo.opacity(0.7))
                        }
                        
                        if let spicy = itm.element.spicy {
                            Text(spicy.emoji)
                                .font(.footnote)
                        }
                        
                        if let duration = itm.element.duration, let durationStr = formatter.string(from: Double(duration)) {
                            Label(durationStr, systemImage: "timer")
                                .font(.footnote)
                        }
                        
                        Spacer()
                        
                        if let caution = itm.element.caution {
                            Label(String(describing: caution), systemImage: "nosign")
                                .font(.footnote)
                                .foregroundColor(.yellow)
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                }
                
                Spacer()
                
                Button(action: onCheck) {
                    let active = self.tappedStepId == itm.offset
                    Image(systemName: isChecked ? "checkmark.circle" : "circle.dashed")
                        .foregroundColor(isChecked ? .green : Color.secondaryLabel)
                        .padding(.horizontal)
                        .font(.title.weight(.light))
                        .scaleEffect(x: active ? 1.5 : 1, y: active ? 1.5 : 1)
                        .animation(.easeInOut)
                }
                
            }
            .opacity(self.isRatingVisible ? 0.5 : 1.0)
            .padding([.bottom, .horizontal])
            .onTapGesture(perform: onCheck)
            
            if let reqIndex = self.requestRatingAt, reqIndex == itm.offset, self.lastStepId == reqIndex, isRatingVisible {
                self.userRatingView
                    .padding(.bottom)
            }
        }
    }
    
    struct RatingView: View {
        @Binding var rating: Int
        
        var label = ""
        var maximumRating = 5
        
        var offImage: Image?
        var onImage = Image(systemName: "star.fill")
        
        var offColor = Color.gray
        var onColor = Color.yellow
        
        var body: some View {
            HStack {
                if label.isEmpty == false {
                    Text(label)
                }
                
                ForEach(1..<maximumRating + 1, id: \.self) { number in
                    image(for: number)
                        .foregroundColor(number > rating ? offColor : onColor)
                        .onTapGesture {
                            rating = number
                        }
                }
            }
        }
        
        func image(for number: Int) -> Image {
            if number > rating {
                return offImage ?? onImage
            } else {
                return onImage
            }
        }
    }

    
    @State var isRatingVisible: Bool = false
    
    var galleryView: some View {
        
        let images: [String] = [
            "food_ofada",
            "food_ofada-2",
        ]
        
        return NavigationView(){
            ScrollView(){
                LazyVGrid(columns: [GridItem(), GridItem(), GridItem()]) {
                    ForEach(images, id: \.self) { name in
                        Image(name)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: screenWidth / 2, maxHeight: screenWidth / 2)
                            .id(name)
                    }
                    
                    
                    Button(){
                        print("post image")
                    } label: {
                        VStack(){
                            Image(systemName: "plus.viewfinder")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .font(.title.weight(.thin))
                                .frame(maxWidth: screenWidth / 2, maxHeight: screenWidth / 2)
                                .padding()
                                .id("add-new")
                            Text("Post a Photo").font(.subheadline)
                        }
                    }
                    
                }
                .padding()
            }
            .navigationTitle("🤳🏾 Sise Photo Gallery")
        }
    }
    
    var infoView: some View {
        ScrollViewReader() { proxy in
            ScrollView(){
                VStack(spacing: .zero){
                    NetworkImage(url: dataModel?.bannerImageUrl ?? dataModelDefault.bannerImageUrl){
                            ProgressView()
                        }
                        //.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: screenWidth)
                        .frame(maxHeight: screenWidth / 2)
                        .clipped()
                        .overlay(
                            GeometryReader(){ proxy in
                                LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.7), Color.clear]), startPoint: .top, endPoint: .bottom)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            }
                        )
                    
                    Divider()
                    
                    VStack() {
                        NetworkImage(url: dataModel?.logoImageUrl ?? dataModelDefault.logoImageUrl) {
                            ProgressView()
                        }
                        .frame(width: screenWidth / 2, height: screenWidth / 2)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle()
                                    .stroke(Color.secondaryLabel, lineWidth: 1))
                        .shadow(radius: 1)
                        .padding()
                        .id("brand")
                        
                        VStack(){
                            
                            Section(header: Text("HELLO & WELCOME").font(.title3)) {
                                Text(dataModel?.brandName ?? dataModelDefault.brandName).font(.subheadline.weight(.semibold))
                                Text(dataModel?.landingPageText ?? dataModelDefault.landingPageText)
                                    .font(.body.weight(.light))
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                        .frame(width: screenWidth - 100)
                        .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.bottom)
                        .id("body")
                        
                        Button(){
                            self.selectedTab = .steps
                        } label: {
                            HStack(){
                                Spacer()
                                Text("Get to Cooking! 🧑🏾‍🍳")
                                    .font(.title3)
                                    .foregroundColor(.label)
                                Spacer()
                            }
                        }
                        .background(Color.pink)
                        .clipShape(RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        ))
                        .frame(width: screenWidth - 100, height: 60)
                        .accentColor(.orange)
                        .buttonStyle(OutlineButton())
                    }
                    .offset(x: 0, y: (screenWidth / 5.0) * -1)
                    
                    Spacer()
                }
                .frame(minHeight: screenHeight * 1.2)
                .padding(.bottom, max(100, safeAreaInsets.bottom))
            }
            .background(
                Group(){
                    NetworkImage(url: dataModel?.backgroundImageUrl){
                        Image("bg_white")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                    }
                }
            )
        }
    }
    
    public var contentView: some View {
        ZStack(){
            
            Group(){
                if self.selectedTab == .steps {
                    stepsView
                } else if self.selectedTab == .information {
                    infoView
                } else if self.selectedTab == .help {
                    helpView
                }
            }
            .frame(maxWidth: screenWidth, maxHeight: screenHeight)
            .animation(.easeInOut)
            
            VStack(){
                Spacer()
                HStack(){
                    ForEach(Tab.allCases) { tab in
                        Button() {
                            self.selectedTab = tab
                        } label: {
                            HStack(){
                                Image(systemName: selectedTab == tab ? tab.emoji.active : tab.emoji.default)
                                Text(tab.label)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: true)
                            }
                            .foregroundColor(selectedTab == tab ? tab.color : .primary)
                            .padding()
                        }
                        .if(selectedTab == tab){ view in
                            view.background(BlurView(colorScheme == .dark ? .systemThickMaterialDark : .systemThickMaterialLight))
                        } else: { view in
                            view.background(Color.clear)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 25.0))
                        .font(.subheadline.weight(selectedTab == tab ? .semibold : .light))
                    }
                }
                .padding(4)
                .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                .clipShape(RoundedRectangle(cornerRadius: 25.0))
                .animation(.easeInOut)
            }
            .padding(.bottom, max(16, safeAreaInsets.bottom))
        }
        .frame(maxWidth: screenWidth, maxHeight: screenHeight)
        .edgesIgnoringSafeArea(.all)
    }
}

//
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}

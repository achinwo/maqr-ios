//
//  SiseMealboxView.swift
//  Joli
//
//  Created by Anthony Chinwo on 06/06/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground
import Combine
import JoliApi
import AlertToast
import JoliCore
import UIKit
import PassKit

struct PaymentButton: View {
    
    init(_ style: PKPaymentButtonStyle = .automatic){
        
    }
    
    var body: some View {
        Button(action: { /* Custom payment code here */ }, label: { EmptyView() } )
            .buttonStyle(PaymentButtonStyle())
    }
}

struct PaymentButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        return PaymentButtonHelper()
    }
}

struct PaymentButtonHelper: View {
    var body: some View {
        PaymentButtonRepresentable()
            .frame(minWidth: 100, maxWidth: 400)
            .frame(height: 60)
            .frame(maxWidth: .infinity)
    }
}

extension PaymentButtonHelper {
    
    struct PaymentButtonRepresentable: UIViewRepresentable {
        
        var button: PKPaymentButton {
            let button = PKPaymentButton(paymentButtonType: .order, paymentButtonStyle: .automatic) /*customize here*/
            button.cornerRadius = 4.0 /* also customize here */
            return button
        }
        
        func makeUIView(context: Context) -> PKPaymentButton {
            return button
        }
        func updateUIView(_ uiView: PKPaymentButton, context: Context) { }
    }
    
}

public struct Ingredient: Identifiable {
    
    public init(id: String, title: String, description: String, spicy: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.spicy = spicy
    }
    
    public var id: String
    public var title: String
    public var description: String
    
    public var spicy: String?
    
}

let ingredients: [Ingredient] = [
    Ingredient(id: "food_ing_chilliflakes", title: "Chilli Flakes", description: "Crushed Chillies flakes contain the flesh and seeds of whole chillies; if you want to add a warm, fiery punch to a dish, then look no further"),
    Ingredient(id: "food_ing_palmoil", title: "Bleached Palm oil", description: "A unique tasting oil made by bleaching red palm oil for a few minutes till it looks somewhat like vegetable oil"),
    Ingredient(id: "food_ing_salt", title: "Salt", description: "Cooking salt – a seasoning to enhance taste and bring out the natural flavours"),
    Ingredient(id: "food_ing_scotch_bornet", title: "Scotch Bonnet", description: "Scotch bonnet, also known as bonney peppers, or Caribbean red peppers, is a variety of chili pepper named for its resemblance to a tam o' shanter hat"),
    Ingredient(id: "food_ing_seasoningmix", title: "Season Mix", description: "A flavourful, umami-packed blend of ground dried ginger, peanuts, and more"),
]

public struct Step: Identifiable {
    
    public init(id: String, title: String, description: String, duration: TimeInterval? = nil, isOptional: Bool = false, spicy: String? = nil, caution: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.isOptional = isOptional
        self.duration = duration
        self.spicy = spicy
        self.caution = caution
    }
    
    public var duration: TimeInterval? = nil
    public var isOptional: Bool
    public var id: String
    public var title: String
    public var description: String
    
    public var spicy: String?
    public var caution: String?
    
}

let steps: [Step] = [
    Step(id: "heat_oil", title: "Heat Palm Oil", description: "Heat the bleached palm oil on medium heat for 1-2mins", duration: 60.0 * 2, caution: "Do Not Cover"),
    Step(id: "add_locust_beans", title: "Add Locust Beans", description: "Add in locust beans to cook for 50 secs, stir continuously to avoid burning"),
    Step(id: "add_protein", title: "Add Protein", description: "Add protein (meat/fish) and fry for 2-3mins stirring continuously", duration: 60.0 * 3),
    Step(id: "add_red_pepper", title: "Add Red Pepper", description: "Add the precooked red pepper", spicy: "🌶"),
    Step(id: "add_chillies", title: "Add Chilli Flakes", description: "Add the chilli flakes", spicy: "🌶🌶"),
    Step(id: "add_crayfish", title: "Add Crayfish", description: "Add the crayfish", isOptional: true),
    Step(id: "add_scotch_bonnet", title: "Add scotch bonnet", description: "Add scotch bonnet (quarter teaspoon at a time, until desired level of spice is reached)", spicy: "🌶🌶🌶"),
    Step(id: "add_spice", title: "Add the spice/season mix", description: "Add the spice/season mix as desired (half a teaspoon at a time)"),
    Step(id: "add_salt", title: "Add a pinch of salt", description: "Add a pinch of salt, optionally tasting till you achieve your desired taste", isOptional: true),
    Step(id: "cover_and_simmer", title: "Cover and leave to simmer", description: "Cover and leave to simmer for 6-10mins on medium heat", duration: 60.0 * 10),
    Step(id: "serve_enjoy", title: "Serve warn and enjoy", description: "Serve warn and enjoy your meal"),
]

struct SiseMealboxView<PlaybackControllerType: PlaybackController>: JoliContentView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    var localPlaybackController: PlaybackControllerType
    
    var websocket: Socket
    
    @State var websocketCancel: AnyCancellable?
    
    @State var toastInfo: (alert: AlertToast, onDismiss: (Bool) -> Void)? = nil
    
    @Binding var currentUser: User?
    
    enum Tab: Int, Identifiable, CaseIterable {
        case information
        case steps
        case gallery
        case help
        
        var id: Int {
            rawValue
        }
        
        var label: String {
            switch self {
                case .gallery:
                    return "Gallery"
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
                case .gallery:
                    return .orange
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
                case .gallery:
                    return (default: "photo.on.rectangle", active: "photo.on.rectangle.angled")
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
    @AppStorage("active-tab") var selectedTab = Tab.information
    
    public init(currentUser: Binding<User?>, websocket: Socket, localPlaybackController: PlaybackControllerType){
        self._currentUser = currentUser
        self.websocket = websocket
        self.localPlaybackController = localPlaybackController
        self.startDate = Date(timeIntervalSinceNow: 0)
        self._deliveryDate = State(initialValue: startDate)
    }
    
    var autoResetting = AutoResetSubject<Int?, Never, DispatchQueue>(nil, delay: 0.3, scheduler: DispatchQueue.main)
    
    @State var tappedStepId: Int? = nil
    @State var lastStepId: Int = -1
    
    
    @State var deliveryDate: Date
    let startDate: Date
    @State var completed = false
    @State var helpText: String = .empty
    
    var helpView: some View {
        ScrollView(){
            VStack(){
                VStack(){
                    
                    
                    Section(header: Text("Get in Touch").font(.largeTitle)) {
                        Text("Our team of highly trained food technicians are here to help!").font(.subheadline.weight(.light)).padding(.bottom)
                        TextEditor(text: self.$helpText)
                            .frame(height: screenWidth / 2)
                            .overlay(VStack(alignment: .leading){
                                Text("Enter your message here").padding().foregroundColor(.tertiaryLabel)
                            })
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                    }
                    .padding()
                    
                    Button(){
                        print("submitted help!")
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
                            Image("sise_logo")
                                .resizable()
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
                        Text("Smartz").font(.subheadline.weight(.semibold))
                    }
                }
                .padding()
                Spacer()
            }
            .frame(width: screenWidth - 100)
            .padding(.top, safeAreaInsets.top * 2)
        }
        .frame(maxWidth: screenWidth, maxHeight: screenHeight)
        .background(Image(colorScheme == .dark ? "bg_dark" : "bg_white")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
        )
        
    }
    
    var stepsView: some View {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.allowedUnits = [.minute]
        
        let ingredientsView = VStack(){
            
            let header = HStack(){
                Image(systemName: "list.bullet.rectangle")//.renderingMode(.original)
                Text("Ingredients")
                Spacer()
            }
            .font(.title2)
            .padding()
            
            Section(header: header){
                VStack(){
                    ForEach(ingredients) { ing in
                        HStack(){
                            Image(ing.id)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                            VStack(alignment: .leading){
                                Text(ing.title).font(.subheadline)
                                Text(ing.description).font(.caption).foregroundColor(.secondaryLabel).fixedSize(horizontal: false, vertical: true)
                            }
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
                    .font(.body.weight(.light)).foregroundColor(.secondaryLabel).fixedSize(horizontal: false, vertical: true)
                
                HStack(){
                    Spacer()
                    
                    VStack(){
                        Image("instagram_logo").resizable().frame(width: screenWidth / 6, height: screenWidth / 6)
                        Text("Tag us").font(.caption2.weight(.light)).foregroundColor(.secondaryLabel)
                        Text("@ashabismeals").font(.body.weight(.semibold)).foregroundColor(.primary)
                    }
                    .padding()
                    
                    VStack(){
                        Image("fbk_logo").resizable().frame(width: screenWidth / 6, height: screenWidth / 6)
                        Text("Share us").font(.caption2.weight(.light)).foregroundColor(.secondaryLabel)
                        Text("#madewithsise").font(.body.weight(.semibold)).foregroundColor(.primary)
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .padding()
        }
        .id("share-section")
        
        
        let reorderView = VStack(){
            VStack(){
                Text("Schedule a re-order?").font(.title2.weight(.light))
                Text("Scheduling a re-delivery of Ofada sauce is effortless with Apple Pay")
                    .lineLimit(3)
                    .font(.body.weight(.light))
                    .foregroundColor(.secondaryLabel)
                    .padding()
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(){
                    DatePicker("Pick an arrival date", selection: $deliveryDate, displayedComponents: [.date])
                        .padding(.bottom)
                        .padding(.bottom)
                    
                    if let deliveryDay = Calendar.current.dateComponents([.day], from: deliveryDate).day,
                       let today = Calendar.current.dateComponents([.day], from: Date()).day, deliveryDay != today {
                        PaymentButton()
                    }
                }
                .padding()
                .animation(.easeInOut)
            }
            .padding()
        }
        
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
                            Image("food_ofada")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: screenWidth - 100, height: screenWidth - 100)
                                .padding(.top)
                            
                            (Text("(Pronounced Or-far-da) ").fontWeight(.semibold) + Text("also known as designer stew, originates from Western Nigeria and gets its name from a locally grown rice known as Ofada rice. This delicious sauce is enriched with flavours as it is originally made with a variety of red peppers."))
                                .padding()
                                .padding(.horizontal)
                                .font(.body.weight(.light))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Divider().padding()
                            ingredientsView
                            Divider().padding()
                            
                            ForEach(Array(steps.enumerated()), id: \.element.title) { itm in
                                
                                let isChecked = self.lastStepId >= itm.offset
                                
                                HStack(alignment: .top){
                                    VStack(){
                                        Text(itm.offset.advanced(by: 1).description) + Text(".")
                                        Spacer()
                                    }
                                    .foregroundColor(.tertiaryLabel)
                                    
                                    VStack(alignment: .leading){
                                        Text(itm.element.description)
                                            .strikethrough(isChecked, color: .secondaryLabel)
                                            .lineLimit(nil)
                                            .font(.body)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .foregroundColor(isChecked ? .secondaryLabel : .primary)
                                        
                                        HStack() {
                                            
                                            if itm.element.isOptional {
                                                Label("Optional", systemImage: "info.circle")
                                                    .font(.footnote).foregroundColor(Color.systemIndigo.opacity(0.7))
                                            }
                                            
                                            if let duration = itm.element.duration, let durationStr = formatter.string(from: duration) {
                                                Label(durationStr, systemImage: "timer")
                                                    .font(.footnote)
                                            }
                                            
                                            if let spicy = itm.element.spicy {
                                                Text(spicy)
                                                    .font(.footnote)
                                            }
                                            
                                            Spacer()
                                            
                                            if let caution = itm.element.caution {
                                                Label(caution, systemImage: "nosign")
                                                    .font(.footnote)
                                                    .foregroundColor(.yellow)
                                            }
                                        }
                                        .foregroundColor(.secondary)
                                        .padding(.top, 2)
                                    }
                                    
                                    Spacer()
                                    Button() {
                                        self.autoResetting.send(itm.offset)
                                        self.lastStepId = self.lastStepId == 0 && itm.offset == 0 ? -1 : itm.offset
                                        
                                        guard self.lastStepId == steps.count - 1 else { return }
                                        
                                        withImpact(.heavy, animated: .easeInOut){
                                            
                                            self.presentToast("All done!", subTitle: "Enoy your meal", custom: .none, type: .image("confetti", .clear), displayMode: .alert) { dismissed in
                                                print("Alert closed")
                                                self.completed = true
                                                
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
                                                    withAnimation(){
                                                        guard selectedTab == .steps else { return }
                                                        
                                                        proxy.scrollTo("share-section", anchor: .center)
                                                    }
                                                }
                                                
                                            }
                                            
                                        }
                                        
                                    } label: {
                                        let active = self.tappedStepId == itm.offset
                                        Image(systemName: isChecked ? "checkmark.circle" : "circle.dashed")
                                            .foregroundColor(isChecked ? .green : Color.secondaryLabel)
                                            .padding()
                                            .font(.title.weight(.light))
                                            .scaleEffect(x: active ? 1.5 : 1, y: active ? 1.5 : 1)
                                            .animation(.easeInOut)
                                    }
                                    
                                }
                                .padding([.bottom, .horizontal])
                            }
                            .navigationTitle("Preparing Ofada Sauce")
                            
                            Group(){
                                if completed {
                                    
                                    
                                    Divider().padding(.vertical)
                                    shareView
                                    
                                    Divider().padding()
                                    reorderView
                                }
                            }
                            .padding(.bottom, safeAreaInsets.bottom)
                            
                        }
                        .frame(maxWidth: screenWidth)
                        .padding(.bottom, safeAreaInsets.bottom)
                        //.frame(minHeight: screenHeight)
                    }
                }
            }
            
        }
        .onReceive(self.autoResetting) { value in
            self.tappedStepId = value
        }
    }
    
    var galleryView: some View {
        
        let images: [String] = [
            "food_ofada",
            "food_ofada-2",
            "food_ofada-3",
            "food_ofada-4",
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
                    Image("sise_cover")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: screenWidth, height: screenWidth / 2)
                        //.clipped()
                        .overlay(
                            GeometryReader(){ proxy in
                                ZStack(){
                                    
                                    
                                    LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.7), Color.clear]), startPoint: .top, endPoint: .bottom)
                                        .frame(width: proxy.size.width, height: proxy.size.height)
                                    
                                }
                            }
                        )
                    
                    Divider()
                    Image("sise_logo")
                        .resizable()
                        .frame(width: screenWidth / 2, height: screenWidth / 2)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle()
                                    .stroke(Color.secondaryLabel, lineWidth: 1))
                        .offset(x: 0, y: (screenWidth / 24) * -1)
                        .shadow(radius: 1)
                        .id("brand")
                    //
                    
                    VStack(){
                        Section(header: Text("HELLO & WELCOME").font(.title3)) {
                            Text("Sísè ").font(.subheadline.weight(.semibold)) + Text("pronounced sea-say, is a Yoruba word that means cook").font(.subheadline.weight(.light))
                            Text("Sísè food box provides you with pre-prepped ingredients as well as simple step by step instructions required to cook delicious mouth-watering meals in under 20mins! \n\nOur ❤️ for food means that we source only the best ingredients with quality and authenticity at the heart of it all.")
                                .font(.body.weight(.light))
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
                    
                    Spacer()
                }
                .frame(minHeight: screenHeight * 1.2)
            }
            
            .background(Image(colorScheme == .dark ? "bg_dark" : "bg_white")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
            )
            .onAppear(){
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation(){
                        guard selectedTab == .information else { return }
                        
                        proxy.scrollTo("body", anchor: .center)
                    }
                }
            }
        }
    }
    
    var contentView: some View {
        ZStack(){
            
            Group(){
                if self.selectedTab == .steps {
                    stepsView
                } else if self.selectedTab == .gallery {
                    galleryView
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
                //                Picker(selection: self.$selectedTab, label: Text("Users")) {
                HStack(){
                    ForEach(Tab.allCases) { tab in
                        Button() {
                            self.selectedTab = tab
                        } label: {
                            Label(tab.label, systemImage: selectedTab == tab ? tab.emoji.active : tab.emoji.default)
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
            .padding(.bottom, safeAreaInsets.bottom)
            
            
            //            HStack(){
            //                Button() {
            //
            //                }
            //            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

//
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}

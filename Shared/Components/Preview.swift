//
//  SwiftUIView.swift
//  Joli
//
//  Created by Anthony Chinwo on 16/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//
#if !os(macOS)
import UIKit
#endif

import SwiftUI
import JoliCore
import Promises



struct SignInSheetView: JoliView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @State var title: String
    @State var subtitle: String
    @State var callback: (Bool) -> Void
    
    var contentView: some View {
        VStack {
            VStack {
                Text(title).font(.title)
                Text(subtitle)
                    .lineLimit(4)
                    .padding()
                    .frame(maxWidth: screenWidth - 100)
                    .fixedSize()
                    .font(.subheadline)
                    .foregroundColor(.secondaryLabel)
                
                
                SignInWithApple()
                    .onTapGesture() {
                        self.appCoordinator.requestedSignIn.send(.apple(callback))
                    }
                    .frame(width: screenWidth - 100, height: 60)
                Text("Allows voting ONLY")
                    .font(.footnote.weight(.light))
                    .foregroundColor(.secondaryLabel)
                    .padding(.bottom)
                
                Button(){
                    print("perform spotify auth!")
                    self.appCoordinator.requestedSignIn.send(.spotify(callback))
                } label: {
                    HStack(){
                        Spacer()
                        Image(platformImage: Images.spotifyLogo.uiImage)
                            .resizable()
                            .frame(width: 24, height: 24, alignment: .center)
                        Text("Sign in with Spotify")
                            .font(.title3)
                            .foregroundColor(.label)
                        Spacer()
                    }
                }
                .frame(width: screenWidth - 100, height: 60)
                .buttonStyle(OutlineButton())
                
                Text("Allows voting & playback")
                    .font(.footnote.weight(.light))
                    .foregroundColor(.secondaryLabel)
                    .padding(.bottom, Sizing.xxLarge)
                

            }
            .padding(.bottom, Sizing.xxLarge)
            .onTapGesture {
                // Fixes issue with scroll
            }
            .padding()
        }
    }
}

public enum AppPreview: View, Equatable {
    
    public static func == (lhs: AppPreview, rhs: AppPreview) -> Bool {
        switch (lhs, rhs) {
        case (.userAccount, .userAccount):
            return true
        default:
            return false
        }
    }
    
    public var body: some View {
        switch self {
            case .userProfile(let user):
                UserProfileView2(user: .constant(user))
                    .background(Color.clear)
                    .id(user.emailAddress.email)
            case .view(let scrollAxis, let viewFunc):
                ScrollView(scrollAxis ?? .vertical){
                    viewFunc().clipped()
                }
            case .track(let track):
                VStack() {
                    NetworkImage(string: track.albumCoverUrl) {
                        Text("\(track.title)")
                    }
                }
            case .event(let evt, let ent, let cb):
                EventView(evt, entitlement: ent, callback: cb)
                    .id(evt.uuid)
            case .playroomCreate:
                PlayroomCreateView()
                    .background(Color.clear)
            default:
                EmptyView()
        }
    }
    
    case userAccount
    case userProfile(UserIdentifiable)
    case track(Track)
    case event(Event, Entitlement? = nil, (Entitlement) -> Void)
    case view(Axis.Set? = nil, () -> AnyView)
    case playroomCreate
}


public struct EventView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @State var entitlement: Entitlement? = nil
    let event: Event
    let callback: (Entitlement) -> Void
    
    @State var loadingDietaryChoices = false
    
    public init(_ event: Event, entitlement: Entitlement? = nil, callback: @escaping (Entitlement) -> Void){
        self.callback = callback
        self.event = event
        self._entitlement = State(initialValue: entitlement)
    }
    
    var entitlementRecord: EntitlementRecord {
        var ent = EntitlementRecord()
        ent.type = "event"
        //ent.uuid = event.uuid
        ent.targetRecordId = event.id
        ent.userId = appCoordinator.activeAuth?.user.id
        
        return ent
    }
    
    private func saveEntitlement(_ entitlement: EntitlementRecord) {
        entitlement.save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession, on: .main)
            .then() { e in
                self.entitlement = e
                
                guard e.rejectedAt != nil else {
                    return
                }
                
                self.callback(e)
            }
            .catch() { error in
                self.presentToast("Unable to action", subTitle: "An error occured, try terminating and restarting the App", type: .error(.red), onDismiss: { _ in })
                appCoordinator.globalErrorHandler()(error)
            }
    }
    
    func authenticateAndPerform(_ callback: @escaping (Bool) -> Void){
        #if !os(macOS)
        self.appCoordinator.sheet.show(){
            print("Sheet dismissed!")
        } content: {
            SignInSheetView(title: "Authentication Required", subtitle: "Choose an authentication method", callback: callback)
        }
        #endif
    }
    
    func onAccept() {
        print("Accepted Invite")
        
        let perform = { (authSuccessful: Bool) -> Void in
            
            guard authSuccessful else {
                presentToast("Authentication Failed", subTitle: "Unable to complete authenication", type: .error(.red)) { _ in
                    #if !os(macOS)
                    self.appCoordinator.sheet.closePartialSheet()
                    #endif
                }
                return
            }
            
            var rec = entitlementRecord
            rec.acceptedAt = Date()
            self.saveEntitlement(rec)
            self.loadFoodAndDrinks()
            
            DispatchQueue.main.async(){
                scrollProxy?.scrollTo("food", anchor: .top)
                self.appCoordinator.sheet.closePartialSheet()
            }
        }
        
        
        guard appCoordinator.activeAuth != nil else {
            authenticateAndPerform(perform)
            return
        }
        
        perform(true)
    }
    
    func onReject() {
        print("Rejected Invite")
        
        let perform = { (authSuccessful: Bool) -> Void in
            
            guard authSuccessful else {
                presentToast("Authentication Failed", subTitle: "Unable to complete authenication", type: .error(.red)) { _ in
                    #if !os(macOS)
                    self.appCoordinator.sheet.closePartialSheet()
                    #endif
                }
                return
            }
            
            var rec = entitlementRecord
            rec.rejectedAt = Date()
            self.saveEntitlement(rec)
            
            DispatchQueue.main.async {
                self.appCoordinator.sheet.closePartialSheet()
            }
        }
        
        guard appCoordinator.activeAuth != nil else {
            authenticateAndPerform(perform)
            return
        }
        
        perform(true)
        
    }
    
    private func loadFoodAndDrinks() {
        self.loadingDietaryChoices = true
        
        let p1 = Food.all(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            .then(on: .main){ foods in
                self.foods = foods
            }
            .catch(self.appCoordinator.globalErrorHandler())
        
        let p2 = Drink.all(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            .then(on: .main){ drinks in
                self.drinks = drinks.sorted(by: { $0.alcoholContent ?? 0 > $1.alcoholContent ?? 0})
            }
            .catch(self.appCoordinator.globalErrorHandler())
        
        Promises.all(p1, p2)
            .then() { (_, _) in
                updateSelections()
            }
            .always {
                self.loadingDietaryChoices = false
            }
    }
    
    @State var foods: [Food] = []
    @State var selectedFoods: [Food.ID] = []
    
    @State var drinks: [Drink] = []
    @State var selectedDrinks: [Drink.ID] = []
    
    @State var allChoices: [MealChoice] = []
    
    var choicesIds: (drinks: [Drink.ID], foods: [Food.ID]) {
        let choices = self.allChoices.filter() { $0.eventId == event.id && $0.createdById == appCoordinator.activeAuth?.user.id }
        let drinkIds = choices.filter({ $0.type == .drink }).compactMap() { $0.targetId }
        let foodIds = choices.filter({ $0.type == .food }).compactMap() { $0.targetId }
        return (drinkIds, foodIds)
    }
    
    @State var scrollProxy: ScrollViewProxy? = nil
    
    public var dietaryView: some View {
        VStack(){
            GridChooserView(items: $foods, selections: $selectedFoods, layout: .list) { food in
                
                let choices = self.allChoices.filter() { $0.targetId == food.id && $0.eventId == event.id  && $0.type == .food }
                
                HStack(alignment: .center) {
                    NetworkImage(url: api.baseUrlHttp.appendingPathComponent("/images/\(food.imageName)")) {
                        Image(systemName: "xmark.octagon")
                    }
                    .aspectRatio(contentMode: .fit)
                    .frame(width:  80, height: 80)
                    
                    VStack(alignment: .leading){
                        Text(food.title).font(.headline).foregroundColor(.label)
                        Text(food.subtitle)
                            .fixedSize()
                            .font(.subheadline)
                            .lineLimit(4)
                            .foregroundColor(.secondary)
                        
                        if choices.count > 0 {
                            Label(){
                                Text(choices.count.description)
                            } icon: {
                                Image(systemName: "person.2.fill")
                            }
                            .font(.footnote)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    VStack(){
                        Spacer()
                        let selected = choicesIds.foods.contains(food.id)
                        Image(systemName: selected ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.title)
                        .foregroundColor(selected ? .green : .label)
                        .padding()
                        Spacer()
                    }
                }
                .id(food.id)
                
            }
            .padding(.bottom)
            
            Divider().padding()
            
            GridChooserView(items: $drinks, selections: $selectedDrinks, layout: .grid) { drink in
                
                let choices = self.allChoices.filter() { $0.targetId == drink.id && $0.type == .drink && $0.eventId == event.id}
                
                VStack(alignment: .center) {
                    NetworkImage(url: api.baseUrlHttp.appendingPathComponent("/images/\(drink.imageName)")) {
                        Image(systemName: "xmark.octagon")
                    }
                    .aspectRatio(contentMode: .fit)
                    .frame(width:  80, height: 80)
                    .padding(.top)
                    
                    VStack(alignment: .leading){
                        Text(drink.title).font(.headline).foregroundColor(.label)
                        Text(drink.subtitle).font(.subheadline)
                            .lineLimit(4)
                            .foregroundColor(.secondary)
                        
                        if choices.count > 0 {
                            Label(){
                                Text(choices.count.description)
                            } icon: {
                                Image(systemName: "person.2.fill")
                            }
                            .font(.footnote)
                        }
                    }
                    .padding()
                    
                }
                .overlay(
                    Group(){
                        
                        if choicesIds.drinks.contains(drink.id) {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green, lineWidth: 2)
                        } else {
                            Color.clear
                        }
                    }
                )
                .id(drink.id)
                
            }
        }
        .onChange(of: selectedDrinks) { drinks in
            let toCreated = drinks.filter({ !self.choicesIds.drinks.contains($0) })
            let toDelete = self.choicesIds.drinks.filter({ !drinks.contains($0) })
            
            if !toCreated.isEmpty {
                self.selectItem(type: "drink", ids: toCreated)
            }
            
            if !toDelete.isEmpty {
                self.removeItem(type: "drink", ids: toDelete)
            }
        }
        .onChange(of: selectedFoods) { foods in
            let toCreated = foods.filter({ !self.choicesIds.foods.contains($0) })
            let toDelete = self.choicesIds.foods.filter({ !foods.contains($0) })
            
            if !toCreated.isEmpty {
                self.selectItem(type: "food", ids: toCreated)
            }
            
            if !toDelete.isEmpty {
                self.removeItem(type: "food", ids: toDelete)
            }
        }
    }
    
    func removeItem(type: String, ids: [Int]) {
        let allChoices = self.allChoices
        var toRemove = [MealChoice]()
        
        for meal in allChoices {
            guard meal.createdById == appCoordinator.activeAuth?.user.id, let mealId = meal.targetId, meal.type.rawValue == type, ids.contains(mealId) else { continue }
            
            meal.delete(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
                .then(on: .main){ _ in
                    toRemove.append(meal)
                }
        }
        
        self.allChoices = self.allChoices.filter() { !toRemove.contains($0) }
        
        let userChoices = self.choicesIds
        self.selectedDrinks = userChoices.drinks
        self.selectedFoods = userChoices.foods
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateSelections()
        }
    }
    
    func selectItem(type: String, ids: [Int]) {
        for elemId in ids {
            
            guard allChoices.first(where: { $0.targetId == elemId && $0.type.rawValue == type && $0.createdById == appCoordinator.activeAuth?.user.id }) == nil else {
                continue
            }
            
            var ch = MealChoiceRecord()
            ch.eventId = event.id
            ch.roomId = event.roomId
            ch.type = type
            ch.targetId = elemId
            
            ch.save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
                .then(on: .main) { choice in
                    allChoices.append(choice)
                }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.updateSelections()
        }
    }
    
    private func updateSelections(){
        MealChoice.all(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
        .then(on: .main){ choices in
            self.allChoices = choices.filter() { $0.deletedAt == nil }
            
            let userChoices = self.choicesIds
            
            self.selectedDrinks = userChoices.drinks
            self.selectedFoods = userChoices.foods
        }
        .catch(self.appCoordinator.globalErrorHandler())
    }
    
    public var contentView: some View {
        ZStack(){
            ScrollViewReader() { scrollProxy in
                
                ScrollView(){
                    VStack(alignment: .center) {
                        Text(event.title)
                            .font(.largeTitle)
                            .padding()
                        Text(event.subtitle)
                            .font(.body.weight(.light))
                            .multilineTextAlignment(.center)
                            .padding(.bottom)
                        
                        let timeHeader = HStack(){
                            Label(){
                                Text("Time")
                            } icon: {
                                Image(systemName: "calendar")
                                    .font(Font.title.weight(.thin))
                            }
                            .foregroundColor(.secondary)
                            .font(Font.title.weight(.thin))
                            
                            Spacer()
                        }
                        
                        Section(header: timeHeader) {
                            HStack(){
                                Text(event.startsAt, style: .date)
                                Text(event.startsAt, style: .time).padding(.leading, 2)
                                Text("—").padding(.horizontal, 4)
                                Text(event.endsAt, style: .date)
                                Text(event.endsAt, style: .time).padding(.leading, 2)
                            }
                            .padding()
                        }
                        
                        if let venue = event.venue {
                            let header = HStack(){
                                Label(){
                                    Text("Venue")
                                } icon: {
                                    Image(systemName: "location")
                                        .font(Font.title.weight(.thin))
                                }
                                .foregroundColor(.secondary)
                                .font(Font.title.weight(.thin))
                                
                                Spacer()
                            }
                            
                            Section(header: header) {
                                Text(venue).font(.body.weight(.light)).padding()
                            }
                        }
                        
                        let menuHeader = HStack(){
                            Text("Food & Drinks")
                                .foregroundColor(.secondary)
                                .font(Font.title.weight(.thin))
                            
                            Spacer()
                        }
                        
                        if entitlement != nil {
                            Section(header: menuHeader) {
                                Group(){
                                    if self.loadingDietaryChoices {
                                        ProgressView("Loading choices")
                                    } else {
                                        self.dietaryView
                                    }
                                }
                            }
                            .id("food")
                        }
                    }
                    .padding()
                    .padding(.bottom, Sizing.xxLarge * 3)
                    .onAppear(){
                        self.scrollProxy = scrollProxy
                    }
                }
            }
            
            VStack(alignment: .center, spacing: .zero) {
                Spacer()
                
                Divider().padding(.horizontal)
                
                HStack(alignment: .center, spacing: Sizing.medium) {
                    Spacer()
                    
                    if let entitlement = entitlement {
                        Button(){
                            self.presentToast("You're all set!", type: .complete(.green), onDismiss: { _ in })
                            
                            self.callback(entitlement)
                        } label: {
                            VStack(){
                                Text("I'm done choosing").font(.headline)
                                Text("Take me to song list").font(.footnote)
                            }
                        }
                        .buttonStyle(FilledButton())
                    } else {
                        
                        Button(action: self.onReject) {
                            Text("Can't make it")
                        }
                        .buttonStyle(OutlineButton())
                        
                        Button(action: self.onAccept) {
                            Text("I'll be there!")
                        }
                        .buttonStyle(FilledButton())
                    }
                    
                    Spacer()
                }
                .padding()
                .padding(.bottom, bottomPadding)
                .background(Color.tertiarySystemBackground.opacity(0.4))
            }
        }
        .onAppear(){
            
            guard entitlement != nil else { return }
            
            self.loadFoodAndDrinks()
        }
    }
    
    #if APPCLIP
    let bottomPadding = Sizing.xxLarge
    #else
    let bottomPadding = Sizing.small
    #endif
    
}

struct FilledButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(configuration.isPressed ? .gray : .label)
            .padding()
            .background(Color.accentColor)
            .cornerRadius(8)
    }
}

struct OutlineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(configuration.isPressed ? .gray : .accentColor)
            .padding()
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                ).stroke(Color.accentColor)
            )
    }
}

public struct AppPreviewView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @Binding var preview: AppPreview?
    @Binding var currentUser: User?
    @Binding var closeable: Bool
    var animation: Namespace.ID
    
    public init(preview: Binding<AppPreview?>, currentUser: Binding<User?>, isDismissable: Binding<Bool> = .constant(true), animation: Namespace.ID){
        self._preview = preview
        self._currentUser = currentUser
        self._closeable = isDismissable
        self.animation = animation
    }
    
    public var contentView: some View {
        ZStack(){
            
            VStack(spacing: .zero){
                Divider()
                Spacer(minLength: .zero)
                
                if let currentUser = currentUser, preview == .userAccount {
                    UserProfileView2(user: .constant(currentUser))
                } else if let preview = self.preview {
                    preview
                } else {
                    Text("No Preview.")
                }
                Spacer(minLength: .zero)
                Divider()
            }
            .environmentObject(appCoordinator)
            .matchedGeometryEffect(id: "preview", in: animation)
            
            if closeable {
                let largeTitleSize = UIFont.preferredFont(forTextStyle: .title1).pointSize
                VStack(alignment: .trailing){
                    HStack(){
                        Spacer()
                        Image(systemName: "xmark")
                            .font(Font.title.weight(.light))
                            .foregroundColor(.gray)
                            .opacity(0.9)
                            .background(Circle()
                                            .frame(width: largeTitleSize * 1.4, height: largeTitleSize * 1.6)
                                            .foregroundColor(Colors.lightGray.opacity(0.8)))
                            
                            .padding([.top, .trailing], Sizing.medium)
                    }
                    .padding()
                    .onTapGesture() {
                        self.preview = nil
                    }
                    //.frame(maxWidth: Sizing.large, maxHeight: Sizing.large)
                    Spacer()
                }
            }
        }
        
    }
}

struct Preview_Previews: PreviewProvider {
    
    struct SampleView: View {
        @Namespace var namespace
        @State var preview: AppPreview? = .userProfile(SEED_DATA.users.first!.builder())
        
        var body: some View {
            return AppPreviewView(preview: self.$preview,
                                  currentUser: .constant(SEED_DATA.users.first),
                                  animation: namespace)
        }
    }
    
    
    static var previews: some View {
        SampleView()
    }
}

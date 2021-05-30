//
//  ContentView.swift
//  SmartzClip
//
//  Created by Anthony Chinwo on 22/05/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground
import Combine
import JoliApi
import AlertToast
import JoliCore

public struct Step: Identifiable {
    
    public init(id: String, title: String, description: String, isOptional: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.isOptional = isOptional
    }
    
    public var isOptional: Bool
    public var id: String
    public var title: String
    public var description: String
    
}

let steps: [Step] = [
    Step(id: "heat_oil", title: "Heat Palm Oil", description: "Heat the bleached palm oil on medium heat"),
    Step(id: "add_locust_beans", title: "Add Locust Beans", description: "Add in locust beans to cook for 50 secs, stir continuously to avoid burning"),
    Step(id: "add_protein", title: "Add Protein", description: "Add protein (meat/fish) and fry for 2-3mins stirring continuously"),
    Step(id: "add_red_pepper", title: "Add Red Pepper", description: "Add the precooked red pepper"),
    Step(id: "add_chillies", title: "Add Chilli Flakes", description: "Add the chilli flakes"),
    Step(id: "add_crayfish", title: "Add Crayfish", description: "Add the crayfish", isOptional: true),
    Step(id: "add_scotch_bonnet", title: "Add scotch bonnet", description: "Add scotch bonnet (quarter teaspoon at a time, until desired level of spice is reached) (spicy)"),
    Step(id: "add_spice", title: "Add the spice/season mix", description: "Add the spice/season mix as desired (half a teaspoon at a time)"),
    Step(id: "add_salt", title: "Add a pinch of salt", description: "Add a pinch of salt, optionally tasting till you achieve your desired taste"),
    Step(id: "cover_and_simmer", title: "Cover and leave to simmer", description: "Cover and leave to simmer for 6-10mins on medium heat"),
    Step(id: "serve_enjoy", title: "Serve warn and enjoy", description: "Serve warn and enjoy your meal"),
]

struct ContentView<PlaybackControllerType: PlaybackController>: JoliContentView {
    
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
    @State var selectedTab = Tab.information
    
    public init(currentUser: Binding<User?>, websocket: Socket, localPlaybackController: PlaybackControllerType){
        self._currentUser = currentUser
        self.websocket = websocket
        self.localPlaybackController = localPlaybackController
    }
    
    var autoResetting = AutoResetSubject<String?, Never, DispatchQueue>(nil, delay: 0.3, scheduler: DispatchQueue.main)
    
    var stepsView: some View {
        NavigationView(){
            List(Array(steps.enumerated()), id: \.element.title) { itm in
                HStack(alignment: .top){
                    VStack(){
                        Text(itm.offset.advanced(by: 1).description) + Text(".")
                        Spacer()
                    }
                    
                    VStack(){
                        //Text(itm.element.title)
                        Text(itm.element.description).font(.body)
                    }
                    
                    Spacer()
                    Image(systemName: "checkmark.circle")
                }
                .padding()
            }
            .navigationTitle("The Steps")
        }
    }
    
    var contentView: some View {
        ZStack(){
            
            if self.selectedTab == .steps {
                stepsView
            }
            
            VStack(){
                Spacer()
//                Picker(selection: self.$selectedTab, label: Text("Users")) {
                HStack(){
                    ForEach(Tab.allCases) { tab in
                        Button() {
                            self.selectedTab = tab
                        } label: {
                            Label(tab.label, systemImage: selectedTab == tab ? tab.emoji.active : tab.emoji.default)
                                .foregroundColor(Color.label)
                                .padding()
                        }
                        .if(selectedTab == tab){ view in
                            view.background(BlurView(colorScheme == .dark ? .systemThinMaterialDark : .systemThinMaterialLight))
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

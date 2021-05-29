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

let steps: [(title: String, description: String)] = [
    ("", "Heat the bleached palm oil on medium heat")
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
    
    var contentView: some View {
        ZStack(){
            
            if self.selectedTab == .steps {
                List(Array(steps.enumerated()), id: \.element.title) { itm in
                    HStack(){
                        VStack(){
                            Text(itm.offset.advanced(by: 1).description)
                            Spacer()
                        }
                        VStack(){
                            Text(itm.element.title)
                            Text(itm.element.description)
                        }
                        
                    }
                }
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

//
//  AppView.swift
//  Joli
//
//  Created by Anthony Chinwo on 11/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi
import JoliCore

public struct AppView2: JoliView {
    
    enum ScrollPosition: Equatable {
        case leadingEdge
        case trailingEdge
        case point(CGPoint)
    }
    
    static let viewIds: (explore: String, listen: String, notset: String) = ("views.explore", "views.listen", "views.none")
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @State var scrollPosition: ScrollPosition = .leadingEdge
    
    @State var isExpanded = false
    
    @State var heartLevel: HeartLevel = .full
    @State var draggingValue: CGSize = .zero
    
    @AppStorage("selectedViewId") var selectedViewId: String = viewIds.notset
    @State var peopleViewBounds: CGRect? = nil
    @State var navbarViewBounds: CGRect? = nil
    @State var filterText = ""
    
    @Namespace var animation
    
    @Binding var playroom: Musicroom? {
        didSet {
            
            
        }
    }
    
    @Binding var currentUser: User?
    
    
    
    public init(playroom: Binding<Musicroom?>, currentUser: Binding<User?>){
        self._playroom = playroom
        self._currentUser = currentUser
    }
    
    @State var filteredTracks: [Playable] = []
    
    @State var preview: AppPreview? = nil
    
    
    public var body: some View {
        
        return GeometryReader() { geoProxy in
            ZStack(){
                ScrollViewReader() { (proxy: ScrollViewProxy) in
                    ScrollView(.horizontal, showsIndicators: false){
                        HStack(alignment: .top, spacing: .zero){
                            ExploreView(geoProxy: geoProxy, playroom: self.$playroom, selectedViewId: self.$selectedViewId)
                                .frame(width: screenWidth)
                                .frame(minHeight: screenHeight - geoProxy.safeAreaInsets.top - geoProxy.safeAreaInsets.bottom)
                                .onChange(of: self.scrollPosition) { value in
                                    
                                    if [.leadingEdge, .trailingEdge].contains(value) {
                                        print("Scroll position: \(value), safeArea: \(geoProxy.safeAreaInsets.top)")
                                    }
                                    
                                    switch value {
                                        case .leadingEdge:
                                            self.selectedViewId = Self.viewIds.explore
                                        case .trailingEdge:
                                            self.selectedViewId = Self.viewIds.listen
                                        default:
                                            break
                                    }
                                }
                                .background(Color.white)
                                .id(Self.viewIds.explore)
                                .simultaneousGesture(
                                    TapGesture()
                                        .onEnded() { value in
                                            
                                            guard appCoordinator.keyboardHeight > 0 else {
                                                return
                                            }
                                            
                                            appCoordinator.dismissKeyboard()
                                        }
                                )
                            
                            ListenView(geoProxy: geoProxy, tabbarExpaned: self.$isExpanded,
                                       preview: self.$preview, filterText: self.$filterText, animation: animation,
                                       playroom: self.$playroom, currentUser: self.$currentUser)
                                .frame(width: screenWidth)
                                //.clipped()
//                                .onChange(of: self.filterText) { term in
//                                    let term = self.filterText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
//
//                                    guard !self.filterText.isEmpty else {
//                                        self.filteredTracks = SEED_DATA.tracks
//                                        return
//                                    }
//
//                                    self.filteredTracks = SEED_DATA.tracks.filter() { track in
//                                        return track.artistName.lowercased().contains(term) || track.title.lowercased().contains(term)
//                                    }
//                                }
                                .background(Color.white)
                                .id(Self.viewIds.listen)
                        }
                        .onFrameChange(){ frame in
                            
                            DispatchQueue.main.async {
                                switch (frame.origin.x, frame.origin.y) {
                                    case (0, _):
                                        self.scrollPosition = .leadingEdge
                                    case (self.screenWidth * -1 , _):
                                        self.scrollPosition = .trailingEdge
                                    default:
                                        self.scrollPosition = .point(frame.origin)
                                }
                                
                                let trailingThreshold = ((self.screenWidth + 100) * -1)
                                
                                guard frame.origin.x > 100 || frame.origin.x < trailingThreshold else {
                                    //print("Overscroll menues disabled! \(frame.origin.x)")
                                    return
                                }
                                
                                if frame.origin.x > 100 {
                                    print("Leading menu enabled \(frame.origin)")
                                } else if frame.origin.x < trailingThreshold {
                                    print("Trailing menu enabled \(frame.origin)")
                                }
                            }
                        }
                    }
                    .background(
                        GeometryReader() { gProx in
                            HStack(){
                                VStack(){
//                                    Image(systemName: "star.circle.fill")
//                                                .font(.system(size: 100))
//                                                .offset(x: 0, y: draggingValue.height)
                                }
                                .frame(width: 100, height: gProx.size.height)
                                .background(Color.yellow)
                                .fixedSize()
                                
                                Spacer()
                                
                                VStack(){
                                    
                                }
                                .frame(width: 100, height: gProx.size.height)
                                .background(Color.blue)
                                .fixedSize()
                            }
                            .frame(width: gProx.size.width, height: gProx.size.height)
                            
                            //.background(Color.red)
                        }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { gesture in
                                self.offset = gesture.translation
                                //print("Dragging: \(self.offset)")
                            }
                            
                            .onEnded { _ in
                                
                                defer {
                                    self.offset = .zero
                                }
                                
                                guard appCoordinator.keyboardHeight > 0 && self.offset.height < appCoordinator.keyboardHeight else {
                                    return
                                }
                                
                                appCoordinator.dismissKeyboard()
                            }
                    )
                    .onChange(of: self.selectedViewId) { value in
                        withAnimation(){
                            print("[AppView2] scrolling to: \(value)")
                            proxy.scrollTo(value)
                        }
                    }
                    .onChange(of: playroom) { room in
                        guard let pla = playroom else {
                            return
                        }
                        
                        self.filteredTracks = []
                    }
                    .onAppear() {
                        
                        guard self.selectedViewId != Self.viewIds.notset else {
                            self.selectedViewId = Self.viewIds.listen
                            return
                        }
                        
                        withAnimation(){
                            proxy.scrollTo(self.selectedViewId)
                        }
                    }
//                    .highPriorityGesture(
//                        DragGesture()
//                            .updating(self.$draggingValue) { (value, state, trans) in
//                                print("DRAGGING - \(value)")
//                                state = value.translation
//                            }
//                            .onChanged() { value in
//                                print("DRAG changed - \(value)")
//                            }
//                            .onEnded() { value in
//                                print("DRAG ended - \(value)")
//                            }
//                    )
                }
            }
            .ignoresSafeArea(.all, edges: [.top, .bottom])
            //.edgesIgnoringSafeArea()
        }
        .frame(minWidth: screenWidth)
    }
    
    @State private var offset = CGSize.zero
    
}


//struct AppView2_Previews: PreviewProvider {
//    static var previews: some View {
//        let coord = AppCoordinator()
//        AppView2(playroom: .constant(SEED_DATA.musicrooms.first), currentUser: .constant(SEED_DATA.users.first))
//            .environmentObject(coord)
//    }
//}

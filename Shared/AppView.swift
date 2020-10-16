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

public struct AppView2: View {
    
    enum ScrollPosition: Equatable {
        case leadingEdge
        case trailingEdge
        case point(CGPoint)
    }
    
    static let viewIds: (explore: String, listen: String, notset: String) = ("views.explore", "views.listen", "views.none")
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State var scrollPosition: ScrollPosition = .leadingEdge
    
    @State var isExpanded = false
    
    @State var heartLevel: HeartLevel = .full
    
    @AppStorage("selectedViewId") var selectedViewId: String = viewIds.notset
    @State var peopleViewBounds: CGRect? = nil
    @State var navbarViewBounds: CGRect? = nil
    @State var filterText = ""
    
    @Namespace var animation
    
    @Binding var playroom: Musicroom?
    @Binding var currentUser: User?
    
    public init(playroom: Binding<Musicroom?>, currentUser: Binding<User?>){
        self._playroom = playroom
        self._currentUser = currentUser
    }
    
    @State var filteredTracks: [Playable] = SEED_DATA.tracks
    
    @State var preview: AppPreview? = nil
    
    
    public var body: some View {
        
        return GeometryReader() { geoProxy in
            ZStack(){
                ScrollViewReader() { (proxy: ScrollViewProxy) in
                    ScrollView(.horizontal, showsIndicators: false){
                        HStack(alignment: .top, spacing: .zero){
                            ExploreView(geoProxy: geoProxy, playroom: self.$playroom, selectedViewId: self.$selectedViewId)
                                .frame(width: screenWidth)
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
                                .id(Self.viewIds.explore)
                            
                            ListenView(geoProxy: geoProxy, tracks: self.$filteredTracks, tabbarExpaned: self.$isExpanded,
                                       preview: self.$preview, filterText: self.$filterText, animation: animation,
                                       playroom: self.$playroom, currentUser: self.$currentUser)
                                .frame(width: screenWidth)
                                .onChange(of: self.filterText) { term in
                                    let term = self.filterText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                    
                                    guard !self.filterText.isEmpty else {
                                        self.filteredTracks = SEED_DATA.tracks
                                        return
                                    }
                                    
                                    self.filteredTracks = SEED_DATA.tracks.filter() { track in
                                        return track.artistName.lowercased().contains(term) || track.title.lowercased().contains(term)
                                    }
                                }
                                .id(Self.viewIds.listen)
                        }
                        //.background(Images.joliIconRounded.image.blur(radius: screenWidth, opaque: true))
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
                            }
                        }
                    }
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { gesture in
                                self.offset = gesture.translation
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
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded() { value in
                                
                                guard appCoordinator.keyboardHeight > 0 else {
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
                    .onAppear() {
                        
                        guard self.selectedViewId != Self.viewIds.notset else {
                            self.selectedViewId = Self.viewIds.listen
                            return
                        }
                        
                        withAnimation(){
                            proxy.scrollTo(self.selectedViewId)
                        }
                    }
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

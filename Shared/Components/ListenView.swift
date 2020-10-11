//
//  ListenView.swift
//  Joli
//
//  Created by Anthony Chinwo on 16/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore

struct ShakeEffect: GeometryEffect {
    
    var position: CGFloat
    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }
    
    init(shakes: Int) {
        position = CGFloat(shakes)
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        return ProjectionTransform(CGAffineTransform(translationX: -30 * sin(position * 2 * .pi), y: 0))
    }
    
}

struct ShakeButtonView: View {
    @State var invalidAttempts = 0
    
    var body: some View {
        VStack {
            Button(action: {
                self.invalidAttempts += 1
            }) { Text("Shake") }
            Rectangle()
                .fill(Color.purple)
                .frame(width: 200, height: 200)
                .modifier(ShakeEffect(shakes: invalidAttempts * 2))
                .animation(Animation.linear)
        }
    }
}

struct ListenView: JoliView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    let geoProxy: GeometryProxy
    @Binding var tracks: [Playable]
    @Binding var tabbarExpaned: Bool
    @Binding var preview: AppPreview?
    @Binding var filterText: String
    
    @State var peopleViewBounds: CGRect? = nil
    @State var navbarViewBounds: CGRect? = nil
    @State var roomControlViewBounds: CGRect? = nil
    
    var animation: Namespace.ID
    @Binding var playroom: Musicroom?
    @Binding var currentUser: User?
    @State var scrollProxy: ScrollViewProxy? = nil
    
    @State private var membership: [PlayroomMembership] = SEED_DATA.users.map() { user in
                    guard user.id != 3 else {
                        return PlayroomMembership(inviteStatus: .pending, activityStatus: .offline, playroomId: 3, user: user)
                    }
        
                    let act = [PlayroomMembership.ActivityStatus.offline,
                               PlayroomMembership.ActivityStatus.online].randomElement()!
        
                    let mem = PlayroomMembership(inviteStatus: .accepted,
                                                 activityStatus: act,
                                                 playroomId: 3, user: user)
                    return mem
                }
    
    var body: some View {
//        let users: [UserIdentifiable] = SEED_DATA.users.map() { user in
//            guard user.id != 3 else {
//                return PlayroomMembership(inviteStatus: .pending, activityStatus: .offline, playroomId: 3, user: user)
//            }
//
//            let act = [PlayroomMembership.ActivityStatus.offline,
//                       PlayroomMembership.ActivityStatus.online].randomElement()!
//
//            let mem = PlayroomMembership(inviteStatus: .accepted,
//                                         activityStatus: act,
//                                         playroomId: 3, user: user)
//            return mem
//        }
        return ZStack(){
            ScrollViewReader() { scrollProxy in
                GeometryReader() { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        //                VStack(){
                        //                    Text("Playing View").font(.largeTitle)
                        //                }
                        //                .frame(width: screenWidth, height: screenWidth)
                        //                .onAppear(){
                        //                    print("[ListenView] playing view appeared")
                        //                }
                        //                .onDisappear() {
                        //                    print("[ListenView] playing view disappeared")
                        //                }
                        TrackList(tracks: self.$tracks, preview: $preview, playroom: self.$playroom)
                            //.padding(.top, geoProxy.safeAreaInsets.top)
                            //.padding(.top, roomControlViewBounds == nil ? geoProxy.safeAreaInsets.top : roomControlViewBounds?.height)
                            .padding(.top, proxy.frame(in: .named("playroom-controls-space")).minY)//== nil ? .zero : navbarViewBounds?.height)
                            .padding(.bottom, peopleViewBounds == nil ? .zero : peopleViewBounds?.height)
                    }
                }
                .onAppear() {
                    self.scrollProxy = scrollProxy //
                }
            }
            .frame(maxWidth: screenWidth)
            
            VStack(spacing: .zero) {
                Spacer()
                Divider()
                ListenTabbarView(users: membership, isExpanded: $tabbarExpaned, searchText: self.$filterText, preview: self.$preview, playroom: self.$playroom)
                    .padding(.bottom, geoProxy.safeAreaInsets.bottom)
                    .frame(width: screenWidth)
                    .onFrameChange() { rect in
                        DispatchQueue.main.async {
                            self.peopleViewBounds = rect
                        }
                    }
                    .background(BlurView(.systemUltraThinMaterialLight))
                //Color.white.blur(radius: 20).opacity(0.9))
                //.anchorPreference(key: MyAnchorPreferenceKey.self, value: .bounds) { [MyAnchorPreferenceData(bounds: $0)] }
            }
            //.offset(x: appCoordinator.tabbar., y: )
            .zIndex(100)
            
            VStack(spacing: .zero) {
                HStack(spacing: .zero){
                    Spacer()
                }
                .animation(.easeIn)
                .frame(width: screenWidth, height: geoProxy.safeAreaInsets.top)
                .background(Color.white.opacity(0.89))
                .onFrameChange() { rect in
                    DispatchQueue.main.async {
                        self.navbarViewBounds = rect
                    }
                }
                
                Group(){
                    if let playroom = playroom {
                        
                        let a = SEED_DATA.tracks.first!
                        let b = SEED_DATA.tracks[16]
                        let c = SEED_DATA.tracks[SEED_DATA.tracks.count - 3]
                        
                        HStack(alignment: .center){
                            NetworkImage(string: a.albumCoverUrl) {
                                Text("Oops")
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 2.36, style: .continuous))
                            .onTapGesture {
                                withImpact(.soft, animated: .easeInOut) {
                                    scrollProxy?.scrollTo(a.uri, anchor: .center)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 1){
                                NetworkImage(string: b.albumCoverUrl) {
                                    Text("Oops 2")
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 2.36, style: .continuous))
                                .frame(width: 40, height: 40)
                                Text("Up Next")
                                    .font(Font.footnote.weight(.thin))
                                    .foregroundColor(Color.primary)
                            }
                            .frame(height: 56)
                            .onTapGesture {
                                withImpact(.soft, animated: .easeInOut) {
                                    scrollProxy?.scrollTo(b.uri, anchor: .center)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 1){
                                NetworkImage(string: c.albumCoverUrl) {
                                    Text("Oops 3")
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 2.36, style: .continuous))
                                .frame(width: 40, height: 40)
                                Text("Runner-up")
                                    .font(Font.footnote.weight(.thin))
                                    .foregroundColor(Color.primary)
                            }
                            .frame(height: 56)
                            .onTapGesture {
                                withImpact(.soft, animated: .easeInOut) {
                                    scrollProxy?.scrollTo(c.uri, anchor: .center)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                HStack(alignment: .center){
                                    Text("in")
                                        .font(Font.subheadline)
                                        .foregroundColor(Color.gray)
                                    Text(playroom.name)
                                        .font(Font.headline)
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: screenWidth / 1.8)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                Text("by Obialo")
                                    .font(Font.footnote.weight(.thin))
                                    .foregroundColor(Color.secondary)
                            }.onTapGesture {
                                self.preview = .view() {
                                    VStack(){
                                        Spacer()
                                        Button(){
                                            withAnimation() {
                                                self.playroom = nil
                                                self.preview = nil
                                            }
                                        } label: {
                                            Text("Exit \"\(playroom.name)\"?")
                                                .font(.title2)
                                        }
                                        .cornerRadius(12)
                                        Spacer()
                                    }
                                    .background(Color.clear)
                                    .padding()
                                    .eraseToAnyView()
                                }
                            }
                        }
                        .padding(.horizontal, Sizing.small * 0.6)
                        .padding([.horizontal, .bottom], Sizing.small * 0.5)
                        .background(Color.white.opacity(0.90))
                        
                        
                    } else {
//                        HStack(){
//                            Spacer()
//                            ShakeButtonView()
//                        }
                    }
                }
                .coordinateSpace(name: "playroom-controls-space")
                    .onFrameChange() { rect in
                        DispatchQueue.main.async {
                            self.roomControlViewBounds = rect
                        }
                    }
                Divider()
                
                AppPreviewView(preview: self.$preview, currentUser: self.$currentUser, animation: animation)
                    .frame(maxWidth: screenWidth)
                    .frame(minWidth: screenWidth, maxHeight: screenHeight)
                    .background(BlurView(.extraLight))
                    //.padding(.top, 1)
                    .padding(.bottom, self.peopleViewBounds?.height.advanced(by: 1))
                    .offset(x: 0, y: self.preview == nil ? screenHeight : 0)
                    .animation(.spring())
                
            }
        }
    }
}

//struct ListenView_Previews: PreviewProvider {
//    static var previews: some View {
//        ListenView()
//    }
//}

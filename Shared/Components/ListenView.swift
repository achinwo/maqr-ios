//
//  ListenView.swift
//  Joli
//
//  Created by Anthony Chinwo on 16/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore

struct ListenView: JoliView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    let geoProxy: GeometryProxy
    @Binding var tracks: [Track]
    @Binding var tabbarExpaned: Bool
    @Binding var preview: AppPreview?
    @Binding var filterText: String
    
    @State var peopleViewBounds: CGRect? = nil
    @State var navbarViewBounds: CGRect? = nil
    var animation: Namespace.ID
    @Binding var playroom: Musicroom?
    @Binding var currentUser: User?
    
    var body: some View {
        let users: [UserIdentifiable] = SEED_DATA.users.map() { user in
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
        return ZStack(){
            ScrollView(.vertical, showsIndicators: true) {
                TrackList(tracks: self.$tracks, preview: $preview)
                    //.padding(.top, geoProxy.safeAreaInsets.top)
                    .padding(.top, navbarViewBounds == nil ? .zero : navbarViewBounds!.height)
                    .padding(.bottom, peopleViewBounds == nil ? .zero : peopleViewBounds!.height)
            }
            .frame(maxWidth: screenWidth)
            
            VStack(spacing: .zero) {
                Spacer()
                Divider()
                ListenTabbarView(users: users, isExpanded: $tabbarExpaned, searchText: self.$filterText, preview: self.$preview, playroom: self.$playroom)
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
            //.offset(x: appCoordinator.tabbar., y: /*@START_MENU_TOKEN@*/10.0/*@END_MENU_TOKEN@*/)
            .zIndex(100)
            
            VStack(spacing: .zero) {
                HStack(spacing: .zero){
                    Spacer()
                }
                .frame(width: screenWidth, height: geoProxy.safeAreaInsets.top)
                .background(Color.white.opacity(0.70))
                .onFrameChange() { rect in
                    DispatchQueue.main.async {
                        self.navbarViewBounds = rect
                    }
                }
                Divider()
                AppPreviewView(preview: self.$preview, currentUser: self.$currentUser, animation: animation)
                    .frame(maxWidth: screenWidth)
                    .frame(minWidth: screenWidth, maxHeight: screenHeight)
                    .background(BlurView(.extraLight))
                    .padding(.top, 1)
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

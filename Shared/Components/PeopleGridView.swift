//
//  PeopleGridView.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import LetterAvatarKit

//protocol User {
//    var name: String { get }
//}
//
//extension JoliCore.User: User {
//    
//}

public struct PersonGenericImage: View {
    public var body: some View {
        return GeometryReader() { proxy in
            Image(systemName: "person.fill")
            .resizable()
                //.frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .foregroundColor(.gray)
            .background(Colors.lightGray.opacity(0.7))
                .offset(x: 0, y: proxy.size.height * 0.2)
            .background(Colors.lightGray.opacity(0.7))
        }
        .clipShape(Circle())
    }
}

public struct InvitePeopleView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public var body: some View {
        let view = VStack(alignment: .center){
            HStack(alignment: VerticalAlignment.top){
                let width = UIFont.preferredFont(forTextStyle: .title2).pointSize
                Spacer()
                Images.joliIconRounded.image
                    .resizable()
                    .frame(width: width * 2, height: width * 2)
                    .padding()
                
                VStack(alignment: .leading){
                    Text("Invite a friend")
                        .font(Font.largeTitle.weight(.light))
                    Text("to ")
                        .foregroundColor(.gray)
                        .fontWeight(.regular)
                        .font(Font.headline)
                        + Text("Wiz Party")
                        .fontWeight(.light)
                        .font(Font.headline)
                }
                .padding(.bottom, Sizing.medium)
                Spacer()
                Spacer()
            }
            Divider()
            // Include
            PersonGenericImage()
                .frame(idealWidth: screenWidth / 1.9, idealHeight: screenWidth / 1.9)
                .fixedSize()
                .padding([.top, .bottom], Sizing.large)
            
            HStack(){
                Button() {
                    print("Share view")
                    appCoordinator.share(text: "https://api.jolimc.com/join/")
                } label: {
                    Label("Copy link", systemImage: "link")
                }
                .font(.headline)
                .accentColor(.primary)
                .padding()
                
                Button(){
                    print("share via email")
                } label: {
                    Label("Enter email", systemImage: "envelope.circle.fill")
                    
                }
                .accentColor(.primary)
                .font(.headline)
                .padding()
                .alignmentGuide(.leading) { d in d[.leading] }
            }
            Divider().padding()
            
            Link(destination: Urls.appclips) {
                VStack(){
                    Label("Scan AppClip barcode to join in", systemImage: "viewfinder.circle").font(Font.footnote.weight(.light)).foregroundColor(.secondary)
                    Images.appclipBarcodeClearExample.image
                        .resizable()
                        .aspectRatio(contentMode: ContentMode.fit)
                        .padding()
                        //.padding(.top, Sizing.medium)
                        .frame(width: screenWidth / 2, height: screenWidth / 2, alignment: .center)
                        .fixedSize()
                }
                
            }
            Spacer()
        }
        return view
    }

}

struct PeopleGridView: JoliView {
    
    let rows = [
        GridItem(.fixed(100)),
    ]
    
    @Binding var users: [UserIdentifiable]
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @Namespace var localNamespace
    
    var currentUser: UserIdentifiable? {
        return users.first() { $0.isOwnDevice }
    }
    
    public init(users: Binding<[UserIdentifiable]>, _ onUserTapGesture: ((GestureType, UserIdentifiable?) -> Void)? = nil){
        self._users = users
        self.gestureCallback = onUserTapGesture
    }
    
    var body: some View {
        let width = Sizing.xxxLarge * 0.7
        let grid = HStack(alignment: .center) {
            
            if let currentUser = currentUser {
                Image(systemName: "person.crop.circle")
                    .renderingMode(.original)
                    .resizable()
                    .font(.system(size: width, weight: Font.Weight.ultraLight, design: .default))
                    .frame(width: width, height: width)
                    .onTapGesture {
                        self.gestureCallback?(.tap, currentUser)
                    }
                Divider().accentColor(.primary)
            }
            
            Image(systemName: "plus.circle")
                .renderingMode(.original)
                .resizable()
                .font(.system(size: width, weight: Font.Weight.ultraLight, design: .default))
                .frame(width: width, height: width)
                .foregroundColor(.gray)
                .onTapGesture(){
                    self.gestureCallback?(.tap, nil)
                }
                .matchedGeometryEffect(id: "preview", in: appCoordinator.namespace ?? localNamespace)
            
            ForEach(0 ..< users.count) { idx in
                let user = users[idx]
                
                Image(uiImage: UIImage.makeLetterAvatar(withUsername: user.displayName.name ?? "Anonymous")!)
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: width, height: width)
                    .clipShape(Circle())
                    .overlay(
                        Group() {
                            
                            if let member = user as? PlayroomMembership, member.inviteStatus == .pending {
                                Text("Invited")
                                    .fontWeight(.thin)
                                    .padding([.leading, .trailing], 4)
                                    .foregroundColor(.white)
                                    .background(Color.secondary)
                                    .font(.caption2)
                                    .clipShape(Capsule())
                            } else if let member = user as? PlayroomMembership {
                                Circle()
                                    .fill(member.activityStatus == .online ? Color.green : Color.gray)
                                    .frame(width: max(width / 4, 15), height: max(width / 4, 15))
                            }
                        }
                        .offset(x: width / 3, y: width / 3)
                    ).onTapGesture {
                        //self.heartLevel = self.heartLevel != .full ? self.heartLevel.next : .empty
                        print("Tapping Image: \(Sizing.xxLarge)")
                        self.gestureCallback?(.tap, user)
                    }.onLongPressGesture {
                        self.gestureCallback?(.longpress, user)
      
                    }
            }
        }
        
        return grid
    }
    
    public enum GestureType {
        case tap
        case longpress
    }
    
    private var gestureCallback: ((GestureType, UserIdentifiable?) -> Void)? = nil
    
    @State var isDragging = false
    @State var offset: CGSize = .zero
    
}



struct PeopleGridView_Previews: PreviewProvider {
    
    @State static var isExpanded = true
    
    static var previews: some View {
        let users = SEED_DATA.users
        return VStack() {
            PeopleGridView(users: .constant(users)).padding()
            Spacer()
        }
    }
}

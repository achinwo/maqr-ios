//
//  PeopleGridView.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore

#if !os(macOS)
import LetterAvatarKit
#endif

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

enum CodeType: Int {
    case appClip = 1
    case qr = 2
    
    var label: String {
        switch self {
        case .appClip:
            return "App Clip"
        case .qr:
            return "QR"
        }
    }
}

public struct InvitePeopleView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @State var playroom: Room?
    @State private var selection: CodeType = .appClip
    @State var retries: Int = .zero
    
    @State var appclipLoadError: Error? = nil {
        didSet {
            guard retries == .zero, appclipLoadError != nil else {
                return
            }
            
            DispatchQueue.main.async {
                self.selection = .qr
            }
        }
    }
    
    let appclipGenIndex: Int
    
    init(playroom: Room?){
        self._playroom = State(initialValue: playroom)
        self.appclipGenIndex = Array(0..<18).randomElement() ?? 13
    }
    
    private func resolveQrCodeUrl(_ url: URL, width: Int = 120, height: Int = 120) -> URL? {
        let urlQuery = "chs=\(width)x\(height)&cht=qr&chl=\(url.absoluteString)&chof=.png"
        guard
            let serviceUrl = URL(string: "https://image-charts.com/chart?\(urlQuery)&choe=UTF-8") else {
            return nil
        }
        
        return serviceUrl
    }
    
    public var contentView: some View {
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
                        + Text(playroom?.name ?? Strings.appName)
                        .fontWeight(.light)
                        .font(Font.headline)
                }
                .padding(.bottom, Sizing.medium)
                Spacer()
                Spacer()
            }
            Divider()
            // Include
            if let url = playroom?.inviteUrl(for: appCoordinator.activeAuth?.user, fallback: playroom?.inviteUrl),
               let qrUrl = resolveQrCodeUrl(url) {
                
                HStack(){
                    Spacer()
                    Picker("Scan Code Type", selection: self.$selection) {
                        Image(systemName: "applelogo").tag(CodeType.appClip)
                        Image(systemName: "qrcode").tag(CodeType.qr)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    Spacer()
                }
                .padding()
                
                Group(){
                    if selection == .appClip {
                        Link(destination: Urls.appclips) {
                            NetworkImage(string: "\(url.absoluteString).png?index=\(appclipGenIndex)&logo=none") { image, error in
                                //print("[\(Self.self)#appclipcode] error loading \(url.absoluteString): \(String(describing: error))")
                                defer {
                                    self.retries += 1
                                }
                                
                                guard error == nil else {
                                    self.appclipLoadError = error
                                    return
                                }
                                
                                self.appclipLoadError = nil
                                
                            } content: {
                                Images.appclipBarcodeClearExample.image
                                    .resizable()
                                    .aspectRatio(contentMode: ContentMode.fit)
                                    .overlay(
                                        BlurView(.prominent)
                                                .clipShape(Circle())
                                                .opacity(0.8)
                                    )
                            }
                            .frame(maxWidth: screenWidth / 2, maxHeight: screenWidth / 2)
                        }
                        .frame(idealWidth: screenWidth / 2, idealHeight: screenWidth / 2)
                    } else if selection == .qr {
                        QrCodeImageView(targetUrl: qrUrl)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 12)
                            )
                            .frame(maxWidth: screenWidth / 2, maxHeight: screenWidth / 2)
                    }
                    
                    if self.appclipLoadError != nil, selection == .appClip {
                        Label("Unable to generate App Clip code at this time", systemImage: "xmark.octagon.fill")
                            .lineLimit(3)
                            .foregroundColor(.systemRed)
                            .padding()
                    } else {
                        Label("Scan \(selection.label) code to join in", systemImage: selection == .qr ? "qrcode.viewfinder" : "viewfinder.circle")
                            .font(Font.footnote.weight(.light))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                Divider().padding()
            }
            
            PersonGenericImage()
                .frame(width: screenWidth / 3, height: screenWidth / 3, alignment: .center)
                .fixedSize()
                .padding([.top, .bottom], Sizing.large)
            
            HStack(){
                Button() {
                    print("Share view")
                    guard let playroom = playroom else {
                        return
                    }
                    
                    appCoordinator.share(room: playroom)
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
            Spacer()
        }
        return view
    }

}

struct PeopleGridView: JoliView {
    
    let rows = [
        GridItem(.fixed(100)),
    ]
    
    @Binding var playroom: Playroom?
    
    @State var users: [PlayroomMembership] = []
    @State var selectedUser: UserIdentifiable? = nil
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @Namespace var localNamespace
    
    public init(playroom: Binding<Playroom?>, _ onUserTapGesture: ((GestureType, UserIdentifiable?) -> Void)? = nil){
        self.gestureCallback = onUserTapGesture
        self._playroom = playroom
    }
    
    var contentView: some View {
        let width = Sizing.xxxLarge * 0.7
        let grid = HStack(alignment: .center) {
            
            if let room = playroom {
                let createdBy: UserIdentifiable = self.users.first(where: { $0.user.id == room.createdByUser.id }) ?? room.createdByUser
                UserAvatarView(user: createdBy, width: width)
                    .onTapGesture {
                        self.gestureCallback?(.tap, createdBy)
                    }
                    .onReceive(room.$membership) { membership in
                        self.users = membership
                    }
                    
                Divider().accentColor(.primary)
            }
            
            Image(systemName: "plus.circle")
                .resizable()
                .font(.system(size: width, weight: Font.Weight.ultraLight, design: .default))
                .foregroundColor(.primary)
                .frame(width: width, height: width)
                .onTapGesture(){
                    self.gestureCallback?(.tap, nil)
                }
                .matchedGeometryEffect(id: "preview", in: appCoordinator.namespace ?? localNamespace)
            
            let otherUsers = self.users.filter() { $0.user.id != playroom?.musicroom.createdById }
            ForEach(otherUsers) { user in
                UserAvatarView(user: user, width: width)
                    .scaleEffect(selectedUser?.emailAddress.email == user.emailAddress.email ? 1.16 : 1)
//                    .scaleEffect(x: selectedUser == user ? 1.2 : 1,
//                                 y: selectedUser == user ? 1.2 : 1)
                    .onTapGesture {
                        //self.heartLevel = self.heartLevel != .full ? self.heartLevel.next : .empty
                        print("Tapping Image: \(Sizing.xxLarge)")
                        
                        selectedUser = selectedUser?.emailAddress.email == user.emailAddress.email ? nil : user
                        self.gestureCallback?(.tap, user)
                    }.onLongPressGesture {
                        self.gestureCallback?(.longpress, user)
      
                    }
                    .id(user.emailAddress.email)
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

public struct UserAvatarView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public let user: UserIdentifiable
    public let width: CGFloat
    
    public var contentView: some View {
        let url = (user.imageLarge != nil ?
                    URL(string: "images/\(user.imageLarge!)", relativeTo: api.baseUrlHttp)
                    : nil)
        
        #if os(macOS)
        let dummyImage = UIImage(systemName: "person")!
        #else
        let dummyImage = UIImage.makeLetterAvatar(withUsername: user.displayName.name ?? "Anonymous")!
        #endif
        
        return NetworkImage(url: url) {
                    Image(platformImage: dummyImage)
                        .resizable()
                        .renderingMode(.original)
                }
                .frame(width: width, height: width)
                .clipShape(Circle())
                .overlay(
                    Group() {
                        
                        if let member = user as? PlayroomMembership, member.inviteStatus == .pending {
                            Text("Invited")
                                .fontWeight(.thin)
                                .padding([.leading, .trailing], 4)
                                .foregroundColor(.primary)
                                .background(Color.secondary)
                                .font(.caption2)
                                .clipShape(Capsule())
                        } else if let member = user as? PlayroomMembership {
                            Circle()
                                .fill(member.activityStatus == .online ? Color.green : Color.gray)
                                .overlay(
                                    Circle()
                                        .stroke(member.activityStatus == .online ? Color.green : Color.systemBackground, lineWidth: 0.5)
                                )
                                .frame(width: max(width / 4, 15), height: max(width / 4, 15))
                        }
                    }
                    .offset(x: width / 3, y: width / 3)
                )
    }
}


//struct PeopleGridView_Previews: PreviewProvider {
//
//    @State static var isExpanded = true
//
//    static var previews: some View {
//        let users = SEED_DATA.users
//        return VStack() {
//            PeopleGridView(users: .constant(users)).padding()
//            Spacer()
//        }
//    }
//}

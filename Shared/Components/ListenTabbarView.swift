//
//  ListenTabbarView.swift
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


struct BlurView: UIViewRepresentable {
    
    let style: UIBlurEffect.Style
    
    init(_ style: UIBlurEffect.Style = .systemMaterial) {
        self.style = style
    }
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: self.style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: self.style)
        uiView.isUserInteractionEnabled = false
    }
    
}


struct ListenTabbarView: JoliView {
    
    @Binding var isExpanded: Bool
    @Binding var preview: AppPreview?
    @State var users: [UserIdentifiable]
    @Binding var searchText: String
    
    @State var isSearching = false
    @State var searchbarActive = false
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State var volume: CGFloat = 30
    @Binding var playroom: Musicroom?
    
    @State var hearts: Hearts? = nil {
        
        didSet {
            self.heartsForegroundColor = hearts == nil || hearts!.score <= HeartLevel.empty.rawValue ? Color.gray : Color.red
        }
        
    }
    
    @Namespace var localNamespace
    
    @State var isDragging = false
    @State var offset: CGSize = .zero
    
    public init(users: [UserIdentifiable], isExpanded: Binding<Bool>? = nil, searchText: Binding<String>? = nil, preview: Binding<AppPreview?>? = nil, playroom: Binding<Musicroom?>){
        
        self._playroom = playroom
        self._users = State(initialValue: users)
        self._isExpanded = isExpanded ?? .constant(true)
        self._searchText = searchText ?? .constant("")
        self._preview = preview ?? .constant(.userProfile(SEED_DATA.users.first!.builder()))
    }
    
    var stickyHeaderView: some View {
        RoundedRectangle(cornerRadius: 25.0, style: .continuous)
            .fill(Color.gray)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .overlay(
                Text("Section")
                    .foregroundColor(Color.white)
                    .font(.largeTitle)
            )
    }
    
    @State var requestingVote: Int? = nil
    @State var heartsForegroundColor: Color = Color.red
    
    var body: some View {
        var label = ""
        
        if self.isExpanded {
            label = "\(label)\(users.count)" //•
        }
        
        let mainView = DisclosureGroup(isExpanded: self._isExpanded) {
            
            ScrollView(.horizontal) {
                PeopleGridView(users: self.$users) { (gestureType, user) in
                    
                        guard let user = user else {
                            withImpact(.soft, animated: .spring()){
                                self.preview = .view(.vertical) {
                                    return InvitePeopleView(playroom: playroom)
                                        .padding(.top, Sizing.xLarge)
                                        .environmentObject(self.appCoordinator).eraseToAnyView()
                                }
                                self.isExpanded = false
                            }
                            return
                        }
                        
                        switch gestureType {
                            case .tap:
                                if user.isOwnDevice {
                                    self.preview = .userAccount
                                    self.isExpanded = false
                                } else if case .userProfile(let currentUser) = self.preview,
                                          currentUser.emailAddress.email == user.emailAddress.email {
                                    self.preview = nil
                                } else {
                                    self.preview = .userProfile(user)
                                }
                            case .longpress:
                                withImpact(.medium, animated: .spring()) {
                                    self.preview = .userProfile(user)
                                    self.isExpanded = false
                                }
                        }
                    }
                    .padding()
            }
            .accentColor(.primary)
            .background(Colors.lightGray.opacity(0.3))
            .cornerRadius(Sizing.large)
            .animation(.spring())
        } label: {
            
            let dragGesture = DragGesture()
                .onChanged { value in self.offset = value.translation }
                .onEnded { _ in
                    withAnimation {
                        self.offset = .zero
                        self.isDragging = false
                    }
                }
            
            // a long press gesture that enables isDragging
            let pressGesture = LongPressGesture()
                .onEnded { value in
                    withImpact(.medium, animated: .interactiveSpring()) {
                        self.isDragging = true
                    }
                }
            
            // a combined gesture that forces the user to long press then drag
            let combined = pressGesture.sequenced(before: dragGesture)
                .onEnded(){ gesture in
                    self.isDragging = false
                }
            
            
            HStack(){
                
                Button(){
                    self.searchbarActive.toggle()
                    self.devicesBarActive = false
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(Font.title2.weight(self.searchbarActive ? .light : .ultraLight))
                }
                
                Spacer()
                Button(){
                    self.devicesBarActive.toggle()
                    self.searchbarActive = false
                } label: {
                    Image(systemName: "hifispeaker")
                }
                .font(Font.title.weight(self.devicesBarActive ? .light : .ultraLight))
                
                if playroom != nil {
                    Spacer()
                    JoyMeterView($hearts, textStyle: .title3, foregroundColor: self.$heartsForegroundColor)
                        //.background(Image(systemName: "heart.fill").font(.title).foregroundColor(.black))
                        .font(Font.title.weight(.ultraLight))
                        .onReceive(appCoordinator.voteRequestedSubject) { requesting in
                            self.requestingVote = requesting
                        }
                        .scaleEffect(self.requestingVote == nil ? 1 : 0.7)
                        //.scaleEffect(isDragging ? 1.5 : 1)
                        .offset(offset)
                        .modifier(ShakeEffect(shakes: insufficientPointsAttempt * 2))
                        .onTapGesture() {
                            withImpact(.soft, animated: .spring()) {
                                self.isExpanded.toggle()
                            }
                        }
                        .gesture(combined)
                    //.offset(x: !(self.isExpanded || users.isEmpty) ? Sizing.small / 2 * -1 : 0, y: 0)
                    //.alignmentGuide(.custom) { dims in dims[.custom] }
                }
                Spacer()
                
                if playroom == nil {
                    Image(systemName: "person")
                        .font(Font.title.weight(self.preview == .userAccount ? .light : .thin))
                        .onTapGesture {
                            withImpact {
                                self.preview = .userAccount
                                self.isExpanded = false
                            }
                        }
                } else {
                    Image(systemName: "person.2")
                        .font(Font.title2.weight(self.isExpanded ? .light : .thin))
                        .overlay(
                            Text(label)
                                .font(Font.caption.weight(.light))
                                .offset(x: UIFont.preferredFont(forTextStyle: .title2).pointSize, y: 0)
                        )
                        .onTapGesture(){
                            withAnimation(){
                                self.isExpanded.toggle()
                            }
                        }
                        .onLongPressGesture {
                            withImpact(.rigid) {
                                self.preview = .view() {
                                    InvitePeopleView(playroom: playroom)
                                        .padding(.top, Sizing.xLarge)
                                        .eraseToAnyView()
                                }
                            }
                        }
                }
                
                Spacer()
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(Font.title3.weight(self.isExpanded ? .light : .thin))
                    .foregroundColor(Color.gray)
                    .onTapGesture(){}
                
            }
            .accentColor(.primary)
            .padding()
            .padding(.trailing, .zero)
            .frame(minWidth: screenWidth / 2)
            .background(Color.gray.opacity(0.001))
            .offset(x: Sizing.small)
            .onTapGesture(){
                withAnimation(){
                    self.isExpanded.toggle()
                }
            }
        }
        .accentColor(.clear)
        
        
        return VStack(alignment: .center, spacing: .zero){
            
            if self.searchbarActive {
                SearchBar(text: self.$searchText, isEditing: self.$isSearching)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Colors.lightGray.opacity(self.isSearching ? 0 : 0.9), lineWidth: 1))
                    .padding(.top, Sizing.medium)
                    .background(Color.clear)
                    .matchedGeometryEffect(id: "listenbar-addon", in: localNamespace)
            } else if self.devicesBarActive {
                VStack() {
                    DevicesView() { _ in
                        self.devicesBarActive.toggle()
                    }
                    Divider()
                }
                .background(Color.clear)
                .matchedGeometryEffect(id: "listenbar-addon", in: localNamespace)
            }
            mainView
        }
        .onReceive(appCoordinator.userHeartsSubject) { hearts in
            self.hearts = hearts
            print("[ListenTabbarView] hearts: \(String(describing: hearts))")
        }
        .onReceive(self.appCoordinator.$insufficientPointsAttempt) { insufficientPointsAttempt in
            self.insufficientPointsAttempt = insufficientPointsAttempt
        }
        .onChange(of: self.isSearching) { value in
            if self.searchbarActive && !value {
                self.searchbarActive = false
            }
        }
        .accentColor(.primary)
        .padding(.trailing, Sizing.medium)
        .padding(.leading, Sizing.medium)
        .padding(.bottom, isExpanded ? Sizing.medium : .zero)
        .animation(.spring())
        
    }
    
    
    @State var insufficientPointsAttempt = 0
    @State var devicesBarActive = false
}

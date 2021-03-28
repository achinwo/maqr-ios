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
import Combine

public struct AppView2: JoliView {
    
    public enum ScrollPosition: Equatable {
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
    
    @State var filteredTracks: [Playable] = []
    @State var preview: AppPreview? = nil
    @State var votePubCancel: AnyCancellable? = nil
    @State private var offset = CGSize.zero
    
    @Namespace var animation
    
    @Binding var playroom: Playroom?
    
    @Binding var currentUser: User?
    let websocket: Socket
    
    public init(playroom: Binding<Playroom?>, currentUser: Binding<User?>, websocket: Socket){
        self._playroom = playroom
        self._currentUser = currentUser
        self.websocket = websocket
    }
    
    @State var reconnectingTasks: [DispatchWorkItem] = []
    @Environment(\.scenePhase) var scenePhase
    
    func scheduleSocketReconnect(){
        
        guard reconnectingTasks.isEmpty && !self.websocket.isConnected && [.background, .active].contains(scenePhase) else {
            return
        }
        
        let maxDelay = 300000 // 5 minutes
        
        func getDelay(for n: Int) -> Int {
            let delay = Int(pow(2.0, Double(n))) * 1000
            let jitter = Int.random(in: 0...1000)
            return min(delay + jitter, maxDelay)
        }
        
        let now = Date()
        
        var attempt = 1
        var delay = getDelay(for: attempt)
        
        while delay < maxDelay {
            
            let thisAttempt = attempt
            
            print("[App#scheduleSocketReconnect] scheduling retry: \(attempt) - \(now.advanced(by: Double(delay) / 1000))")
            
            let workItem = DispatchWorkItem {
                // Your async code goes in here
                print("[App#scheduleSocketReconnect] triggered retry: \(thisAttempt) - \(Date())")
                
                guard !self.websocket.isConnected && [.background, .active].contains(scenePhase) else {
                    self.reconnectingTasks.cancelAll()
                    self.reconnectingTasks.removeAll()
                    return
                }
                
                self.websocket.connect()
                print("[App#scheduleSocketReconnect] connect called: \(thisAttempt)")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay), execute: workItem)
            self.reconnectingTasks.append(workItem)
            
            attempt += 1
            delay = getDelay(for: attempt)
        }
        
    }
    
    
    var playbackRefreshRate: TimeInterval = 0.15
    
    static var defaultIdleTime: Double {
        return Strings.appName == "Joli" ? 4 : 6
    }
    
    let cb: Publishers.Smooth<PlayState.Publisher, String>.StateGetter = { (state, now) in
        
        let uid = state.trackUri == nil ? nil : state.trackUri! + state.id.description
        
        guard let duration = state.durationMs, state.playingState == .playing else {
            return (id: uid, value: state.progressMs, duration: nil, idleTimeout: defaultIdleTime)
        }
        
        return (id: uid, value: state.progressMs, duration: TimeInterval(duration), idleTimeout: defaultIdleTime)
    }
    
    private func updatePublishers() {
        let publisher: PlayState.Publisher = self.websocket.publish(PlayState.self, interval: self.playbackRefreshRate, path: \.progressMs, resolver: cb)
        
        let votesPubs: QueuedTrackVote.Publisher = self.websocket
            .deserialize(QueuedTrackVote.self)
            .autoconnect()
            .multicast() {
                return PassthroughSubject<QueuedTrackVote, SocketError>()
            }
            .autoconnect()
            .eraseToAnyPublisher()
        
        self.appCoordinator.playStatePublisher = publisher
        self.appCoordinator.votesPublisher = votesPubs
    }
    
    func onConnectionStateChanged(_ socket: Socket, _ connected: Bool){
        print("[App#onConnectionStateChanged] connected: \(connected)")
        
        guard connected else {
            scheduleSocketReconnect()
            return
        }
        
        socket.write(topic: "/subscribe", body: ["subject": "PLAYER_STATE_NOW_PLAYING"]) { error in
            print("[App] updated subscriptions: PLAYER_STATE_NOW_PLAYING - \(String(describing: error))")
            
            
            DispatchQueue.main.async {
                self.reconnectingTasks.cancelAll()
                self.reconnectingTasks.removeAll()
                self.updatePublishers()
            }
        }
        
        socket.write(topic: "/subscribe", body: ["subject": "PLAYER_STATE_CHANGED"]) { error in
            
            guard error == nil else {
                print("[App] updated subscriptions (error): PLAYER_STATE_CHANGED - \(String(describing: error))")
                return
            }
            
            
            self.websocketCancel = self.websocket
                .sink() { completion in
                    websocketCancel?.cancel()
                    websocketCancel = nil
                } receiveValue: { message in
                    
                    guard case let .text(_, _, _, subjectValue) = message, let subject = subjectValue, subject == "PLAYER_STATE_CHANGED" else {
                        return
                    }
                    
                    self.appCoordinator.playStateChangeSubject.send(Date())
                }
        }
        
        socket.write(topic: "/subscribe", body: ["subject": "database_updates"]) { error in
            print("[App] updated subscriptions: database_updates - \(String(describing: error))")
        }
    }
    
    @State var websocketCancel: AnyCancellable? = nil
    
    func assertWebsocketConnected() {
        //print("[AppView#assertWebsocketConnected] attempting...")
        self.websocket.write(topic: "/status", body: [:]) { error in
            
            guard let error = error else {
                logger.info("[assertWebsocketConnected] asserting websocket connected successful")
                return
            }
            
            logger.error("[assertWebsocketConnected] asserting websocket connected: \(String(describing: error))")
            appCoordinator.globalErrorHandler()(error)
        }
    }
    
    public var contentView: some View {
        
        return GeometryReader() { geoProxy in
            ZStack(){
                ScrollViewReader() { (proxy: ScrollViewProxy) in
                    ScrollView(.horizontal, showsIndicators: false){
                        HStack(alignment: .top, spacing: .zero){
                            ExploreView(geoProxy: geoProxy, playroom: self.$playroom, selectedViewId: self.$selectedViewId, websocket: self.websocket)
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
                                       playroom: self.$playroom, currentUser: self.$currentUser, websocket: self.websocket)
                                .frame(width: screenWidth)
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
                            // Tree House as Clubhouse
                            // Personal Inventory Management Tool as Objects
                            print("[AppView2] scrolling to: \(value)")
                            proxy.scrollTo(value)
                        }
                    }
                    .onChange(of: playroom) { room in
                        guard playroom != nil else {
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
                }
            }
            .ignoresSafeArea(.all, edges: [.top, .bottom])
            .frame(width: geoProxy.size.width, height: geoProxy.size.height)
        }
        .frame(minWidth: screenWidth)
        .onReceive(appCoordinator.$activeSessionToken) { sessionId in
            self.assertWebsocketConnected()
        }
        .onReceive(appCoordinator.connectionStateSubject) { info in
            self.onConnectionStateChanged(websocket, info.state == ConnectionState.connected)
        }
        .onReceive(appCoordinator.voteRequestedSubject) { voting in
            print("[App#voteRequestedSubject] voting: \(String(describing: voting))")
            guard voting != nil else {
                print("[App#voteRequestedSubject] voting, aborting...")
                return
            }
            
            self.assertWebsocketConnected()
        }
        .onReceive(appCoordinator.playRequestedSubject) { playing in
            guard playing != nil else { return }
            
            self.assertWebsocketConnected()
        }
        .onReceive(appCoordinator.appViewScrollPosition) { scrollPosition in
            switch scrollPosition {
                case .leadingEdge:
                    self.selectedViewId = Self.viewIds.explore
                case .trailingEdge:
                    self.selectedViewId = Self.viewIds.listen
                default:
                    break
            }
        }
        .onReceive(appCoordinator.$votesPublisher) { votePublisher in
            votePubCancel?.cancel()
            
            guard let votePublisher = votePublisher else {
                votePubCancel = nil
                return
            }
            
            self.votePubCancel = votePublisher.sink() { completion in
                votePubCancel?.cancel()
            } receiveValue: { value in
                logger.debug("[AppView] recieved vote: \(value)")
                appCoordinator.voteCastSubject.send(value)
            }
        }
    }
    
}


//struct AppView2_Previews: PreviewProvider {
//    static var previews: some View {
//        let coord = AppCoordinator()
//        AppView2(playroom: .constant(SEED_DATA.musicrooms.first), currentUser: .constant(SEED_DATA.users.first))
//            .environmentObject(coord)
//    }
//}

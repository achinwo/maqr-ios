//
//  ContentView.swift
//  JoliClip
//
//  Created by Anthony Chinwo on 26/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliPlayground
import JoliCore
import AlertToast
//#if canImport(StoreKit)
//import StoreKit
//#endif

import UIImageColors
import Combine

struct SizePreferenceKey: PreferenceKey {
    typealias Value = CGSize

    static var defaultValue: Value = .zero

    static func reduce(value: inout Value, nextValue: () -> Value) {
        let next = nextValue()
        
        guard next != .zero else { return }
        value = next
        //value = value + nextValue()
    }
}

public struct PlayroomView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    @Binding public var playroom: Playroom
    @Binding public var showRecommended: Bool
    @Binding public var preview: AppPreview?
    @State public var authcallback: () -> Void
    
    @State private var votesByQueuedTrackId: [Int: Int] = [:]
    @State private var strip: PlayroomHeaderView.TrackStrip = (nil, nil, nil)
    @State private var tracks: [Playable] = []
    
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    @State private var pendingAction: (() -> Void)? = nil
    
    public var contentView: some View {
        
        let binding = Binding<Playroom?>(){
            return self.playroom
        } set: { value in
            guard let value = value else { return }
            
            self.playroom = value
        }
                
        let header: PlayroomHeaderView = PlayroomHeaderView(
            playroom: binding,
            strip: $strip,
            preview: $preview,
            tracks: $tracks,
            scrollProxy: $scrollProxy,
            isDismissable: .constant(false)
        )
        
        let installMessage = "Install the full experience, search \"Joli\" in App Store for the ability to create your own playrooms and more"
        
        return ZStack(alignment: .top) {
            
            ScrollViewReader(){ scrollProxy in
                ScrollView(){
                    VStack(){
                        
                        HStack(){
                            Text(installMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondaryLabel)
                                .lineLimit(5)
                            Spacer()
                            Button(){
                                self.showRecommended.toggle()
                            } label: {
                                Text("Get ") + Text("\(Strings.appSymbol.stringValue)oli").fontWeight(.semibold)
                            }
                        }
                        .padding()
                        
                        TrackList(tracks: self.$tracks, playroom: binding, addonView: self.addonView)
                            .padding(.top, safeAreaInsets.top + Sizing.xxxLarge * 2)
                            .frame(width: screenWidth)
                            .id("tracks-list")
                        
                        Divider().padding(.vertical)
                        
                        HStack(){
                            Text(installMessage)
                                .lineLimit(5)
                                .font(.subheadline)
                                .foregroundColor(.secondaryLabel)
                            Spacer()
                            Button(){
                                self.showRecommended.toggle()
                            } label: {
                                Text("Get ") + Text("\(Strings.appSymbol.stringValue)oli").fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .padding(.bottom, safeAreaInsets.bottom)
                    }
                    .padding(.top, safeAreaInsets.top + Sizing.xxxLarge * 2)
                    .padding(.bottom, safeAreaInsets.bottom)
                }
                .onReceive(playroom.$votesByQueuedTrackId, assign: \.votesByQueuedTrackId, target: self)
                .onAppear(){
                    self.scrollProxy = scrollProxy
                    scrollProxy.scrollTo("tracks-list", anchor: .top)
                }
            }
            
            VStack(spacing: .zero){
                header
                    .overlay(
                        GeometryReader(){ proxy in
                            Color.clear.preference(key: SizePreferenceKey.self, value: proxy.size)
                        }
                    )
                    .padding(.horizontal, Sizing.small * 0.6)
                    .padding([.horizontal, .bottom], Sizing.small * 0.5)
                    .padding(.top, safeAreaInsets.top)
                    .background(Color.systemBackground.opacity(0.9))
                Spacer()
            }
            .frame(width: screenWidth)
        }
        .onReceive(playroom.$queue){ tracks in
            self.tracks = tracks
        }
        .onReceive(appCoordinator.$activeSessionToken) { token in
            guard let pending = self.pendingAction, token != nil else { return }
            pending()
        }
        .onReceive(appCoordinator.voteRequestedSubject) { requested in
            self.requestingVoteTrackId = requested
        }
        .onReceive(appCoordinator.voteCastSubject) { vote in
            self.voteCasted = vote
        }
        .onReceive(playroom.$strip, assign: \.strip, target: self)
        .onAppear(){
            DispatchQueue.main.asyncAfter(deadline: .now() + 2){
                ready.toggle()
            }
        }
    }
    
    @State var ready = false
    @State var requestingVoteTrackId: Int? = nil
    @State var voteCasted: QueuedTrackVote? = nil
    
    func addonView(track: Playable, playStates: [PlayState], colors: UIImageColors?) -> some View {
        
        return Group() {
            if let track = track as? QueuedTrack {
                
                let scaleX: CGFloat = self.requestingVoteTrackId == track.id || self.voteCasted?.queuedTrackId == track.id ? 1.32 : 1
                let scaleY: CGFloat = self.requestingVoteTrackId == track.id || self.voteCasted?.queuedTrackId == track.id ? 1.32 : 1
                
                let heart: Binding<Hearts?> = Binding() { () -> Hearts? in
                    
                    guard let count: Int = self.votesByQueuedTrackId[track.id] else {
                        return Hearts(score: HeartLevel.empty.rawValue)
                    }
                    
                    return Hearts(score: CGFloat(count) * HeartLevel.quarter.rawValue)
                    
                } set: { (heart, trasacton) in
                    
                }
                
                JoyMeterView(heart, textStyle: UIFont.TextStyle.title2, backgroundColor: Color.systemRed.opacity(0.5))
                    .padding()
                    .padding(.trailing, Sizing.medium)
                    .foregroundColor(colors?.secondaryColor ?? Color.primary)
                    .modifier(ShakeEffect(shakes: self.appCoordinator.insufficientPointsAttempt * 2))
                    .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
                    .onReceive(appCoordinator.voteCastSubject) { vote in
                        self.voteCasted = vote
                    }
                    .onTapGesture {
                        guard self.appCoordinator.voteRequestedSubject.value == nil else {
                            return
                        }
                        
                        let performVote = { () async -> Void in
                            
                            do {
                                let _ = try await self.appCoordinator.voteTrack(track)
                                guard let currentCount = self.votesByQueuedTrackId[track.id] else { return }
                                
                                var votes = self.votesByQueuedTrackId
                                votes[track.id] = currentCount + 1
                                
                                self.votesByQueuedTrackId = votes
                            } catch {
                                guard let error = error as? AppCoordinator.ActionError else {
                                    print("[ListenView] unrecognised error: \(error)")
                                    return
                                }
                                
                                switch error {
                                    case .insufficientHeartPoints:
                                        self.appCoordinator.insufficientPointsAttempt += 1
                                }
                            }
                        }
                        
                        guard appCoordinator.activeAuth != nil else {
                            let message = "Voting requires a verified identity, sign in with Spotify?"
                            appCoordinator.withAlert("Sign-In Required", message: message, label: "Sign In") {
                                self.pendingAction = {
                                    Task() { await performVote() }
                                    self.pendingAction = nil
                                }
                                authcallback()
                            }
                            return
                        }
                        
                        Task() { await performVote() }
                    }
            }
        }
    }
    
}


struct ContentView<PlaybackControllerType: PlaybackController>: JoliContentView {
    
    @State var websocketCancel: AnyCancellable? = nil
    @State var toastInfo: (alert: AlertToast, onDismiss: (Bool) -> Void)? = nil
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    @Binding var playroom: Playroom?
    @Binding var currentUser: User?
    
    @State var errorMessage: String? = nil
    @State var scrollProxy: ScrollViewProxy? = nil
    
    let websocket: Socket
    
    @State var loadingView = false
    
    @State var filterText: String = ""
    @State var preview: AppPreview? = nil
    @State var tabbarExpaned = false
    
    @State var currentLocation: AppLocation = .home
    @Binding var showRecommended: Bool
    
    @State var tracks: [Playable] = []
    
    @State var tracksFiltered: [Playable] = []
    public var localPlaybackController: PlaybackControllerType
    
    public init(playroom: Binding<Playroom?>, currentUser: Binding<User?>, websocket: Socket, localPlaybackController: PlaybackControllerType, showRecommended: Binding<Bool>){
        self._playroom = playroom
        self._currentUser = currentUser
        self.websocket = websocket
        self.localPlaybackController = localPlaybackController
        self._showRecommended = showRecommended
    }
    
    var refreskButton: some View {
        Button() {
            
            guard case let .invited(inviteId) = self.currentLocation else {
                return
            }
            
            Task() { try? await self.fetchPlayroomByInviteId(inviteId) }
            
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }
    
    var contentView: some View {
        //        NavigationView() {
        //
        //                    ScrollViewReader() { scrollProxy in
        //                        ScrollView(.vertical, showsIndicators: true) {
        
        
        return ZStack(){
            
            VStack(alignment: .center, spacing: .zero){
                if loadingView {
                    ProgressView("Loading Playroom").padding()
                } else if let error = errorMessage {
                    Text(error).font(Font.title.weight(.light)).padding()
                    refreskButton//.padding(.top, UIScreen.main.bounds.height / 1.4)
                } else if let playroom = playroom {
                    PlayroomView(playroom: .constant(playroom), showRecommended: $showRecommended, preview: event != nil && eventEntitlement == nil ? .constant(nil) : $preview) {
                        localPlaybackController.authorize(token: nil)
                    }
                    .background(Color.systemBackground)
                    .frame(width: screenWidth)
                    .id(playroom.name)
                    .onAppear(){
                        
                        guard let event = event else { return } //, eventEntitlement == nil else { return }
                        
                        self.preview = .event(event, eventEntitlement) { entitlement in
                                self.eventEntitlement = entitlement
                                self.preview = nil
                            
                                guard entitlement.rejectedAt != nil else {
                                  return
                                }
                            
                            self.presentToast("Sorry you can't make it", type: .systemImage("info.circle", .blue), onDismiss: { _ in })
                        
                        }
                    }
                } else {
                    Text(Self.GENERIC_ERROR_MESSAGE).font(Font.title.weight(.light)).padding()
                    refreskButton//.padding(.top, UIScreen.main.bounds.height / 1.4) i/0mzKhO
                }
            }
            
            AppPreviewView(preview: self.$preview, currentUser: .constant(nil), isDismissable: event != nil && eventEntitlement == nil ? .constant(false) : $previewDismissable, animation: animation)
                .frame(maxWidth: screenWidth)
                .frame(minWidth: screenWidth, maxHeight: screenHeight)
                .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                .padding(.top, self.headerSize.height + safeAreaInsets.top)
                //.padding(.bottom, self.peopleViewBounds?.height.advanced(by: 1))
                .offset(x: 0, y: self.preview == nil ? screenHeight : 0)
                .animation(.spring())
        }
        .onPreferenceChange(SizePreferenceKey.self) { size in
            self.headerSize = size
        }
        .edgesIgnoringSafeArea([.top, .bottom])
        .frame(width: screenWidth, height: screenHeight, alignment: .center)
        .onReceive(appCoordinator.$currentLocation, assign: \.currentLocation, target: self)
        .onChange(of: currentLocation) { location in
            print("LOACTION Changed: \(location)")
            switch location {
                case .invited(let inviteId):
                    Task() { try? await self.fetchPlayroomByInviteId(inviteId) }
                case .rsvp(let eventUid):
                //   self.errorMessage = Self.GENERIC_ERROR_MESSAGE
                    Task() {
                        do {
                            try await self.fetchPlayroomByEventId(eventUid)
                        } catch {
                            self.appCoordinator.globalErrorHandler()(error)
                        }
                    }
                default:
                    Task() { try? await self.fetchPlayroomByInviteId("mnsv9A") } // Joli Live
            }
        }
        .onReceive(appCoordinator.connectionStateSubject) { info in
            self.onConnectionStateChanged(websocket, info.state == ConnectionState.connected)
        }
        .onReceive(appCoordinator.voteRequestedSubject) { voting in
            guard voting != nil else {
                return
            }
            
            self.assertWebsocketConnected()
        }
        .onReceive(appCoordinator.playRequestedSubject) { playing in
            guard playing != nil else { return }
            
            self.assertWebsocketConnected()
        }
        .onAppear() {
            if [.home, .unset].contains(appCoordinator.currentLocation) {
                Task() { try? await self.fetchPlayroomByInviteId("mnsv9A") }
            }
            
            print("Location: \(currentLocation)")
        }
    }
    
    @State var event: Event? = nil
    @State var eventEntitlement: Entitlement? = nil
    @State var previewDismissable = true
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @State var headerSize: CGSize = .zero
    @Environment(\.colorScheme) var colorScheme
    @Namespace var animation
    @State var creatingRoomEntitlement: Bool = false
    
    static var GENERIC_ERROR_MESSAGE: String {
        return "An error occured while loading your Playroom invitation, please try again later."
    }
    
    func fetchPlayroomByEventId(_ eventUid: String) async throws -> Void { //Promise<(event: Event, room: Musicroom)?> {
        self.loadingView = true
        
        defer {
            self.loadingView = false
        }
        
        let events = try await Event.all(where: [.uuid: eventUid as AnyObject],
                                              limit: 1, baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
        guard let event = events.first else {
            return
        }
        
        let room = try await Musicroom.findById(id: event.roomId, baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
        guard let room = room else { return }
        
        
        let ents = try await Entitlement.all(where: [.type: "event" as AnyObject], baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
        
        guard let entitlement = ents.first(where: { $0.userId == appCoordinator.activeAuth?.user.id && $0.targetRecordId == event.id }) else {
            return
        }
        
        
        let play = Playroom(musicroom: room, socket: websocket, api: api)
        self.playroom = play
        self.event = event
        self.eventEntitlement = entitlement
                
        let _ = try await play.updateQueuedTracks()
        let artists = try await play.fetchSpotifyTopArtists()
        let filtered = artists.filter() { $0.imageMedium != nil }
        
        play.artists = filtered
    }
    
    @discardableResult
    @MainActor
    func fetchPlayroomByInviteId(_ inviteId: String) async throws -> Entitlement {
        let url = "/i/\(inviteId)"
        self.loadingView = true
        
        defer {
            self.loadingView = false
        }
        
        do {
            let entitlement = try await HttpMethod.Fetch.get(url: url, dataType: Entitlement.self, baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            self.errorMessage = nil
            guard let musicroom = entitlement.musicroom else {
                return entitlement
            }
            
            let play = Playroom(musicroom: musicroom, socket: websocket, api: api)
            self.playroom = play
            
            let _ = try await play.updateQueuedTracks()
            let artists = try await play.fetchSpotifyTopArtists()
            let filtered = artists.filter() { $0.imageMedium != nil }
            play.artists = filtered
            
            return entitlement
        } catch {
            self.appCoordinator.globalErrorHandler()(error)
            print("[fetchPlayroomByInviteId] error: \(error)")
            self.errorMessage = Self.GENERIC_ERROR_MESSAGE
            
            throw error
        }
        
    }
    
    private func filterTracks(_ tracks: [Playable], _ q: String) -> [Playable] {
        
        let query = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !query.isEmpty else {
            return tracks
        }
        
        return self.tracks.filter() { track in
            
            for fld in [track.artistName, track.title,] {
                if fld.lowercased().contains(query) {
                    return true
                }
            }
            
            return false
        }
    }
}


//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}

//
//  ListenView.swift
//  Joli
//
//  Created by Anthony Chinwo on 16/08/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import JoliApi
import Promises
import Combine
import UIImageColors
//import Sourceful

#if canImport(StoreKit)
import StoreKit
#endif

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

struct ScaleEffect: GeometryEffect {
    
    var scaleX: CGFloat
    var scaleY: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(scaleX, scaleY) }
        set {
            scaleX = newValue.first
            scaleY = newValue.second
        }
    }
    
    init(x: CGFloat, y: CGFloat) {
        self.scaleX = x
        self.scaleY = y
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        return ProjectionTransform(CGAffineTransform(scaleX: scaleX, y: scaleY))
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
                .fill(Color.systemPurple)
                .frame(width: 200, height: 200)
                .modifier(ShakeEffect(shakes: invalidAttempts * 2))
                .animation(Animation.linear)
        }
    }
}

public extension Search.Engine {
    
    typealias SearchMethod2 = (String, Set<Search.Category>, Int) -> AnyPublisher<Spotify.SearchResult?, Never>
    
    func search(_ q: String, _ categories: Set<Search.Category>, limit: Int = 6, search searchFn: SearchMethod2) -> AnyPublisher<Spotify.SearchResult?, Never> {
        let supported = categories.filter(){ supportedCategories.contains($0) }
        
        guard !supported.isEmpty else {
            return Just(nil).eraseToAnyPublisher()
        }
        
        return searchFn(q, supported, limit)
    }
    
}

struct ListenView: JoliView {
    
    
    class Model: ObservableObject {
        
        @Published var triggeredSwipeRefresh = false {
            didSet {
                if oldValue == false && triggeredSwipeRefresh == true {
                    print("[ListenView] trigger refresh")
                    self.lastResfreshedAt = Date()
                }
            }
        }
        
        @Published var lastResfreshedAt: Date? = nil
        
    }
    
    @EnvironmentObject var appCoordinator: AppCoordinator
        
    @State var tracks: [Playable] = []
    
    @Binding var tabbarExpaned: Bool
    @Binding var preview: AppPreview?
    @Binding var filterText: String
    
    @State var peopleViewBounds: CGRect? = nil
    @State var navbarViewBounds: CGRect? = nil
    @State var roomControlViewBounds: CGRect? = nil
    @State var pullToRefreshCancel: AnyCancellable? = nil
    
    @State var playStateCancel: AnyCancellable? = nil
    @State var showRecommended: Bool = false
    @AppStorage("announcements/released-open-beta") var seenOpenBetaAnnouncement = false
    
    var animation: Namespace.ID
    @Binding var playroom: Playroom?
    @Binding var currentUser: User?
    @State var scrollProxy: ScrollViewProxy? = nil
    
    @State var votes: [QueuedTrackVote] = []
    let websocket: Socket
    
    init(tabbarExpaned: Binding<Bool>, preview: Binding<AppPreview?>, filterText: Binding<String>, animation: Namespace.ID, playroom: Binding<Playroom?>, currentUser: Binding<User?>, websocket: Socket) {
        self._tabbarExpaned = tabbarExpaned
        self._preview = preview
        self._filterText = filterText
        self.animation = animation
        self._playroom = playroom
        self._currentUser = currentUser
        self.websocket = websocket
    }
    
    @State var liveTracks: [Spotify.Track] = []
    @State var recentTracks: [Playable] = []
    @State var playrooms: [Musicroom] = []
    
    public struct SpotiftyTracksResponse: Codable {
        public var tracks: [Spotify.Track]
    }
    
    @State var loadingLiveTracks = false {
        didSet {
            if !loadingLiveTracks {
                self.loadingFinishedAt = Date()
            }
        }
    }
    @State var loadingPlayrooms = false
    
    private func loadPlayrooms() {
        self.loadingPlayrooms = true
        Musicroom.all(baseUrl: api.baseUrl.http, urlSession: api.urlSession)
            .then() { rooms  in
                self.playrooms = rooms
            }
            .catch(appCoordinator.globalErrorHandler())
            .always() {
                self.loadingPlayrooms = false
            }
    }
    
    private func loadLiveTracks() {
        
        self.loadingLiveTracks = true
        PlayState.all(baseUrl: api.baseUrl.http, urlSession: api.urlSession)
            .then() { states -> Promise<SpotiftyTracksResponse?> in
                //print("[PlayStates] states: \(states)")
                let tracks: Set<Track> = Set(states.compactMap() { $0.track })
                self.recentTracks = tracks.sorted() { $0.name > $1.name }
                
                let trackUris = states
                    .sorted(by: { $0.updatedAt > $1.updatedAt })
                    .compactMap() { state -> String? in
                        guard state.playingState == .playing, let isLocal = state.trackUri?.starts(with: "spotify:local:"), !isLocal else {
                            return nil
                        }
                        
                        return state.trackUri?.replacingOccurrences(of: "spotify:track:", with: "", options: .literal, range: nil)
                    }
                
                guard var comp = URLComponents(string: "/api/spotify/tracks"), !trackUris.isEmpty else {
                    return Promise(nil)
                }
                
                comp.queryItems = [
                    URLQueryItem(name: "ids", value: Set(trackUris).joined(separator: ","))
                ]
                
                return HttpMethod.Fetch.get(url: comp, dataType: SpotiftyTracksResponse.self, baseUrl: api.baseUrl.http, urlSession: api.urlSession)
                    .then(on: .main) { resp -> SpotiftyTracksResponse in
                        self.liveTracks = resp.tracks.sorted() { $0.name > $1.name }
                        return resp
                    }
                    .catch(appCoordinator.globalErrorHandler())
            }
            .catch(appCoordinator.globalErrorHandler())
            .always() {
                loadingLiveTracks = false
                self.refreshModel.triggeredSwipeRefresh = false
            }
    }
    
    
    @State var votesByTrack: [Int: [QueuedTrackVote]] = [:]
    @State var tripLine: CGFloat = 0
    @State var loadingFinishedAt: Date? = nil
    @GestureState private var dragOffset = CGSize.zero
    @State var requestingVoteTrackId: Int? = nil
    @State var isDragging = false {
        didSet {
            guard isDragging else { return }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, qos: .userInitiated) {
                self.isDragging = false
            }
        }
    }
    
    @State var needsRefreshSubject = PassthroughSubject<String, Never>()
    @State var needsRefreshCancel: AnyCancellable? = nil
    
    private func refreshContent(reason: String) {
        logger.debug("[loadLiveTracks] reason: \(reason)")
        self.loadLiveTracks()
        self.loadPlayrooms()
    }
    
    @State var voteCasted: QueuedTrackVote? = nil
    
    func assertWebsocketConnected() {
        self.websocket.write(topic: "/status", body: [:]) { error in
            
            guard let error = error else {
                logger.info("[assertWebsocketConnected] asserting websocket connected successful")
                return
            }
            
            logger.error("[assertWebsocketConnected] asserting websocket connected: \(String(describing: error))")
        }
    }
    
    func addonView(track: Playable, playStates: [PlayState], colors: UIImageColors?) -> some View {
        
        
        return Group() {
            if let track = track as? QueuedTrack,
               let room = playroom,
               let playlistUri = room.playlistUri,
               let playing = self.strip.playing as? QueuedTrack,
               playing.id == track.id,
               playing.isPlayable, track.isPlayable {
                
                Button() {
                    let state = playStates.first() { $0.email == room.createdByUser.email } ?? playStates.first
                    appCoordinator.play(track, positionMs: state?.progressMs, contextUri: playlistUri, device: appCoordinator.activeDeviceSubject.value)
                        .then() { state in
                            print("[ListenView] rejoining \(track.title) at \(String(describing: state?.progressMs)) - \(String(describing: state))")
                        }
                } label: {
                    Text("Rejoin").padding()
                }
                .font(.headline)
                .padding(.trailing, Sizing.medium)
                .buttonStyle(BlackWhiteButtonStyle(inverted: true))
                
            } else if let track = track as? QueuedTrack {
                
                let scaleX: CGFloat = self.requestingVoteTrackId == track.id || self.voteCasted?.queuedTrackId == track.id ? 1.32 : 1
                let scaleY: CGFloat = self.requestingVoteTrackId == track.id || self.voteCasted?.queuedTrackId == track.id ? 1.32 : 1
                
                let heart: Binding<Hearts?> = Binding() { () -> Hearts? in
                    
                    guard playroom != nil else {
                        return nil
                    }
                    
                    guard let count: Int = self.votesByTrack[track.id]?.count else {
                        return Hearts(score: HeartLevel.empty.rawValue)
                    }
                    
                    return Hearts(score: CGFloat(count) * HeartLevel.quarter.rawValue)
                    
                } set: { (heart, trasacton) in
                    
                }
                
                JoyMeterView(heart, textStyle: UIFont.TextStyle.title2, backgroundColor: Color.systemRed.opacity(0.5))
                    .padding()
                    .padding(.trailing, Sizing.medium)
                    .foregroundColor(colors?.secondaryColor ?? Color.primary)
                    .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
                    .onReceive(appCoordinator.voteCastSubject) { vote in
                        self.voteCasted = vote
                    }
                    .onTapGesture {
                        guard self.appCoordinator.voteRequestedSubject.value == nil else {
                            return
                        }
                        
                        self.appCoordinator.voteTrack(track)
                            .then() { vote in
                                guard !self.votes.contains(vote) else { return }
                                self.votes.append(vote)
                            }
                            .catch() { voteError in
                                
                                guard let error = voteError as? AppCoordinator.ActionError else {
                                    print("[ListenView] unrecognised error: \(voteError)")
                                    return
                                }
                                
                                switch error {
                                case .insufficientHeartPoints:
                                    self.appCoordinator.insufficientPointsAttempt += 1
                                }
                            }
                    }
            }
        }
    }
    
    @State var tracksFiltered: [Playable] = []
    @State var searchResult: Spotify.SearchResult? = nil
    @StateObject var model = SearchStore()
    @State var playPubCancel: AnyCancellable? = nil
    @State var searchResultCancel: AnyCancellable? = nil
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    @State var strip: (playing: Playable?, next: Playable?, runnerup: Playable?) = (nil, nil, nil)
    
    func setupSearch(){
        
        self.searchResultCancel = model.$query
            .removeDuplicates()
            .debounce(for: 0.3, scheduler: DispatchQueue.global(qos: .userInteractive))
            .map() { q -> AnyPublisher<Spotify.SearchResult?, Never> in
                
                guard !q.isEmpty else {
                    return Just(nil).eraseToAnyPublisher()
                }
                
                
                return spotifyEngine.search(q, [.tracks], limit: 4) { (q, categories, limit) ->
                    AnyPublisher<Spotify.SearchResult?, Never> in
                    
                    return Future<Spotify.SearchResult?, Never>() { promise in
                        api.searchSpotify(q: q, categories: categories, limit: limit)
                            .then(){ res in
                                promise(.success(res))
                            }
                            .catch() { error in
                                promise(.success(nil))
                                
                                logger.error("[searchSpotify] error: \(String(describing: error))")
                            }
                    }.eraseToAnyPublisher()
                }
            }
            .switchToLatest()
            .receive(on: RunLoop.main)
            .assign(to: \.searchResult, on: self)
        
    }
    
    @State var creatingRoomEntitlement = false
    
    var lobbyView: some View {
        ZStack(){
            LobbyView(recentTracks: self.$recentTracks, liveTracks: self.$liveTracks, playrooms: self.$playrooms, filterText: self.$filterText, isLoading: self.$loadingLiveTracks, preview: self.$preview) { room in
                self.tracks = []
                self.votes = []
                self.playroom = Playroom(musicroom: room, socket: self.websocket, api: api)
                
                guard let auth = appCoordinator.activeAuth, !room.entitlements.contains(where: { $0.userId == auth.user.id }) else {
                    return
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.preview = .view() {
                        VStack(){
                            Spacer()
                            Text(room.name).font(.largeTitle).padding().padding(.top, Sizing.xxxLarge)
                            Text(room.details).font(.subheadline).foregroundColor(.secondary).padding()
                            
                            if self.creatingRoomEntitlement {
                                ProgressView().padding()
                                    .matchedGeometryEffect(id: "entering-room", in: animation)
                            } else {
                                Button("Enter") {
                                    var entitlement = EntitlementRecord()
                                    entitlement.userId = auth.user.id
                                    entitlement.type = "musicroom"
                                    entitlement.targetRecordId = room.id
                                    entitlement.acceptedAt = Date()
                                    
                                    self.creatingRoomEntitlement = true
                                    entitlement.save(baseUrl: api.baseUrlHttp, urlSession: api.urlSession, on: .main)
                                        .then() { ent in
                                            logger.debug("[ListenView#lobbyView] created entitlement: \(ent)")
                                            self.preview = nil
                                        }
                                        .always {
                                            self.creatingRoomEntitlement = false
                                        }
                                }
                                .font(Font.title)
                                .padding()
                                .matchedGeometryEffect(id: "entering-room", in: animation)
                            }
                            
                            Spacer()
                        }.eraseToAnyView()
                    }
                }
            }
        }
        .frame(width: screenWidth)
        .background(Color.systemBackground)
    }
    
    @StateObject var refreshModel = Model()
    @State var trackRecommendations: [Playable] = []
    @State var queueRequested: (uri: String, playroom: Musicroom)? = nil
    
    var contentView: some View {
        ScrollViewReader() { scrollProxy in
            let isEmptySearchResult = self.searchResult?.tracks.isEmpty ?? true
            
            RefreshableScrollView(refreshing: self.$refreshModel.triggeredSwipeRefresh, showsIndicators: true) {
                
                VStack(alignment: .center, spacing: .zero){
                    
                    Group() {
                        self.searchResultView
                            .padding([.horizontal, .bottom])
                            .padding(.top, safeAreaInsets.top + 80)
                        Divider()
                    }
                    .background(Color.systemBackground)
                    .opacity(isEmptySearchResult ? 0 : 1)
                    .frame(height: isEmptySearchResult ? 0 : nil)
                    .animation(.easeInOut)
                    
                    if let playroom = playroom {
                        ZStack(){
                            TrackList(tracks: self.$tracksFiltered, votes: self.$votes, playroom: self.$playroom, addonView: self.addonView)
                                //.frame(width: screenWidth)
                                //.padding(.top, roomControlViewBounds == nil ? safeAreaInsets.top : roomControlViewBounds?.height)
                                .padding(.top, isEmptySearchResult ? safeAreaInsets.top + 100 : nil)
                                .background(Color.systemBackground)
                                .onReceive(playroom.$recommendations, assign: \.trackRecommendations, target: self)
                                .onReceive(self.appCoordinator.queueRequestedSubject) { val in
                                    self.queueRequested = val
                                }
                                .matchedGeometryEffect(id: "playroom/\(playroom.musicroom.id.description)", in: animation)//, properties: .frame, isSource: true)
                                .onReceive(playroom.$queue) { tracks in
                                    var tracksByMusicrooms: [Int: [QueuedTrack]] = [:]
                                    var allVotes: [QueuedTrackVote] = []
                                    
                                    for track in tracks.filter({ $0.isPlayable }) {
                                        var roomTracks = tracksByMusicrooms[track.roomId] ?? []
                                        
                                        guard !roomTracks.contains(track) else {
                                            continue
                                        }
                                        
                                        roomTracks.append(track)
                                        tracksByMusicrooms[track.roomId] = roomTracks
                                        
                                        guard let votes = track.votes, track.roomId == playroom.musicroom.id else {
                                            continue
                                        }
                                        
                                        allVotes.append(contentsOf: votes)
                                    }
                                    
                                    self.votes = allVotes
                                    self.tracks = tracksByMusicrooms[playroom.musicroom.id] ?? []
                                    self.tracksFiltered = self.filterTracks(self.tracks, self.filterText)
                                    
                                    self.strip = (
                                        playing: tracks.first,
                                        next: tracks.count > 1 ? tracks[1] : nil,
                                        runnerup: tracks.count > 2 ? tracks[2] : nil
                                    )
                                }
                                .onChange(of: self.votes) { votes in
                                    var mapping: [Int: [QueuedTrackVote]] = [:]
                                    
                                    for vote in votes {
                                        
                                        guard var existing = mapping[vote.queuedTrackId] else {
                                            mapping[vote.queuedTrackId] = []
                                            continue
                                        }
                                        
                                        existing.append(vote)
                                        mapping[vote.queuedTrackId] = existing
                                    }
                                    
                                    self.votesByTrack = mapping
                                }
                                .onAppear(){
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        guard let currentTrack = self.strip.playing else {
                                            return
                                        }
                                        withAnimation(){
                                            scrollProxy.scrollTo(currentTrack.uri, anchor: .center)
                                        }
                                    }
                                }
                        }
                        
                        HStack(alignment: .top){
                            Text("Suggestions")
                            Spacer()
                        }
                        .font(Font.largeTitle.weight(.thin))
                        .padding([.top, .horizontal])
                        .foregroundColor(.secondary)
                        
                        Divider().padding(.vertical)
                        
                        TrackList(tracks: $trackRecommendations) { (track, states, color) in
                            Image(systemName: "plus")
                                .font(queueRequested?.uri == track.uri ?  Font.title2.weight(.semibold) : Font.title2.weight(.thin))
                                .foregroundColor(.secondary)
                                .padding()
                                .disabled(queueRequested != nil)
                                .onTapGesture {
                                    print("[Search.ResultView] queue \(track.title)")
                                    self.appCoordinator.queueTrack(track, playroom: playroom.musicroom)
                                    playroom.recommendations = trackRecommendations.filter({ $0.uri != track.uri })
                                }
                                .scaleEffect(x: queueRequested?.uri == track.uri ? 0.8 : 1,
                                             y: queueRequested?.uri == track.uri ? 0.8 : 1)
                            }
                            //.frame(maxWidth: screenWidth)
                            //.padding(.horizontal)
                            .padding(.bottom, peopleViewBounds == nil ? .zero : peopleViewBounds?.height)
                            .id(playroom.themeGenreNames)//.background(Color.pink)
                        Spacer()
                    } else {
                        self.lobbyView
                            //.frame(minHeight: 68.0 * CGFloat(recentTracks.count + liveTracks.count) + CGFloat(screenHeight) + CGFloat(68.0 * CGFloat(playrooms.count) / 2.0))
                            .padding(.top, isEmptySearchResult ? Sizing.xxLarge * 2 : nil)
                            .background(Color.systemBackground)
                            .matchedGeometryEffect(id: "group1", in: animation, properties: .frame, isSource: true)
                    }
                }
                .frame(width: screenWidth)
                .onReceive(self.refreshModel.$lastResfreshedAt) { date in
                    guard date != nil else { return }
                    
                    self.refreshContent(reason: "swipe to refresh")
                }
            }
            .animation(.easeInOut)
            .onAppear() {
                self.scrollProxy = scrollProxy //
                self.needsRefreshSubject.send("listenview appeared")
            }
            
        }
        .onReceive(appCoordinator.voteCastSubject) { vote in
            
            guard let vote = vote,
                  !self.votes.contains(vote),
                  let queuedTracks = tracks as? [QueuedTrack],
                  queuedTracks.contains(where: { $0.id == vote.queuedTrackId }) else {
                return
            }
            
            self.votes.append(vote)
        }
        .onReceive(appCoordinator.globalPreviewSubject) { view in
            self.preview = view
        }
        .onReceive(appCoordinator.voteRequestedSubject) { requested in
            self.requestingVoteTrackId = requested
        }
        .onChange(of: self.filterText) { txt in
            print("[filterText] \(txt)")
            self.model.query = txt
            self.tracksFiltered = self.filterTracks(self.tracks, txt)
        }
        .onChange(of: self.playroom) { value in
            
            guard let room = value else {
                self.needsRefreshSubject.send("room changed")
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2){
                
                room.fetchSpotifyRecommendations()
                    .then(){ tracks in
                        room.recommendations = tracks.tracks
                        //print("[ListenView] got track recommm: \(tracks)")
                    }
                    .catch(self.appCoordinator.globalErrorHandler())
            }
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
    
    var searchResultView: some View {
        let header = HStack(){
            Label(){
                Text("Track Search")
            } icon: {
                Image(systemName: "magnifyingglass")
                    .font(Font.title.weight(.thin))
            }
            .foregroundColor(.secondary)
            .font(Font.largeTitle.weight(.thin))
            Spacer()
        }
        
        return VStack(){
            Section(header: header) {
                VStack(alignment: .leading, spacing: .zero){
                    ForEach(self.searchResult?.tracks ?? [], id: \.uri) { track in
                        TrackView2<Never>(track: .constant(track))
                            .id(track.uri)
                    }
                }
            }
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    @State var keyboardHeight: CGFloat = 0
    
    var body: some View {
        
        return ZStack(alignment: .top){
            self.contentView
                .frame(width: screenWidth, height: screenHeight)
                .simultaneousGesture(
                    TapGesture()
                        .onEnded() { value in
                            
                            guard appCoordinator.keyboardHeight > 0 else {
                                return
                            }
                            
                            appCoordinator.dismissKeyboard()
                        }
                )
            
            VStack(spacing: .zero) {
                Spacer()
                Divider()
                ListenTabbarView(isExpanded: $tabbarExpaned, searchText: self.$filterText, preview: self.$preview,
                                 playroom: self.$playroom)
                    .padding(.bottom, max(safeAreaInsets.bottom, keyboardHeight))
                    .frame(width: screenWidth)
                    .onFrameChange() { rect in
                        DispatchQueue.main.async {
                            self.peopleViewBounds = rect
                        }
                    }
                    .background(BlurView(colorScheme == .dark ? .systemThinMaterialDark : .systemUltraThinMaterialLight))
                //Color.white.blur(radius: 20).opacity(0.9))
                //.anchorPreference(key: MyAnchorPreferenceKey.self, value: .bounds) { [MyAnchorPreferenceData(bounds: $0)] }
            }
            .frame(width: screenWidth)
            .onReceive(appCoordinator.$keyboardHeight, assign: \.keyboardHeight, target: self)
            .onChange(of: votes) { votes in
                
                guard let playroom = playroom else {
                    self.strip = (nil, nil, nil)
                    return
                }
                
                playroom.fetchQueuedTracks(limit: 3)
                    .then() { tracks in
                        self.strip = (
                            playing: tracks.first,
                            next: tracks.count > 1 ? tracks[1] : nil,
                            runnerup: tracks.count > 2 ? tracks[2] : nil
                        )
                    }
            }
            .onChange(of: playroom) { room in
                
                guard let room = room else {
                    return
                }
                
                room.updateQueuedTracks()
            }
            .onReceive(self.appCoordinator.queueRequestedSubject) { req in
                
                guard let queued = req, let playroom = playroom, queued.room.id == playroom.musicroom.id else {
                    return
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                    playroom.updateQueuedTracks()
                }
            }
            .zIndex(100)
            
            VStack(spacing: .zero) {
                AppVisorView()
                    .animation(.easeIn)
                    .frame(width: screenWidth, height: safeAreaInsets.top)
                    .background(Color.systemBackground.opacity(0.89))
                    .onFrameChange() { rect in
                        DispatchQueue.main.async {
                            self.navbarViewBounds = rect
                        }
                    }
                
                Group(){
                    if playroom != nil {
                        PlayroomHeaderView(playroom: self.$playroom,
                                           strip: self.$strip,
                                           preview: self.$preview,
                                           tracks: self.$tracks,
                                           scrollProxy: self.$scrollProxy
                                           )
                            .padding(.horizontal, Sizing.small * 0.6)
                            .padding([.horizontal, .bottom], Sizing.small * 0.5)
                            .matchedGeometryEffect(id: "listen-header", in: animation)
                            .background(Color.systemBackground.opacity(0.90))
                            .frame(maxWidth: screenWidth)
                    } else {
                        HStack(alignment: .top){
                            Spacer()
                            //ShakeButtonView()
                            Text(Strings.appSymbol.stringValue)
                                .font(Font.title.weight(.thin))
                                .gradientForeground(colors: [Color.systemRed, Color.systemOrange, Color.systemYellow, Color.systemGreen, Color.systemBlue, Color.systemPurple, Color.systemPink])
                                .scaleEffect(x: self.loadingLiveTracks ? 1.6 : 1.0, y: self.loadingLiveTracks ? 1.6 : 1.0)
                                .onTapGesture {
                                    self.assertWebsocketConnected()
                                    self.refreshContent(reason: "logo tapped")
                                }
                                .background(
                                    Circle()
                                        .fill(Color.systemBackground.opacity(0.90))
                                        .scaleEffect(x: 1.4, y: 1.4)
                                )
                            
                            Spacer()
                        }
                        .matchedGeometryEffect(id: "listen-header", in: animation)
                    }
                }
                .animation(.easeInOut)
                .coordinateSpace(name: "playroom-controls-space")
                .onFrameChange() { rect in
                    DispatchQueue.main.async {
                        self.roomControlViewBounds = rect
                    }
                }
                
                
                #if canImport(StoreKit)
                Divider().opacity(self.playroom == nil ? 0 : 1).animation(.easeInOut)
                    .appStoreOverlay(isPresented: $showRecommended) {
                        SKOverlay.AppConfiguration(appIdentifier: Strings.appId, position: .bottomRaised)
                    }
                #else
                Divider().opacity(self.playroom == nil ? 0 : 1).animation(.easeInOut)
                #endif
                
                AppPreviewView(preview: self.$preview, currentUser: self.$currentUser, animation: animation)
                    .frame(maxWidth: screenWidth)
                    .frame(minWidth: screenWidth, maxHeight: screenHeight)
                    .background(BlurView(colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight))
                    .padding(.bottom, self.peopleViewBounds?.height.advanced(by: 1))
                    .offset(x: 0, y: self.preview == nil ? screenHeight : 0)
                    .animation(.spring())
                
            }
            .onReceive(appCoordinator.playStateChangeSubject) { timestamp in
                guard !self.loadingLiveTracks else { return }
                
                let waitTime = Int.random(in: 1..<3)
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(waitTime)) {
                    guard !self.loadingLiveTracks else { return }
                    
                    self.needsRefreshSubject.send("play state changed")
                }
            }
            .onReceive(appCoordinator.playRequestedSubject) { playable in
                guard playable != nil || !self.loadingLiveTracks else { return }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                    guard !self.loadingLiveTracks else { return }
                    
                    self.needsRefreshSubject.send("play requested")
                }
            }
            .onReceive(appCoordinator.connectionStateSubject) { state in
                guard state.state == .connected else { return }
                self.needsRefreshSubject.send("server connected")
            }
            .onAppear() {
                setupSearch()
                
                self.needsRefreshCancel?.cancel()
                
                self.needsRefreshCancel = self.needsRefreshSubject
                    .debounce(for: .seconds(2), scheduler: DispatchQueue.global(qos: .userInitiated))
                    .receive(on: DispatchQueue.main)
                    .sink() { reason in
                        print("[ListenView] recieved refresh request: \(reason)")
                        self.refreshContent(reason: reason)
                    }
                
                self.needsRefreshSubject.send("view appeared")
            }
            
            //if appCoordinator.is
            if self.showAnnouncements && appCoordinator.isSimulatorOrTestFlight && !self.seenOpenBetaAnnouncement {
                self.announcementBannerView
            }
            
        }
        .onAppear(){
            DispatchQueue.main.asyncAfter(deadline: .now() + 4){
                self.showAnnouncements = true
            }
        }
    }
    
    @State var showAnnouncements: Bool = false
    
    public var announcementBannerView: some View {
        VStack(alignment: .leading, spacing: .zero){
            Text("\(Strings.appSymbol.stringValue)oli is in Open Beta 🎉")
                .lineLimit(1)
                .padding(.horizontal)
                .font(.title)
                .foregroundColor(.white)
            Text("Get the offical app from the App Store")
                .lineLimit(3)
                .padding(.horizontal)
                .font(.subheadline)
                .padding(.bottom)
                .foregroundColor(.white)
            Spacer()
            HStack(){
                Spacer()
                Button("Dismiss") {
                    self.seenOpenBetaAnnouncement.toggle()
                }
                .foregroundColor(Color.secondaryLabel)
                .padding(.horizontal)
                //.font(Font.headline.weight(.light))
                
                Button("Get it") {
                    withImpact(.light) {
                        self.showRecommended.toggle()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.seenOpenBetaAnnouncement.toggle()
                    }
                }
                .padding(.horizontal)
                //.background(Color.gray.opacity(0.5))
                .overlay(
                         RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white, lineWidth: 1)
                )
                .foregroundColor(.white)
                .font(Font.title2)
                .padding(.horizontal)
            }
            .padding(.bottom)
            Spacer()
            Divider()
        }
        .frame(width: screenWidth)
        .padding(.top, safeAreaInsets.top)
        .frame(maxHeight: seenOpenBetaAnnouncement ? 0 : screenHeight * 0.2, alignment: .center)
        .opacity(seenOpenBetaAnnouncement ? 0 : 1)
        .animation(.easeInOut)
        .background(Color.blue.opacity(0.98))
    }

}

public struct TrackAddonView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public init() {
        
    }
    
    
    public var contentView: some View {
        EmptyView()
    }
    
}

public struct AppVisorView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets: EdgeInsets
    
    public var contentView: some View {
        HStack(spacing: .zero){
            //Spacer()
        }
    }
}

public extension Character {
    var stringValue: String {
        return String(self)
    }
}


//struct ListenView_Previews: PreviewProvider {
//    static var previews: some View {
//        ListenView()
//    }
//}

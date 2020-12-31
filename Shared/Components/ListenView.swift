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

public typealias Color = SwiftUI.Color
public typealias View = SwiftUI.View

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
                .fill(Color.purple)
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
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    let geoProxy: GeometryProxy
    
    @State var tracks: [Playable] = []
    
    @Binding var tabbarExpaned: Bool
    @Binding var preview: AppPreview?
    @Binding var filterText: String
    
    @State var peopleViewBounds: CGRect? = nil
    @State var navbarViewBounds: CGRect? = nil
    @State var roomControlViewBounds: CGRect? = nil
    @State var pullToRefreshCancel: AnyCancellable? = nil
    
    var animation: Namespace.ID
    @Binding var playroom: Musicroom?
    @Binding var currentUser: User?
    //    @State var activeDevice: Spotify.Device? = nil
    //    @State var devices: [Spotify.Device] = []
    @State var scrollProxy: ScrollViewProxy? = nil
    
    @State var votes: [QueuedTrackVote] = []
    
    init(geoProxy: GeometryProxy, tabbarExpaned: Binding<Bool>, preview: Binding<AppPreview?>, filterText: Binding<String>, animation: Namespace.ID, playroom: Binding<Musicroom?>, currentUser: Binding<User?>) {
        self.geoProxy = geoProxy
        self._tabbarExpaned = tabbarExpaned
        self._preview = preview
        self._filterText = filterText
        self.animation = animation
        self._playroom = playroom
        self._currentUser = currentUser
    }
    
    @discardableResult
    func fetchTracks(_ room: Musicroom) -> Promise<[QueuedTrack]> {
        
        return QueuedTrack.all(baseUrl: api.baseUrl.rawValue.http, urlSession: api.urlSession)
            .then() { tracks -> [QueuedTrack] in
                var tracksByMusicrooms: [Int: [QueuedTrack]] = [:]
                var allVotes: [QueuedTrackVote] = []
                
                for track in tracks.filter({ $0.isPlayable }) {
                    var roomTracks = tracksByMusicrooms[track.roomId] ?? []
                    
                    guard !roomTracks.contains(track) else {
                        continue
                    }
                    
                    roomTracks.append(track)
                    tracksByMusicrooms[track.roomId] = roomTracks
                    
                    guard let votes = track.votes, track.roomId == playroom?.id else {
                        continue
                    }
                    
                    allVotes.append(contentsOf: votes)
                }
                
                self.votes = allVotes
                self.tracks = tracksByMusicrooms[room.id] ?? []
                self.tracksFiltered = self.filterTracks(self.tracks, self.filterText)
                
                return tracksByMusicrooms[room.id] ?? []
            }
    }
    
    @State private var membership: [PlayroomMembership] = []
    
    //        SEED_DATA.users.map() { user in
    //        guard user.id != 3 else {
    //            return PlayroomMembership(inviteStatus: .pending, activityStatus: .offline, playroomId: 3, user: user)
    //        }
    //
    //        let act = [PlayroomMembership.ActivityStatus.offline,
    //                   PlayroomMembership.ActivityStatus.online].randomElement()!
    //
    //        let mem = PlayroomMembership(inviteStatus: .accepted,
    //                                     activityStatus: act,
    //                                     playroomId: 3, user: user)
    //        return mem
    //    }
    
    @State var liveTracks: [Spotify.Track] = []
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
        print("[loadLiveTracks] loading...")
        self.loadingPlayrooms = true
        Musicroom.all(baseUrl: api.baseUrl.http, urlSession: api.urlSession)
            .then() { rooms  in
                self.playrooms = rooms
            }
            .catch() { error in
                logger.error("[PlayrromsFetch] error: \(error)")
            }
            .always() {
                self.loadingPlayrooms = false
            }
    }
    
    private func loadLiveTracks() {
        print("[loadLiveTracks] loading...")
        self.loadingLiveTracks = true
        PlayState.all(baseUrl: api.baseUrl.http, urlSession: api.urlSession)
            .then() { states -> Promise<SpotiftyTracksResponse?> in
                //print("[PlayStates] states: \(states)")
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
                    .catch() { error in
                        logger.error("[SpotifyTracksFetch] \(comp) - \(error)")
                    }
            }
            .always() {
                loadingLiveTracks = false
            }
    }
    
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
    
    private func refreshContent() {
        self.loadLiveTracks()
        self.loadPlayrooms()
    }
    
    @State var votesByTrack: [Int: [QueuedTrackVote]] = [:]
    
    func addonView(track: Playable, colors: UIImageColors?) -> some View {
        Group() {
            if let track = track as? QueuedTrack,
               let playing = self.strip.playing as? QueuedTrack,
               playing.id == track.id, playing.isPlayable, track.isPlayable {
                
                Button() {
                    print("[ListenView] rejoining \(track.title)")
                } label: {
                    Text("Rejoin").padding()
                }
                .font(.headline)
                .padding(.trailing, Sizing.medium)
                .buttonStyle(BlackWhiteButtonStyle(inverted: true))
                
            } else if let track = track as? QueuedTrack {
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
                
                JoyMeterView(heart, textStyle: UIFont.TextStyle.title2, backgroundColor: Color.red.opacity(0.5))
                    .padding()
                    .padding(.trailing, Sizing.medium)
                    .foregroundColor(colors?.secondaryColor ?? Color.primary)
                    .scaleEffect(x: self.requestingVoteTrackId == track.id ? 1.32 : 1, y: self.requestingVoteTrackId == track.id ? 1.32 : 1, anchor: .center)
                    .onTapGesture {
                        guard self.appCoordinator.voteRequestedSubject.value == nil else {
                            return
                        }
                        
                        self.appCoordinator.voteTrack(track)
                            .then() { vote in
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
    
    @State var searchResultCancel: AnyCancellable? = nil
    
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
                                
                                logger.error("[searchSpotify] error: \(error)")
                            }
                    }.eraseToAnyPublisher()
                }
            }
            .switchToLatest()
            .receive(on: RunLoop.main)
            .assign(to: \.searchResult, on: self)
        
    }
        
    var lobbyView: some View {
        ZStack(){
            LobbyView(liveTracks: self.$liveTracks, playrooms: self.$playrooms, filterText: self.$filterText, isLoading: self.$loadingLiveTracks) { room in
                self.tracks = []
                self.votes = []
                self.playroom = room
            }
        }
        .frame(width: screenWidth)
        .background(Color.white)
    }
    
    var contentView: some View {
        ScrollViewReader() { scrollProxy in
            GeometryReader() { proxy in
                
                let dragGesture = DragGesture()
                    .updating($dragOffset) { (value, state, transaction) in
                        state = value.translation
                        
                        DispatchQueue.main.async {
                            self.isDragging = value.translation != .zero
                        }
                    }
                
                ScrollView(.vertical, showsIndicators: true) {
                    
                    let isEmptySearchResult = self.searchResult?.tracks.isEmpty ?? true
                    
                    VStack(){
                        
                        Group() {
                            self.searchResultView
                                .padding([.horizontal, .bottom])
                                .padding(.top, geoProxy.safeAreaInsets.top + 80)
                            Divider()
                        }
                        .background(Color.white)
                        .opacity(isEmptySearchResult ? 0 : 1)
                        .frame(height: isEmptySearchResult ? 0 : nil)
                        .animation(.easeInOut)
                        
                        if playroom == nil {
                            self.lobbyView
                                .frame(minHeight: screenHeight * 1.3)
                                .padding(.top, isEmptySearchResult ? Sizing.xxLarge * 2 : nil)
                                .background(Color.white)
                                .matchedGeometryEffect(id: "group1", in: animation, properties: .frame, isSource: true)
                        } else {
                            TrackList(tracks: self.$tracksFiltered, votes: self.$votes, preview: $preview, playroom: self.$playroom, addonView: self.addonView)
                                //.padding(.top, geoProxy.safeAreaInsets.top)
                                //.padding(.top, roomControlViewBounds == nil ? geoProxy.safeAreaInsets.top : roomControlViewBounds?.height)
                                .padding(.top, isEmptySearchResult ? geoProxy.safeAreaInsets.top + 100 : nil)
                                .padding(.bottom, peopleViewBounds == nil ? .zero : peopleViewBounds?.height)
                                .background(Color.white)
                                .matchedGeometryEffect(id: "group1", in: animation, properties: .frame, isSource: true)
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
                    }
                    .onChange(of: self.playroom) { value in
                        guard value == nil else {
                            return
                        }
                        
                        self.refreshContent()
                    }
                    .onFrameChange() { value in
                        
                        guard isDragging else { return }
                        
                        if value.origin.y < tripLine, isDragging {
                            DispatchQueue.main.async {
                                self.tripLine = 0
                            }
                        }
                        
                        guard value.origin.y >= 100 && self.tripLine < 100, !self.loadingLiveTracks else { return }
                        
                        DispatchQueue.main.async {
                            self.tripLine = value.origin.y
                            
                            withImpact(.rigid) {
                                self.refreshContent()
                                print("[] Frame chnaged: \(value)")
                            }
                        }
                    }
                }
                .simultaneousGesture(dragGesture)
                .frame(width: screenWidth, height: screenHeight)
                .background(
                    VStack() {
                        ProgressView(self.loadingLiveTracks ? "Refreshing..." : "Done!", value: self.loadingLiveTracks ? nil : 100.0, total: 100.0)
                            .opacity(self.loadingLiveTracks ? 1 : 0.5)
                            .progressViewStyle(CircularProgressViewStyle())
                            .font(Font.headline.weight(.thin))
                        Spacer()
                    }
                    .opacity(self.playroom == nil ? 1 : 0)
                    .padding(.top, Sizing.xxLarge * 2.6)
                )
            }
            .animation(.easeInOut)
            .onAppear() {
                self.scrollProxy = scrollProxy //
                self.refreshContent()
            }
            
        }
        .onReceive(appCoordinator.voteRequestedSubject) { requested in
            self.requestingVoteTrackId = requested
        }
        .onChange(of: self.filterText) { txt in
            print("[filterText] \(txt)")
            self.model.query = txt
            self.tracksFiltered = self.filterTracks(self.tracks, txt)
        }
        .frame(maxWidth: screenWidth)
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
    
    @State var strip: (playing: Playable?, next: Playable?, runnerup: Playable?) = (nil, nil, nil)
    
    var body: some View {
        
        return ZStack(){
            self.contentView
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
                ListenTabbarView(users: membership, isExpanded: $tabbarExpaned, searchText: self.$filterText, preview: self.$preview,
                                 playroom: self.$playroom)
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
            .frame(width: screenWidth)
            .onChange(of: votes) { votes in
                
                guard let tracks = tracks as? [QueuedTrack] else {
                    self.strip = (nil, nil, nil)
                    return
                }
                
                let grouped = Dictionary(grouping: votes, by: { $0.queuedTrackId })
                let items = grouped.sorted() { $0.value.count >= $1.value.count }
                
                let firstKey = items.first?.key ?? tracks.first?.id
                let secondKey: Int? = items.count > 1 ? items[1].key : nil
                let thirdKey = items.count > 2 ? items[2].key : nil
                
                
                self.strip = (
                    playing: tracks.first() { $0.id == firstKey },
                    next: tracks.first() { $0.id == secondKey },
                    runnerup: tracks.first() { $0.id == thirdKey}
                )
                
            }
            .onChange(of: playroom) { room in
                
                guard let room = room else {
                    return
                }
                
                self.fetchTracks(room)
            }
            .onReceive(self.appCoordinator.queueRequestedSubject) { req in
                
                guard let queued = req, queued.room.id == playroom?.id else {
                    return
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                    self.fetchTracks(queued.room)
                }
            }
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
                    if playroom != nil {
                        PlayroomHeaderView(playroom: self.$playroom,
                                           strip: self.$strip,
                                           preview: self.$preview)
                            .padding(.horizontal, Sizing.small * 0.6)
                            .padding([.horizontal, .bottom], Sizing.small * 0.5)
                            .matchedGeometryEffect(id: "listen-header", in: animation)
                    } else {
                        HStack(alignment: .top){
                            Spacer()
                            //ShakeButtonView()
                            Text("ꚠ")
                                .font(Font.title.weight(.thin))
                                .gradientForeground(colors: [Color.red, Color.orange, Color.yellow, Color.green, Color.blue, Color.purple, Color.pink])
                                .scaleEffect(x: self.loadingLiveTracks ? 1.5 : 1.0, y: self.loadingLiveTracks ? 1.5 : 1.0)
                                .onTapGesture {
                                    self.loadPlayrooms()
                                    self.loadLiveTracks()
                                }
                            
                            Spacer()
                        }
                        .matchedGeometryEffect(id: "listen-header", in: animation)
                    }
                }
                .animation(.easeInOut)
                .background(Color.white.opacity(0.90))
                .coordinateSpace(name: "playroom-controls-space")
                .onFrameChange() { rect in
                    DispatchQueue.main.async {
                        self.roomControlViewBounds = rect
                    }
                }
                Divider().opacity(self.playroom == nil ? 0 : 1).animation(.easeInOut)
                
                AppPreviewView(preview: self.$preview, currentUser: self.$currentUser, animation: animation)
                    .frame(maxWidth: screenWidth)
                    .frame(minWidth: screenWidth, maxHeight: screenHeight)
                    .background(BlurView(.extraLight))
                    .padding(.bottom, self.peopleViewBounds?.height.advanced(by: 1))
                    .offset(x: 0, y: self.preview == nil ? screenHeight : 0)
                    .animation(.spring())
                
            }
            .onReceive(appCoordinator.playStateChangeSubject) { timestamp in
                guard !self.loadingLiveTracks else { return }
                
                let waitTime = Int.random(in: 1..<9)
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(waitTime)) {
                    guard !self.loadingLiveTracks else { return }
                    self.refreshContent()
                }
            }
            .onReceive(appCoordinator.playRequestedSubject) { playable in
                guard playable != nil || !self.loadingLiveTracks else { return }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                    guard !self.loadingLiveTracks else { return }
                    
                    self.refreshContent()
                }
            }
            .onAppear() {
                setupSearch()
            }
        }
    }
}


//struct ListenView_Previews: PreviewProvider {
//    static var previews: some View {
//        ListenView()
//    }
//}

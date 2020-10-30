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
                return tracksByMusicrooms[room.id] ?? []
                
                //print("[onAppear#ListenView] tracks=\(self.tracks.count), strip=\(self.strip)")
            }
    }
    
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
                    URLQueryItem(name: "ids", value: trackUris.joined(separator: ","))
                ]
                
                return HttpMethod.Fetch.get(url: comp, dataType: SpotiftyTracksResponse.self, baseUrl: api.baseUrl.http, urlSession: api.urlSession)
                    .then(on: .main) { resp -> SpotiftyTracksResponse in
                        self.liveTracks = resp.tracks
                        return resp
                    }
                    .catch() { error in
                        print("[SpotifyTracksFtech] \(comp) - \(error)")
                    }
            }
            .always() {
                loadingLiveTracks = false
            }
    }
    
    @State var tripLine: CGFloat = 0
    @State var loadingFinishedAt: Date? = nil
    @GestureState private var dragOffset = CGSize.zero
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
                    if playroom == nil {
                        
                        VStack(){
                            
                            Divider()
                                .opacity(self.loadingLiveTracks ? 1 : 0)
                            
                            if !self.liveTracks.isEmpty {
                                
                                let header = HStack(){
                                    Text("Live Tracks")
                                        .font(Font.largeTitle.weight(.thin))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                
                                Section(header: header) {
                                    ForEach(self.liveTracks, id: \.uri) { (track: Spotify.Track) in
                                        TrackView2(track: .constant(track), useDynamicColors: true)
                                            .id(track.uri)
                                    }
                                }
                            }
                            
                            if !self.playrooms.isEmpty {
                                let header = HStack(){
                                    Text("Playrooms")
                                        .font(Font.largeTitle.weight(.thin))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                
                                let space = Sizing.small / 2
                                let columns = [
                                    GridItem(.fixed(screenWidth / 2 - space), spacing: space),
                                    GridItem(.fixed(screenWidth / 2 - space), spacing: space)
                                ]
                                
                                Section(header: header) {
                                    LazyVGrid(columns: columns) {
                                        ForEach(self.playrooms, id: \.id) { room in
                                            SpotifyItemView(item: room,
                                                            images: [],
                                                            titleKeyPath: \.name,
                                                            subtitleKeyPath: \.details)
                                                .frame(height: 64)
                                                .onTapGesture {
                                                    self.tracks = []
                                                    self.votes = []
                                                    self.playroom = room
                                                }
                                                //.background(Color.yellow)
                                                .id(room.id)
                                        }
                                    }
                                }
                                
                            }
                            
                            //                                Group(){
                            //                                    Color.white
                            //                                }
                            //                                .frame(width: screenWidth, height: screenWidth)
                            
                            Divider().padding(.vertical, Sizing.xxLarge)
                            
                            let header = HStack(){
                                Label(){
                                    Text("Settings")
                                } icon: {
                                    Image(systemName: "gearshape")
                                        .font(Font.title.weight(.thin))
                                }
                                .foregroundColor(.secondary)
                                .font(Font.largeTitle.weight(.thin))
                                
                                Spacer()
                            }
                            
                            Section(header: header) {
                                HStack(alignment: .top){
                                    VStack(alignment: .leading) {
                                        Text("Autoplay")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Begin playback immediately when joining a playroom")
                                            .font(.footnote)
                                            .foregroundColor(Color.secondary)
                                    }
                                    .frame(maxWidth: screenWidth / 2)
                                    
                                    Spacer()
                                    
                                    Toggle("Autoplay", isOn: .constant(false))
                                        .labelsHidden()
                                        .padding(.trailing, Sizing.xLarge)
                                }
                            }
                            .id("settings")
                            
                        }
                        //.frame(minHeight: screenHeight)
                        .onChange(of: self.playroom) { value in
                            guard value == nil else {
                                return
                            }
                            
                            self.refreshContent()
                        }
                        .padding(.horizontal, Sizing.large)
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
                        .background(Color.white)
                        .padding(.top, Sizing.xxLarge * 2)
                        .matchedGeometryEffect(id: "group1", in: animation, properties: .frame, isSource: true)
                    } else {
                        TrackList(tracks: self.$tracks, votes: self.$votes, preview: $preview, playroom: self.$playroom) { track in
                            
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
                            .background(Color.white)
                            //.padding(.top, geoProxy.safeAreaInsets.top)
                            //.padding(.top, roomControlViewBounds == nil ? geoProxy.safeAreaInsets.top : roomControlViewBounds?.height)
                            .padding(.top, geoProxy.safeAreaInsets.top + 100)
                            .padding(.bottom, peopleViewBounds == nil ? .zero : peopleViewBounds?.height)
                            .matchedGeometryEffect(id: "group1", in: animation, properties: .frame, isSource: true)
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
                .simultaneousGesture(dragGesture)
                .background(
                    VStack() {
                        ProgressView(self.loadingLiveTracks ? "Refreshing..." : "Done!", value: self.loadingLiveTracks ? nil : 100.0, total: 100.0)
                            .opacity(self.loadingLiveTracks ? 1 : 0.5)
                            .progressViewStyle(CircularProgressViewStyle())
                            .font(Font.headline.weight(.thin))
                        Spacer()
                    }
                    .opacity(self.playroom == nil ? 1 : 0)
                    .padding(.trailing, Sizing.small)
                    .padding(.top, Sizing.xxLarge * 2.6)
                )
            }
            .animation(.easeInOut)
            .onAppear() {
                self.scrollProxy = scrollProxy //
                self.refreshContent()
            }
             
        }
        .frame(maxWidth: screenWidth)
    }
    
    @State var strip: (playing: Playable?, next: Playable?, runnerup: Playable?) = (nil, nil, nil)
    
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
        
        
        let makeTitle = { (playroom: Playroom) in
            VStack(alignment: .trailing) {
                Button(){
                    withImpact(.soft) {
                        self.playroom = nil
                    }
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .resizable()
                        .frame(width: 18, height: 18)
                        .font(Font.subheadline.weight(.thin))
                        .foregroundColor(Color.secondary)
                }
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
            }
        }
        

        let makeStrip = { (playroom: Playroom) in
            HStack(alignment: .center){
                
                if let playing = strip.playing {
                    NetworkImage(string: playing.thumbnailUrl) {
                        Rectangle().stroke(Color.gray)
                    }
                    .frame(width: 56, height: 56)
                    .onTapGesture {
                        withImpact(.soft, animated: .easeInOut) {
                            scrollProxy?.scrollTo(playing.uri, anchor: .center)
                        }
                    }
                    .id(playing.thumbnailUrl)
                }
                
                if let next = strip.next, strip.playing != nil {

                    VStack(alignment: .leading, spacing: 1){
                        NetworkImage(string: next.thumbnailUrl) {
                            Rectangle().stroke(Color.gray)
                        }
                        .frame(width: 40, height: 40)
                        Text("Up Next")
                            .font(Font.footnote.weight(.thin))
                            .foregroundColor(Color.primary)
                    }
                    .frame(height: 56)
                    .onTapGesture {
                        withImpact(.soft, animated: .easeInOut) {
                            scrollProxy?.scrollTo(next.uri, anchor: .center)
                        }
                    }
                    .id(next.thumbnailUrl)
                }
                
                if let runnerup = strip.runnerup, strip.playing != nil, strip.next != nil {
                    VStack(alignment: .leading, spacing: 1){
                        NetworkImage(string: runnerup.thumbnailUrl) {
                            Rectangle().stroke(Color.gray)//.fill(style: Color.gray)
                        }
                        .frame(width: 40, height: 40)
                        Text("Runner-up")
                            .font(Font.footnote.weight(.thin))
                            .foregroundColor(Color.primary)
                    }
                    .frame(height: 56)
                    .onTapGesture {
                        withImpact(.soft, animated: .easeInOut) {
                            scrollProxy?.scrollTo(runnerup.uri, anchor: .center)
                        }
                    }
                    .id(runnerup.thumbnailUrl)
                }
                
                Spacer()

                makeTitle(playroom)
            }
            .padding(.horizontal, Sizing.small * 0.6)
            .padding([.horizontal, .bottom], Sizing.small * 0.5)
            .matchedGeometryEffect(id: "listen-header", in: animation)
            .animation(.easeInOut)
        }
        
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
                        makeStrip(playroom)
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
                        .animation(.easeInOut)
                        .matchedGeometryEffect(id: "listen-header", in: animation)
                    }
                }
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
                    //.padding(.top, 1)
                    .padding(.bottom, self.peopleViewBounds?.height.advanced(by: 1))
                    .offset(x: 0, y: self.preview == nil ? screenHeight : 0)
                    .animation(.spring())
                
            }
        }
    }
}

extension View {
    
    public func gradientForeground(colors: [Color]) -> some View {
        self.overlay(AngularGradient(gradient: Gradient(colors: colors),
                                     center: UnitPoint(x: 0.5, y: 1),
                                     angle: Angle(degrees: 0.00)))
            .mask(self)
    }
    
}

//struct ListenView_Previews: PreviewProvider {
//    static var previews: some View {
//        ListenView()
//    }
//}

//
//  TrackView.swift
//  Joli
//
//  Created by Anthony Chinwo on 05/09/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import Combine
import JoliCore
import UIImageColors
import Promises

public struct PauseButton: View {
    
    public let action: () -> ()
    
    public var body: some View {
        return Button() {
            action()
        } label: {
            Image(systemName: "pause")
        }
    }
    
}

public struct TrackView2<AddonView: View>: JoliView {
    
    public typealias AddonViewGetter = (Playable, [PlayState], UIImageColors?) -> AddonView
    
    @Binding var track: Playable
    @Binding var contextUri: String?
    @Binding var playroom: Playroom?
    
    @State var colors: UIImageColors? = nil
//    var colors: UIImageColors? {
//        guard let track = track as? QueuedTrack, useDynamicColors else {
//            return nil
//        }
//
//        return track.colors
//    }
    
    public var addonViewGetter: AddonViewGetter? = nil
    var useDynamicColors = false
    @GestureState var isDetectingLongPress = false
    @State var completedLongPress = false
    
    @State var heartIconFont: UIFont.TextStyle = UIFont.TextStyle.title2
    @State var requestingPlay = false
    
    @State var playPubCancel: AnyCancellable? = nil
    @State var playStatePublisherCancel: AnyCancellable? = nil
    
    @State var playStatebyUsername = [String: PlayState]()
    
    @Namespace var animation
    
    var activeDevice: Spotify.Device? {
        appCoordinator.activeDeviceSubject.value
    }
    
    var userPlayState: PlayState? {
        return self.playStatebyUsername.values.first() {
            $0.email == self.appCoordinator.activeAuth?.user.email
        }
    }
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @State var invalidPlayAttempts = 0
    @State var requestingVoteTrackId: Int? = nil
    
    @State var menuEnabled: Bool = false
    
    var longPress: some Gesture {
            LongPressGesture(minimumDuration: 3)
                .updating($isDetectingLongPress) { currentstate, gestureState,
                        transaction in
                    gestureState = currentstate
                    transaction.animation = Animation.easeIn(duration: 2.0)
                }
                .onEnded { finished in
                    self.completedLongPress = finished
                }
        }
    
    public init(track: Binding<Playable>, playroom: Binding<Playroom?> = .constant(nil), contextUri: Binding<String?> = .constant(nil), colors: UIImageColors? = nil, useDynamicColors: Bool = false) {
        self._playroom = playroom
        self._track = track
        self.useDynamicColors = useDynamicColors
        self.addonViewGetter = nil
        self._contextUri = contextUri
    }
    
//    public init(uri: Binding<String>, playroom: Binding<Playroom?> = .constant(nil), contextUri: Binding<String?> = .constant(nil), colors: UIImageColors? = nil, useDynamicColors: Bool = false, @ViewBuilder content: @escaping AddonViewGetter){
//        self._playroom = playroom
//        self._track = track
//        self._contextUri = contextUri
//        self.useDynamicColors = useDynamicColors
//        self.addonViewGetter = content
//    }
    
    public var controlsView: some View {
        HStack(){
            
            Button(){
                print("Play track: \(track.title)")
                self.play(true)
            } label: {
                Image(systemName: "play")
                    .padding(Sizing.small)
                    .background(Color.secondarySystemBackground)
            }
            .clipShape(Circle())
            .padding(.leading, 2)
            
//            Button(){
//                print("Add track: \(track.title)")
//            } label: {
//                Image(systemName: "plus")
//                    .padding(Sizing.small)
//                    .background(Color.secondarySystemBackground)
//            }
//            .clipShape(Circle())
            
            Button(){
                appCoordinator.share(track: track){ success in
                    guard !success else {
                        return
                    }
                    
                    let msg = "Something went wrong while attempting to share \"\(track.title)\", re-launch app if issue persists"
                    self.presentToast("Unable to share track", subTitle: msg, type: .error(.red), displayMode: .alert){ _ in
                    }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .padding(Sizing.small)
                    .background(Color.secondarySystemBackground)
            }
            .clipShape(Circle())
            
            if let state = self.userPlayState, state.playingState == .playing {
                //Image(systemName: "info.circle").padding(.vertical, Sizing.small)
                Divider().padding(.horizontal, 2)
                Button(){
                    self.appCoordinator.pausePlayback()
                } label: {
                    Image(systemName: "pause")
                        .padding(Sizing.small)
                        .background(Color.secondarySystemBackground)
                }
                .clipShape(Circle())
                .matchedGeometryEffect(id: "pause-btn-\(state.userName)", in: animation, isSource: true)
                .padding(.trailing, 2)
                    //.background(Color.yellow)
            } else {
                //Image(systemName: "info.circle").padding(Sizing.small)
            }
        }
        .padding(2)
        .foregroundColor(Color.secondary)
        .font(Font.title2)
        .background(BlurView(colorScheme == .dark ? .systemThickMaterialDark : .systemUltraThinMaterialLight)
                        .opacity(0.7)
                        .cornerRadius(32))
        .animation(.easeInOut(duration: 0.3))
    }
    
    @Environment(\.colorScheme) public var colorScheme
    
    private func play(_ fromBegining: Bool = false) {
        self.requestingPlay = true
        let progress: Int? = fromBegining ? nil : self.playStatebyUsername.first?.value.progressMs
        
        let playFunc = { (offset: ContentOffset?) in
            appCoordinator.play(track, positionMs: progress, contentOffset: offset, device: activeDevice)
                .then(){ playState in
                    
                    guard var playState = playState else {
                        return
                    }
                    
                    playState.progressMs = progress
                    playState.durationMs = self.playStatebyUsername[playState.userName]?.durationMs
                    
                    self.playStatebyUsername[playState.userName] = playState
                }
                .catch() { error in
                    print("[PlayTrack] error: \(error)")
                    invalidPlayAttempts += 1
                }
                .always {
                    self.requestingPlay = false
                }
        }
        
        guard let playroom = playroom, let track = track as? QueuedTrack, let playlistUri = playroom.playlistUri else {
            let _ = playFunc(nil)
            return
        }
        
        if let position = playroom.queue.firstIndex(where: { $0.id == track.id }) {
            let _ = playFunc(.both(playlistUri, position))
        } else if let contextUri = contextUri {
            let _ = playFunc(.uri(contextUri))
        }
        
    }
    
    public var contentView: some View {
        let setupPublisher = { (publisher: PlayState.Publisher?) -> Void in
            self.playPubCancel?.cancel()
            
            guard let publisher = publisher else {
                self.playPubCancel = nil
                return
            }
            
            self.playPubCancel = publisher
                .filter(\.trackUri, value: track.uri)
                .sink() { completion in
                    
                    self.playPubCancel = nil
                    //print("[playStatePublisher] errored: \(completion)")
                    
//                        guard case let Subscribers.Completion.failure(error) = completion else {
//                            return
//                        }
                    
                } receiveValue: { value in
                    //print("[playStatePublisher] received: \(value)")
                    
                    DispatchQueue.main.async {
                        self.playStatebyUsername[value.userName] = value
                    }
                    
                    guard value.trackUri == track.uri else {
                        return
                    }
                    
                    self.appCoordinator.playingSubject.send((track, value))
                }
        }
        
        return HStack(alignment: .center) {
            
            NetworkImage(imageURL: URL(string: track.thumbnailUrl)!,
                         placeholderImage: UIImage(systemName: "timelapse")!) { (loadedImage, _) in
                
                guard let loadedImage = loadedImage, useDynamicColors else {
                    return
                }
                
                DispatchQueue.global(qos: .background).async {
                    let colors = loadedImage.getColors()
                    
                    DispatchQueue.main.async {
                        self.colors = colors
                    }
                }
            }
            .frame(width: 64, height: 64, alignment: .center)
            //.clipShape(RoundedRectangle(cornerRadius: 2.36, style: .continuous))
            .onTapGesture(count: 1) { self.play(false) }
            .onTapGesture(count: 2) { self.play(true) }
            .onReceive(appCoordinator.$playStatePublisher, perform: setupPublisher)
            .onReceive(appCoordinator.voteRequestedSubject) { requested in
                self.requestingVoteTrackId = requested
            }
            .onAppear() { setupPublisher(appCoordinator.playStatePublisher) }
            .modifier(ShakeEffect(shakes: invalidPlayAttempts * 2))
            .animation(Animation.linear)
            .padding(.all, 2)
            
            GeometryReader() { proxy in
                
                HStack() {
                    ZStack(){
                        Rectangle()
                            .foregroundColor(Color.primary.opacity(0.001))
                            .background(Color.clear)
                            .onTapGesture {
                                menuEnabled.toggle()
                                print("[Menu] enabled: \(menuEnabled)")
                                
                                guard menuEnabled else { return }
                                
                                self.hideMenuTask?.cancel()
                                
                                let workItem = DispatchWorkItem(qos: .userInitiated) {
                                    menuEnabled = false
                                }
                                
                                self.hideMenuTask = workItem
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: workItem)
                            }
                        
                        self.trackDetailsView
                    }
                    .overlay(
                        HStack(){
                            Spacer()
                            
                            if menuEnabled {
                                self.controlsView
                                    .padding(.trailing, Sizing.small)
                                    .opacity(menuEnabled ? 1 : 0)
                            }
                        }
                    )
                    
                    if let state = self.userPlayState, state.playingState == .playing && !menuEnabled {
                        PauseButton() {
                                Task(){
                                    await self.appCoordinator.pausePlayback()
                                }
                            }
                            .foregroundColor(Color.primary)
                            .font(Font.title)
                            .matchedGeometryEffect(id: "pause-btn-\(state.userName)", in: animation)
                            .padding()
                    }
//
//                    if menuEnabled && self.addonViewGetter != nil {
//                        Divider()
//                    }
                    
                    if let getter = self.addonViewGetter {
                        getter(track, Array(self.playStatebyUsername.values), nil)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                .background(
                    self.liveProgressView(proxy: proxy)
                )
            }
        }
        //.rotation3DEffect(.degrees(45), axis: (x: 0.0, y: 0.0, z: self.requestingPlay ? 1.0 : 0.0))
        .scaleEffect(x: self.requestingPlay ? 0.98 : 1, y: self.requestingPlay ? 0.98 : 1, anchor: .center)
        .animation(.interactiveSpring())
        .background(colors?.backgroundColor ?? Color.clear)
        .frame(minHeight: 64, maxHeight: 72)
        .onTapGesture {
            menuEnabled.toggle()
            print("[Menu] enabled: \(menuEnabled)")
        }
    }
    
    @State var hideMenuTask: DispatchWorkItem? = nil
    
    public var trackDetailsView: some View {
        return VStack(alignment: .leading) {
                Text(track.title)
                    .foregroundColor(colors?.primaryColor ?? Color.primary)
                    .animation(.easeInOut)
                    .font(Font.headline.weight(.light))
                    .lineLimit(1)
                    .onTapGesture() {
                        self.play(false)
                    }
                
                HStack(spacing: .zero) {
                    if track.explicit {
                        Text(track.explicit  ? "E" : "")
                            .font(Font.footnote)
                            .padding(.horizontal, 2)
                            .background(Color.systemGray.opacity(0.85))
                            .font(.footnote)
                            .foregroundColor(Color.fixedWhite)
                            .cornerRadius(3)
                            .padding(.trailing, Sizing.small / 3)
                    }
                        //.overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.red, lineWidth: 1.2))
                    Text(track.artistName)
                        .lineLimit(1)
                        .foregroundColor(colors?.secondaryColor ?? Color.primary)
                        .animation(.easeInOut)
                        .font(Font.subheadline.weight(.semibold))
                    
                    if let release = track.releasedAt {
                        Text("•").foregroundColor(colors?.detailColor ?? Color.primary).padding(.horizontal, Sizing.small / 3)
                        Text("\(Calendar.current.component(.year, from: release).description)")
                            .lineLimit(1)
                            .foregroundColor(colors?.detailColor ?? Color.primary)
                            .animation(.easeInOut)
                            .font(Font.subheadline.weight(.light))
                    }
                    
                    Spacer()
                }
                .onTapGesture() {
                    self.play(false)
                }
                Spacer()
                
                if contextUri != nil, track as? QueuedTrack == nil {
                    HStack(alignment: .center){
                        Image(systemName: "music.note.house")
                            .foregroundColor(.systemGreen)
                            .font(.footnote)
                        Spacer()
                    }
                    .padding(.bottom, 2)
                }
            }
            //.background(Colors.lightGray.opacity(0.001))
    }
    
    public func liveProgressView(proxy: GeometryProxy) -> some View {
        
        let resolveColor = { (playState: PlayState) -> Color in
            guard self.appCoordinator.activeAuth != nil else {
                return .secondary
            }
            
            guard let playroom = playroom,
                  let playlistUri = playroom.playlistUri,
                  let playStatePlaylistUri = playState.playlistUri,
                  let queued = track as? QueuedTrack,
                  queued.isPlayable, playState.track?.uri == queued.uri else {
                return playState.color
            }
            
            return playlistUri == playStatePlaylistUri ? playState.color : .secondary
        }
        
        return ZStack(alignment: .leading){
            
            let containerWidth = CGFloat(proxy.size.width)
            
            ForEach(Array(self.playStatebyUsername), id: \.key) { item in
                
                if let progressMs = item.value.progressMs, let progress = CGFloat(progressMs), let durMs = item.value.durationMs, let trackDuration = CGFloat(durMs) {
                    
                    let offset = containerWidth * (max(progress, 1) / trackDuration)
                    
                    HStack(alignment: .bottom){
                        
                        
                        RoundedRectangle(cornerSize: CGSize(width: 2, height: 3))
                            .fill(resolveColor(item.value)
                                    .opacity(self.appCoordinator.activeAuth?.user.id == item.value.createdById ? 70 :  0.48)
                            )
                            .frame(width: 3, height: proxy.size.height)
                            .offset(x: offset.truncatingRemainder(dividingBy: proxy.size.width), y: 0)
                            .id(item.key)
                        Spacer()
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    EmptyView()
                }
                
            }
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
        //.background(Color.pink)
        .opacity(self.playStatebyUsername.isEmpty ? 0 : 1)
        .animation(.easeInOut)
        .id(track.uri)
    }
    
}


extension TrackView2 where AddonView: View {
    
    public init(track: Binding<Playable>, playroom: Binding<Playroom?> = .constant(nil), contextUri: Binding<String?> = .constant(nil), colors: UIImageColors? = nil, useDynamicColors: Bool = false, @ViewBuilder content: @escaping AddonViewGetter){
        self._playroom = playroom
        self._track = track
        self._contextUri = contextUri
        self.useDynamicColors = useDynamicColors
        self.addonViewGetter = content
    }
    
}

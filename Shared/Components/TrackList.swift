//
//  TrackList.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import Combine
import JoliCore
import UIImageColors
import Promises

public extension UIImageColors {
    
    var primaryColor: Color {
        return Color(primary)
    }
    
    var backgroundColor: Color {
        return Color(background)
    }
    
    var secondaryColor: Color {
        return Color(secondary)
    }
    
    var detailColor: Color {
        return Color(detail)
    }
    
}

extension QueuedTrack {
    
    public var colors: UIImageColors? {
        guard let bg = track?.colorBackground, let primary = track?.colorPrimary, let sec = track?.colorSecondary, let detail = track?.colorDetail else {
            return nil
        }
        return .init(background: UIColor(hexString: bg), primary: UIColor(hexString: primary), secondary: UIColor(hexString: sec), detail: UIColor(hexString: detail))
    }
    
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
            case 3: // RGB (12-bit)
                (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6: // RGB (24-bit)
                (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            case 8: // ARGB (32-bit)
                (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            default:
                (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

public struct TrackView2<AddonView: View>: JoliView {
    
    typealias AddonView = EmptyView
    
    @Binding var track: Playable
    
    var colors: UIImageColors? {
        guard let track = track as? QueuedTrack, useDynamicColors else {
            return nil
        }
        
        return track.colors
    }
    var addonView: AddonView? = nil
    var useDynamicColors = false
    @GestureState var isDetectingLongPress = false
    @State var completedLongPress = false
    
    @Binding var hearts: Hearts?
    @State var heartIconFont: UIFont.TextStyle = UIFont.TextStyle.title2
    @State var requestingPlay = false
    
    @State var playPubCancel: AnyCancellable? = nil
    @State var playStatePublisherCancel: AnyCancellable? = nil
    
    @State var playStatebyUsername = [String: PlayState]()
    
    var activeDevice: Spotify.Device? {
        appCoordinator.activeDeviceSubject.value
    }
    
    let onHeartTapped: (() -> Void)?
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @State var invalidPlayAttempts = 0
    @State var requestingVoteTrackId: Int? = nil
    
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
    
    public init(track: Binding<Playable>, hearts: Binding<Hearts?> = .constant(nil), colors: UIImageColors? = nil, useDynamicColors: Bool = false, onHeartTapped: (() -> Void)? = nil){
        self.onHeartTapped = onHeartTapped
        self._hearts = hearts
        self._track = track
        self.useDynamicColors = useDynamicColors
        self.addonView = nil
    }
    
    public var body: some View {
        let cb: (Bool) -> () = { (fromBegining: Bool) -> Void in

            self.requestingPlay = true
            let progress: Int? = fromBegining ? nil : self.playStatebyUsername.first?.value.progressMs

            appCoordinator.play(track, positionMs: progress, device: activeDevice)
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
        
        let setupPublisher = { (publisher: PlayState.Publisher) -> Void in
            guard self.playPubCancel == nil else {
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
                         placeholderImage: UIImage(systemName: "timelapse")!) { (loadedImage, error) in
                
                guard let loadedImage = loadedImage, useDynamicColors else {
                    return
                }
                
            }
            .frame(width: 64, height: 64, alignment: .center)
            //.clipShape(RoundedRectangle(cornerRadius: 2.36, style: .continuous))
            .onTapGesture(count: 2) { cb(true) }
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
                    VStack(alignment: .leading) {
                        Text(track.title)
                            .foregroundColor(colors?.primaryColor ?? Color.primary)
                            .animation(.easeInOut)
                            .font(Font.headline.weight(.light))
                            .lineLimit(2)
                        
                        HStack(spacing: .zero) {
                            if track.explicit {
                                Text(track.explicit  ? "E" : "")
                                    .font(Font.footnote)
                                    .padding(.horizontal, 2)
                                    .background(Color.gray.opacity(0.85))
                                    .font(.footnote)
                                    .foregroundColor(Color.white)
                                    .cornerRadius(3)
                                    .padding(.trailing, Sizing.small / 3)
                            }
                                //.overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.red, lineWidth: 1.2))
                            Text(track.artistName)
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
                            
//                            if let queued = (track as? QueuedTrack)?.track, let releaseDatePrecision = queued.releaseDatePrecision {
//                                Text("(\(releaseDatePrecision))")
//                                    .lineLimit(1)
//                                    .foregroundColor(colors?.detailColor ?? Color.primary)
//                                    .animation(.easeInOut)
//                                    .font(Font.subheadline.weight(.light))
//                            }
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    
                    if let addonView = self.addonView {
                        Spacer()
                        addonView
                    }
                }
                .background(
                    ZStack(alignment: .leading){
                        
                        let containerWidth = CGFloat(proxy.size.width)
                        
                        ForEach(Array(self.playStatebyUsername), id: \.key) { item in
                            
                            if let progressMs = item.value.progressMs, let progress = CGFloat(progressMs), let durMs = item.value.durationMs, let trackDuration = CGFloat(durMs) {
                                
                                let offset = containerWidth * (max(progress, 1) / trackDuration)
                                
                                HStack(alignment: .bottom){
                                    RoundedRectangle(cornerSize: CGSize(width: 2, height: 3))
                                        .fill(item.value.color.opacity(0.48))
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
                )
            }
        }
        //.rotation3DEffect(.degrees(45), axis: (x: 0.0, y: 0.0, z: self.requestingPlay ? 1.0 : 0.0))
        .onTapGesture() { cb(false) }
        .scaleEffect(x: self.requestingPlay ? 0.98 : 1, y: self.requestingPlay ? 0.98 : 1, anchor: .center)
        .animation(.interactiveSpring())
        .background(colors?.backgroundColor ?? Color.clear)
    }
    
    
}

public extension String {
    func count(of needle: Character) -> Int {
        return reduce(0) {
            $1 == needle ? $0 + 1 : $0
        }
    }
}

public extension PlayState {
    
    static var allColors: [Color] {
        return [
            .red,
            .yellow,
            .blue,
            .pink,
            .green,
            .orange,
            .purple,
        ]
    }
    
    var color: Color {
        let colors = Self.allColors
        let color = colors[(userName.count + userName.lowercased().count(of: "g")) % colors.count ]
        return color
    }
}

extension TrackView2 where AddonView: View {
    
    public init(track: Binding<Playable>, hearts: Binding<Hearts?> = .constant(nil), colors: UIImageColors? = nil, useDynamicColors: Bool = false,
                onHeartTapped: (() -> Void)? = nil, @ViewBuilder content: (Playable, UIImageColors?) -> AddonView){
        self.onHeartTapped = onHeartTapped
        self._hearts = hearts
        self._track = track
        self.useDynamicColors = useDynamicColors
        self.addonView = content(self.track, nil)
    }
    
}

public struct TrackList<AddonView: View>: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    let onVoteTapped: ((QueuedTrack) -> Void)?
    @State var subscriptionCounts: [String: Hearts] = [:]
    @Binding var tracks: [Playable]
    @Binding var votes: [QueuedTrackVote]
    @Binding var preview: AppPreview?
    @Binding var playroom: Musicroom?
    
    @State var votesByTrack: [Int: [QueuedTrackVote]] = [:]
    let addonViewFunc: (Playable, UIImageColors?) -> AddonView
    
    public init(tracks: Binding<[Playable]>, votes: Binding<[QueuedTrackVote]>? = .constant([]), preview: Binding<AppPreview?> = .constant(nil),
                playroom: Binding<Musicroom?> = .constant(nil), onVoteTapped: ((QueuedTrack) -> Void)? = nil, @ViewBuilder addonView: @escaping (Playable, UIImageColors?) -> AddonView){
        self.onVoteTapped = onVoteTapped
        self._tracks = tracks
        self._preview = preview
        self._playroom = playroom
        self._votes = votes ?? .constant([])
        self.addonViewFunc = addonView
    }
    
    func trackBinding(_ trackId: Array<Playable>.Index) -> Binding<Playable> {
        let track: Binding<Playable> = Binding() { () -> Playable in
                return tracks[trackId]
            } set: { (track, trasacton) in
                tracks[trackId] = track
                //print("Transaction: \(transaction)")
                //transaction.
            }
        return track
    }
    
    func heartLevelBinding(_ trackId: Array<Playable>.Index) -> Binding<Hearts?> {
        
        
        let heart: Binding<Hearts?> = Binding() { () -> Hearts? in
            
            guard trackId < tracks.count, playroom != nil else {
                return nil
            }
            
            guard let track = tracks[trackId] as? QueuedTrack, let count: Int = self.votesByTrack[track.id]?.count else {
                return Hearts(score: HeartLevel.empty.rawValue)
            }
            
            return Hearts(score: CGFloat(count) * HeartLevel.quarter.rawValue)
            
        } set: { (heart, trasacton) in
            
//            withTransaction(trasacton) {
//
//                guard trackId < tracks.count else {
//                    return
//                }
//
//                let track = tracks[trackId]
//                subscriptionCounts[track.uri] = heart
//
//                //track.subscriptionCount = heart
//                print("[TrackList] failed to set hear \(String(describing: heart)) for \(trasacton)")
//            }
        }
        return heart
    }
    
    public var body: some View {
        return VStack(alignment: .center, spacing: 0) {
                ForEach(Array(tracks.enumerated()), id: \.element.uri) { item in
                    
                    let track = item.element
                    
                    TrackView2(track: .constant(track), hearts: self.heartLevelBinding(item.offset), useDynamicColors: false) {
                        print("[Heart Tapped] \(track.title)")
                        
                        guard let queued = track as? QueuedTrack else {
                            return
                        }
                        
                        self.onVoteTapped?(queued)
                        
                    } content: { (trackObj, colors) -> AddonView in
                        return addonViewFunc(trackObj, colors)
                    }
                    .id(track.uri)
                }
        }
        
    }
    
}

struct TrackList_Previews: PreviewProvider {
    
    static var previews: some View {
        TrackList(tracks: .constant(SEED_DATA.tracks)) { (_, _) in EmptyView() }
    }
    
}

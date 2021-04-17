//
//  PlayroomHeaderView.swift
//  Joli
//
//  Created by Anthony Chinwo on 30/12/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//
import Combine
import Foundation
import JoliCore
import SwiftUI

struct FlippingView: View {

      @State private var flipped = false
      @State private var animate3d = false

      var body: some View {

            return VStack {
                  Spacer()

                  ZStack() {
                        FrontCard().opacity(flipped ? 0.0 : 1.0)
                        BackCard().opacity(flipped ? 1.0 : 0.0)
                  }
                  .modifier(FlipEffect(flipped: $flipped, angle: animate3d ? 180 : 0, axis: (x: 1, y: 0)))
                  .onTapGesture {
                        withAnimation(Animation.linear(duration: 0.8)) {
                              self.animate3d.toggle()
                        }
                  }
                  Spacer()
            }
      }
}

struct FlipEffect: GeometryEffect {

      var animatableData: Double {
            get { angle }
            set { angle = newValue }
      }

      @Binding var flipped: Bool
      var angle: Double
      let axis: (x: CGFloat, y: CGFloat)

      func effectValue(size: CGSize) -> ProjectionTransform {

            DispatchQueue.main.async {
                  self.flipped = self.angle >= 90 && self.angle < 270
            }

            let tweakedAngle = flipped ? -180 + angle : angle
            let a = CGFloat(Angle(degrees: tweakedAngle).radians)

            var transform3d = CATransform3DIdentity;
            transform3d.m34 = -1/max(size.width, size.height)

            transform3d = CATransform3DRotate(transform3d, a, axis.x, axis.y, 0)
            transform3d = CATransform3DTranslate(transform3d, -size.width/2.0, -size.height/2.0, 0)

            let affineTransform = ProjectionTransform(CGAffineTransform(translationX: size.width/2.0, y: size.height / 2.0))

            return ProjectionTransform(transform3d).concatenating(affineTransform)
      }
}

struct FrontCard : View {
      var body: some View {
            Text("One thing is for sure – a sheep is not a creature of the air.").padding(5).frame(width: 250, height: 150, alignment: .center).background(Color.yellow)
      }
}

struct BackCard : View {
      var body: some View {
            Text("If you know you have an unpleasant nature and dislike people, this is no obstacle to work.").padding(5).frame(width: 250, height: 150).background(Color.green)
      }
}


extension Array {

    func mapToSet<T: Hashable>(_ transform: (Element) -> T) -> Set<T> {
        var result = Set<T>()
        for item in self {
            result.insert(transform(item))
        }
        return result
    }

}

struct StackedArtistAvatarView: View {
    @Binding var artists: [Artist]
    
    var uniqueArtists: Set<Artist> {
        Set(self.artists)
    }
    
    var body: some View {
        let distinctUsers = uniqueArtists
        let sortedUsers = Array(distinctUsers)
        
        return HStack(alignment: .bottom){
            HStack(spacing: -25) {
                ForEach(sortedUsers.prefix(4)) { item in
                    NetworkImage(string: item.imageSmall) {
                        Image(systemName: "person")
                            .resizable()
                            .renderingMode(.original)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .id(item.id)
                }
            }
            Text(distinctUsers.count > 4 ? "+\(distinctUsers.count - 3)" : "")
                .foregroundColor(.secondaryLabel)
                .font(Font.subheadline.weight(.thin))
        }
        
        //.background(Color.yellow)
    }
}

public struct PlayroomHeaderView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public typealias TrackStrip = Playroom.TrackStrip
    
    @Binding var playroom: Playroom?
    @Binding var strip: TrackStrip
    @Binding var preview: AppPreview?
    @Binding var tracks: [Playable]
    @Binding var scrollProxy: ScrollViewProxy?
    
    @State var playbackProgress: Int? = nil
    @State var tappedUri: String? = nil
    
    public init(playroom: Binding<Playroom?>, strip: Binding<TrackStrip>, preview: Binding<AppPreview?>,
                tracks: Binding<[Playable]>, scrollProxy: Binding<ScrollViewProxy?>){
        self._playroom = playroom
        self._strip = strip
        self._preview = preview
        self._tracks = tracks
        self._scrollProxy = scrollProxy
    }
    
    let tappedSubject: AutoResetSubject<String?, Never, DispatchQueue> = AutoResetSubject(nil, delay: .milliseconds(300), scheduler: DispatchQueue.global(qos: .userInitiated))
    
    var memberColors: [Color] {
        
        guard self.appCoordinator.activeAuth != nil else {
            return [Color.secondary, Color.black]
        }
        
        return [Color.green, Color.blue, Color.purple]
    }
    
    public var stripView: some View {
        HStack(alignment: .bottom){
            
            if let playing = strip.playing {
                
                let containerWidth = CGFloat(56.0)
                
                VStack(alignment: .leading, spacing: .zero){
                    NetworkImage(string: playing.thumbnailUrl) {
                        Rectangle().stroke(Color.gray)
                    }
                    .frame(width: containerWidth, height: 56)
                    
                    let progressWidth = containerWidth * (max(CGFloat(playbackProgress ?? 0), 1.0) / CGFloat(playing.duration))
                    
                    RoundedRectangle(cornerSize: CGSize(width: 2, height: 2))
                        .gradientForeground(colors: memberColors)//.fill(Color.green)
                        .frame(width: progressWidth, height: 2)
                        .padding(.top, 2)
                        
                }
                .frame(width: containerWidth, height: 60)
                .scaleEffect(x: self.tappedUri == playing.uri ? 1.02 : 1, y: self.tappedUri == playing.uri ? 1.02 : 1, anchor: .center)
                .onReceive(self.appCoordinator.playingSubject) { item in
                    
                    guard let item = item, let room = playroom,
                          item.track.uri == playing.uri,
                          room.playlistUri == item.playState.playlistUri else {
                        return
                    }
                    
                    self.playbackProgress = item.playState.progressMs
                }
                .onTapGesture {
                    withImpact(.soft, animated: .easeInOut) {
                        self.tappedSubject.send(playing.uri)
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
                    .frame(width: 42, height: 42)
                    Text("Up Next")
                        .font(Font.footnote.weight(.thin))
                        .foregroundColor(Color.primary)
                }
                .frame(height: 60)
                .scaleEffect(x: self.tappedUri == next.uri ? 1.02 : 1, y: self.tappedUri == next.uri ? 1.02 : 1, anchor: .center)
                .onTapGesture {
                    withImpact(.soft, animated: .easeInOut) {
                        self.tappedSubject.send(next.uri)
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
                    .frame(width: 42, height: 42)
                    Text("Runner-up")
                        .font(Font.footnote.weight(.thin))
                        .foregroundColor(Color.primary)
                        .fixedSize()
                }
                .frame(height: 60)
                .scaleEffect(x: self.tappedUri == runnerup.uri ? 1.02 : 1, y: self.tappedUri == runnerup.uri ? 1.02 : 1, anchor: .center)
                .onTapGesture {
                    withImpact(.soft, animated: .easeInOut) {
                        self.tappedSubject.send(runnerup.uri)
                        scrollProxy?.scrollTo(runnerup.uri, anchor: .center)
                    }
                }
                .id(runnerup.thumbnailUrl)
            }
            
    }
    }
    
    public var contentView: some View {
        VStack(alignment: .leading, spacing: .zero){
            HStack(){
                if let playroom = playroom {
                    Text(playroom.name)
                        .font(Font.title2)
                        .foregroundColor(self.connectionState == .connected ? Color.blue : Color.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                        .onReceive(playroom.$membership) { members in
                            self.membership = members
                        }
                        .onReceive(playroom.$artists, assign: \.artists, target: self)
                        .onTapGesture() {
                            self.preview = .view() {
                                VStack() {
                                    Text(playroom.name).font(.largeTitle)
                                    Divider()
                                    HStack() {
                                        Text("Description").font(.headline)
                                        Spacer()
                                    }
                                    Text(playroom.details).lineLimit(nil).font(.body)
            
                                    Spacer()
                                    Button() {
                                        self.appCoordinator.synchronizePlayroom(playroom.musicroom)
            
                                    } label: {
                                        Text("Synchronize Playlist")
                                    }
                                    .padding()
                                    Spacer()
                                }
                                .padding(.top, Sizing.large)
                                .padding()
                                .background(Color.clear)
                                .eraseToAnyView()
                            }
                        }
                }
                
                Spacer()
                Button(){
                    withImpact(.soft) {
                        self.playroom = nil
                    }
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        //.resizable()
                        //.frame(width: closeIconSize, height: closeIconSize)
                        .font(Font.title3.weight(.thin))
                        .foregroundColor(Color.secondary)
                }
                .padding()
            }
            
            HStack(alignment: .bottom){
                self.stripView
                Spacer()
                
                VStack(alignment: .trailing){
                    StackedArtistAvatarView(artists: $artists)
                    makeDurationLabel()
                }
            }
        }
        .onReceive(self.tappedSubject) { uri in
            self.tappedUri = uri
        }
        .onReceive(self.appCoordinator.connectionStateSubject) { conn in
            self.connectionState = conn.state
        }
    }
    
    @State var membership: [PlayroomMembership] = []
    @State var artists: [Artist] = []
    @State var connectionState: ConnectionState = .stopped
    @ScaledMetric(relativeTo: .subheadline) var closeIconSize: CGFloat = 24
    
    private func makeDurationLabel() -> some View {
        let totalCountMillisecs: Int = tracks.map() { $0.duration }.reduce(0, +)
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .brief
        
        let formattedString = formatter.string(from: TimeInterval(totalCountMillisecs / 1000))!
        
        let tracksAndDurationLabel = "\(tracks.count) songs, \(formattedString)"
        
        return Text(tracksAndDurationLabel)
                    .font(Font.footnote.weight(.light))
                    .foregroundColor(Color.secondary)
            
                
    }
    
}
//
//struct PlayroomHeaderView_Previews: PreviewProvider {
//    static var previews: some View {
//        PlayroomHeaderView()
//    }
//}

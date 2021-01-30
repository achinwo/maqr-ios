//
//  PlayroomHeaderView.swift
//  Joli
//
//  Created by Anthony Chinwo on 30/12/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import JoliCore
import SwiftUI

public struct PlayroomHeaderView: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    public typealias TrackStrip = (playing: Playable?, next: Playable?, runnerup: Playable?)
    
    @Binding var playroom: Playroom?
    @Binding var strip: TrackStrip
    @Binding var preview: AppPreview?
    @Binding var tracks: [Playable]
    @Binding var scrollProxy: ScrollViewProxy?
    
    @State var playbackProgress: Int? = nil
    @State var tappedUri: String? = nil
    
    let tappedSubject: AutoResetSubject<String?, Never, DispatchQueue> = AutoResetSubject(nil, delay: .milliseconds(300), scheduler: DispatchQueue.global(qos: .userInitiated))
    
    var memberColors: [Color] {
        return [Color.blue, Color.purple, Color.orange, Color.yellow, Color.green, Color.pink]
    }
    
    public var body: some View {
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
            
            Spacer()
            
            if let playroom = playroom {
                makeTitle(playroom)
            }
        }
        .onReceive(self.tappedSubject) { uri in
            self.tappedUri = uri
        }
    }
    
    @State var connectionState: ConnectionState = .stopped
    
    private func makeTitle(_ playroom: Playroom) -> some View {
        let totalCountMillisecs: Int = tracks.map() { $0.duration }.reduce(0, +)
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .brief
        
        let formattedString = formatter.string(from: TimeInterval(totalCountMillisecs / 1000))!
        
        let tracksAndDurationLabel = "\(tracks.count) songs, \(formattedString)"
        
        return VStack(alignment: .trailing) {
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
            
            VStack(alignment: .trailing){
                HStack(alignment: .center){
                    Text("in")
                        .font(Font.subheadline)
                        .foregroundColor(Color.gray)
                    Text(playroom.name)
                        .font(Font.headline)
                        .foregroundColor(self.connectionState == .connected ? Color.blue : Color.secondary)
                        .frame(maxWidth: screenWidth / 1.8)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                Text(tracksAndDurationLabel)
                    .font(Font.footnote.weight(.light))
                    .foregroundColor(Color.secondary)
            }
            .onReceive(self.appCoordinator.connectionStateSubject) { conn in
                self.connectionState = conn.state
            }
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
    }
    
}
//
//struct PlayroomHeaderView_Previews: PreviewProvider {
//    static var previews: some View {
//        PlayroomHeaderView()
//    }
//}

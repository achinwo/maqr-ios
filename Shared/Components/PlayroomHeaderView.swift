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
    
    public var body: some View {
        HStack(alignment: .center){
            
            if let playing = strip.playing {
                NetworkImage(string: playing.thumbnailUrl) {
                    Rectangle().stroke(Color.gray)
                }
                .frame(width: 56, height: 56)
                .onTapGesture {
                    withImpact(.soft, animated: .easeInOut) {
                        //scrollProxy?.scrollTo(playing.uri, anchor: .center)
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
                        //scrollProxy?.scrollTo(next.uri, anchor: .center)
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
                        .fixedSize()
                }
                .frame(height: 56)
                .onTapGesture {
                    withImpact(.soft, animated: .easeInOut) {
                        //scrollProxy?.scrollTo(runnerup.uri, anchor: .center)
                    }
                }
                .id(runnerup.thumbnailUrl)
            }
            
            Spacer()
            
            if let playroom = playroom {
                makeTitle(playroom)
            }
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

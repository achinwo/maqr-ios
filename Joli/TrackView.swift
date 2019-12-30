//
//  TrackView.swift
//  Joli
//
//  Created by Anthony Chinwo on 10/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi
import JoliCore

struct TrackView: View {
    
    @EnvironmentObject var appState: AppState
    var track: Playable
    @State var isPlaying = false
    
    var isVoteable: Bool {
        return track is QueuedTrack
    }
    
    var votes: [QueuedTrackVote]? {
        guard let queuedTrack = self.track as? QueuedTrack else {
            return nil
        }
        return self.appState.votesByTrackId[queuedTrack.id]
    }
    
    var queuedTrackUris: [String] {
        guard let room = appState.activeRoom else {
            return []
        }
        return (appState.queuedTracksByMusicrooms[room.id] ?? []).map() { $0.uri }
    }
    
    @State var image: Image?
    var spotifyDevice: Spotify.Device? {
        return self.appState.spotifyDevice
    }
    
    var isQueueable: Bool {
        return !(track is QueuedTrack)
    }
    
    var isDeleteable: Bool {
        return track is QueuedTrack || track is RoomTrack
    }
    
    var currentlyPlayingContent: Spotify.CurrentlyPlayingContent? {
        guard let track = track as? Spotify.CurrentlyPlayingContent else {
            return nil
        }
        
        if let current = self.appState.currentlyPlayingContent, current.uri == track.uri {
            return current
        } else {
            return track
        }
    }
    
    init(track: Playable){
        self.track = track
    }
    
    var explicitLabel: some View {
        return Text(track.explicit == nil ? "" : "E")
        .padding(2)
        .background(Color.red)
        .font(.footnote)
        .foregroundColor(Color.white)
        .cornerRadius(3)
        .opacity(track.explicit == nil ? 0.0 : 100)
        //.overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.red, lineWidth: 1.2))
    }
    
    func playTrack(){
        self.isRequestingPlay = true
        self.appState.playTrack(self.track)
            .always {
                self.isRequestingPlay = false
        }
    }
    
    @State var isVoting = false
    @State var isQueueing = false
    @State var isRequestingPlay = false
    
    var body: some View {
        let votesText: String
        
        if let votes = votes, votes.count > 0 {
            votesText = votes.count.description
        } else {
            votesText = ""
        }
        
        return HStack(alignment: VerticalAlignment.center) {
            
            CircleImage(url: track.thumbnailUrl)
                .opacity(self.isRequestingPlay ? 0.85 : 1)
                .onTapGesture(perform: playTrack)
            
            VStack(alignment: .leading) {
                Text(track.title)
                    .animation(.easeInOut)
                    .font(.headline).lineLimit(2)
                
                HStack {
                    
                    Text(track.artistName)
                        .animation(.easeInOut)
                        .font(.subheadline)
                    Spacer()
                    
                    self.explicitLabel
                }
            }
            .opacity(self.isRequestingPlay ? 0.85 : 1)
            .onTapGesture(perform: playTrack)
            
            if self.currentlyPlayingContent != nil {
                Image(systemName: self.isPlaying ? "pause.circle" : "play.circle")
                    .resizable().padding(.trailing, 10).padding(.bottom, 10)
                    .foregroundColor(self.isRequestingPlay ? Color.gray : Color.primary)
                    .frame(width: 64, height: 64, alignment: .bottomLeading)
                    .onTapGesture() {
                        guard let content = self.currentlyPlayingContent else {
                            return
                        }
                        
                        self.isRequestingPlay = true
                        
                        if self.isPlaying {
                            self.appState.pausePlayback()
                                .then() { _ in
                                    self.isPlaying = false
                            }.always {
                                self.isRequestingPlay = false
                            }
                        } else {
                            self.appState.playTrack(content, positionMs: content.progressMs)
                                .then() {
                                    self.isPlaying = true
                                }.always {
                                    self.isRequestingPlay = false
                                }
                        }
                    }
            }
            
            if self.isQueueable && !queuedTrackUris.contains(track.uri) {
                Image(systemName: "plus")
                    .animation(.easeInOut)
                    .font(self.isQueueing ? .title : .subheadline)
                    .padding()
                    .onTapGesture {
                        logger.debug("[TrackView] \(self.track.title)")
                        self.isQueueing = true
                        self.appState.queueTrack(self.track)
                            .always {
                                self.isQueueing = false
                        }
                        self.appState.showToast = true
                }
            }
            
            if self.isVoteable {
                HStack(){
                    Image(systemName: "hand.thumbsup").font(self.isVoting ? .title : .subheadline)
                    Text(votesText).font(self.isVoting ? .title : .subheadline)
                }
                .animation(.spring())
                .onTapGesture {
                    self.isVoting = true
                    self.appState.voteTrack(self.track as! QueuedTrack)
                        .always {
                            self.isVoting = false
                    }
                }
            }
        }
        .onAppear() {
            self.isPlaying = self.currentlyPlayingContent?.isPlaying ?? false
        }
        .contextMenu {
            
            if self.isQueueable {
                Button(action: {
                    guard let room = self.appState.activeRoom, let track = self.track as? Spotify.Track else { return }
                    self.appState.api.addTrackToRoom(room, track)
                        .then(){ track in
                            return
                        }
                        .catch() { error in
                            logger.error("[TrackView] addTrack error: \(error)")
                        }
                        .always {
                            self.appState.fetchTracks(room)
                            self.appState.fetchQueuedTracks(room)
                    }
                }) {
                    Text("Add to Queue")
                    Image(systemName: "plus")
                }
            }
//            if self.track is Persisted {
//
//                Button(action: {
//                    self.appState.api.delete(self.track)
//                        .catch() { error in
//                            logger.error("[TrackView] delete error: \(error)")
//                        }
//                        .always() {
//                            guard let room = self.appState.activeRoom else { return }
//
//                            self.appState.fetchTracks(room)
//                        }
//                }) {
//                    Text("Delete").foregroundColor(.red)
//                    Image(systemName: "minus.circle")
//                }
//            }
        }
        .onAppear(){
            
            self.appState.fetchedImage(url: self.track.thumbnailUrl)
                .then() { (image: Image?) in
                    self.image = image
            }
        }
    }
}

struct Toast<Presenting>: View where Presenting: View {

    /// The binding that decides the appropriate drawing in the body.
    @Binding var isShowing: Bool
    /// The view that will be "presenting" this toast
    let presenting: () -> Presenting
    /// The text to show
    let text: Text

    var body: some View {

        GeometryReader { geometry in

            ZStack(alignment: .center) {

                self.presenting()
                    .blur(radius: self.isShowing ? 1 : 0)

                VStack {
                    self.text
                }
                .frame(width: geometry.size.width / 2,
                       height: geometry.size.height / 5)
                .background(Color.secondary.colorInvert())
                .foregroundColor(Color.primary)
                .cornerRadius(20)
                .transition(.slide)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                      withAnimation {
                        self.isShowing = false
                      }
                    }
                }
                .opacity(self.isShowing ? 1 : 0)

            }

        }

    }

}

extension View {

    func toast(isShowing: Binding<Bool>, text: Text) -> some View {
        Toast(isShowing: isShowing,
              presenting: { self },
              text: text)
    }

}

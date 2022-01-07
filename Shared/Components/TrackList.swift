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

public extension Search.Engine {
    
    typealias SearchMethod = (String, Set<Search.Category>, Int) -> AnyPublisher<[SearchResult], Never>
    
    func search(_ q: String, _ categories: Set<Search.Category>, limit: Int = 6, search searchFn: SearchMethod) -> AnyPublisher<[SearchResult], Never> {
        let supported = categories.filter(){ supportedCategories.contains($0) }
        
        guard !supported.isEmpty else {
            return Just([]).eraseToAnyPublisher()
        }
        
        return searchFn(q, supported, limit)
    }
    
}

public enum PlaybackControllerMetadataKey: EnvironmentKey {
    
    public static var defaultValue: PlaybackControllerMetadata? {
        return nil
    }
    
}

public extension EnvironmentValues {
    
    var playbackControllerMetadata: PlaybackControllerMetadata? {
        get {
            self[PlaybackControllerMetadataKey.self]
        }
        
        set {
            self[PlaybackControllerMetadataKey.self] = newValue
        }
    }
    
}




public struct TrackList<AddonView: View>: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    let onVoteTapped: ((QueuedTrack) -> Void)?
    @State var subscriptionCounts: [String: Hearts] = [:]
    @Binding var tracks: [Playable]
    @Binding var playroom: Playroom?
    @Binding var contextUri: String?
    
    let addonViewFunc: (Playable, [PlayState], UIImageColors?) -> AddonView
    
    public init(tracks: Binding<[Playable]>, contextUri: Binding<String?> = .constant(nil),
                playroom: Binding<Playroom?> = .constant(nil), onVoteTapped: ((QueuedTrack) -> Void)? = nil, @ViewBuilder addonView: @escaping (Playable, [PlayState], UIImageColors?) -> AddonView){
        self.onVoteTapped = onVoteTapped
        self._tracks = tracks
        self._playroom = playroom
        self._contextUri = contextUri
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
    
    public var contentView: some View {
        return VStack(alignment: .center, spacing: 0) {
            
                ForEach(tracks, id: \.uri) { track in
                    
                    //let track = item.element
                    
                    TrackView2(track: .constant(track),
                               playroom: self.$playroom,
                               contextUri: self.$contextUri,
                               useDynamicColors: playroom?.themeTrackUri == track.uri) { (trackObj, states, colors) -> AddonView in
                        return addonViewFunc(trackObj, states, colors)
                    }
                    .id(track.uri)
                }
        }
        
    }
    
}

//struct TrackList_Previews: PreviewProvider {
//    
//    static var previews: some View {
//        TrackList(tracks: .constant(SEED_DATA.tracks)) { (_, _) in EmptyView() }
//    }
//    
//}

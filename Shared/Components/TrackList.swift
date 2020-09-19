//
//  TrackList.swift
//  Joli
//
//  Created by Anthony Chinwo on 19/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import UIImageColors

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

public struct TrackView2: JoliView {
    
    @Binding var track: Playable
    @State var colors: UIImageColors? = nil
    @GestureState var isDetectingLongPress = false
    @State var completedLongPress = false
    
    @Binding var heartLevel: HeartLevel?
    @State var heartIconFont: UIFont.TextStyle = UIFont.TextStyle.title2
    @State var requestingPlay = false
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
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
    
    public init(track: Binding<Playable>, heartLevel: Binding<HeartLevel?> = .constant(nil), colors: UIImageColors? = nil){
        self._heartLevel = heartLevel
        self._track = track
        self.colors = colors
    }
    
    public var body: some View {
        let cb: () -> () = {
            self.requestingPlay = true
            appCoordinator.play(track)
                .always {
                    self.requestingPlay = false
                }
        }
        HStack(alignment: .center) {
            
            NetworkImage(imageURL: URL(string: track.thumbnailUrl)!,
                         placeholderImage: UIImage(systemName: "timelapse")!) { (loadedImage, error) in
                
                guard let loadedImage = loadedImage else {
                    return
                }
                
                DispatchQueue.global(qos: .background).async {
                    let newColors = loadedImage.getColors()
                        
                    DispatchQueue.main.async {
                        self.colors = newColors
                        
//                        var builder = track//.builder()
//                        builder.colorBackground = colors?.background.hexString
//                        builder.colorDetail = colors?.detail.hexString
//                        builder.colorSecondary = colors?.secondary.hexString
//                        builder.colorPrimary = colors?.primary.hexString
//
//                        builder.save()
//                            .catch(){ error in
//                                logger.debug("[TrackView] colors update error: \(error)")
//                            }
//                            .then(){ newTrack in
//                                logger.debug("[TrackView] created track: \(newTrack)")
//                            }
                    }
                }
            }
            .frame(width: 64, height: 64, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 2.36, style: .continuous))
            .onTapGesture(perform: cb)
            .padding(.all, 2)
            
            VStack(alignment: .leading) {
                Text(track.title)
                    .foregroundColor(colors?.primaryColor ?? Color.primary)
                    .animation(.easeInOut)
                    .font(Font.headline.weight(.light))
                    .lineLimit(2)
                
                HStack {
                    
                    Text(track.artistName)
                        .foregroundColor(colors?.secondaryColor ?? Color.primary)
                        .animation(.easeInOut)
                        .font(Font.subheadline.weight(.semibold))
                    Text("•").foregroundColor(colors?.detailColor ?? Color.primary)
                    Text("2003")
                        .foregroundColor(colors?.detailColor ?? Color.primary)
                        .animation(.easeInOut)
                        .font(Font.subheadline.weight(.light))
                    Spacer()
                }
            }
            
            if self.heartLevel != nil {
                Spacer()
                JoyMeterView(self.$heartLevel, heartCount: 1, textStyle: self.heartIconFont, labelColor: colors?.detailColor ?? Color.primary)
                    .padding()
                    .padding(.trailing, Sizing.large)
                    .foregroundColor(colors?.secondaryColor ?? Color.primary)
                    .onTapGesture {
                        
                        guard self.heartLevel != .full else {
                            withAnimation(.none) {
                                self.heartLevel = .quarter
                            }
                            return
                        }
                        self.heartLevel = self.heartLevel?.next
                    }
                    .onLongPressGesture {
                        
                        appCoordinator.withImpact(.medium) {
                            self.heartLevel = .quarter
                        }
                        print("new count: \(self.heartLevel)")
                    }
            }
        }
        //.rotation3DEffect(.degrees(45), axis: (x: 0.0, y: 0.0, z: self.requestingPlay ? 1.0 : 0.0))
        .onTapGesture(perform: cb)
        .scaleEffect(x: self.requestingPlay ? 0.98 : 1, y: self.requestingPlay ? 0.98 : 1, anchor: .center)
        .animation(.interactiveSpring())
        .background(colors?.backgroundColor ?? Color.clear)
    }
}

public extension Playable {
    
    
}

public struct TrackList: JoliView {
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
    @State var subscriptionCounts: [String: HeartLevel] = [:]
    @Binding var tracks: [Playable]
    @Binding var preview: AppPreview?
    
    public init(tracks: Binding<[Playable]>, preview: Binding<AppPreview?> = .constant(nil)){
        self._tracks = tracks
        self._preview = preview
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
    
    func heartLevelBinding(_ trackId: Array<Playable>.Index) -> Binding<HeartLevel?> {
        
        
        let heart: Binding<HeartLevel?> = Binding() { () -> HeartLevel? in
            let track = tracks[trackId]
            
            guard let subscriptionCounts = self.subscriptionCounts[track.uri] else {
                
                let elem = [HeartLevel.empty, HeartLevel.full, HeartLevel.third, HeartLevel.half].randomElement()!
                
                DispatchQueue.main.async {
                    self.subscriptionCounts[track.uri] = elem
                }
                
                return elem
            }
            
            return subscriptionCounts
            
        } set: { (heart, trasacton) in
            withTransaction(trasacton) {
                let track = tracks[trackId]
                subscriptionCounts[track.uri] = heart
                
                //track.subscriptionCount = heart
                print("[] failed to set hear \(String(describing: heart)) for \(trasacton)")
            }
        }
        return heart
    }
    
    public var body: some View {
        return LazyVStack(alignment: .center, spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.offset) { item in
                TrackView2(track: self.trackBinding(item.offset), heartLevel: self.heartLevelBinding(item.offset))
                        .onLongPressGesture(minimumDuration: 0.2, maximumDistance: 1) {
                            withImpact {
                                self.preview = .track(item.element as! Track)
                            }
                        }
                }
            }
    }
    
}

struct TrackList_Previews: PreviewProvider {
    
    static var previews: some View {
        TrackList(tracks: .constant(SEED_DATA.tracks))
    }
    
}

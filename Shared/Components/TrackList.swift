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

public struct TrackView2: View {
    
    @Binding var track: Track
    @State var colors: UIImageColors? = nil
    @GestureState var isDetectingLongPress = false
    @State var completedLongPress = false
    
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
    
    public init(track: Binding<Track>, colors: UIImageColors? = nil){
        _track = track
        self.colors = colors
    }
    
    @State var heartLevel: HeartLevel = .empty
    @State var heartIconFont: UIFont.TextStyle = UIFont.TextStyle.title2
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    public var body: some View {
        HStack(alignment: .center) {
            
            NetworkImage(imageURL: URL(string: track.thumbnailUrl)!,
                         placeholderImage: UIImage(systemName: "timelapse")!) { loadedImage in
                
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
            }.padding(.all, 2)
            
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
                    self.heartLevel = self.heartLevel.next
                }
                .onLongPressGesture {
                    
                    appCoordinator.withImpact(.medium) {
                        self.heartLevel = .quarter
                    }
                    print("new count: \(self.heartLevel)")
                }
        }
        .animation(.easeIn)
        .background(colors?.backgroundColor ?? Color.clear)
    }
}

public struct TrackList: View {
    
    @Binding var tracks: [Track]
    
    public init(tracks: Binding<[Track]>){
        self._tracks = tracks
    }
    
    func trackBinding(_ trackId: Array<Track>.Index) -> Binding<Track> {
        let track: Binding<Track> = Binding() { () -> Track in
                return tracks[trackId]
            } set: { (track, trasacton) in
                tracks[trackId] = track
                print("Transaction: \(transaction)")
                //transaction.
            }
        return track
    }
    
    public var body: some View {
        return VStack(alignment: .center, spacing: 0) {
                ForEach(tracks) { track in
                    TrackView2(track: self.trackBinding(tracks.firstIndex(of: track)!))
                }
            }
    }
    
}

struct TrackList_Previews: PreviewProvider {
    
    static var previews: some View {
        TrackList(tracks: .constant(SEED_DATA.tracks))
    }
    
}

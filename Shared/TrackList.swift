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
    
    @State var track: Track
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
    
    public init(track: Track, colors: UIImageColors? = nil){
        _track = State(initialValue: track)
        self.colors = colors
    }
    
    @State var heartLevel: JoyMeterView.HeartLevel = .empty
    @State var heartIconFont: UIFont.TextStyle = UIFont.TextStyle.title1
    
    public var body: some View {
        HStack(alignment: .center) {
            
            NetworkImage(imageURL: URL(string: track.thumbnailUrl)!,
                         placeholderImage: UIImage(systemName: "timelapse")!) { loadedImage in
                
                guard let loadedImage = loadedImage else {
                    return
                }
                
                DispatchQueue.global(qos: .background).async {
                    colors = loadedImage.getColors()
                        
                    DispatchQueue.main.async {
                        self.colors = colors
                    }
                }
            }.padding(.all, 2)
            
            VStack(alignment: .leading) {
                Text(track.title)
                    .foregroundColor(colors?.primaryColor ?? Color.primary)
                    .animation(.easeInOut)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    
                    Text(track.artistName)
                        .foregroundColor(colors?.secondaryColor ?? Color.primary)
                        .animation(.easeInOut)
                        .font(.subheadline)
                    Text("•").foregroundColor(colors?.detailColor ?? Color.primary)
                    Text("2003")
                        .foregroundColor(colors?.detailColor ?? Color.primary)
                        .animation(.easeInOut)
                        .font(.subheadline)
                    Spacer()
                }
            }
            Spacer()
            JoyMeterView(heartLevel: self.$heartLevel, heartCount: 1, width: UIFont.preferredFont(forTextStyle: self.heartIconFont).pointSize)
                .padding()
                .padding(.trailing, Sizing.large)
                .foregroundColor(colors?.secondaryColor ?? Color.primary)
                .onTapGesture {
                    
                    withAnimation() {
                        self.heartIconFont = .largeTitle
                    }
                    
                    defer {
                        withAnimation() {
                            self.heartIconFont = .title2
                        }
                    }
                    
                    guard self.heartLevel != .full else {
                        withAnimation(.none) {
                            self.heartLevel = .quarter
                        }
                        return
                    }
                    self.heartLevel = self.heartLevel.next
                }
                .onLongPressGesture {
                    let impactHeavy = UIImpactFeedbackGenerator(style: .rigid)
                    self.heartLevel = .full
                    impactHeavy.impactOccurred()
                    print("new count: \(self.heartLevel)")
                }
        }.onLongPressGesture {
            
        }
        .animation(.easeIn)
        .background(colors?.backgroundColor ?? Color.clear)
    }
}

public struct TrackList: View {
    
    @State var tracks: [Track]
    
    public init(tracks: [Track]){
        self._tracks = State(initialValue: tracks)
    }
    
    public var body: some View {
        return VStack(alignment: .center, spacing: 0) {
                ForEach(tracks) { track in
                    TrackView2(track: track)
                }
            }
    }
    
}

struct TrackList_Previews: PreviewProvider {
    
    static var previews: some View {
        TrackList(tracks: SEED_DATA.tracks)
    }
    
}

//
//  DevicesView.swift
//  Joli
//
//  Created by Anthony Chinwo on 25/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import UIKit
import PartialSheet

extension View {
    
    var screenSize: CGSize {
        return UIScreen.main.bounds.size
    }
    
    var screenWidth: CGFloat {
        return screenSize.width
    }
    
    var screenHeight: CGFloat {
        return screenSize.height
    }
    
}

extension Spotify.Device {
    
    var imageName: String {
        switch type {
        case .smartphone:
            return "iphone"
        case .computer:
            return "laptopcomputer"
        case .automobile:
            return "car"
        case .tablet:
            return "ipad"
        case .tv:
            return "tv"
        default:
            return "hifispeaker"
        }
    }
}

public struct DevicesView: View {
    @State var idx = 0
    @State var volume = CGFloat(30)
    @Binding var activeDevice: Spotify.Device?
    @State var devices: [Spotify.Device] = []
    
    var volumeImageName: String {
        var volumeImage: String
        switch volume {
        case 6..<30:
            volumeImage = "speaker.wave.1"
        case 30..<70:
            volumeImage = "speaker.wave.2"
        case 70...100:
            volumeImage = "speaker.wave.3"
        default:
            volumeImage = "speaker"
        }
        return volumeImage
    }
    
    var deviceGridItems: [GridItem] {
        if devices.count >= 3 {
            return [
                GridItem(),
                GridItem()
            ]
        } else {
            return [GridItem()]
        }
    }
    
    public var body: some View {
        VStack(){
            HStack(){
                Image(systemName: volumeImageName)
                    .frame(width: Sizing.large, height: Sizing.large)
                    .labelsHidden()
                    .font(.largeTitle)
                    .padding()
                Slider(value: self.$volume, in: 0...100) {
                    Text("Volume")
                }.labelsHidden()
            }
            Divider().padding()
            
            ScrollView(.horizontal){
                LazyHGrid(rows: deviceGridItems, spacing: Sizing.medium){
                    
                    ForEach(devices) { device in
                        Button(){
                            
                        } label: {
                            VStack {
                                Image(systemName: device.imageName)
                                    .padding()
                                    .font(.largeTitle)
                                Text(device.name)
                            }
                        }
                        .padding()
                        .cornerRadius(20)
                        .background(device == activeDevice ? Color.yellow : Colors.lightGray)
                        .onTapGesture() {
                            guard let idx = self.devices.firstIndex(of: device) else {
                                return
                            }
                            
                            self.activeDevice = self.devices[idx]
                        }
                    }
                }.padding()
            }
        }
    }
}

public struct SampleView: View {
    @State var chooserPresented: Bool = false
    @State var activeDevice: Spotify.Device?
    //@EnvironmentObject var partialSheetManager: PartialSheetManager
    
    public init(){
        
    }
    
    public var body: some View {
        let devices: [Spotify.Device] = [
            Spotify.Device(name: "Devialet Phantom", type: .smartphone, isActive: true, id: "test_device3"),
            Spotify.Device(name: "Joli Player", type: .computer, isActive: true, id: "test_device1"),
            Spotify.Device(name: "Microwave", type: .speaker, isActive: true, id: "test_device4"),
            
            Spotify.Device(name: "Cyber Truck", type: .automobile, isActive: true, id: "test_device5"),
            Spotify.Device(name: "Living Room", type: .tv, isActive: true, id: "test_device6")
        ]
        
            // 1.2 Add the manager as environmentObject
            
        return VStack() {
            Text("Some stuff")
        }
        .background(Color.pink)
        .sheet(isPresented: self.$chooserPresented) {
            DevicesView(activeDevice: self.$activeDevice,
                               devices: devices)//.environmentObject(partialSheetManager)
        }
        .onTapGesture() {
            self.chooserPresented.toggle()
//            self.partialSheetManager.showPartialSheet({
//                    print("Partial sheet dismissed")
//                }) {
//                     Text("This is a Partial Sheet")
//                }
        }
    }
}

struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        
        return NavigationView(){
            SampleView()//.environmentObject(PartialSheetManager())
        }
    }
}

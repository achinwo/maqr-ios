//
//  DevicesView.swift
//  Joli
//
//  Created by Anthony Chinwo on 25/07/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore
import Combine
import PartialSheet

public struct DevicesView: View {
    
    @Binding var activeDevice: Spotify.Device?
    @Binding var volume: CGFloat
    @State var devices: [Spotify.Device] = []
    
    @Environment(\.presentationMode) var presentationMode
    
    public init(activeDevice: Binding<Spotify.Device?>, volume: Binding<CGFloat>, devices: [Spotify.Device] = []){
        self._volume = volume
        self._activeDevice = activeDevice
        self.devices = devices
    }
    
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
        let view = VStack(){
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
                            guard let idx = self.devices.firstIndex(of: device) else {
                                return
                            }
                            logger.debug("[DevicesView] setting active device: \(self.devices[idx])")
                            self.activeDevice = self.devices[idx]
                            presentationMode.wrappedValue.dismiss()
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
                    }
                }.padding()
            }
            
        }//.frame(width: .infinity, height: self.screenHeight / 3)
        return view
    }
}

public struct DevicesSampleView: View {
    
    @State var chooserPresented: Bool = false
    @State var activeDevice: Spotify.Device?
    @State var volume: CGFloat = 30
    
    @EnvironmentObject var partialSheetManager: PartialSheetManager
    
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
        .addPartialSheet()
        .padding()
        .background(Color.pink)
        .onTapGesture() {
            //self.chooserPresented.toggle()
            
            self.partialSheetManager.showPartialSheet(){
                print("Partial sheet dismissed")
            } content: {
                DevicesView(activeDevice: self.$activeDevice, volume: self.$volume,
                        devices: devices)
            }
        }
    }
}

struct DevicesView_Previews: PreviewProvider {
    
    static var partialManager = PartialSheetManager()
    
    static var previews: some View {
        
        return NavigationView(){
            DevicesSampleView()
        }.environmentObject(DevicesView_Previews.partialManager)
    }
}

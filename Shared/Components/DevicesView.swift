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

public struct DevicesView: JoliView {
    
    @State var activeDevice: Spotify.Device? = nil
    @State var volume: CGFloat = .zero
    @State var devices: [Spotify.Device] = []
    let onClose: ((Spotify.Device?) -> Void)?
    
    public init(onClose: ((Spotify.Device?) -> Void)? = nil){
        self.onClose = onClose
    }
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    
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
        return [
            GridItem(),
            GridItem(),
        ]
    }
    
    @State var selectedAuthTokenIdx: Int = .zero
    
    @State var selectedAuthToken: String? = nil
    @State var auths: [Auth] = []
    
    public var body: some View {
//        Picker(selection: self.$appState.selectedTabIdx, label: Text("Room")){
//            ForEach(MusicroomTab.allCases, id: \.self){ roomTab in
//                Text("\(roomTab.emoji != nil ? "\(roomTab.emoji!) " : "")\(roomTab.title)")
//                    .foregroundColor(.green)
//                    .tag(roomTab.rawValue)
//            }
//        }

        let view = VStack(){
            
            if self.auths.count > 1 {
                
                Picker(selection: self.$selectedAuthTokenIdx, label: Text("Users")) {
                    ForEach(Array(self.auths.enumerated()), id: \.offset) { item in
                        let auth = item.element
                        Text("\(auth.user.ranking.emoji) \(auth.user.name)")
                            .tag(item.offset)
//                            .onTapGesture() {
//                                self.selectedAuthToken = auth.session.token
//                            }
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .id(self.selectedAuthToken)
                
                Divider()
            }
            
            HStack(){
                Image(systemName: volumeImageName)
                    .frame(width: Sizing.large, height: Sizing.large)
                    .labelsHidden()
                    .font(.title)
                    .foregroundColor(.secondary)
                    .padding()
                Slider(value: self.$volume, in: 0...100) {
                    Text("Volume")
                }
                .disabled(self.activeDevice == nil || devices.isEmpty)
                .labelsHidden()
                
                Button() {
                    self.onClose?(self.activeDevice)
                } label: {
                    Image(systemName: "xmark")
                        .font(.title)
                        .foregroundColor(.secondary)
                        .padding()
                        .onTapGesture {
                            self.onClose?(self.activeDevice)
                        }
                }
                .offset(x: Sizing.small, y: 0)
                    
            }
            .onChange(of: self.selectedAuthTokenIdx) { idx in
                print("[DevicesView] token changed: \(idx)")
                
                guard idx < self.auths.count else { return }
                
                let auth = auths[idx]
                
                guard appCoordinator.activeSessionToken != auth.session.token else {
                    return
                }
                
                appCoordinator.activeSessionToken = auth.session.token
                
                DispatchQueue.main.async {
                    appCoordinator.refreshDevices()
                }
            }
            .onReceive(appCoordinator.authsSubject) { auths in
                self.auths = auths
                
                guard self.selectedAuthTokenIdx < self.auths.count else {
                    self.selectedAuthTokenIdx = 0
                    return
                }
            }
            .onReceive(appCoordinator.$activeSessionToken) { token in
                
                guard let newIdx = appCoordinator.authsSubject.value.firstIndex(where: { $0.session.token == token }) else { return }
                
                self.selectedAuthTokenIdx =  newIdx
            }
            .padding()
            //Divider()//.padding()
            
            if devices.isEmpty {
                VStack(){
                    Text("No Spotify Devices Detected").font(.headline).foregroundColor(.secondary).padding()
                    
                    ProgressView("Refreshing...", value: nil, total: 100)
                        .labelsHidden()
                        .progressViewStyle(CircularProgressViewStyle())
                        .opacity(appCoordinator.refreshingDevices ? 1 : 0)
                        .animation(.easeInOut)
                        .padding(.bottom, Sizing.small)
                    
                    Button() {
                        appCoordinator.refreshDevices()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(Font.headline.weight(.light))
                            .padding()
                            .animation(.easeInOut)
                    }
                    .disabled(appCoordinator.refreshingDevices)
                    .background(Colors.lightGray.opacity(0.7))
                    .cornerRadius(50, antialiased: true)
                }
                .padding()
            } else {
                LazyVGrid(columns: deviceGridItems, spacing: Sizing.medium){
                    
                    ForEach(devices) { device in
                        Button(){
                            logger.debug("[DevicesView] setting active device: \(device)")
                            
                            self.appCoordinator.activeDeviceSubject.send(device)
                        } label: {
                            VStack {
                                Image(systemName: device.imageName)
                                    .font(Font.title.weight(.thin))
                                Text(device.name)
                                    .lineLimit(2)
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(device.id == activeDevice?.id ? Colors.lightGray : Color.clear)
                        .cornerRadius(20)
                    }
                }.padding()
            }
            
            
        }
        .onChange(of: self.volume) { volume in
            
            guard let activeDevice = activeDevice, CGFloat(activeDevice.volumePercent) != volume else {
                return
            }
            
            self.appCoordinator.volumeSubject.send(Int(volume))
        }
        .onReceive(appCoordinator.$devices) { devices in
            self.devices = devices
        }
        .onReceive(appCoordinator.activeDeviceSubject){ activeDevice in
            
            logger.debug("[DevicesView] active device updated: \(String(describing: activeDevice))")
            //let prevActive = self.activeDevice
            self.activeDevice = activeDevice
            
            guard let device = activeDevice else {
                return
            }
            
            self.volume = CGFloat(device.volumePercent)
        }
        .onAppear() {
            appCoordinator.refreshDevices()
        }
        
        //.frame(width: .infinity, height: self.screenHeight / 3)
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
//        let devices: [Spotify.Device] = [
//            Spotify.Device(name: "Devialet Phantom", type: .smartphone, isActive: true, id: "test_device3"),
//            Spotify.Device(name: "Joli Player", type: .computer, isActive: true, id: "test_device1"),
//            Spotify.Device(name: "Microwave", type: .speaker, isActive: true, id: "test_device4"),
//
//            Spotify.Device(name: "Cyber Truck", type: .automobile, isActive: true, id: "test_device5"),
//            Spotify.Device(name: "Living Room", type: .tv, isActive: true, id: "test_device6")
//        ]
        
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
                DevicesView()
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

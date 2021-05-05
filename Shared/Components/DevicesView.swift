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

#if !os(macOS)
import PartialSheet
#endif

public struct DevicesView: JoliView {
    
    var activeDevice: Spotify.Device? {
        return devices.first() { $0.id == activeDeviceId }
    }
    
    @State var activeDeviceId: String? = nil
    @State var volume: CGFloat = .zero
    @State var devices: [Spotify.Device] = []
    let onClose: ((Spotify.Device?) -> Void)?
    
    public init(onClose: ((Spotify.Device?) -> Void)? = nil){
        self.onClose = onClose
    }
    
    @EnvironmentObject public var appCoordinator: AppCoordinator
    @Environment(\.playbackControllerMetadata) public var playbackControllerMetadata: PlaybackControllerMetadata?
    
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
    @State var accentColor = Color.primary
    
    public var contentView: some View {
//        Picker(selection: self.$appState.selectedTabIdx, label: Text("Room")){
//            ForEach(MusicroomTab.allCases, id: \.self){ roomTab in
//                Text("\(roomTab.emoji != nil ? "\(roomTab.emoji!) " : "")\(roomTab.title)")
//                    .foregroundColor(.green)
//                    .tag(roomTab.rawValue)
//            }
//        }playbackConnectBtn
        
        let view = VStack(){
            
            if self.auths.count > 1 {
                
                Picker(selection: self.$selectedAuthTokenIdx, label: Text("Users")) {
                    ForEach(Array(self.auths.enumerated()), id: \.offset) { item in
                        let auth = item.element
                        Text("\(auth.user.ranking.emoji) \(auth.user.name)")
                            .tag(item.offset)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.vertical, Sizing.small)
                .id(self.selectedAuthToken)
                
                Divider()
            } else if let auth = self.auths.first {
                HStack() {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(auth.user.name).font(.headline).foregroundColor(.gray)
                        Text(auth.user.ranking.description.lowercased()).font(.footnote).foregroundColor(.gray)
                    }
                    .padding()
                    Spacer()
                }
                
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
                .accentColor(self.accentColor)
                
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
                GridChooserView(items: $devices, selection: self.$activeDeviceId){ item in
                    logger.debug("[DevicesView] setting active device: \(String(describing: item))")
                    self.appCoordinator.activeDeviceSubject.send(item)
                } content: { device in
                    VStack {
                        Image(systemName: device.imageName)
                            .font(Font.title.weight(.thin))
                        Text(device.name)
                            .lineLimit(2)
                            .font(.caption)
                    }
                    .padding()
                    .background(self.activeDeviceId == device.id ? Color.tertiarySystemBackground : Color.clear)
                }
                .padding()
            }
            
            if let playbackControllerMetadata = playbackControllerMetadata, playbackControllerMetadata.isInstalled, playbackControllerMetadata.connectionState != .connected {
                Button(){
                    
                    guard appCoordinator.localPlaybackConnectRequest == nil else { return }
                    print("\(tag) connecting to \(playbackControllerMetadata.name)")
                    
                    self.localPlaybackConnectRequest = appCoordinator.requestLocalPlaybackConnect()
                                                            .sink(){ completion in
                                                                self.localPlaybackConnectRequest = nil
                                                            } receiveValue: { value in
                                                                self.localPlaybackConnectRequest = nil
                                                            }
                } label: {
                    Label() {
                        HStack(){
                            Text(appCoordinator.localPlaybackConnectRequest != nil ? "Connecting..." : "Connect to app")
                            
                            if appCoordinator.localPlaybackConnectRequest != nil {
                                ProgressView()
                            }
                        }
                        .padding([.vertical, .trailing])
                        .foregroundColor(playbackControllerMetadata.brandColor)
                    } icon: {
                        Image(platformImage: #imageLiteral(resourceName: "Spotify_Icon_RGB_Green"))
                            .resizable()
                            .frame(width: logoImageSize, height: logoImageSize, alignment: .center)
                    }
                }
                .disabled(appCoordinator.localPlaybackConnectRequest != nil)
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
        .onReceive(appCoordinator.$activeSessionToken) { token in
            
            guard token != nil else {
                self.accentColor = .primary
                return
            }
            
            api.fetchSpotifyUserProfile(on: .main)
                .then(){ user in
                    let colors = PlayState.allColors
                    self.accentColor = colors[(user.id.count + user.id.lowercased().count(of: "g")) % colors.count].opacity(0.7)
                }
                .catch() { error in
                    self.accentColor = .primary
                }
        }
        .onReceive(appCoordinator.activeDeviceSubject){ activeDevice in
            
            logger.debug("[DevicesView] active device updated: \(String(describing: activeDevice))")
            //let prevActive = self.activeDevice
            self.activeDeviceId = activeDevice?.id
            
            guard let device = activeDevice else {
                return
            }
            
            self.volume = CGFloat(device.volumePercent)
        }
        .onAppear() {
            appCoordinator.refreshDevices()
            print("[\(Self.self)] playbackControllerMetadata: \(String(describing: playbackControllerMetadata))")
        }
        
        //.frame(width: .infinity, height: self.screenHeight / 3)
        
        
        
        return view
    }
    
    @ScaledMetric(relativeTo: .title) var logoImageSize: CGFloat = 24
    @State var localPlaybackConnectRequest: AnyCancellable? = nil
    
}

public struct DevicesSampleView: View {
    
    @State var chooserPresented: Bool = false
    @State var activeDevice: Spotify.Device?
    @State var volume: CGFloat = 30
    
    //@EnvironmentObject var partialSheetManager: PartialSheetManager
    
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
        //.addPartialSheet()
        .padding()
        .background(Color.pink)
        .onTapGesture() {
            //self.chooserPresented.toggle()
            
//            self.partialSheetManager.showPartialSheet(){
//                print("Partial sheet dismissed")
//            } content: {
//                DevicesView()
//            }
        }
    }
}
//
//struct DevicesView_Previews: PreviewProvider {
//
//    static var partialManager = PartialSheetManager()
//
//    static var previews: some View {
//
//        return NavigationView(){
//            DevicesSampleView()
//        }.environmentObject(DevicesView_Previews.partialManager)
//    }
//}

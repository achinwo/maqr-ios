//
//  SettingsView.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/11/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi
import WebKit
import JoliCore

struct WebView: UIViewRepresentable {
      
    let request: URLRequest
    
    var webViewDelegate = WebViewDelegate(trustedHosts: JoliApi.sharedUrlSessionDelegate.trustedHosts)
      
    func makeUIView(context: Context) -> WKWebView  {
        return WKWebView()
    }
      
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(request)
        uiView.navigationDelegate = webViewDelegate
    }
      
}

class WebViewDelegate: NSObject, WKNavigationDelegate {
    
    var trustedHosts: [String] = []
    
    init(trustedHosts: [String]? = nil) {
        super.init()
        self.trustedHosts = trustedHosts ?? []
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        logger.info("[WebViewDelegate] decidePolicyFor host: \(String(describing: navigationAction.request.url?.host))")

        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error){
        logger.info("[WebViewDelegate] error: \(error)")
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        logger.info("[WebViewDelegate] challenge: \(challenge) - \(trustedHosts)")
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            trustedHosts.contains(challenge.protectionSpace.host)
        else {
            return completionHandler(.useCredential, nil)
        }
        
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        challenge.sender?.use(credential, for: challenge)
        completionHandler(.useCredential, credential)
    }
}

struct SettingsView: View {
    
    @EnvironmentObject var appState: AppState
    
    var url: URL {
        var components = URLComponents(string: "/spotify_login")!
        components.queryItems = [URLQueryItem(name: "platform", value: "ios")]
        
        return components.url(relativeTo: self.appState.baseUrl.rawValue.http)!
        //return URL(string: "https://google.com")!
    }
    
    @State var baseUrl: URL? = nil
    
    var body: some View {
        return VStack {
//
//            //WebView(request: URLRequest(url: url)).padding(0)
//            ExampleView()
//            Text("Room Membership")
            Button(action: {
                //#imageLiteral(resourceName: "party-people.jpg")
               let path = Bundle.main.path(forResource: "party-people", ofType: "jpg")
                let url = URL.init(fileURLWithPath: path!)
                let fileData = try! Data(contentsOf: url)
                
                
                let boundary = "Boundary-\(UUID().uuidString)"
                var req = URLRequest.init(url: URL(string: "/images", relativeTo: self.appState.api.baseUrl.http)!)
                req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

                req.httpMethod = "POST"
                //req.allHTTPHeaderFields = self.appState.api.urlSessionConfiguration.httpAdditionalHeaders as? [String : String]
                logger.debug("Uploading \(req)")
                
                var httpBody = Data()
                
                func convertFileData(fieldName: String, fileName: String, mimeType: String, fileData: Data, using boundary: String) -> Data {
                  var data = Data()

                  data.append("--\(boundary)\r\n")
                  data.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
                  data.append("Content-Type: \(mimeType)\r\n\r\n")
                  data.append(fileData)
                  data.append("\r\n")

                  return data as Data
                }


                httpBody.append(convertFileData(fieldName: "image_field",
                                                fileName: "party-people.jpg",
                                                mimeType: "image/jpg",
                                                fileData: fileData,
                                                using: boundary))

                httpBody.append("--\(boundary)--")

                req.httpBody = httpBody as Data
                
                let task = self.appState.api.urlSession.uploadTask(with: req, from: httpBody) { (data, resp, error) in
                    logger.debug("data=\(String(describing: data)), resp=\(String(describing: resp)), error=\(String(describing: error))")
                }
                task.resume()
                
            }) {
                Text("Upload Image")
            }.padding()
            
            Button(action: { self.appState.spotifyDelegate.requestSpotifyAccess() }) {
                HStack(alignment: .center) {
                    Spacer()
                    
                    if self.appState.spotifyAuthorizationInProgress {
                        ActivityIndicator(isAnimating: self.appState.spotifyAuthorizationInProgress) { (indicator: UIActivityIndicatorView) in
                            indicator.color = .white
                            indicator.hidesWhenStopped = true
                            //Any other UIActivityIndicatorView property you like
                        }
                    }
                    
                    Text("Spotify Authorize").foregroundColor(Color.white).bold()
                    Spacer()
                }
            }.padding()
                .background(Color.green)
                .cornerRadius(CGFloat(4.0))
        }
        .navigationBarTitle("Setting")
        .navigationBarItems(trailing: Button(action: { self.appState.isSettingsPresented.toggle() }) {
            Image(systemName: "xmark")
            Text("Close")
        })
    }
}

struct ExampleView: View {
    @State private var pushed = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                NavigationLink(destination: PushedView(),
                               isActive: $pushed) { Text("Push Now") }
                
                Button("Push with delay") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                        self.pushed = true
                    }
                }
            }
        }
    }
    
    struct PushedView: View {
        var body: some View {
            Text("Hello")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}




typealias Size = ()

struct ViewOffset {
    
    var x: CGFloat?
    var y: CGFloat?
    
    func computedSize(geometry: GeometryProxy) -> CGSize {
        return CGSize(width: x ?? geometry.size.width, height: y ?? geometry.size.height)
    }
    
}

struct CurrentlyPlayingView: View {
    
    @EnvironmentObject var currentlyPlaying: AppCurrentlyPlayingState
    
    var body: some View {
        return self.currentPlayingView
    }
    
    var currentPlayingView: some View {
        let gesture = DragGesture(minimumDistance: 10)
            .onEnded() { val in
                self.dragging = false
                self.heightOffset = val.translation.height > 50 ? AppView.DEFAULT_PLAY_WIDGET_HIEGHTOFFSET : val.location.y
            }
            .onChanged() { changeVal in
                self.dragging = true
                self.heightOffset = changeVal.location.y
            }
        
        var width: CGFloat = .zero
        
        if self.currentlyPlaying.progressPct > 0 {
            width = CGFloat(self.currentlyPlaying.progressPct / 100.0) * (UIScreen.main.bounds.width - 142)
        }
        
        return VStack(alignment: .leading){
            HStack(alignment: .center, spacing: 4){
                if self.currentlyPlaying.content != nil
                    && self.appState.imagesByUrl[self.currentlyPlaying.track!.albumCoverUrl] != nil {
                    self.appState.imagesByUrl[self.currentlyPlaying.track!.albumCoverUrl]?
                        .resizable().frame(width: 116, height: 116, alignment: .bottomLeading)
                }
                
                VStack(alignment: .leading, spacing: 0){
                    
                    HStack(alignment: .top){
                        
                        Text(self.currentlyPlaying.track?.name ?? "No Name")
                            .font(.headline)//.background(Color.blue)
                    }
                    HStack(alignment: .top){
                        VStack(alignment: .leading){
                            Text(self.currentlyPlaying.track == nil ? "" : "By \(self.currentlyPlaying.track!.artistName)").font(.subheadline)
                            
                            HStack(alignment: .center){
                                Image(systemName: "hand.thumbsup")
                                Text("4")
                                
                                if self.appState.spotifyDevice != nil {
                                    
                                    Text("•").font(.title)
                                    
                                    Image(systemName: "hifispeaker")
                                    Text(self.appState.spotifyDevice!.type.rawValue)
                                        .lineLimit(1)
                                        .font(.footnote)
                                }
                            }
                        }
                        Spacer()
                        if self.currentlyPlaying.track != nil && self.currentlyPlaying.content!.isPlaying {
                            Image(systemName: "pause.circle").resizable().padding(.trailing, 10).padding(.bottom, 10)
                                .frame(width: 64, height: 64, alignment: .bottomLeading)
                                .onTapGesture {
                                    self.appState.pausePlayback()
                                }
                        }else{
                            Image(systemName: "play.circle").resizable().padding(.trailing, 10).padding(.bottom, 10)
                                .frame(width: 64, height: 64, alignment: .bottomLeading)
                                .onTapGesture {
                                    guard let track = self.currentlyPlaying.track else {
                                        return
                                    }
                                    self.appState.playTrack(track)
                                }
                        }
                    }//.background(Color.green)
                    
                    ZStack(alignment: .leading){
                        Color.gray.frame(width: UIScreen.main.bounds.width - 142, height: 4, alignment: .leading)
                        
                        Color.green.frame(width: width, height: 4, alignment: .leading)
                            .cornerRadius(1)
                            .animation(.interactiveSpring())
                    }.offset(x: -4, y: 0)
                    
                }.frame(width: UIScreen.main.bounds.width - 32 - 116, height: 116, alignment: .bottomLeading)
                
            }
        }
        //   .animation(self.dragging ? .none : .easeInOut)
        .simultaneousGesture(gesture)
        .frame(width: UIScreen.main.bounds.width - 32, height: 116, alignment: .bottomLeading)
        .padding(.trailing, 8)
        .background(Color.yellow)
        .opacity(0.95)
        .shadow(radius: 8)
        
        .cornerRadius(10)
        .animation(.easeInOut)
        .offset(self.currentlyPlayingViewOffset)
        .edgesIgnoringSafeArea(.bottom)
        
    }
    
    var currentlyPlayingViewOffset: CGSize {
        guard let content = currentlyPlaying.content else {
            return CGSize(width: -16, height: AppView.DEFAULT_PLAY_WIDGET_HIEGHTOFFSET)
        }
        
        if self.appState.activeRoom != nil && self.appState.selectedTabIdx == MusicroomTab.playQueue.rawValue {
            return CGSize(width: -16, height: AppView.DEFAULT_PLAY_WIDGET_HIEGHTOFFSET)
        }
        
        if !content.isPlaying {
            return CGSize(width: -16, height: AppView.DEFAULT_PLAY_WIDGET_HIEGHTOFFSET)
        }
        
        return CGSize(width: -16, height: heightOffset)
    }
    
    @EnvironmentObject var appState: AppState
    @State var settingsViewOffset: ViewOffset = ViewOffset(x: nil, y: 0)
    @State var settingsViewOffsetSize = CGSize(width: 0, height: 0)
    @State var mainViewOffset = CGSize(width: 0, height: 0)
    
    @State var dragging = false
    
    @State var heightOffset: CGFloat = 0
    
}


struct AppView: View {
    
    @EnvironmentObject var appState: AppState
    
    
    @State var settingsViewOffset: ViewOffset = ViewOffset(x: nil, y: 0)
    @State var settingsViewOffsetSize = CGSize(width: 0, height: 0)
    @State var mainViewOffset = CGSize(width: 0, height: 0)
    
    @State var image: Image? = nil
    @State var isLogoutAlertPresented = false
    
    static let DEFAULT_PLAY_WIDGET_HIEGHTOFFSET: CGFloat = 200
    
    var body: some View {
        var buttons: [ActionSheet.Button] = appState.spotifyDevices.map() { device in
            var suffix = ""
            if let selectedDeviceIdx = self.appState.selectedSpotifyDeviceIdx,
               device == self.appState.spotifyDevices[selectedDeviceIdx] {
                suffix = " ✔️"
            }
            
            return .default(Text("\(device.name)\(suffix)")) {
                logger.debug("[spotifyDevices] selected device: \(device)")
                self.appState.selectedSpotifyDeviceIdx = self.appState.spotifyDevices.firstIndex(of: device)
                self.appState.triggerAndClearDeviceCallbacks(cancelled: false)
            }
        }
        
        let showSyntheticDevice = buttons.isEmpty && !self.appState.deviceReadyCallbacks.isEmpty
        if showSyntheticDevice {
            buttons.append(.default(Text("iPhone")) {
                let device = Spotify.Device(name: "iPhone", type: Spotify.DeviceType.smartphone, isActive: true, id: "__this_phone__")
                self.appState.triggerAndClearDeviceCallbacks(device: device, cancelled: false)
            })
        }
        
        buttons.append(.cancel() {
            self.appState.triggerAndClearDeviceCallbacks(cancelled: true)
        })
        
        var deviceChooserMessage = Text(self.appState.spotifyDevices.count == 0 && !showSyntheticDevice ? "You have no connected Spotify devices" : "Spotify connected devices")
        
        if self.appState.spotifyDevices.count == 0 {
            deviceChooserMessage = deviceChooserMessage.foregroundColor(.red).bold()
        }
        
        let settingsOffsetWidth: CGFloat? = appState.isSettingsPresented ? 0 : nil
        
        let logonButtonAction = {
            if self.appState.auth == nil {
                self.appState.isLogonViewPresented = true
            } else {
                self.isLogoutAlertPresented = true
            }
        }
        
        let roomsView = NavigationView {
            MusicroomList()
                .sheet(isPresented: self.$appState.isLogonViewPresented) {
                    //ImagePickerCamera(isShown: self.$appState.isLogonViewPresented, image: self.$image)
                    NavigationView {
                        LogOnView() { cancelled in
                            logger.debug("[LogOnView] view dismissed")
                        }
                    }
                    .environmentObject(self.appState)
                    .environmentObject(self.appState.keyboardState)
                }
                .navigationBarItems(leading:
                                        Button(action: logonButtonAction) {
                                            
                                            if self.appState.auth != nil {
                                                UserProfileView(user: self.appState.auth!.user.builder())
                                            } else {
                                                Text("Sign In")
                                            }
                                        }.alert(isPresented: self.$isLogoutAlertPresented) {
                                            Alert(title: Text("Sign out?").font(.title),
                                                  message: Text("\(self.appState.auth!.user.name)").font(.subheadline),
                                                  primaryButton: .cancel(),
                                                  secondaryButton: .destructive(Text("Yes")) {
                                                    self.appState.api.auth = nil
                                                  }
                                            )
                                        }
                                    , trailing:
                                        
                                        HStack(){
                                            NavigationLink(destination: VStack() { RoomCreateFormView() }) {
                                                Image(systemName: "plus")
                                            }.padding()
                                            Button(action: {
                                                self.appState.isSettingsPresented.toggle()
                                            }) {
                                                Image(systemName: "gear")
                                                
                                            }.padding()
                                        }
                )
        }
        
        return GeometryReader(){ geometry in
            ZStack(alignment: .bottomTrailing) {
                roomsView.animation(.spring())
                
                NavigationView {
                    SettingsView()
                }
                .animation(.spring())
                .offset(CGSize(width: settingsOffsetWidth ?? geometry.size.width, height: 0))
                
                CurrentlyPlayingView()
                
            }
            .actionSheet(isPresented: self.$appState.isDeviceChooserPresented){
                ActionSheet(title: Text("Audio Device"),
                            message: deviceChooserMessage,
                            buttons: buttons)
            }
            //.colorScheme(.dark)
        }
    }
    
    
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}

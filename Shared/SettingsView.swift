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
        logger.info("[WebViewDelegate] decidePolicyFor host: \(navigationAction.request.url?.host)")

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

                  data.appendString("--\(boundary)\r\n")
                  data.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
                  data.appendString("Content-Type: \(mimeType)\r\n\r\n")
                  data.append(fileData)
                  data.appendString("\r\n")

                  return data as Data
                }


                httpBody.append(convertFileData(fieldName: "image_field",
                                                fileName: "party-people.jpg",
                                                mimeType: "image/jpg",
                                                fileData: fileData,
                                                using: boundary))

                httpBody.appendString("--\(boundary)--")

                req.httpBody = httpBody as Data
                
                let task = self.appState.api.urlSession.uploadTask(with: req, from: httpBody) { (data, resp, error) in
                    logger.debug("data=\(data), resp=\(resp), error=\(error)")
                }
                task.resume()
                
            }) {
                Text("Upload Image")
            }.padding()
            
            Button(action: { self.appState.sceneDelegate?.requestSpotifyAccess() }) {
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

extension Data {
    
    mutating func appendString(_ string: String) {
        guard let data = string.data(using: .utf8) else {
          return
        }
        self.append(data)
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

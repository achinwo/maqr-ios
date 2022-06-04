//
//  WebView.swift
//  Joli
//
//  Created by Anthony Chinwo on 21/04/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import WebKit

public final class WebViewWrapper: NSObject, UIViewRepresentable {
  
    @ObservedObject public var webViewStateModel: WebViewStateModel //action two way binding
    let action: ((_ navigationAction: WebView.NavigationAction) -> Void)? //delegates callback
    
    public let request: URLRequest
    public static var SCRIPT_HANDLER_MESSAGE = "mobileMessageHandler"
      
    public init(webViewStateModel: WebViewStateModel,
    action: ((_ navigationAction: WebView.NavigationAction) -> Void)?,
    request: URLRequest) {
        self.action = action
        self.request = request
        self.webViewStateModel = webViewStateModel
    }
    
    public func makeUIView(context: Context) -> WKWebView  {
        let view = WKWebView()
        view.configuration.userContentController.add(self, name: Self.SCRIPT_HANDLER_MESSAGE)
        
        view.navigationDelegate = context.coordinator
        view.load(request)
        
        #if !os(macOS)
        view.scrollView.contentInsetAdjustmentBehavior = .never
        #endif
        
        return view
    }
      
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.canGoBack, webViewStateModel.goBack {
            uiView.goBack() //go back if user tapped go back and last page is available
            webViewStateModel.goBack = false
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(action: action, webViewStateModel: webViewStateModel)
    }
    
    public final class Coordinator: NSObject {
        @ObservedObject var webViewStateModel: WebViewStateModel
        let action: ((_ navigationAction: WebView.NavigationAction) -> Void)?
        
        public init(action: ((_ navigationAction: WebView.NavigationAction) -> Void)?,
             webViewStateModel: WebViewStateModel) {
            self.action = action
            self.webViewStateModel = webViewStateModel
        }
        
    }
}

extension WebViewWrapper {
    
    public func makeNSView(context: Context) -> WKWebView {
        return self.makeUIView(context: context)
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {
        self.updateUIView(nsView, context: context)
    }
    
}

extension WebViewWrapper: WKScriptMessageHandler {
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        guard message.name == Self.SCRIPT_HANDLER_MESSAGE else {
            print("[WebViewWrapper#userContentController] unrecognised message name: \(message.name)")
            return
        }
        
        webViewStateModel.onJsScriptMessage(userContentController, message)
    }
    
}

extension WebViewWrapper.Coordinator: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if action == nil {
            decisionHandler(.allow) //if no custom delegates always return allow
        } else {
            action?(.decidePolicy(navigationAction, decisionHandler))
        }
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        webViewStateModel.loading = true
        action?(.didStartProvisionalNavigation(navigation))
    }
    
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        action?(.didReceiveServerRedirectForProvisionalNavigation(navigation))

    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webViewStateModel.loading = false
        webViewStateModel.canGoBack = webView.canGoBack
        action?(.didFailProvisionalNavigation(navigation, error))
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        action?(.didCommit(navigation))
    }
    
    static var debug: Bool {
#if DEBUG
        return true
#else
        return false
#endif
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webViewStateModel.loading = false
        webViewStateModel.canGoBack = webView.canGoBack
        
        if let title = webView.title {
            webViewStateModel.pageTitle = title
        }
        
        let appInfo = resolveAppInfo()
        let version = resolveAppVersion()
        
        let jsScript = """
window.android = {};
window.android.build = {
                    versionCode: '',
                    versionName: '\(version.description)',
                    buildType: '',
                    isDebug: \(Self.debug),
                    appId: '\(appInfo.appId ?? "")',
                    deviceId: '\(appInfo.uuid ?? "")',
                    deviceName: '\(appInfo.name)',
                    deviceModel: '\(appInfo.model)',
                    platform: 'ios',
                    platformVersion: '\(appInfo.systemVersion)'
                };
"""
        webView.evaluateJavaScript(jsScript) { (result, error) in
            print("[\(Self.self)] result: \(String(describing: result)), error: \(String(describing: error))")
        }
        
        if let edgeInsets = webViewStateModel.edgeInsets {
            let script = """
                        window.setWindowInsets({
                            top: \(edgeInsets.top),
                            right: \(edgeInsets.trailing),
                            bottom: \(edgeInsets.bottom),
                            left: \(edgeInsets.leading)
                        });
                    """
            
            webView.evaluateJavaScript(script) { (result, error) in
                print("[\(Self.self)] insets result: \(String(describing: result)), error: \(String(describing: error))")
            }
        }
        
        action?(.didFinish(navigation))
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webViewStateModel.loading = false
        webViewStateModel.canGoBack = webView.canGoBack
        action?(.didFail(navigation, error))
    }
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if action == nil  {
            completionHandler(.performDefaultHandling, nil)
        } else {
            action?(.didRecieveAuthChallange(challenge, completionHandler))
        }
        
    }
}

public final class WebViewStateModel: ObservableObject {
    
    public typealias JsMessageCallback = (WKUserContentController, WKScriptMessage) -> Void
    
    @Published public var pageTitle: String = "Web View"
    @Published public var loading: Bool = false
    @Published public var canGoBack: Bool = false
    @Published public var goBack: Bool = false
    
    let onJsMessageCallback: JsMessageCallback?
    @Published public var edgeInsets: EdgeInsets?
    
    public init(pageTitle: String = "Web View", windowInsets: EdgeInsets? = nil, callback: JsMessageCallback? = nil){
        self.pageTitle = pageTitle
        self.onJsMessageCallback = callback
        self.edgeInsets = windowInsets
    }
    
    public func updatedEdgeInsets(_ edgeInsets: EdgeInsets) -> Self {
        
        guard edgeInsets != self.edgeInsets else { return self }
        
        self.edgeInsets = edgeInsets
        return self
    }
    
    public func onJsScriptMessage(_ userContentController: WKUserContentController, _ message: WKScriptMessage) {
        self.onJsMessageCallback?(userContentController, message)
    }
    
}

public struct WebView: View {
    public enum NavigationAction {
           case decidePolicy(WKNavigationAction,  (WKNavigationActionPolicy) -> Void) //mendetory
           case didRecieveAuthChallange(URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) //mendetory
           case didStartProvisionalNavigation(WKNavigation)
           case didReceiveServerRedirectForProvisionalNavigation(WKNavigation)
           case didCommit(WKNavigation)
           case didFinish(WKNavigation)
           case didFailProvisionalNavigation(WKNavigation,Error)
           case didFail(WKNavigation,Error)
       }
       
    @ObservedObject var webViewStateModel: WebViewStateModel
    
    private var actionDelegate: ((_ navigationAction: WebView.NavigationAction) -> Void)?
    
    
    let uRLRequest: URLRequest
    
    
    public var body: some View {
        
        WebViewWrapper(webViewStateModel: webViewStateModel,
                       action: actionDelegate,
                       request: uRLRequest)
    }
    /*
     if passed onNavigationAction it is mendetory to complete URLAuthenticationChallenge and decidePolicyFor callbacks
    */
    public init(request: URLRequest, webViewStateModel: WebViewStateModel, onNavigationAction: ((_ navigationAction: WebView.NavigationAction) -> Void)? = nil) {
        self.uRLRequest = request
        self.webViewStateModel = webViewStateModel
        self.actionDelegate = onNavigationAction
    }
    
    public init(url: URL, webViewStateModel: WebViewStateModel, onNavigationAction: ((_ navigationAction: WebView.NavigationAction) -> Void)? = nil) {
        self.init(request: URLRequest(url: url),
                  webViewStateModel: webViewStateModel,
                  onNavigationAction: onNavigationAction)
    }
}

//struct WebView_Previews: PreviewProvider {
//    static var previews: some View {
//        WebView()
//    }
//}

//
//  EventView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 15/04/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import MaqrApi
import AlertToast

#if !os(macOS)
import SharedUI
#endif

struct WeddingEventView: JoliView, Experience {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State var dataModel: ExperienceData?
    
    var dataModelDefault: ExperienceData.Defaults
    
    @State var editMode: EditingState = .inactive
    
    @StateObject var webViewStateModel: WebViewStateModel
    
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    static var title: String = "Wedding"
    
    static var subtitle: String = "Guest organiser for marriage ceremony"
    
    static var iconName: String = "person.2.circle"
    
    static var basePath: String = "ewed"
    
    public static var dataKeys: [PartialKeyPath<ExperienceData>] {
        return [
             \ExperienceData.bannerImageUrl,
             \ExperienceData.backgroundImageUrl,
             \ExperienceData.brandContactEmail,
              \ExperienceData.productName,
              \ExperienceData.productDescription,
              \ExperienceData.productImageUrl,
              \ExperienceData.socialInstagramUsername,
              \ExperienceData.socialFacebookPage,
        ]
    }
    
    public static var supportedItemTypes: Set<ExperienceItemType> {
        return [.menuFoodItem, .product]
    }
    
    init(_ data: ExperienceData?) {
        self._dataModel = State(initialValue: data)
        self.dataModelDefault = ExperienceData.Defaults()
        
        let model = WebViewStateModel() { (controller, message) in
            print("[WeddingEventView] received: \(message.body)")
        }
        
        self._webViewStateModel = StateObject(wrappedValue: model)
    }
    
    @State var currentLocation: AppLocation? = nil
    
    var url: URL {
        
        guard case let AppLocation.experienceWeddingEvent(_, rawUrl) = appCoordinator.currentLocation,
              let url = rawUrl, let components = URLComponents(url: url, resolvingAgainstBaseURL: true), let absUrl = components.url else {
            return api.baseUrlHttp.appendingPathComponent("ewed/\(dataModel?.uuid ?? "lizmanfred")")
        }
        
        return absUrl
    }
    
    var contentView: some View {
        WebView(request: URLRequest(url: self.url), webViewStateModel: self.webViewStateModel.updatedEdgeInsets(safeAreaInsets), onNavigationAction: self.onWebViewNavigation(_:))
            .edgesIgnoringSafeArea(.vertical)
        .frame(minWidth: screenWidth, minHeight: screenHeight, alignment: .center)
        .backgroundColor(.fixedWhite)
        .fullScreenCover(item: self.$webViewStateModel.externalUrl) {
            self.webViewStateModel.externalUrl = nil
        } content: { url in
            SafariWebView(url: url)
                .ignoresSafeArea()
        }
        .toast(isPresenting: self.$webViewStateModel.isPresentingAlert) {
            AlertToast(type: .regular, title: self.webViewStateModel.alertMessage)
        } completion: {
            self.webViewStateModel.alertMessage = nil
        }
        .onReceive(appCoordinator.$currentLocation) { appLocation in
            self.currentLocation = appLocation
        }
    }
    
    func onWebViewNavigation(_ navigationAction: WebView.NavigationAction) -> Void {
        switch navigationAction {
            case .decidePolicy(_, let completionHandler):
                completionHandler(.allow)
            case .didRecieveAuthChallange(let challenge, let completionHandler):
#if DEBUG
                let cred = URLCredential(trust: challenge.protectionSpace.serverTrust!)
                completionHandler(.useCredential, cred)
#else
                completionHandler(.performDefaultHandling, nil)
#endif
                
            default:
                break
        }
    }
}

struct EventView_Previews: PreviewProvider {
    static var previews: some View {
        WeddingEventView(nil)
    }
}

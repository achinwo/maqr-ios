//
//  EventView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 15/04/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliCore

#if !os(macOS)
import SharedUI
#endif

struct WeddingEventView: JoliView, Experience {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State var dataModel: ExperienceData?
    
    var dataModelDefault: ExperienceData.Defaults
    
    @State var editMode: EditingState = .inactive
    
    @StateObject var webViewStateModel: WebViewStateModel = WebViewStateModel()
    
    static var title: String = "Wedding"
    
    static var subtitle: String = "Guest organiser for marriage ceremony"
    
    static var iconName: String = "person.2.circle"
    
    static var basePath: String = "ewed"
    
    public static var dataKeys: [PartialKeyPath<ExperienceData>] {
        return [
             \ExperienceData.bannerImageUrl,
             \ExperienceData.backgroundImageUrl,
             \ExperienceData.brandContactEmail,
        ]
    }
    
    public static var supportedItemTypes: Set<ExperienceItemType> {
        return [.menuFoodItem, .product]
    }
    
    init(_ data: ExperienceData?) {
        self._dataModel = State(initialValue: data)
        self.dataModelDefault = ExperienceData.Defaults()
    }
    
    var contentView: some View {
        WebView(request: URLRequest(url: api.baseUrlHttp.appendingPathComponent("ewed/\(dataModel?.uuid ?? "lizmanfred")")), webViewStateModel: self.webViewStateModel, onNavigationAction: self.onWebViewNavigation(_:))
            .edgesIgnoringSafeArea(.vertical)
        .frame(minWidth: screenWidth, minHeight: screenHeight, alignment: .center)
        .backgroundColor(.fixedWhite)
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

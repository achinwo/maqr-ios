//
//  DynamicExperienceView.swift
//  Joli
//
//  Created by Anthony Chinwo on 05/12/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import MaqrApi
import Combine
import AlertToast

extension AppLocation {
    
    func experienceView(_ expData: ExperienceData) -> AnyView? {
        let path = self.rawValue
        
        guard let exp = Experiences.allCases.first(where: { path.starts(with: $0.rawValue.basePath) || path.starts(with: "/\($0.rawValue.basePath)/") }),
                self.isExperience else {
            return nil
        }
        
        return exp.toView(expData).eraseToAnyView()
    }
    
}

struct DynamicExperienceView: JoliContentView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    
    var websocket: Socket
    
    @State var experienceData: ExperienceData? = nil
    @State var toastInfo: (alert: AlertToast, onDismiss: (Bool) -> Void)? = nil
    @State var loadingData: Bool = false
    
    @Binding var currentUser: User?
    
    @Environment(\.colorScheme) var colorScheme
    let appLocation: AppLocation
    
    public init(_ location: AppLocation, currentUser: Binding<User?>, websocket: Socket){
        self._currentUser = currentUser
        self.websocket = websocket
        self.appLocation = location
    }
    
    @MainActor
    private func loadExperienceData() async {
        guard let expId = appLocation.experienceId else { return }
        
        self.loadingData = true
        defer { self.loadingData = false }
        
        do {
            let dataList = try await StikrExperienceData.all(where: [.uuid: expId as AnyObject], limit: 1, baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            guard let data = dataList.first else { return }
            
            self.experienceData = ExperienceData.fromExperienceData(data, baseUrl: api.baseUrlHttp)
        } catch {
            self.appCoordinator.globalErrorHandler()(error)
        }
    }
    // URL(staticString: "https://169.254.249.58:3000/public/icon-192_smartz.png")
    //@State var selectedImageUrl: URL? = nil //URL(staticString: "https://localhost:3000/public/icon-192_smartz.png")
    
    var contentView: some View {
        VStack(){
            if let experienceData = experienceData, let view = appLocation.experienceView(experienceData) {
                view
            } else if loadingData {
                ProgressView("Loading experience...")
                    .font(.title.weight(.light))
            } else {
                
//                let imageCallback = { (img: UIImage?, imgName: String?, error: Error?) in
//                    print("selected image: \(String(describing: imgName))")
//                }
//
//                ImageView(url: selectedImageUrl, isCircular: false, onSelected: imageCallback) { (image, imgName, error) in
//
//                } content: {
//                    Color.clear
//                }
//                .frame(width: screenWidth / 3, height: screenWidth / 3)
                
                Button(){
                    Task() { await self.loadExperienceData() }
                } label: {
                    Label("Tap to refresh", systemImage: "arrow.clockwise.circle.fill")
                }
                .font(.title.weight(.light))
            }
        }
        .frame(width: screenWidth, height: screenHeight)
        .backgroundColor(.fixedWhite)
        .task(){
            guard !loadingData else { return }
            await self.loadExperienceData()
        }
    }
}

//struct DynamicExperienceView_Previews: PreviewProvider {
//    static var previews: some View {
//        DynamicExperienceView()
//    }
//}

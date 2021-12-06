//
//  DynamicExperienceView.swift
//  Joli
//
//  Created by Anthony Chinwo on 05/12/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import JoliCore
import Combine
import AlertToast

extension AppLocation {
    
    func experienceView(_ expData: ExperienceData) -> AnyView? {
        
        guard self.isExperience else { return nil }
        
        switch self {
            case .experienceCook(_):
                return MealboxView(expData).eraseToAnyView()
            case .experienceMeal(_):
                return RestaurantView(expData).eraseToAnyView()
            case .experienceBrand(_):
                return TvShowPromoView(expData).eraseToAnyView()
            default:
                return nil
        }
    }
    
}

struct DynamicExperienceView<PlaybackControllerType: PlaybackController>: JoliContentView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    
    var localPlaybackController: PlaybackControllerType
    
    var websocket: Socket
    
    @State var websocketCancel: AnyCancellable?
    @State var experienceData: ExperienceData? = nil
    @State var toastInfo: (alert: AlertToast, onDismiss: (Bool) -> Void)? = nil
    @State var loadingData: Bool = false
    
    @Binding var currentUser: User?
    
    @Environment(\.colorScheme) var colorScheme
    let appLocation: AppLocation
    
    public init(_ location: AppLocation, currentUser: Binding<User?>, websocket: Socket, localPlaybackController: PlaybackControllerType){
        self._currentUser = currentUser
        self.websocket = websocket
        self.localPlaybackController = localPlaybackController
        self.appLocation = location
    }
    
    private func loadExperienceData() {
        guard let expId = appLocation.experienceId else { return }
        
        self.loadingData = true
        StikrExperienceData.all(where: [.uuid: expId as AnyObject], limit: 1, baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            .then() { dataList in
                guard let data = dataList.first else { return }
                
                self.experienceData = ExperienceData.fromExperienceData(data, baseUrl: api.baseUrlHttp)
            }
            .catch() { error in
                print("[error] \(error)")
                appCoordinator.globalErrorHandler()(error)
            }
            .always {
                self.loadingData = false
            }
    }
    
    var contentView: some View {
        VStack(){
            if let experienceData = experienceData, let view = appLocation.experienceView(experienceData) {
                view
            } else if loadingData {
                ProgressView("Loading experience...")
                    .font(.title.weight(.light))
            } else {
                Button(){
                    self.loadExperienceData()
                } label: {
                    Label("Tap to refresh", systemImage: "arrow.clockwise.circle.fill")
                }
                .font(.title.weight(.light))
            }
        }
        .frame(width: screenWidth, height: screenHeight)
        .onAppear(){
            guard !loadingData else { return }
            //self.loadExperienceData()
        }
    }
}

//struct DynamicExperienceView_Previews: PreviewProvider {
//    static var previews: some View {
//        DynamicExperienceView()
//    }
//}

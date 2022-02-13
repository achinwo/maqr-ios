//
//  HomeView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 12/02/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import JoliCore

struct HomeView<Footer: View>: JoliView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Environment(\.colorScheme) var colorScheme
    
    @Debounced(delay: 0.3) public var requestStoredExperienceRefreshAt: Date? = nil
    @Debounced(delay: 1.3) public var requestExperiencePersistAt: Date? = nil
    
    let footerView: Footer
    
    @State var isRefreshingHistory = false
    @State public var storedExperiences: [StikrExperienceData] = []
    @Binding var selectedExperienceUuid: String?
    public var onSelect: (StikrExperienceData) -> Void
    
    @MainActor
    func updateStoredExperiences() async {
        defer { isRefreshingHistory = false }
        
        do {
            let exps = try await StikrExperienceData.all(baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            self.storedExperiences = exps
        } catch {
            print("Unable to fetch exps: \(error)")
        }
    }
    
    public init(selectedExperienceUuid: Binding<String?>, onSelect: @escaping (StikrExperienceData) -> Void, @ViewBuilder footer: () -> Footer) {
        self.footerView = footer()
        self._selectedExperienceUuid = selectedExperienceUuid
        self.onSelect = onSelect
    }
    
    var contentView: some View {
        RefreshableScrollView(refreshing: $isRefreshingHistory){
            ScrollViewReader() { proxy in
                VStack(){
                    VStack(){
                        LiveExperiencesView(experiences: $storedExperiences, selectedExperienceUuid: $selectedExperienceUuid, onSelect: onSelect)
                    }
                    .padding([.top, .horizontal])
                    .frame(minHeight: screenHeight / 2)
                    footerView
                    Spacer()
                }
                .frame(minHeight: screenHeight * 0.5)
                
            }
        }
        .onReceive(self.$requestStoredExperienceRefreshAt){ requestedAt in
            print("Requested refresh: \(String(describing: requestedAt))")
            
            guard requestedAt != nil else { return }
            
            Task() { await self.updateStoredExperiences() }
            self.requestStoredExperienceRefreshAt = nil
        }
        .onChange(of: self.isRefreshingHistory) { refreshing in
            print("REFRESHING: \(refreshing)")
            guard refreshing else { return }
            self.requestStoredExperienceRefreshAt = Date()
        }
        .onAppear(){
            Task() { await self.updateStoredExperiences() }
        }
    }
    
}

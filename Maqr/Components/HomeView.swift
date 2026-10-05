//
//  HomeView.swift
//  Smartz
//
//  Created by Anthony Chinwo on 12/02/2022.
//  Copyright © 2022 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import SharedUI
import MaqrApi

extension ExperienceDataAccess: CaseIterable, Identifiable {
    
    public var id: String {
        rawValue
    }
    
    
    public static var allCases: [ExperienceDataAccess] {
        return [.experienceDataAccessPublic, .restricted, .experienceDataAccessPrivate]
    }
    
}

struct HomeView<Footer: View>: JoliView {
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.safeAreaInsets) var safeAreaInsets
    @Environment(\.colorScheme) var colorScheme
    
    @Debounced(delay: 0.3) public var requestStoredExperienceRefreshAt: Date? = nil
    @Debounced(delay: 1.3) public var requestExperiencePersistAt: Date? = nil
    
    let footerView: Footer
    
    @State var isRefreshingHistory = false
    @State public var storedExperiences: [StikrExperienceData] = []
    @State var currentAuth: Auth? = nil
    
    @Binding var selectedExperienceUuid: String?
    @Binding var selectedAccessLevel: ExperienceDataAccess
    
    public var onSelect: (LiveExperiencesView.Action, StikrExperienceData) -> Void
    
    @MainActor
    func updateStoredExperiences() async {
        defer { isRefreshingHistory = false }
        
        do {
            let exps = try await StikrExperienceData.all(where: [.experienceDataAccess: selectedAccessLevel.rawValue as AnyObject], baseUrl: api.baseUrlHttp, urlSession: api.urlSession)
            self.storedExperiences = exps
        } catch {
            print("Unable to fetch exps: \(error)")
        }
    }
    
    public init(selectedExperienceUuid: Binding<String?>, accessLevel: Binding<ExperienceDataAccess>, onSelect: @escaping (LiveExperiencesView.Action, StikrExperienceData) -> Void, @ViewBuilder footer: () -> Footer) {
        self.footerView = footer()
        self._selectedExperienceUuid = selectedExperienceUuid
        self.onSelect = onSelect
        self._selectedAccessLevel = accessLevel
    }
    
    var contentView: some View {
        RefreshableScrollView(refreshing: $isRefreshingHistory){
            ScrollViewReader() { proxy in
                VStack(){
                    VStack(){
                        if isRefreshingHistory && storedExperiences.isEmpty {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding()
                            Text("Fetching \(selectedAccessLevel.rawValue.lowercased()) experiences...")
                                .font(.callout)
                                .padding(.horizontal)
                        } else if !isRefreshingHistory && storedExperiences.isEmpty {
                            Text("No \(selectedAccessLevel.rawValue.lowercased()) experiences to show. Create one from the \"Design\" tab.")
                                .font(.callout)
                                .foregroundColor(.secondaryLabel)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            LiveExperiencesView(experiences: $storedExperiences, selectedExperienceUuid: $selectedExperienceUuid, onSelect: onSelect)
                        }
                    }
                    .padding([.top, .horizontal])
                    .padding(.top)
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
        .onChange(of: self.selectedAccessLevel) { accessLevel in
            print("[HomeView] changes accesslevel: \(accessLevel)")
            Task() { await self.updateStoredExperiences() }
        }
        .onChange(of: self.currentAuth) { _ in
            Task() { await self.updateStoredExperiences() }
        }
        .onReceive(appCoordinator.authSubject, assign: \.currentAuth, target: self)
        .onAppear(){
            Task() { await self.updateStoredExperiences() }
        }
    }
    
}

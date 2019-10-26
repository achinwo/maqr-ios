//
//  AppState.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliApi
import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var musicrooms: [Musicroom] = []

    var didChange = PassthroughSubject<AppState, Never>()

    func fetch() {
        Musicroom.all()
            .then { [weak self] rooms in
                self?.musicrooms = rooms
        }
//        service.search(matching: query) { [weak self] result in
//            DispatchQueue.main.async {
//                switch result {
//                case .success(let repos): self?.repos = repos
//                case .failure: self?.repos = []
//                }
//            }
//        }
    }
}

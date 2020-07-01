//
//  View.swift
//  Joli
//
//  Created by Anthony Chinwo on 25/06/2020.
//  Copyright © 2020 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore
import JSONSchema
import SwiftUI
//import UIKit

enum Location {
    case home
}

protocol SchemaView: View {
    var schema: Schema { get }
}

//struct AppView: SchemaView {
//
//    @State var schema: Schema
//    @State var location: Location
//
//    var body: some View {
//        return Text("Hello world") //AppView.viewFromSchema(schema)
//    }
//
//}
//
//extension SchemaView {
//
//    static func viewFromSchema(_ schema: Schema) -> some View {
//        return EmptyView()
//    }
//
//}

//struct ContainerView: SchemaView {
//    var schema: Schema
//    var body: some View {
//        return Text("Hello world")
//    }
//}

@available(iOS 13, *)
struct ContainerView_Preview: PreviewProvider {
    
    static var previews: some View {
        return Text("Hello")//AppView(schema: Schema(["type":"string"]), location: .home)
    }
    
    static var platform: PreviewPlatform {
        return .iOS
    }
}

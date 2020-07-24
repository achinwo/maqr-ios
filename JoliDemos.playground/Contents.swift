//: A UIKit based Playground for presenting user interface
import Foundation
import UIKit
import PlaygroundSupport
import SwiftUI
import JoliPlayground
import JoliCore


struct ContentView: View {
     var body: some View {
        //return Text("Hello World")//.frame(width: 100, height: 100, alignment: .center)
        
        let user = SEED_DATA.users.first!
        //Text("Hello World \(user.name)")//
        return UserProfileView2(user: user.builder()).offset(x: 0, y: 1)
//            VStack(){
//                Text("SwiftUI in a Playground!")
//
//            }
        //}
                //.frame(minWidth: 200,
//                maxWidth: 210,
//                minHeight: 500,
//                maxHeight: 600,
//                alignment: .topLeading)
     }
}
//let parent = playgroundWrapper(
//  child: UIHostingController(rootView: ContentView()),
//  device: .phone4_7inch,
//  orientation: .landscape,
//  contentSizeCategory: .large)

//print(aVeryLongString)

// Present the view controller in the Live View window
PlaygroundPage.current.liveView = UIHostingController(rootView: ContentView())//

//: A UIKit based Playground for presenting user interface
import Foundation
import UIKit
import PlaygroundSupport
import SwiftUI
import JoliPlayground
import JoliCore
import JoliApi
import PartialSheet
import Combine
import Starscream

var soc: Socket!
var cancellable: AnyCancellable? = nil

func logicMain() -> Void {
    let url = URL(fileURLWithPath: "myImage.png")
    print("Logic main triggered - \(url.absoluteString)")
//    let track:Track = SEED_DATA.tracks.first!
//
//    soc = Socket()
//    soc.connect()
//    cancellable = soc
//        .sink(){ completion in
//            print("completion: \(completion)")
//        } receiveValue: { value in
//            print("value: \(value)")
//        }
//
////    let liveTrack: LiveTrack = track.play()
//    PlaygroundPage.current.needsIndefiniteExecution = true
}

struct MasterView: View {
    @State private var showPopover: Bool = false

    var body: some View {
        VStack {
            Button("Show popover") {
                self.showPopover = true
            }.popover(
                isPresented: self.$showPopover,
                arrowEdge: .bottom
            ) { Text("Popover") }
        }
    }
}

struct ContentView: View {
    
    //@EnvironmentObject var partial: PartialSheetManager
    
     var body: some View {
        let user = SEED_DATA.users.first!
        //print("partial: \(partial)")
        //Text("Hello World \(user.name)")//
        //return DevicesSampleView()
            //.addPartialSheet()
        //UserProfileView2(user: user.builder()).offset(x: 0, y: 1)
        MasterView()
     }
}

func uiMain() -> Void {
    
    let view = NavigationView(){
        ContentView()
    }//.environmentObject(PartialSheetManager())
    
    let parent = playgroundWrapper(
        child: UIHostingController(rootView: view),
        device: .phone4inch,
        orientation: .portrait,
        contentSizeCategory: .large)
    
    PlaygroundPage.current.liveView = parent
}


let main: () -> Void = logicMain

main()

//hello()
// Present the view controller in the Live View window
//UIHostingController(rootView: ContentView())//


/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view that clips an image to a circle and adds a stroke and shadow.
*/

import SwiftUI

struct CircleImage: View {
    @EnvironmentObject var appState: AppState
    
    @State var image: Image?
    var url: String?
    
    init(url: String){
        self.url = url
    }
    
    var body: some View {
        
        let img: Image
        if let url = url, let urlImage = appState.imagesByUrl[url] {
            img = urlImage
        }else{
            img = image ?? Image(systemName: "exclamationmark.icloud")
        }
        
        return img
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .onAppear() {
                    
                    guard let url = self.url else {
                        return
                    }
                    
                    self.appState.fetchedImage(url: url)
                        .then() { (image: Image?) in
                            self.image = image
                    }
                }
        
    }
}

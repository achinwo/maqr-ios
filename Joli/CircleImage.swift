/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view that clips an image to a circle and adds a stroke and shadow.
*/

import SwiftUI

struct CircleImage: View {
    var image: Image?

    var body: some View {
        
        let img = self.image ?? Image(systemName: "exclamationmark.icloud")
        
        return img
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    //.overlay(Circle().stroke(Color.secondary, lineWidth: 1))
        
    }
}

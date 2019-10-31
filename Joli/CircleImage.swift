/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view that clips an image to a circle and adds a stroke and shadow.
*/

import SwiftUI

struct CircleImage: View {
    var image: Image?

    var body: some View {
        if let img = self.image {
            return img
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
        } else {
            return Image(systemName: "exclamationmark.icloud")
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
        }
        
    }
}

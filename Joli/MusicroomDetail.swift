//
//  MusicroomDetail.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi

struct MusicroomDetail: View {
    var room: Musicroom

    var body: some View {
        VStack {

            VStack(alignment: .leading) {
                Text(room.name)
                    .font(.title)

//                HStack(alignment: .top) {
//                    Text(landmark.park)
//                        .font(.subheadline)
//                    Spacer()
//                    Text(landmark.state)
//                        .font(.subheadline)
//                }
            }
            .padding()

            Spacer()
        }
        .navigationBarTitle(Text(verbatim: room.name), displayMode: .inline)
    }
}

//struct MusicroomDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        MusicroomDetail()
//    }
//}

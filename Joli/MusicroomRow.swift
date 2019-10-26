//
//  MusicroomRow.swift
//  Joli
//
//  Created by Anthony Chinwo on 26/10/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import JoliApi

struct MusicroomRow: View {
    var room: Musicroom

    var body: some View {
        HStack {
            Text(verbatim: room.name)
            Spacer()
        }
    }
}

//struct MusicroomRow_Previews: PreviewProvider {
//    static var previews: some View {
//        MusicroomRow()
//    }
//}

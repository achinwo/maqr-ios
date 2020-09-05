//
//  MusicroomCreateView.swift
//  Joli
//
//  Created by Anthony Chinwo on 08/12/2019.
//  Copyright © 2019 Anthony Chinwo. All rights reserved.
//

import SwiftUI
import Combine


struct MultipleSelectionRow: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        return Button(action: self.action) {
            HStack {
                Text(self.title)
                if self.isSelected {
                    Spacer()
                    Image(systemName: "checkmark").foregroundColor(.blue)
                }
            }
        }.foregroundColor(Color.black)
    }
}

enum Language: Int, CaseIterable, Identifiable {
    case english = 0
    case polish = 1

    var id: Language {
        self
    }

    var literal: String {
        switch self {
        case .english: return "English"
        case .polish: return "Polish"
        }
    }
}

class PreferedLanguages: ObservableObject {
    @Published var languages = [Language]()

}

struct SettingsLanguagePickerView: View {
    @State private var selections = [Language]()

    @ObservedObject var preferedLanguages: PreferedLanguages

    init(_ preferedLanguages: PreferedLanguages) {
        self.preferedLanguages = preferedLanguages
    }

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        //return Text("Hello")
        NavigationView {
            List {
                Section(header: Text("Choose prefered languages")) {
                    ForEach(Language.allCases, id: \.self) { item in
                        MultipleSelectionRow(title: item.literal, isSelected: self.selections.contains(item)) {
                            if self.selections.contains(item) {
                                self.selections.removeAll(where: { $0 == item })
                            }
                            else {
                                self.selections.append(item)
                            }
                        }
                    }

                }
            }
            .onAppear(perform: { self.selections = self.preferedLanguages.languages })
            .listStyle(GroupedListStyle())
            .navigationBarTitle("Languages", displayMode: .inline)
            .navigationBarItems(trailing:
                Button(action: {
                    self.preferedLanguages.languages = self.selections
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("OK")
                }
            )
        }
    }
}

struct RoomCreateFormView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var details = ""
    @State private var departure = Date()
    @State private var pin = "1234"
    @State private var checked = true
    @State private var smoker = false
    @State private var pets = false
    
    @State private var checkin  = Date()
    @State private var checkout = Date()
    @State private var rating: Double = 4.0
    
    @State var error: String? = nil
    @State var name = ""
    
    @State var padding = 0
    @State private var showLanguageSheet = false

    @State private var x = 0
    var choices = [1,2,3,4,5,6,7]

    @ObservedObject var preferedLanguages = PreferedLanguages()
    
    @EnvironmentObject var appState: AppState
    
    var form: some View {
        return Form {

            //Section(header: Text("Flight")) {
            TextField("Title", text: self.$name).lineLimit(1)
            TextField("Details", text: self.$details)
                .frame(width: UIScreen.main.bounds.width, height: 50, alignment: .center)
                .lineLimit(nil)
                

//                Toggle(isOn: self.$checked) {
//                    Text("Luggage ")
//                    Image(systemName: "briefcase.fill")
//                }
//
//                DatePicker(selection: self.$departure) {
//                    HStack {
//                        Text("Departure ")
//                        Image(systemName: "airplane")
//                    }
//                }
//
//                HStack {
//                    Spacer()
//                    Button("Send") { print("edit hotel") }
//                }
   //         }
            
            Section(header: Text("Invites").font(.caption)) {
                Button(action: {
                    self.showLanguageSheet.toggle()
                }) {
                    HStack {
                        Text("Guests").foregroundColor(Color.black)
                        Spacer()
                        Text("\(preferedLanguages.languages.count)")
                            .foregroundColor(Color(UIColor.systemGray))
                            .font(.body)
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(UIColor.systemGray4))
                            .font(Font.body.weight(.medium))

                    }
                }
                .sheet(isPresented: $showLanguageSheet) {
                    SettingsLanguagePickerView(self.preferedLanguages)
                }

                Picker(selection: $x, label: Text("One item Picker")) {
                    ForEach(choices, id: \.self) { num in
                      Text("\(num)")
                   }
                }

            }
        //}

//        Section(header: Text("Accomodation")) {
//
//            Toggle(isOn: self.$smoker) {
//                Text("Smoking Room ")
//                Image(systemName: "nosign")
//            }
//
//            Toggle(isOn: self.$pets) {
//                Text("Pets ")
//                Image(systemName: "tortoise.fill")
//            }
//            //.padding(.bottom, self.padding)
//
//            HStack {
//                Spacer()
//                Button("Send") { print("edit hotel") }
//            }
//        }
//
//        Section(header: Text("Booking")) {
//            Text("Rating \(Int(self.rating)) out of 5 ⭐️")
//            Slider(value: self.$rating, in: 1...5, step: 1)
//            SecureField("Pin", text: self.$pin)
//        }
            
        Button(action: self.testClick){
                                Text("Done").font(.title)
                                }.padding()
            
        Text("Cancel")
            .foregroundColor(Color.gray)
            .onTapGesture {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
        //.navigationBarBackButtonHidden(true)
        .navigationBarTitle(Text("Setup Room"), displayMode: NavigationBarItem.TitleDisplayMode.automatic)
        .keyboardAwarePadding()
        .resignKeyboardOnDragGesture()
    }
    
    var body: some View {
        let errorText = Text(error ??  "")
                        .foregroundColor(Color.white)
                        .animation(.easeInOut)
        
        return VStack() {
            HStack(){
                if error == nil {
                    errorText.frame(width: UIScreen.main.bounds.width, height: 0, alignment: .center)
                } else{
                    errorText.padding()
                }
            }
            .background(Color.red)
            
            self.form
        }
//            HStack(alignment: .center) {
//                Spacer()
//                Button(action: {
//                    self.testClick()
//                }){
//                    Text("Done").font(.title)
//                    }.padding()
//                Spacer()
//            }.padding()
//
//            Text("Cancel").foregroundColor(Color.gray).onTapGesture {
//                self.presentationMode.wrappedValue.dismiss()
//            }
//
//        }
    }
    
    func testClick(){
        self.error = nil
        
        logger.debug("[RoomCreateFormView] clicked")
        let name: String = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let details: String = self.details.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !name.isEmpty && !details.isEmpty else {
            return
        }
        
        self.appState.api.createMusicroom(name: name, details: details)
            .then() { newRoom in
                logger.debug("[NEW_ROOM] \(newRoom)")
                self.presentationMode.wrappedValue.dismiss()
        }
        .catch(){ error in
            self.error = error.localizedDescription
        }
    }
    
}

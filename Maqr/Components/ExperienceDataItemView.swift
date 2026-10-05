    //
    //  ExperienceDataItemView.swift
    //  Smartz
    //
    //  Created by Anthony Chinwo on 22/05/2022.
    //  Copyright © 2022 Anthony Chinwo. All rights reserved.
    //

import SwiftUI
import SharedUI
import MaqrApi

struct ExperienceDataItemSummaryView: View {
    
    @State var item: ExperienceData.Item
    @State var index: Int
    
    var body: some View {
        HStack(){
            if item.experienceItemType.isNumbered {
                VStack(alignment: .leading){
                    Text("\(index + 1).")
                        .font(.headline.weight(.light))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .id("\(item.id)-\(index)")
            }
            
            VStack(alignment: .leading){
                Text(item.title ?? "Untitled \(item.experienceItemType.label) \(index + 1)")
                    .if(item.title == nil) { textView in
                        textView.font(.callout.italic())
                    }
                if let subtitle = item.subtitle {
                    Text(subtitle).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
            }
        }
    }
    
}

struct ExperienceDataItemView: JoliView {
    
    init(item: ExperienceData.Item, index: Int, data: ExperienceData) {
        self._itemDescription = State(initialValue: item.subtitle ?? .empty)
        
        self._item = State(wrappedValue: item)
        self._index = State(initialValue: index)
        self._data = StateObject(wrappedValue: data)
    }
    
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.presentationMode) var presentationMode
    
    @State var item: ExperienceData.Item
    @State var index: Int
    @StateObject var data: ExperienceData
    @State var itemDescription: String
    
    func onItemRemove() {
        self.appCoordinator.withAlert("Remove \(item.experienceItemType.label)?", message: "Permanent delete this item", destructive: true, label: "Remove") {
            data.items = data.items.filter() { $0.uuid != item.uuid }
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    @available(iOS 15.0, *)
    var removeButton: some View {
        Button(role: .destructive){
            onItemRemove()
        } label: {
            Label("Delete", systemImage: "trash")
                .foregroundColor(.red)
        }
        .buttonStyle(.borderless)
        .controlSize(.large)
        .font(.headline)
    }
    
    var removeButtonLegacy: some View {
        Button(){
            onItemRemove()
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .foregroundColor(.red)
    }
    
    @State private var spicyRating: Double = 0
    @State var hasCaution: Bool = false
    @State var duration: Double = 0
    @State var priceField: String = "0.00"
    
    var mealPrepStepSections: some View {
        let setter = { (newValue: String, keyPath: WritableKeyPath<ExperienceData.Item, String?>) in
                //var element = item
            item[keyPath: keyPath] = newValue
                //items = items.filter({ $0.uuid != element.uuid }) + [element]
        }
        
        let makeBinding = { (item: ExperienceData.Item, keyPath: WritableKeyPath<ExperienceData.Item, String?>) -> Binding<String> in
            return Binding<String>(){
                return item[keyPath: keyPath] ?? .empty
            } set: { newValue in
                print("Setting value: \(newValue)")
                setter(newValue, keyPath)
            }
        }
        
        return Group(){
            Section(header: Text("Spicy")) {
                HStack(){
                    if let spicy = Spicy.fromNumber(Int(spicyRating)) {
                        Text(spicy.rawValue.capitalized)
                        Spacer()
                        Text("\(spicy.emoji)")
                    } else {
                        Text("Not Spicy")
                            .font(.callout.italic())
                            .foregroundColor(.secondary)
                    }
                }
                Slider(value: self.$spicyRating, in: 0...3, step: 1)
                    .accentColor(.orange)
            }
            .onChange(of: self.spicyRating) { rating in
                item.spicy = Spicy.fromNumber(Int(spicyRating))
            }
            
            Section(header: Label("Duration", systemImage: "timer")) {
                if duration > 0 {
                    HStack(){
                        Spacer()
                        Text("\(Int(duration)) minutes")
                            .font(.callout.italic())
                    }
                }
                Slider(value: self.$duration, in: 0 ... 59, step: 1)
            }
            .onChange(of: self.duration) { duration in
                guard duration >= 1 else {
                    item.duration = nil
                    return
                }
                
                item.duration = Int(duration) * 60
            }
            
            let header = HStack(){
                Label("\(hasCaution ? "" : "Include ")Cautionary Information", systemImage: "nosign")
                Spacer()
                Toggle(isOn: $hasCaution) {
                    Text("Cautionary information")
                }
                .labelsHidden()
            }
            
            if hasCaution {
                Section(header: header) {
                    TextEditor(text: makeBinding(item, \.caution))
                }
            } else {
                Section(){
                    header
                }
            }
        }
    }
    
    func onDone() {
        data.items = data.items.filter() { $0.uuid != item.uuid } + [item]
        print("wrote back item! \(String(describing: item.title)) - \(String(describing: item.itemNo))")
        presentationMode.wrappedValue.dismiss()
    }
    
    var contentView: some View {
        let setter = { (newValue: String, keyPath: WritableKeyPath<ExperienceData.Item, String?>) in
            //var element = item
            item[keyPath: keyPath] = newValue
            //items = items.filter({ $0.uuid != element.uuid }) + [element]
        }
        
        let makeBinding = { (item: ExperienceData.Item, keyPath: WritableKeyPath<ExperienceData.Item, String?>) -> Binding<String> in
            return Binding<String>(){
                return item[keyPath: keyPath] ?? .empty
            } set: { newValue in
                print("Setting value: \(newValue)")
                setter(newValue, keyPath)
            }
        }
        
        let onSelected = createImageCb() { url in
            setter(url.absoluteString, \ExperienceData.Item.imageName)
        }
        
        return Form {
            
            if !item.experienceItemType.isNumbered {
                Section(){
                    HStack(){
                        Spacer()
                        ImageView(urlString: item.imageName, isCircular: false, onSelected: onSelected) { (image, imgName, error) in
                            
                        } content: {
                            Color.clear
                        }
                        .frame(width: screenWidth / 5, height: screenWidth / 5)
                        .padding()
                        Spacer()
                    }
                }
            }
            
            Section(header: Text("Title")) {
                TextField("Title", text: makeBinding(item, \.title))
            }
            
            Section(header: Text("Description")) {
                TextEditor(text: self.$itemDescription)//makeBinding(item, \.subtitle))
            }
            
            if item.experienceItemType == .mealPrepStep {
                mealPrepStepSections
            }
            
            Section(header: Text("Price (£)")) {
                TextField("£.££", text: $priceField)
                    .keyboardType(.decimalPad)
            }
            
            let isAvaliable = Binding<Bool>(){
                return item.quantityAvailable != nil
            } set: { newValue in
                item.quantityAvailable = newValue ? 1 : nil
            }
            
            HStack(){
                Label("Availability", systemImage: "nosign")
                Spacer()
                Toggle(isOn: isAvaliable) {
                    Text("Cautionary information")
                }
                .labelsHidden()
            }
            
            
            Section(header: Text("Grouping Tags (Optional)")) {
                TextField("Primary", text: makeBinding(item, \.itemGrouping))
                TextField("Secondary", text: makeBinding(item, \.itemSubgrouping))
            }
            
            Section(){
                HStack(alignment: .center){
                    Spacer()
                    Button(action: onDone) {
                        Label("Done", systemImage: "arrow.right")
                    }
                    .font(.headline)
                    Spacer()
                }
            }
            
            Section(footer: Spacer().padding(.bottom, 100)){
                HStack(alignment: .center){
                    Spacer()
                    if #available(iOS 15.0, *) {
                        removeButton
                    } else {
                        removeButtonLegacy
                    }
                    Spacer()
                }
                
            }
            
        }
        .toolbar() {
            ToolbarItem(placement: .navigationBarTrailing){
                Button(action: onDone) {
                    Text("Done")
                }
            }
        }
        .onChange(of: itemDescription) { desc in
            self.item.subtitle = desc
        }
        .onAppear() {
            
            self.spicyRating = Double(item.spicy?.numericValue ?? 0)
            
            if let durationSecs = item.duration, durationSecs >= 60 {
                self.duration = Double(durationSecs) / 60.0
            }
            
            if let txt = item.caution?.trimmingCharacters(in: .whitespacesAndNewlines) {
                self.hasCaution = !txt.isEmpty
            }
            
            guard item.experienceItemType.isNumbered, item.itemNo == nil else { return }
            
            item.itemNo = index
        }
        .id(item.id)
    }
}

    
//struct ExperienceDataItemView_Previews: PreviewProvider {
//    static var previews: some View {
//        ExperienceDataItemView(item: siseMealboxDemo.items[0], index: 0, items: .constant([]))
//            .environmentObject(AppCoordinator())
//    }
//}

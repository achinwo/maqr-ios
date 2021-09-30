//
//  Restuarant.swift
//  Joli
//
//  Created by Anthony Chinwo on 04/07/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore
import Promises

protocol Priceable {
    var defaultPrice: Decimal? { get }
}

protocol RestaurantItem {
    var title: String { get }
    var price: String { get}
    var priceWhole: Int { get }
    var priceFraction: String? { get }
}

struct MealNutrition: Codable {
    var title: String
    var quantity: Int
}

struct RestaurantMeal: Codable, Priceable, RestaurantItem, Identifiable {
    let defaultPrice: Decimal?
    let nutrition: [MealNutrition]
    let title: String
    let subtitle: String?
    
    var price: String
    var priceWhole: Int
    var priceFraction: String?
    
    var dietary: String?
    
    var isVegetarian: Bool {
        dietary == "v"
    }
    
    var isGluttenFree: Bool {
        dietary == "g"
    }
    
    var id: String {
        return title
    }
}

struct RestaurantDrink: Codable, Priceable, RestaurantItem, Identifiable {
    
    enum Category: String, Codable, CaseIterable {
        case wine
        case beer
        case cocktails
        case nonAlcoholic = "non-alcoholic"
    }
    
    let title: String
    
    var defaultPrice: Decimal? {
        return pricePerBottle ?? pricePer90z ?? pricePer60z
    }
    
    var pricePer60z: Decimal?
    var pricePer90z: Decimal?
    var pricePerBottle: Decimal?
    
    var category: Category? = nil
    
    var price: String
    var priceWhole: Int
    var priceFraction: String?
    
    var id: String {
        return title
    }
}

struct RestaurantItemGroup<Item: RestaurantItem & Identifiable>: Identifiable {
    let title: String
    let subtitle: String?
    let items: [Item]
    let imageUrl: URL?
    
    var id: String
}

struct RestaurantHappyhour<P: Priceable & Codable>: Codable, Priceable {
    
    var caption: String? = nil
    
    let priceable: P
    let price: Decimal
    
    var defaultPrice: Decimal? {
        return price
    }
    
    init(_ priceable: P, newPrice: Decimal, caption: String? = nil){
        self.priceable = priceable
        self.price = newPrice
        self.caption = caption
    }
    
}

struct JoeysData: Codable {
    
    struct SectinData<Itm: RestaurantItem & Codable>: Codable {
        let title: String
        let subtitle: String?
        var items: [Itm]
        var imageUrl: URL?
    }
    
    var food: [String: SectinData<RestaurantMeal>]
    
    var wines: [String: SectinData<RestaurantDrink>]
    var beers: [String: SectinData<RestaurantDrink>]
    var cocktails: [String: SectinData<RestaurantDrink>]
    var nonAlcoholics: [String: SectinData<RestaurantDrink>]
    
    var happyHour: [String: SectinData<RestaurantDrink>]
    
    public static func load(from bundle: Bundle? = nil) throws -> Self? {
        //https://storage.googleapis.com/joli-app-bucket/images/joey_sherway_data.json
        
        let decoder = Musicroom.jsonDecoder()
        let bundle = bundle ?? Bundle.main
        
        guard let filePath = bundle.path(forResource: "joey_sherway_data", ofType: "json") else {
            print("Unable to load file!")
            return nil
        }
        
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let obj: Self = try decoder.decode(Self.self, from: data)
        
        return obj
    }
}

struct RestaurantMenu {
    var foods: [RestaurantItemGroup<RestaurantMeal>] = []
    var drinks: [RestaurantItemGroup<RestaurantDrink>] = []
    
    var happyhourFoods: [RestaurantHappyhour<RestaurantMeal>] = []
    var happyhourDrinks: [RestaurantHappyhour<RestaurantDrink>] = []
    
    static func getDefaultMenu() -> RestaurantMenu? {
        
        guard let data = try? JoeysData.load() else { return nil }
        
        var allFoods: [RestaurantMeal] = []
        var foods: [RestaurantItemGroup<RestaurantMeal>] = []
        
        let sortIds: [String] = [
            "sandwichesBurgers",
            "smallsSharing",
            "sushi",
            "salads",
            "mains",
            "steakhouse",
            "sweets",
        ]
        
        let sortedFood = data.food.sorted(){ (item1, item2) in
            guard let idx1 = sortIds.firstIndex(of: item1.key), let idx2 = sortIds.firstIndex(of: item2.key) else {
                return item1.key > item2.key
            }
            
            return idx1 < idx2
        }
        
        for (groupId, section) in sortedFood {
            let group = RestaurantItemGroup(title: section.title, subtitle: section.subtitle, items: section.items, imageUrl: section.imageUrl, id: groupId)
            foods.append(group)
            allFoods.append(contentsOf: section.items)
        }
        
        var allDrinks: [RestaurantDrink] = []
        var drinks: [RestaurantItemGroup<RestaurantDrink>] = []
        
        for (cat, dictionary) in [(RestaurantDrink.Category.wine, data.wines), (RestaurantDrink.Category.cocktails, data.cocktails),
                           (RestaurantDrink.Category.beer, data.beers), (RestaurantDrink.Category.nonAlcoholic,data.nonAlcoholics)] {
            for (groupId, drinkSec) in dictionary {
                
                
                let newDrinks = drinkSec.items.map() { itm in
                    return RestaurantDrink(title: itm.title,
                                            pricePer60z: nil,
                                            pricePer90z: nil,
                                            pricePerBottle: Decimal(itm.priceWhole),
                                            category: cat,
                                            price: itm.price, priceWhole: itm.priceWhole,
                                            priceFraction: itm.priceFraction)
                    
                }
                
                let group = RestaurantItemGroup(title: drinkSec.title, subtitle: drinkSec.subtitle, items: newDrinks, imageUrl: drinkSec.imageUrl, id: groupId)
                drinks.append(group)
                allDrinks.append(contentsOf: newDrinks)
            }
        }
        
        var happyhourFoods: [RestaurantHappyhour<RestaurantMeal>] = []
        var happyhourDrinks: [RestaurantHappyhour<RestaurantDrink>] = []
        
        if let hhDrinks = data.happyHour["drinks"] {
            
            for itm in hhDrinks.items {
                
                guard let drink = allDrinks.first(where: { $0.title == itm.title }) else { continue }
                
                let hr = RestaurantHappyhour(drink, newPrice: Decimal(itm.priceWhole), caption: hhDrinks.subtitle)
                
                happyhourDrinks.append(hr)
            }
        }
        
        if let hhDrinks = data.happyHour["food"] {
            
            for itm in hhDrinks.items {
                
                guard let drink = allFoods.first(where: { $0.title == itm.title }) else { continue }
                
                let hr = RestaurantHappyhour(drink, newPrice: Decimal(itm.priceWhole), caption: hhDrinks.subtitle)
                
                happyhourFoods.append(hr)
            }
        }
//
//        if let hhDrinks = data.happyHour["food"] {
//            let group = RestaurantItemGroup(title: hhDrinks.title, subtitle: hhDrinks.subtitle, items: hhDrinks.items, imageUrl: hhDrinks.imageUrl, id: "happyhour-drinks")
//            happyhourDrinks.append(group)
//        }
        
        let m = RestaurantMenu(foods: foods, drinks: drinks, happyhourFoods: happyhourFoods, happyhourDrinks: happyhourDrinks)
        return m
    }
}

import Foundation
import Promises



public struct JoliApi {
    public var text = "Hello, World!"
    
    public init(){
            
    }
    
    public static func doTest(completionHandler: (() -> Void)?) -> Void {
        //let urlSession = URLSession(configuration: .default)
        //let url = URL(string: "http://localhost:8080/api/db/musicrooms")!
        //debugPrint("names: \(Musicroom(name: "test").propertyValues())")
        
        Musicroom.findById(id: 1, on: .global(qos: .background))
        .then() { (res) -> Promise<[Track]> in
            var r = res!
            debugPrint(r)
            r.name = "Davido Party"
            
            debugPrint("response: \(String(describing: r.$createdAt)) - \(String(describing: r.createdAt))")
            return r.fetchTracks()
                
        }
        .then(){ res in
            print("Result: \(res)")
        }
        .always() {
            completionHandler?()
        }.catch() { error in
            print("error: \(error)")
        }
        
    }
}


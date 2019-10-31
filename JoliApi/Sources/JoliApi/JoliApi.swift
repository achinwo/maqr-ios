import Foundation
import Promises



struct WebSocketMessage: Encodable {
    let topic: String
    let body = ["subject": "PLAYER_STATE_NOW_PLAYING"]
}

extension WebSocketMessage {
    
    func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try! encoder.encode(self)
        
        return  String(data: jsonData, encoding: .utf8)!
    }
    
}

class WebSocketTest: NSObject {
    
    typealias MessageCallback = (Result<URLSessionWebSocketTask.Message, Error>) -> Void
    
    var session: URLSession!
    var task: URLSessionWebSocketTask!
    var onMessage: MessageCallback?
    var connected = false

    init(url: URL, onMessage: MessageCallback? = nil) {
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue.main)
        self.task = self.session.webSocketTask(with: url)
        self.onMessage = onMessage
    }

    public func send(topic: String, payload: Encodable? = nil, completionHandler: ((Error?) -> Void)?){
        let msg = WebSocketMessage(topic: topic)
        
        let message = URLSessionWebSocketTask.Message.string(msg.jsonString())
        self.task.send(message) { error in
            completionHandler?(error)
        }
    }
    
    public func receive(){
        self.task.receive() { result in
            //print("[result] \(result)")
            
            defer {
                self.onMessage?(result)
            }
            
            guard self.connected else {
                print("[receive] aborting...")
                return
            }
            
            print("[receive] scheduling next receive cycle...")
            OperationQueue.main.addOperation(self.receive)
        }
    }
    
    public func connect() {
        self.task.resume()
    }

    public func disconnect() {
        self.task.cancel(with: .goingAway, reason: "I cancelled".data(using: .utf8))
    }
}

extension WebSocketTest: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("Connected!")
        self.connected = true
        OperationQueue.main.addOperation(self.receive)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Disconnected! \(String(data: reason!, encoding: .utf8)!)")
        self.connected = false
    }
    
}

public enum SpotifyDeviceType: String, Codable {
    /// https://developer.spotify.com/documentation/web-api/reference/player/get-a-users-available-devices/#device-types
    
    case computer = "Computer"
    case tablet = "Tablet"
    case smartphone = "Smartphone"
    case speaker = "Speaker"
    case tv = "TV"
    case avr = "AVR"
    case stb = "STB"
    case audioDongle = "AudioDongle"
    case gameConsole = "GameConsole"
    case castVideo = "CastVideo"
    case castAudio = "CastAudio"
    case automobile = "Automobile"
    case unknown = "Unknown"
}

extension Result {
    var success: Success? {
        switch self {
        case .success(let success):
            return success
        default:
            return nil
        }
    }
    
    var error: Failure? {
        switch self {
        case .failure(let error):
            return error
        default:
            return nil
        }
    }
}

extension Result where Success == URLSessionWebSocketTask.Message {
    
    var successTuple: (string: String?, data: Data?) {
        switch self {
        case .success(let success):
            switch success {
            case .string(let val):
                return (string: val, data: nil)
            case .data(let data):
                return (string: nil, data: data)
            @unknown default:
                fatalError()
            }
        default:
            return (string: nil, data: nil)
        }
    }
    
    var successString: String? {
        return successTuple.string
    }
    
    var successData: Data? {
        return successTuple.data
    }
    
}

public struct JoliApi {
    public var text = "Hello, World!"
    public var user: User?
    
    public struct SpotifyDevice: Codable, Identifiable, Hashable {
        public let id: String
        public let isActive: Bool
        public let isPrivateSession: Bool
        public let isRestricted: Bool
        public let name: String
        public let type: SpotifyDeviceType
        public let volumePercent: Int
    }
    
    public init(){
        
    }
    
    public func fetchSpotifyDevices(on: DispatchQueue? = nil) -> Promise<[SpotifyDevice]> {
        let on = on ?? DispatchQueue.main
        return Musicroom.fetch(urlPath: "/api/spotify/devices", dataType: [String: [SpotifyDevice]].self, on: on)
            .then(on: on) { (dict) -> [SpotifyDevice] in
                guard let devices = dict["devices"] else {
                    throw NetworkError.badResponse("expected key \"devices\" in response: \(dict)")
                }
                return devices
        }
    }
    
    public static func doTest(completionHandler: (() -> Void)?) -> Void {
        //let urlSession = URLSession(configuration: .default)
        //let url = URL(string: "http://localhost:8080/api/db/musicrooms")!
        //debugPrint("names: \(Musicroom(name: "test").propertyValues())")
        let url = URL(string: "ws://localhost:8080/ws")!
//        let task = URLSession.shared.webSocketTask(with: )
//        task.resume()
//
//        task.send(.string("{\"topic\":  \"Hello world\"}")) { (error) in
//            print("Websocket: \(error)")
//        }
        
        let webSocketTest = WebSocketTest(url: url) { result in
            guard let resp = result.successString else {
                print("[onmessage] error: \(result.error!)")
                return
            }
            
            print("response: \(resp)")
        }
        
        webSocketTest.connect()
        webSocketTest.send(topic: "/subscribe") { error in
            guard let error = error else {
                return
            }
            print("error sending message!")
        }
//
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            webSocketTest.disconnect()
            completionHandler?()
        }
        
//        let json = """
//{"data":{"devices":[{"id":"27e695c3138d67b3f21ed35119d93dbd1351d1e9","is_active":false,"is_private_session":false,"is_restricted":false,"name":"Influence The Music","type":"Computer","volume_percent":100},{"id":"37c249a0aaf5473db8292b2f30ef1e83f4b08cc1","is_active":false,"is_private_session":false,"is_restricted":false,"name":"Devialet Phantom","type":"Speaker","volume_percent":34},{"id":"764cec96ce3d400916aac96e10ece041079ab1f5","is_active":false,"is_private_session":false,"is_restricted":false,"name":"Anthony’s MacBook Pro","type":"Computer","volume_percent":100}]},"headers":{},"status":200}
//"""
//
        //let decoder = Musicroom.jsonDecoder()
        //decoder.keyDecodingStrategy = .convertFromSnakeCase
        //let x = try! decoder.decode(Response<[String: [SpotifyDevice]]>.self, from: json.data(using: .utf8)!)
        
        
//        Self().fetchSpotifyDevices(on: .global(qos: .background))
//            .then() { devices in
//                print("Devices: \(devices)")
//        }
//        .catch { (err) in
//            debugPrint("error: \(err)")
//        }
//        .always {
//            //completionHandler?()
//        }
        
//        Musicroom.findById(id: 1, on: .global(qos: .background))
//        .then() { (res) -> Promise<[Track]> in
//            var r = res!
//            //debugPrint(r)
//            r.name = "Davido Party"
//
//            //debugPrint("response: \(String(describing: r.$createdAt)) - \(String(describing: r.createdAt))")
//            return r.fetchTracks()
//
//        }
//        .then(){ res in
//            //print("Result: \(res)")
//        }
//        .always() {
//            //completionHandler?()
//        }.catch() { error in
//            print("error: \(error)")
//        }
        
    }
}

//class Abc: SPTConfiguration{

//}
//class  Sp:  SPT

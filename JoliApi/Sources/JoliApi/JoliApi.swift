import Foundation
import Promises
import Combine

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

public struct TrackInfo {
    public var track: Track?
    public var info: Json?
}

public class JoliApi: ObservableObject {
    
    @Published var currentPlaying: TrackInfo?
    @Published var currentPlayingTrack: Track?
    
    public func playTrack(_ track: Track, deviceId: String?) -> Promise<Result<TrackInfo, Error>>{
        return track.play(deviceId: deviceId)
            .then() { track -> Result<TrackInfo, Error> in
                return Result<TrackInfo, Error>.success(TrackInfo(track: track, info: [:]))
        }
    }
    
//    public func setVolume(_ volume: Int, deviceId: String, on: DispatchQueue? = nil) -> Promise<Json>{
//        let payload: Json = ["deviceId": deviceId,
//                             "volume": volume]
//
////        return HttpMethod.post.fetch(urlPath: urlPath,
////                                     dataType: Self.self,
////                                     payload: self,
////                                     baseUrl: baseUrl,
////                                     on: on)
//        let dataType = Json.self
//        let urlPath = "/api/spotify/volume"
//
//        return HttpMethod.post.fetch(urlPath: urlPath,
//                                     dataType: dataType,
//                                     payload: payload,
//                                     baseUrl: self.baseUrl.http,
//                                     on: on)
//    }

    public var user: User?
    public var wsClient: WebSocketClient

    public var subjects: Set<String> = []
    public var baseUrl: (ws: URL, http: URL)
    
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
        self.baseUrl = Musicroom.baseUrl
        let url = baseUrl.ws.appendingPathComponent("/ws")
        self.wsClient = WebSocketClient(url: url)
        
        //self.wsClient.connect()
        self.wsClient.connectionHandler = { connected in
            print("JoliApi: connected=\(connected)")
            guard connected, let onMessage = self.wsClient.onMessage else {
                return
            }
            
            for subject in self.subjects  {
                self.subscribe(subject: subject, onMessage: onMessage)
            }
        }
    }
    
    public func subscribe(subject: String, onMessage: @escaping WebSocketClient.MessageCallback){
        self.wsClient.onMessage = onMessage
        let topic = "/subscribe?subject=\(subject)"
        self.wsClient.send(topic: topic) { error in
            if let error = error {
                print("[wsSubscribe] error: \(error)")
                return
            }
            
            print("[JoliApi#subscribe] subject=\(subject)")
            self.subjects.insert(subject)
        }
    }
    
    public func unsubscribe(subject: String){
        let topic = "/unsubscribe?subject=\(subject)"
        self.wsClient.send(topic: topic) { error in
            if let error = error {
                print("[wsUnsubscribe] error: \(error)")
                return
            }
            
            print("[JoliApi#unsubscribe] subject=\(subject)")
            self.subjects.remove(subject)
        }
    }
    
    public func fetchSpotifyDevices(baseUrl optBaseUrl: URL? = nil, on: DispatchQueue? = nil) -> Promise<[SpotifyDevice]> {
        let on = on ?? DispatchQueue.main
        let baseUrl = optBaseUrl ?? self.baseUrl.http
        return HttpMethod.get.fetch(urlString: "/api/spotify/devices", dataType: [String: [SpotifyDevice]].self, baseUrl: baseUrl, on: on)
            .then(on: on) { (dict) -> [SpotifyDevice] in
                guard let devices = dict["devices"] else {
                    throw NetworkError.badResponse("expected key \"devices\" in response: \(dict)")
                }
                return devices
        }
    }
    
    @discardableResult
    public static func doTest() -> some Promise<Any?> {
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
        
//        let webSocketTest = WebSocketClient(url: url) { result in
//            guard let resp = result.successString else {
//                print("[onmessage] error: \(result.error!)")
//                return
//            }
//
//            print("response: \(resp)")
//        }
        
//        webSocketTest.connect()
//        webSocketTest.send(topic: "/subscribe") { error in
//            guard let error = error else {
//                return
//            }
//            print("error sending message! \(error)")
//        }
////
//        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
//            webSocketTest.disconnect()
//            completionHandler?()
//        }
        
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
        
        return Musicroom.findById(id: 1, on: .global(qos: .background))
        .then() { (res) -> Promise<[Track]> in
            var r = res!
            debugPrint(r)
            //r.name = "Davido Party"

            debugPrint("response: \(String(describing: r.$createdAt)) - \(String(describing: r.createdAt))")
            return r.fetchTracks()
        }
//        .then(){ res in
//            //print("Result: \(res)")
//        }
//        .always() {
//            completionHandler?()
//        }.catch() { error in
//            print("error: \(error)")
//        }
        
    }
}

//class Abc: SPTConfiguration{

//}
//class  Sp:  SPT


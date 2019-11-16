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

public typealias Json2 = [String: AnyObject]
//get { (http:BASE_URL ?? URL(string: "http://192.168.1.173:8080")!,
//               ws:URL(string: "ws://192.168.1.173:8080")!)}
public enum BaseUrl: RawRepresentable {
    
    case home
    case mobileHotspot
    case host(String)
    case custom((http: URL, ws: URL))
    
    public var rawValue: (http: URL, ws: URL) {
        switch self {
        case .home:
            return (http: URL(string: "https://192.168.1.173:8080")!, ws: URL(string: "wss://192.168.1.173:8080")!)
        case .mobileHotspot:
            return (http: URL(string: "https://172.20.10.2:8080")!, ws: URL(string: "wss://172.20.10.2:8080")!)
        case .host(let urlString):
            return (http: URL(string: "https://\(urlString)")!, ws: URL(string: "wss://\(urlString)")!)
        case .custom(let urls):
            return urls
        }
    }
    
    public init?(rawValue: String) {
        self = .host(rawValue)
    }
    
    public init?(rawValue: (http: URL, ws: URL)) {
        self = .custom(rawValue)
    }
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
    
    public func searchTracks(q: String, limit: Int = 10) -> Promise<[Track]> {
        var pathComp = URLComponents(string: "/api/spotify/search")!
        pathComp.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "limit", value: limit.description)
        ]
        
        return HttpMethod.get.fetch(urlPath: pathComp, dataType: [Track].self, payload: nil)
    }
    
    public class func post(urlPath: URLComponents, payload: Json2, baseUrl: URL? = nil, on: DispatchQueue? = nil) ->  Promise<Json2> {
        
        let queue = on ?? DispatchQueue.global(qos: .default)
        let baseUrl = baseUrl ?? Track.baseUrl.http
        
        guard let url = urlPath.url(relativeTo: baseUrl) else {
            return Promise(NetworkError.invalidUrl(urlPath, baseUrl))
        }
        
        return Promise<Json2>(on: queue) { (resolve, reject) in
            
            let callback = { (data: Data?, resp: URLResponse?, error: Error?) -> Void in
                
                guard let data = data else {
                    return reject(error!)
                }
                
                do {

                    let respObj = try JSONSerialization.jsonObject(with: data, options: [])
                    
                    resolve(respObj as! Json2)
                } catch {
                    reject(error)
                }
            }
            
            guard let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
                return reject(NetworkError.badRequest("bad paylod for post request: \(String(describing: payload))"))
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
            
            
            
            let task: URLSessionTask = JoliApi.sharedUrlSession.uploadTask(with: request, from: payloadData, completionHandler: callback)
            task.resume()
        }
    }
    
    @discardableResult
    public func setVolume(_ volume: Int, deviceId: String, on: DispatchQueue? = nil) -> Promise<Json2>{
        let payload: Json2 = ["deviceId": deviceId as AnyObject,
                             "volume": volume as AnyObject]

//        return HttpMethod.post.fetch(urlPath: urlPath,
//                                     dataType: Self.self,
//                                     payload: self,
//                                     baseUrl: baseUrl,
//                                     on: on)
        let urlPath = URLComponents(string: "/api/spotify/volume")!

        return Self.post(urlPath: urlPath, payload: payload, on: on)
    }

    public var user: User?
    public var wsClient: WebSocketClient

    public var subjects: Set<String> = []
    public var baseUrl: BaseUrl
    
    public struct SpotifyDevice: Codable, Identifiable, Hashable {
        public let id: String
        public let isActive: Bool
        public let isPrivateSession: Bool
        public let isRestricted: Bool
        public let name: String
        public let type: SpotifyDeviceType
        public let volumePercent: Int
    }
    
    public init(baseUrl: BaseUrl = .home){
        self.baseUrl = baseUrl
        let url = baseUrl.rawValue.ws.appendingPathComponent("/ws")
        self.wsClient = WebSocketClient(url: url)
        
        //(ws: URL, http: URL)
        BASE_URL = baseUrl.rawValue
        
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
        let baseUrl = optBaseUrl ?? self.baseUrl.rawValue.http
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
        BASE_URL = BaseUrl.home.rawValue
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
        let api = JoliApi()
//        api.fetchSpotifyDevices().then { print($0) }
//        return api.searchTracks(q: "killin")
//            .then() { print($0) }
//            .catch() { error in print(error) }
        
        let m = Mirror(reflecting: Musicroom.self)
        
        for c in m.children {
            print("child: \(c)")
        }
        
        return Musicroom.findById(id: 1, on: .global(qos: .background))
        .then() { (res) -> Promise<[Track]> in
            var r = res!
            //debugPrint(r)
            
            let m = Mirror(reflecting: r)
            
            for c in m.children {
                print("child: \(c)")
            }
            
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
    
    static let sharedUrlSessionDelegate = HttpsHook()
    
    static let sharedUrlSession = URLSession.init(configuration: URLSessionConfiguration.default,
                                                  delegate: JoliApi.sharedUrlSessionDelegate, delegateQueue: .main)
    
}

public class HttpsHook: NSObject, URLSessionDelegate {
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        let trustedHostArray = [
            BaseUrl.home.rawValue.http.host!,
            BaseUrl.mobileHotspot.rawValue.http.host!,
        ]

        print("[HttpsHook] trusted: \(trustedHostArray) - \(challenge.protectionSpace.authenticationMethod)")
//        if Utils.getEnviroment() == Constants.Environment.Production.rawValue {
//            trustedHostArray = Constants.TRUSTED_HOSTS.Production
//        } else {
//            trustedHostArray = Constants.TRUSTED_HOSTS.Develop
//        }
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              trustedHostArray.contains(challenge.protectionSpace.host) else {
            return
        }

        print("[HttpsHook] protectionSpace: \(challenge.protectionSpace) - \(challenge.protectionSpace.host)")
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        //print("[HttpsHook] replacing: \(credential)")

        challenge.sender?.use(credential, for: challenge)
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, credential)
    }
    
}

//class Abc: SPTConfiguration{

//}
//class  Sp:  SPT


import Foundation
import Promises
import Combine
import SwiftyBeaver


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

internal let logger = SwiftyBeaver.self

public struct Auth: Codable {
    public var session: Session
    public var user: User
}

// MARK: - JoliApi
public class JoliApi: ObservableObject {
    
    @Published public var currentPlaying: TrackInfo?
    @Published public var currentPlayingTrack: Track?
    
    @Published public var auth: Auth?
    
    private static var loggerInitialized = false

    public static func initLogger() {
        guard !JoliApi.loggerInitialized else { return }
        
        let console = ConsoleDestination()  // log to Xcode Console
        let file = FileDestination()  // log to default swiftybeaver.log file
        //let cloud = SBPlatformDestination(appID: "foo", appSecret: "bar", encryptionKey: "123") // to cloud
        
        // use custom format and set console output to short time, log level & message
        //console.format = "$DHH:mm:ss$d $T $N:$l $L: $M"
        // or use this for JSON output: console.format = "$J"

        // add the destinations to SwiftyBeaver
        logger.addDestination(console)
        logger.addDestination(file)
        
        logger.debug("[JoliApi] initialized logger")
        JoliApi.loggerInitialized = true
    }
    
    public static func getLogger() -> SwiftyBeaver.Type {
        JoliApi.initLogger()
        return logger.self
    }

    // MARK: - Environment
    public enum Environment: String {
        
        public static var CACHED_ENV_CONFIG: [String: AnyObject] = [:]
        
        case local
        case development
        case production
        
        public var baseUrl: BaseUrl {
            switch self {
            case .local:
                guard let host: String = (Environment.CACHED_ENV_CONFIG["host"] as? [String: AnyObject])?["local"] as? String else {
                    let defaultLocalUrl: BaseUrl = .host("localhost")
                    logger.debug("[Environment] using default: \(defaultLocalUrl)")
                    return defaultLocalUrl
                }
                return .host(host)
            case .development:
                return .dev
            case .production:
                return .prod
            }
        }
    }
    
    public enum BaseUrl: RawRepresentable {
        
        case dev
        case prod
        
        case localhost
        case homeLaptop
        case homeDesktop
        case mobileHotspot
        
        case host(String)
        case custom((http: URL, ws: URL))
        
        public var rawValue: (http: URL, ws: URL) {
            switch self {
            case .dev:
                return (http: URL(string: "https://dev.jolimc.com")!, ws: URL(string: "wss://dev.jolimc.com")!)
            case .prod:
                return (http: URL(string: "https://jolimc.com")!, ws: URL(string: "wss://jolimc.com")!)
            case .localhost:
                return (http: URL(string: "https://localhost:8080")!, ws: URL(string: "wss://localhost:8080")!)
            case .homeLaptop:
                return (http: URL(string: "https://192.168.1.173:8080")!, ws: URL(string: "wss://192.168.1.173:8080")!)
            case .homeDesktop:
                return (http: URL(string: "https://192.168.1.188:8080")!, ws: URL(string: "wss://192.168.1.188:8080")!)
            case .mobileHotspot:
                return (http: URL(string: "https://172.20.10.7:8080")!, ws: URL(string: "wss://172.20.10.7:8080")!)
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
    
    public func playTrack(_ track: Track, deviceId: String?) -> Promise<Result<TrackInfo, Error>>{
        return track.play(deviceId: deviceId)
            .then() { track -> Result<TrackInfo, Error> in
                return Result<TrackInfo, Error>.success(TrackInfo(track: track, info: [:]))
        }
    }

    public func authenticate(email: String, password: String, on: DispatchQueue? = nil) -> Promise<Auth?> {
        return Session.fromCredentials(email: email, password: password, baseUrl: self.baseUrl.rawValue.http, on: on)
            .then() { auth -> Auth? in
                self.auth = auth
                return auth
            }
    }
    
    public func authenticate(token: String, on: DispatchQueue? = nil) -> Promise<Auth?> {
        return Session.fromCredentials(token: token, baseUrl: self.baseUrl.rawValue.http, on: on)
            .then() { auth -> Auth? in
                self.auth = auth
                return auth
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
    
    public class func post(urlPath: URLComponents, payload: Json, baseUrl: URL? = nil, on: DispatchQueue? = nil) ->  Promise<Json> {
        
        let queue = on ?? DispatchQueue.global(qos: .default)
        let baseUrl = baseUrl ?? Track.baseUrl.http
        
        guard let url = urlPath.url(relativeTo: baseUrl) else {
            return Promise(NetworkError.invalidUrl(urlPath, baseUrl))
        }
        
        return Promise<Json>(on: queue) { (resolve, reject) in
            
            let callback = { (data: Data?, resp: URLResponse?, error: Error?) -> Void in
                
                guard let data = data else {
                    return reject(error!)
                }
                
                do {

                    let respObj = try JSONSerialization.jsonObject(with: data, options: [])
                    
                    resolve(respObj as! Json)
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
    public func setVolume(_ volume: Int, deviceId: String, on: DispatchQueue? = nil) -> Promise<Json>{
        let payload: Json = ["deviceId": deviceId as AnyObject,
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
    
    // MARK: - init
    public init(baseUrl: BaseUrl = .homeLaptop){
        JoliApi.initLogger()
        
        self.baseUrl = baseUrl
        let url = baseUrl.rawValue.ws.appendingPathComponent("/ws")
        self.wsClient = WebSocketClient(url: url)
        
        //(ws: URL, http: URL)
        BASE_URL = baseUrl.rawValue
        
        //self.wsClient.connect()
        self.wsClient.connectionHandler = { connected in
            logger.debug("JoliApi: connected=\(connected)")
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
                logger.debug("[wsSubscribe] error: \(error)")
                return
            }
            
            logger.debug("[JoliApi#subscribe] subject=\(subject)")
            self.subjects.insert(subject)
        }
    }
    
    public func unsubscribe(subject: String){
        let topic = "/unsubscribe?subject=\(subject)"
        self.wsClient.send(topic: topic) { error in
            if let error = error {
                logger.debug("[wsUnsubscribe] error: \(error)")
                return
            }
            
            logger.debug("[JoliApi#unsubscribe] subject=\(subject)")
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
    
    // MARK: - Test
    @discardableResult
    public static func doTest() -> some Promise<Any?> {
        JoliApi.initLogger()
        
        //let urlSession = URLSession(configuration: .default)
        //let url = URL(string: "http://localhost:8080/api/db/musicrooms")!
        //debugPrint("names: \(Musicroom(name: "test").propertyValues())")
        BASE_URL = BaseUrl.homeDesktop.rawValue
        let url: BaseUrl = .host("localhost:8080")

        let api = JoliApi(baseUrl: .mobileHotspot)
        
        let token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6Imhhd2FAZ21haWwubmV0IiwiY3JlYXRlZEF0IjoiMjAxOS0xMi0wMVQwMDowOToyNy4yOTVaIiwiZXhwaXJlc0luIjoiaGF3YUBnbWFpbC5uZXQifQ.yqjreKSyzkG3VrVV9_7cAtOfBe6c50iGUOyieTBZN7g"
        return api.authenticate(token: token)
            .then(){ res in
                logger.debug("[AUTH] \(res)")
            }
//        api.fetchSpotifyDevices().then { print($0) }
//        return api.searchTracks(q: "killin")
//            .then() { print($0) }
//            .catch() { error in print(error) }
//        return Session.fromCredentials(email: "hawa@gmail.net", password: "Password@", baseUrl: url.rawValue.http)
//            .then() { res in
//                logger.debug("[RESP] \(res)")
//        }.catch() { error in
//            logger.debug("[ERROR] \(error)")
//        }
        
        return Musicroom.all(baseUrl: url.rawValue.http, on: .global(qos: .background))
            .then() { rooms in
                logger.debug("[rooms] \(rooms)")
        }.catch() { err in
            logger.error("[Musicroom] \(err)")
        }
        
        return Musicroom.findById(id: 1, baseUrl: url.rawValue.http, on: .global(qos: .background))
        .then() { (res) -> Promise<[Track]> in
            var r = res!
            debugPrint(r)
            
//            let m = Mirror(reflecting: r)
//
//            for c in m.children {
//                logger.debug("child: \(c)")
//            }
            
            //r.name = "Davido Party"

            debugPrint("response: \(String(describing: r.$createdAt)) - \(String(describing: r.createdAt))")
            return Promise([])//r.fetchTracks()
        }
        .catch() { error in
            logger.debug("error: \(error)")
        }
        
    }
    
    static let sharedUrlSessionDelegate = HttpsHook()
    
    static let sharedUrlSession = URLSession.init(configuration: URLSessionConfiguration.default,
                                                  delegate: JoliApi.sharedUrlSessionDelegate, delegateQueue: .main)
    
}

public class HttpsHook: NSObject, URLSessionDelegate {
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        let trustedHostArray: [String] = [
            JoliApi.BaseUrl.homeLaptop.rawValue.http.host!,
            JoliApi.BaseUrl.homeDesktop.rawValue.http.host!,
            JoliApi.BaseUrl.mobileHotspot.rawValue.http.host!,
            JoliApi.BaseUrl.localhost.rawValue.http.host!,
        ]

        logger.debug("[HttpsHook] trusted: \(trustedHostArray) - \(challenge.protectionSpace.authenticationMethod)")
//        if Utils.getEnviroment() == Constants.Environment.Production.rawValue {
//            trustedHostArray = Constants.TRUSTED_HOSTS.Production
//        } else {
//            trustedHostArray = Constants.TRUSTED_HOSTS.Develop
//        }
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              trustedHostArray.contains(challenge.protectionSpace.host) else {
            return
        }

        logger.debug("[HttpsHook] protectionSpace: \(challenge.protectionSpace) - \(challenge.protectionSpace.host)")
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        //print("[HttpsHook] replacing: \(credential)")

        challenge.sender?.use(credential, for: challenge)
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, credential)
    }
    
}


//class Abc: SPTConfiguration{

//}
//class  Sp:  SPT


let DATA = """
{"timestamp":1574717911678,"context":{"external_urls":{"spotify":"https://open.spotify.com/artist/5ZS223C6JyBfXasXxrRqOk"},"href":"https://api.spotify.com/v1/artists/5ZS223C6JyBfXasXxrRqOk","type":"artist","uri":"spotify:artist:5ZS223C6JyBfXasXxrRqOk"},"progress_ms":223706,"item":{"album":{"album_type":"single","artists":[{"external_urls":{"spotify":"https://open.spotify.com/artist/5ZS223C6JyBfXasXxrRqOk"},"href":"https://api.spotify.com/v1/artists/5ZS223C6JyBfXasXxrRqOk","id":"5ZS223C6JyBfXasXxrRqOk","name":"Jhené Aiko","type":"artist","uri":"spotify:artist:5ZS223C6JyBfXasXxrRqOk"}],"available_markets":["AD","AE","AR","AT","AU","BE","BG","BH","BO","BR","CA","CH","CL","CO","CR","CY","CZ","DE","DK","DO","DZ","EC","EE","EG","ES","FI","FR","GB","GR","GT","HK","HN","HU","ID","IE","IL","IN","IS","IT","JO","JP","KW","LB","LI","LT","LU","LV","MA","MC","MT","MX","MY","NI","NL","NO","NZ","OM","PA","PE","PH","PL","PS","PT","PY","QA","RO","SA","SE","SG","SK","SV","TH","TN","TR","TW","US","UY","VN","ZA"],"external_urls":{"spotify":"https://open.spotify.com/album/2vYEAU3L58qz0d8Mk2JVdi"},"href":"https://api.spotify.com/v1/albums/2vYEAU3L58qz0d8Mk2JVdi","id":"2vYEAU3L58qz0d8Mk2JVdi","images":[{"height":640,"url":"https://i.scdn.co/image/ab67616d0000b273d29a218ce0decfc7bae8efc7","width":640},{"height":300,"url":"https://i.scdn.co/image/ab67616d00001e02d29a218ce0decfc7bae8efc7","width":300},{"height":64,"url":"https://i.scdn.co/image/ab67616d00004851d29a218ce0decfc7bae8efc7","width":64}],"name":"Hello Ego","release_date":"2017-06-19","release_date_precision":"day","total_tracks":1,"type":"album","uri":"spotify:album:2vYEAU3L58qz0d8Mk2JVdi"},"artists":[{"external_urls":{"spotify":"https://open.spotify.com/artist/5ZS223C6JyBfXasXxrRqOk"},"href":"https://api.spotify.com/v1/artists/5ZS223C6JyBfXasXxrRqOk","id":"5ZS223C6JyBfXasXxrRqOk","name":"Jhené Aiko","type":"artist","uri":"spotify:artist:5ZS223C6JyBfXasXxrRqOk"},{"external_urls":{"spotify":"https://open.spotify.com/artist/7bXgB6jMjp9ATFy66eO08Z"},"href":"https://api.spotify.com/v1/artists/7bXgB6jMjp9ATFy66eO08Z","id":"7bXgB6jMjp9ATFy66eO08Z","name":"Chris Brown","type":"artist","uri":"spotify:artist:7bXgB6jMjp9ATFy66eO08Z"}],"available_markets":["AD","AE","AR","AT","AU","BE","BG","BH","BO","BR","CA","CH","CL","CO","CR","CY","CZ","DE","DK","DO","DZ","EC","EE","EG","ES","FI","FR","GB","GR","GT","HK","HN","HU","ID","IE","IL","IN","IS","IT","JO","JP","KW","LB","LI","LT","LU","LV","MA","MC","MT","MX","MY","NI","NL","NO","NZ","OM","PA","PE","PH","PL","PS","PT","PY","QA","RO","SA","SE","SG","SK","SV","TH","TN","TR","TW","US","UY","VN","ZA"],"disc_number":1,"duration_ms":228133,"explicit":true,"external_ids":{"isrc":"USUM71706781"},"external_urls":{"spotify":"https://open.spotify.com/track/2kt06ZsD735FYBZO8yAAQs"},"href":"https://api.spotify.com/v1/tracks/2kt06ZsD735FYBZO8yAAQs","id":"2kt06ZsD735FYBZO8yAAQs","is_local":false,"name":"Hello Ego","popularity":57,"preview_url":"https://p.scdn.co/mp3-preview/cf737c4dc0364bdae370607c7f621e273a2c0fea?cid=e3966e30011d4895997ce89c797de5a5","track_number":1,"type":"track","uri":"spotify:track:2kt06ZsD735FYBZO8yAAQs"},"currently_playing_type":"track","actions":{"disallows":{"resuming":true}},"is_playing":true}
"""

import Foundation
import Promises
import Combine
import SwiftyBeaver
import JoliCore



public struct TrackInfo {
    public var track: Track?
    public var info: Json?
}

internal let logger = SwiftyBeaver.self

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
        return track.play(deviceId: deviceId, urlSession: self.urlSession)
            .then() { track -> Result<TrackInfo, Error> in
                return Result<TrackInfo, Error>.success(TrackInfo(track: track, info: [:]))
        }
    }

    @discardableResult
    public func authenticate(email: String, password: String, urlSession: URLSession? = nil, on: DispatchQueue? = nil) -> Promise<Auth?> {
        return Session.fromCredentials(email: email, password: password, baseUrl: self.baseUrl.rawValue.http, urlSession: urlSession ?? JoliApi.sharedUrlSession, on: on)
            .then() { auth -> Auth? in
                self.auth = auth
                return auth
            }
    }
    
    @discardableResult
    public func authenticate(token: String, urlSession: URLSession? = nil, on: DispatchQueue? = nil) -> Promise<Auth?> {
        return Session.fromCredentials(token: token, baseUrl: self.baseUrl.rawValue.http, urlSession: urlSession ?? JoliApi.sharedUrlSession, on: on)
            .then() { auth -> Auth? in
                self.auth = auth
                //logger.debug("[JoliApi#authenticate] AUTH: \(auth)")
                return auth
            }
    }
    
    public func searchTracks(q: String, limit: Int = 10) -> Promise<[Track]> {
        var pathComp = URLComponents(string: "/api/spotify/search")!
        pathComp.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "limit", value: limit.description)
        ]
        
        return HttpMethod.get.fetch(urlPath: pathComp, dataType: [Track].self, payload: nil, urlSession: self.urlSession)
    }
    
    @discardableResult
    public func setVolume(_ volume: Int, deviceId: String, on: DispatchQueue? = nil) -> Promise<Json>{
        let payload: Json = ["deviceId": deviceId as AnyObject,
                             "volume": volume as AnyObject]
        let urlPath = URLComponents(string: "/api/spotify/volume")!
        return HttpMethod.post.fetchJson(urlPath: urlPath, payload: payload, urlSession: self.urlSession, on: on)
    }

    public var user: User?
    public var wsClient: WebSocketClient

    public var subjects: Set<String> = []
    public var baseUrl: BaseUrl
    
    private var cancellableSet: Set<AnyCancellable> = []
    
    public var urlSessionConfiguration: URLSessionConfiguration {
        didSet {
            urlSession = JoliApi.sharedUrlSession.updated(configuration: self.urlSessionConfiguration)
        }
    }
    public var urlSession: URLSession = JoliApi.sharedUrlSession
    
    // MARK: - init
    public init(baseUrl: BaseUrl = .localhost){
        JoliApi.initLogger()
        self.urlSessionConfiguration = JoliApi.sharedUrlSession.configuration
        
        self.baseUrl = baseUrl
        let url = baseUrl.rawValue.ws.appendingPathComponent("/ws")
        self.wsClient = WebSocketClient(url: url)
        
        //(ws: URL, http: URL)
        BASE_URL = baseUrl.rawValue
        
        self.$auth
            .receive(on: RunLoop.main)
            .sink() { auth in
                
                let config = URLSessionConfiguration.default
                var headers = config.httpAdditionalHeaders ?? [:]
                
                if let auth = auth {
                    headers["X-SESSION-ID"] = auth.session.token
                } else {
                    headers.removeValue(forKey: "X-SESSION-ID")
                }
                
                config.httpAdditionalHeaders = headers
                self.urlSessionConfiguration = config
            }
            .store(in: &cancellableSet)
            
        
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
        let headers = self.urlSessionConfiguration.httpAdditionalHeaders as? HttpMethod.Headers
        self.wsClient.send(topic: topic, headers: headers) { error in
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
        let headers = self.urlSessionConfiguration.httpAdditionalHeaders as? HttpMethod.Headers
        self.wsClient.send(topic: topic, headers: headers) { error in
            if let error = error {
                logger.debug("[wsUnsubscribe] error: \(error)")
                return
            }
            
            logger.debug("[JoliApi#unsubscribe] subject=\(subject)")
            self.subjects.remove(subject)
        }
    }
    
    public func fetchSpotifyDevices(baseUrl optBaseUrl: URL? = nil, urlSession: HttpMethod.Headers? = nil, on: DispatchQueue? = nil) -> Promise<[Spotify.Device]> {
        let on = on ?? DispatchQueue.main
        let baseUrl = optBaseUrl ?? self.baseUrl.rawValue.http
        return HttpMethod.get.fetch(urlString: "/api/spotify/devices", dataType: [String: [Spotify.Device]].self, baseUrl: baseUrl, urlSession: self.urlSession, on: on)
            .then(on: on) { (dict) -> [Spotify.Device] in
                guard let devices = dict["devices"] else {
                    throw NetworkError.badResponse("expected key \"devices\" in response: \(dict)")
                }
                return devices
        }
    }
    
    @discardableResult
    public func delete<T>(_ model: T, on: DispatchQueue? = nil) -> Promise<T> where T: DbModel {
        return model.delete(baseUrl: self.baseUrl.rawValue.http, urlSession: urlSession, on: on)
    }
    
    // MARK: - Test
    @discardableResult
    public static func doTest() -> some Promise<Any?> {
        JoliApi.initLogger()
        
        //let urlSession = URLSession(configuration: .default)
        //let url = URL(string: "http://localhost:8080/api/db/musicrooms")!
        //debugPrint("names: \(Musicroom(name: "test").propertyValues())")
        let api = JoliApi(baseUrl: .localhost)
        let url: BaseUrl = api.baseUrl

        
        //JoliApi.sharedUrlSession.configuration = JoliApi.sharedUrlSession.configuration
        
        return api.authenticate(email: "hawa@gmail.net", password: "Password@")
            .then(){ res -> Promise<[Spotify.Device]> in
                logger.debug("[AUTH] \(res)")
                return api.fetchSpotifyDevices()
                    .then() { logger.debug("devices: \($0)") }
                    .catch { logger.error("[ERROR] devices: \($0)") }
        }.catch() {
            logger.error("[ERROR] \($0)")
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
        
//        return Musicroom.all(baseUrl: url.rawValue.http, on: .global(qos: .background))
//            .then() { rooms in
//                logger.debug("[rooms] \(rooms)")
//        }.catch() { err in
//            logger.error("[Musicroom] \(err)")
//        }
//
//        return Musicroom.findById(id: 1, baseUrl: url.rawValue.http, on: .global(qos: .background))
//        .then() { (res) -> Promise<[Track]> in
//            var r = res!
//            debugPrint(r)
//
////            let m = Mirror(reflecting: r)
////
////            for c in m.children {
////                logger.debug("child: \(c)")
////            }
//
//            //r.name = "Davido Party"
//
//            debugPrint("response: \(String(describing: r.$createdAt)) - \(String(describing: r.createdAt))")
//            return Promise([])//r.fetchTracks()
//        }
//        .catch() { error in
//            logger.debug("error: \(error)")
//        }
        
    }
    
    static var sharedUrlSessionDelegate = HttpsHook(trustedHosts: [
       BaseUrl.homeLaptop.rawValue.http.host!,
       BaseUrl.homeDesktop.rawValue.http.host!,
       BaseUrl.mobileHotspot.rawValue.http.host!,
       BaseUrl.localhost.rawValue.http.host!,
    ])
    
    static var sharedUrlSession = URLSession.init(configuration: URLSessionConfiguration.default,
                                                  delegate: JoliApi.sharedUrlSessionDelegate, delegateQueue: .main)
    
}

extension JoliApi {
    
    public func createMusicroom(name: String, details: String, on: DispatchQueue? = nil) -> Promise<Musicroom> {
        let musicroom = Musicroom(name: name, details: details)
        return musicroom.save(baseUrl: baseUrl.rawValue.http, urlSession: urlSession, on: on)
    }
    
}

extension URLSession {
    
    public func updated(configuration: URLSessionConfiguration, delegate: URLSessionDataDelegate? = nil, delegateQueue: OperationQueue? = nil) -> URLSession {
        return URLSession.init(configuration: configuration,
                               delegate: delegate ?? self.delegate, delegateQueue: delegateQueue ?? self.delegateQueue)
    }
    
}

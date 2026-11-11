import Foundation

/// The one door to tallinntastebuds.ee.
///
/// The app has no server of its own. Everything it shows is either one of the
/// static files the website reads (`data/map.json`, `data/lang/<code>.json`,
/// `data/taxonomy.json`) or an answer from one of the website's own Functions
/// under `/api/`. So a place added on the site, a list somebody publishes or a
/// translation fixed in `ui.json` reaches the app the moment the site deploys,
/// with nothing submitted to Apple.
///
/// Requests go through the shared `URLSession`, whose cookie store is the
/// system's. That is deliberate: the website's session is an HttpOnly cookie
/// (`ttb_s`), and a native `URLSession` keeps and sends it by itself, so signing
/// in with a username and password will need no change on the server.
enum API {
    static let base = URL(string: "https://tallinntastebuds.ee")!

    enum Failure: Error, LocalizedError {
        case status(Int)
        case notFound

        var errorDescription: String? {
            switch self {
            case .status(let code): return "The site answered \(code)."
            case .notFound: return "Not found."
            }
        }
    }

    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static let decoder = JSONDecoder()

    /// A URL on the site, with an optional query.
    static func url(_ path: String, _ query: [String: String] = [:]) -> URL {
        var parts = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            parts.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return parts.url!
    }

    /// The raw bytes of a path, or a thrown error for anything but a 2xx.
    static func data(_ path: String, _ query: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url(path, query))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if http.statusCode == 404 { throw Failure.notFound }
            throw Failure.status(http.statusCode)
        }
        return data
    }

    static func get<T: Decodable>(_ type: T.Type, _ path: String, _ query: [String: String] = [:]) async throws -> T {
        try decoder.decode(T.self, from: try await data(path, query))
    }

    /// What a Function said when it refused: its `error` word ("taken",
    /// "no-match", "signed-out") and the status it came with.
    struct Refusal: Error, LocalizedError {
        let code: String
        let status: Int
        var errorDescription: String? { code }
    }

    /// A JSON POST, the way the website's own pages send one. Answers the
    /// decoded object, or throws a `Refusal` carrying the route's own word for
    /// what went wrong, which the screens turn into the site's own sentence.
    @discardableResult
    static func post(_ path: String, _ body: [String: Any]) async throws -> [String: Any] {
        let (data, status) = try await send(path, body)
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if !(200..<300).contains(status) {
            throw Refusal(code: object["error"] as? String ?? "status-\(status)", status: status)
        }
        return object
    }

    /// The same POST for a route whose answer has a shape worth decoding —
    /// `/api/lookup`, which answers places rather than a word.
    static func post<T: Decodable>(_ type: T.Type, _ path: String, _ body: [String: Any]) async throws -> T {
        let (data, status) = try await send(path, body)
        if !(200..<300).contains(status) { throw Failure.status(status) }
        return try decoder.decode(T.self, from: data)
    }

    private static func send(_ path: String, _ body: [String: Any]) async throws -> (Data, Int) {
        var request = URLRequest(url: url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 200)
    }

    /// A photo of a place on the map: `/photos/<id>/<file>`.
    static func photo(_ placeID: String, _ file: String) -> URL {
        base.appendingPathComponent("photos").appendingPathComponent(placeID).appendingPathComponent(file)
    }

    /// A path the site hands back already rooted, like a profile's face.
    static func absolute(_ pathOrURL: String) -> URL? {
        if pathOrURL.hasPrefix("http") { return URL(string: pathOrURL) }
        let trimmed = pathOrURL.hasPrefix("/") ? String(pathOrURL.dropFirst()) : pathOrURL
        return URL(string: trimmed, relativeTo: base)?.absoluteURL
    }

    // The addresses the website shares, so a link sent from the app opens the
    // same page in a browser.
    static func placeLink(_ id: String) -> URL { url("", ["spot": id]) }
    static func listLink(_ id: String) -> URL { base.appendingPathComponent("list").appendingPathComponent(id) }
    static func profileLink(_ name: String) -> URL { base.appendingPathComponent("u").appendingPathComponent(name) }
}

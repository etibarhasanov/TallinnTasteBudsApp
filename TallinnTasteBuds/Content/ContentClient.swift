import Foundation

/// Fetches the website's JSON, with three layers behind it so the app always has
/// something to draw:
///
/// 1. the network, revalidated with the stored ETag so an unchanged file costs a
///    304 and no body;
/// 2. the disk copy of whatever was fetched last, in Application Support;
/// 3. the seed copy bundled with the app at build time.
///
/// Layers 2 and 3 mean the app opens instantly and offline; layer 1 means an
/// edit on the website reaches the reader on the next refresh.
actor ContentClient {
    static let shared = ContentClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let cacheDirectory: URL

    init(session: URLSession = .shared) {
        self.session = session
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        cacheDirectory = support.appendingPathComponent("TallinnTasteBuds/content", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// The best copy available right now without touching the network. Used for
    /// the first frame, so nothing ever renders empty.
    nonisolated func cached<T: Decodable & Sendable>(_ type: T.Type, _ document: ContentSource.Document) -> T? {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let support {
            let file = support.appendingPathComponent("TallinnTasteBuds/content/\(document.rawValue).json")
            if let data = try? Data(contentsOf: file), let value = try? JSONDecoder().decode(type, from: data) {
                return value
            }
        }
        return seed(type, document)
    }

    /// The copy compiled into the app bundle.
    nonisolated func seed<T: Decodable & Sendable>(_ type: T.Type, _ document: ContentSource.Document) -> T? {
        guard let url = Bundle.main.url(forResource: document.seedResource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Fetch `document` from the site, revalidating against the stored ETag.
    /// Returns `nil` when the server says "not modified" — the caller already has
    /// the current content and does not need to redraw.
    func fetch<T: Decodable & Sendable>(_ type: T.Type, _ document: ContentSource.Document) async throws -> T? {
        var request = URLRequest(url: ContentSource.url(for: document))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        if let tag = etag(for: document) {
            request.setValue(tag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ContentError.badResponse }

        if http.statusCode == 304 { return nil }
        guard (200..<300).contains(http.statusCode) else {
            throw ContentError.http(http.statusCode)
        }

        let value = try decoder.decode(type, from: data)
        // Only persist once it has decoded: a half-written file the app cannot
        // read is worse than the older one it would replace.
        write(data, for: document)
        if let tag = http.value(forHTTPHeaderField: "Etag") {
            setEtag(tag, for: document)
        }
        return value
    }

    // MARK: - Disk

    private func write(_ data: Data, for document: ContentSource.Document) {
        let file = cacheDirectory.appendingPathComponent("\(document.rawValue).json")
        try? data.write(to: file, options: .atomic)
    }

    private func etag(for document: ContentSource.Document) -> String? {
        UserDefaults.standard.string(forKey: "ttb.etag.\(document.rawValue)")
    }

    private func setEtag(_ tag: String, for document: ContentSource.Document) {
        UserDefaults.standard.set(tag, forKey: "ttb.etag.\(document.rawValue)")
    }
}

enum ContentError: LocalizedError {
    case badResponse
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .badResponse: return "The server sent something unexpected."
        case .http(let code): return "The server answered \(code)."
        }
    }
}

import Foundation

/// Where the app's content comes from.
///
/// This single constant is the whole reason the app and the website stay in
/// step. Everything the app shows — the places, the type chips, every string of
/// interface text, the discounts, the radio station — is fetched from the same
/// JSON files the website reads. Edit `data/restaurants.json` in the website
/// repo, push, and the change is live in the app the next time it refreshes.
/// No App Store release is involved.
enum ContentSource {
    /// The production host. Cloudflare Pages serves `data/*` with
    /// `must-revalidate`, so a conditional request is always answered honestly.
    static let productionBase = URL(string: "https://tallinntastebuds.pages.dev")!

    /// Overridable at runtime, so a preview deployment can be pointed at without
    /// a rebuild: set `ttb.contentBaseURL` in UserDefaults (or pass
    /// `-ttb.contentBaseURL <url>` as a launch argument in the scheme).
    static var base: URL {
        if let raw = UserDefaults.standard.string(forKey: "ttb.contentBaseURL"),
           let url = URL(string: raw), url.scheme != nil {
            return url
        }
        return productionBase
    }

    /// The five files the site keeps its content in.
    enum Document: String, CaseIterable {
        case restaurants, taxonomy, ui, deals, radio

        var path: String { "data/\(rawValue).json" }
        /// The copy shipped inside the app, so a first launch with no network
        /// still draws a full map.
        var seedResource: String { rawValue }
    }

    static func url(for document: Document) -> URL {
        base.appendingPathComponent(document.path)
    }

    /// Photos live next to the data, one folder per place id.
    static func photoURL(placeID: String, file: String) -> URL {
        base.appendingPathComponent("photos/\(placeID)/\(file)")
    }

    /// The website's own discount page. The rotating code is generated there and
    /// checked by the staff page against the same clock, so the app deliberately
    /// does not reimplement it — it opens the page the staff already trust.
    static func dealURL(placeID: String, lang: String) -> URL {
        var components = URLComponents(url: base.appendingPathComponent("deal.html"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "spot", value: placeID),
            URLQueryItem(name: "lang", value: lang)
        ]
        return components.url!
    }

    static var instagramProfile: URL {
        URL(string: "https://www.instagram.com/tallinntastebuds/")!
    }
}

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
    /// The production host — the site's own domain, the one its canonical tag
    /// names. Cloudflare Pages serves `data/*` with `must-revalidate`, so a
    /// conditional request is always answered honestly.
    ///
    /// The project's `tallinntastebuds.pages.dev` address serves the same files
    /// from the same deployment and stays valid, so it is the address to fall
    /// back to by hand if the domain ever has a bad day.
    static let productionBase = URL(string: "https://tallinntastebuds.ee")!

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
    ///
    /// The place goes in as `r`, which is what `deal.js` reads. `spot` is the
    /// map page's parameter and means nothing here: passing it leaves the page
    /// with no place at all, and it says so politely instead of failing.
    ///
    /// `style` only knows the site's two, so the app's pink asks for the site's
    /// dark rather than falling through to its light.
    static func dealURL(placeID: String, lang: String, darkStyle: Bool) -> URL {
        var components = URLComponents(url: base.appendingPathComponent("deal.html"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "r", value: placeID),
            URLQueryItem(name: "lang", value: lang),
            URLQueryItem(name: "style", value: darkStyle ? "green" : "red")
        ]
        return components.url!
    }

    /// The identity mark: a photograph of the watercolour the site is named
    /// for. Fetched rather than bundled, so repainting it on the site repaints
    /// it here — only the app icon has to be a copy, because iOS draws that
    /// before the app has run.
    static var markURL: URL {
        base.appendingPathComponent("assets/logo/mark.webp")
    }

    static var instagramProfile: URL {
        URL(string: "https://www.instagram.com/tallinntastebuds/")!
    }
}

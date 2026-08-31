import SwiftUI

/// The painting the map is named for, in the two crops the site keeps of it.
///
/// `pin` is the round one, worn by every dot on the map. `brand` is the wide
/// one the site's header card carries beside the wordmark — the logo, in other
/// words, and the app's headers wear it for the same reason the site's does.
///
/// Loaded once and shared. Seventy-three pins asking for the same URL through
/// AsyncImage would be seventy-three decodes of one picture, so this holds the
/// decoded images instead. The bundled copies draw the first frame; the site's
/// own replace them when they arrive, so repainting the mark on the website
/// repaints it here too.
@MainActor
@Observable
final class MarkImage {
    private(set) var pin: Image?
    private(set) var brand: Image?

    init() {
        pin = Self.bundled("mark-round")
        brand = Self.bundled("mark")
    }

    func refresh() async {
        // A failed fetch leaves the bundled copy in place rather than blanking
        // the pins on a bad connection.
        if let fetched = await Self.fetch(ContentSource.roundMarkURL) { pin = fetched }
        if let fetched = await Self.fetch(ContentSource.markURL) { brand = fetched }
    }

    private static func bundled(_ name: String) -> Image? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "webp"),
              let data = try? Data(contentsOf: url),
              let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
    }

    private static func fetch(_ url: URL) async -> Image? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
    }
}

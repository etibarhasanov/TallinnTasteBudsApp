import SwiftUI

/// The round crop of the painting, which every pin on the map wears.
///
/// Loaded once and shared. Seventy-three pins asking for the same URL through
/// AsyncImage would be seventy-three decodes of one picture, so this holds the
/// decoded image instead. The bundled copy draws the first frame; the site's
/// own copy replaces it when it arrives, so repainting the mark on the website
/// repaints every pin here too.
@MainActor
@Observable
final class MarkImage {
    private(set) var image: Image?

    init() {
        if let url = Bundle.main.url(forResource: "mark-round", withExtension: "webp"),
           let data = try? Data(contentsOf: url),
           let ui = UIImage(data: data) {
            image = Image(uiImage: ui)
        }
    }

    func refresh() async {
        let url = ContentSource.roundMarkURL
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let ui = UIImage(data: data) else { return }
        image = Image(uiImage: ui)
    }
}

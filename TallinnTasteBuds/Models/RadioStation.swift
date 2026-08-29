import Foundation

/// `data/radio.json`: one default station plus a per-language override, so the
/// station follows whichever language the reader picked.
struct RadioFeed: Decodable {
    let `default`: RadioStation?
    let byLanguage: [String: RadioStation]?

    func station(for lang: String) -> RadioStation? {
        byLanguage?[lang] ?? `default`
    }
}

struct RadioStation: Hashable, Decodable {
    let name: String
    let url: URL
}

import Foundation

/// `data/taxonomy.json`: the closed set of type chips, with a label per language.
struct Taxonomy: Decodable {
    let types: [PlaceType]

    static let empty = Taxonomy(types: [])
}

struct PlaceType: Identifiable, Hashable, Decodable {
    let id: String
    /// Every other key in the object is a language code mapped to the label.
    let labels: [String: String]

    func label(in lang: String) -> String {
        labels[lang] ?? labels["en"] ?? id
    }

    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        var found: [String: String] = [:]
        var slug = ""
        for key in c.allKeys {
            let value = try c.decode(String.self, forKey: key)
            if key.stringValue == "id" { slug = value } else { found[key.stringValue] = value }
        }
        guard !slug.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "taxonomy type without an id")
            )
        }
        id = slug
        labels = found
    }
}

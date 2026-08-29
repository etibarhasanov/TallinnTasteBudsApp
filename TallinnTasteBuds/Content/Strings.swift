import Foundation

/// Every word of interface text, read from the website's `data/ui.json`.
///
/// The app ships no `.strings` files on purpose. Add a language to `ui.json` on
/// the site and it appears in the app's language picker on the next refresh;
/// fix a typo there and the app stops showing it, with no release in between.
///
/// A value type, rebuilt from the store's table and the reader's language each
/// time it is read. It holds a dictionary reference and nothing else, so that
/// costs nothing and there is no second copy of the language to keep in step.
struct Strings {
    /// language code -> key -> text
    let table: [String: [String: String]]
    let lang: String

    static let fallbackLang = "en"

    init(table: [String: [String: String]] = [:], lang: String = Strings.fallbackLang) {
        self.table = table
        self.lang = lang
    }

    /// The languages the site offers, English first because it is the fallback
    /// everything else leans on, then by name.
    var languages: [Language] {
        table.keys
            .map { Language(code: $0, name: table[$0]?["langName"] ?? $0.uppercased()) }
            .sorted { lhs, rhs in
                if lhs.code == Strings.fallbackLang { return true }
                if rhs.code == Strings.fallbackLang { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    var hasContent: Bool { !table.isEmpty }

    func has(_ code: String) -> Bool { table[code] != nil }

    /// Look up `key` in the current language, falling back to English and then to
    /// the key itself — a missing string shows as its key rather than as a blank,
    /// which is the difference between a bug you can see and one you cannot.
    func callAsFunction(_ key: String) -> String {
        table[lang]?[key] ?? table[Strings.fallbackLang]?[key] ?? key
    }

    /// The site's placeholder convention: `{n} places`, `Photo {n} of {total}`.
    func callAsFunction(_ key: String, _ replacements: [String: String]) -> String {
        replacements.reduce(callAsFunction(key)) { text, pair in
            text.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
        }
    }

    /// "3 places" / "1 place": the site keeps a separate key for the singular
    /// because not every one of its languages forms it the same way.
    func count(_ n: Int) -> String {
        n == 1 ? callAsFunction("listCountOne") : callAsFunction("listCount", ["n": String(n)])
    }

    /// `YYYY-MM` rendered with the month names from `ui.json`.
    func monthYear(_ value: String) -> String {
        let parts = value.split(separator: "-")
        guard parts.count >= 2, let month = Int(parts[1]), (1...12).contains(month) else { return value }
        let names = callAsFunction("months").split(separator: "|").map(String.init)
        guard names.count == 12 else { return value }
        return callAsFunction("monthYear", ["month": names[month - 1], "year": String(parts[0])])
    }
}

struct Language: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }
}

import Observation
import SwiftUI

/// The one piece of content the app owns rather than mirrors: a reader's own
/// shortlist, kept on the device. The website has no accounts, so this stays
/// local — nothing to sign into, nothing to leak.
@MainActor
@Observable
final class Favourites {
    private(set) var ids: Set<String>

    private static let key = "ttb.favourites"

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
        ids = Set(stored)
    }

    func contains(_ place: Place) -> Bool { ids.contains(place.id) }

    func toggle(_ place: Place) {
        if ids.contains(place.id) {
            ids.remove(place.id)
        } else {
            ids.insert(place.id)
        }
        UserDefaults.standard.set(Array(ids), forKey: Self.key)
    }

    /// Kept in the order the store hands them over, so a saved list reads the
    /// same way as the list it was saved from.
    func filter(_ places: [Place]) -> [Place] {
        places.filter { ids.contains($0.id) }
    }
}

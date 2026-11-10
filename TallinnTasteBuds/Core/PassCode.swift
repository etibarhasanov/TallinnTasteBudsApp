import Foundation
import CryptoKit

/// The hourly code a discount pass shows, made exactly the way the website's
/// `assets/pass.js` makes it, so a waiter's scan of the app's QR opens the
/// website's own `verify.html` and comes back green.
///
///     hour = floor(now / one hour)
///     code = HMAC-SHA256(the deal's key, "<place-id>:<hour>[:<rate>]")
///            first four bytes, big-endian, read off five letters at a time
///            from the top in the alphabet below
///
/// The key is the deal's key string as UTF-8 bytes, not decoded from base 32 —
/// the website signs with the string itself. `Tools/PassCodeCheck.swift` holds
/// this file to codes the website's algorithm made, and CI runs it, because a
/// code that differs by one letter is a guest turned away at the till.
///
/// This file depends on Foundation and CryptoKit alone, so the check can
/// compile it without the rest of the app.
enum PassCode {
    static let hourLength: TimeInterval = 3600

    /// Thirty-two characters with I, L, O and U left out, so a code read off a
    /// screen aloud is never a one, a zero, or an unfortunate word.
    static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    static let length = 5

    static func hour(at date: Date = Date()) -> Int {
        Int((date.timeIntervalSince1970 / hourLength).rounded(.down))
    }

    /// When the given hour ends, which is when its code stops being current.
    static func end(of hour: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(hour + 1) * hourLength)
    }

    static func code(key: String, place: String, hour: Int, rate: Int? = nil) -> String {
        let message = "\(place):\(hour)" + (rate.map { ":\($0)" } ?? "")
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: SymmetricKey(data: Data(key.utf8)))
        let bytes = Array(mac)
        var acc: UInt32 = 0
        for i in 0..<4 { acc = (acc << 8) | UInt32(bytes[i]) }
        var out = ""
        for c in 0..<length {
            let shift = UInt32(27 - c * 5)
            out.append(alphabet[Int((acc >> shift) & 31)])
        }
        return out
    }

    /// The address the QR holds: the website's verify page, which checks the
    /// code against the hour and the rate it names.
    static func verifyURL(base: URL, place: String, hour: Int, code: String, rate: Int?) -> URL {
        var parts = URLComponents(url: base.appendingPathComponent("verify.html"), resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "r", value: place),
            URLQueryItem(name: "h", value: String(hour)),
            URLQueryItem(name: "c", value: code)
        ]
        if let rate { items.append(URLQueryItem(name: "p", value: String(rate))) }
        parts.queryItems = items
        return parts.url!
    }
}

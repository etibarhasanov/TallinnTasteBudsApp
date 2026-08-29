import SafariServices
import SwiftUI

/// Opens a page from the website inside the app.
///
/// Used for the two things that must stay on the site rather than be
/// reimplemented here: the rotating discount code, which the staff page checks
/// against the same clock, and the Instagram and TikTok posts, which have no
/// embeddable form worth shipping.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

extension View {
    /// `sheet(item:)` wants something Identifiable, and a bare URL is not.
    func safariSheet(url: Binding<IdentifiedURL?>) -> some View {
        sheet(item: url) { SafariView(url: $0.url).ignoresSafeArea() }
    }
}

struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

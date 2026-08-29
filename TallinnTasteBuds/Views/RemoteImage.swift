import SwiftUI

/// A photo from the website's `photos/<id>/` folder.
///
/// `AsyncImage` handles the fetch and URLCache handles the caching; the site
/// serves photos with a week-long `max-age`, so a photo seen once stays on the
/// device without the app keeping a cache of its own. WebP decodes natively on
/// iOS 14 and later, which is the format every photo on the site is in.
struct RemoteImage: View {
    let url: URL
    var contentMode: ContentMode = .fill

    @Environment(\.theme) private var theme

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(theme.muted)
                    }
            default:
                placeholder.overlay { ProgressView().tint(theme.muted) }
            }
        }
    }

    private var placeholder: some View {
        Rectangle().fill(theme.hairline)
    }
}

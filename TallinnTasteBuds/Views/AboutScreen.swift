import SwiftUI

/// What the map is and where it comes from. Nothing to set — language and
/// appearance live on the map itself, next to what they change.
struct AboutScreen: View {
    @Environment(ContentStore.self) private var store
    @Environment(MarkImage.self) private var marks
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    mark
                    Text(store.app(.aboutBody))
                        .font(.running(16))
                        .foregroundStyle(theme.ink)
                        .lineSpacing(3)
                    Text(store.app(.syncNote))
                        .font(.running(13))
                        .foregroundStyle(theme.muted)
                }
                .listRowBackground(theme.paper)

                Section {
                    Button(store.strings("instagramHandle")) {
                        openURL(ContentSource.instagramProfile)
                    }
                    Button(store.app(.openWebsite)) {
                        openURL(ContentSource.base)
                    }
                }
                .listRowBackground(theme.paper)
            }
            .scrollContentBackground(.hidden)
            .background(theme.wash)
            .navigationTitle(store.app(.about))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// The painting the map is named for. Bundled so the screen is not a grey
    /// rectangle on a plane, and replaced by the site's own copy when that
    /// arrives, so repainting it there repaints it here.
    @ViewBuilder
    private var mark: some View {
        VStack(spacing: 10) {
            Group {
                if let painting = marks.brand {
                    painting.resizable().aspectRatio(contentMode: .fit)
                } else {
                    RemoteImage(url: ContentSource.markURL, contentMode: .fit)
                }
            }
            .frame(maxWidth: 220, maxHeight: 170)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            Text(store.strings("wordmark"))
                .font(.display(20, weight: .bold))
                .foregroundStyle(theme.ink)
            Text(store.strings("tagline"))
                .font(.running(14))
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

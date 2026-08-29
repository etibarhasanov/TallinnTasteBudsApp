import SwiftUI

/// What the map is and where it comes from. Nothing to set — language and
/// appearance live on the map itself, next to what they change.
struct AboutScreen: View {
    @Environment(ContentStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
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
}

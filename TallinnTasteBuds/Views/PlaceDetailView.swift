import SwiftUI

/// A place on the map, opened: its photos, the write-up, what to order, and
/// the ways to get there or get in touch.
struct PlaceDetailView: View {
    @Environment(ContentStore.self) private var content
    @Environment(SavesStore.self) private var saves
    @Environment(LocationProvider.self) private var location
    @Environment(AccountStore.self) private var account
    @Environment(\.openURL) private var openURL
    let id: String
    @State private var adding = false
    @State private var signingIn = false
    @State private var route: RouteTarget?

    var body: some View {
        if let place = content.place(id) {
            page(place)
        } else {
            EmptyNote(title: content.t("appPlaceGone", "Not on the map any more"),
                      text: content.t("appPlaceGoneSay", "This place has been taken off the map."),
                      systemImage: "mappin.slash")
        }
    }

    private func page(_ place: Place) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                photos(place)
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name).font(.title.bold()).foregroundStyle(Theme.ink)
                        Text(facts(place)).font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    if place.closed {
                        Label(content.t("closedFlag", "Closed for good"), systemImage: "xmark.octagon")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    if !place.types.isEmpty {
                        FlowLayout {
                            ForEach(place.types, id: \.self) { t in
                                Tag(text: content.type(t)?.name(content.lang) ?? t)
                            }
                        }
                    }
                    if let blurb = content.blurb(place.id) {
                        Text(blurb).font(.body).foregroundStyle(Theme.ink).lineSpacing(3)
                    }
                    if let deal = content.deal(place.id) {
                        DealBlock(deal: deal)
                    }
                    if !place.mustOrder.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: content.t("mustOrder", "Must order"))
                            FlowLayout { ForEach(place.mustOrder, id: \.self) { Tag(text: $0) } }
                        }
                    }
                    actions(place)
                }
                .padding(16)
            }
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $adding) { AddToListSheet(place: place) }
        .fullScreenCover(item: $route) { RouteView(target: $0) }
        .sheet(isPresented: $signingIn) {
            SignInView(reason: content.t("appSignInToList", "Sign in to put this place on a list of your own"))
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: API.placeLink(place.id)) { Image(systemName: "square.and.arrow.up") }
                Button {
                    if account.signedIn { adding = true } else { signingIn = true }
                } label: {
                    Image(systemName: "text.badge.plus")
                }
                .accessibilityLabel(content.t("appAddToList", "Add to a list"))
                Button { saves.toggle(place.id) } label: {
                    Image(systemName: saves.isSaved(place.id) ? "heart.fill" : "heart")
                }
                .accessibilityLabel(content.t("savePlace", "Save this place"))
            }
        }
    }

    @ViewBuilder
    private func photos(_ place: Place) -> some View {
        if place.photoURLs.isEmpty {
            Theme.wash.frame(height: 160).overlay(Mark(size: 72))
        } else {
            TabView {
                ForEach(place.photoURLs, id: \.self) { url in Photo(url: url) }
            }
            .tabViewStyle(.page(indexDisplayMode: place.photoURLs.count > 1 ? .always : .never))
            .frame(height: 320)
        }
    }

    private func facts(_ place: Place) -> String {
        var parts: [String] = []
        if !place.address.isEmpty { parts.append(place.address) }
        if let p = place.priceText { parts.append(p) }
        parts.append(Distance.text(location.distance(to: place.location)))
        return parts.joined(separator: " · ")
    }

    private func actions(_ place: Place) -> some View {
        VStack(spacing: 8) {
            Button {
                route = RouteTarget(id: place.id, name: place.name, coordinate: place.coordinate)
            } label: {
                Label(content.t("directions", "Directions"), systemImage: "figure.walk")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.prominent)

            HStack(spacing: 8) {
                if let url = URL(string: place.reel), !place.reel.isEmpty {
                    Button { openURL(url) } label: {
                        Label(content.t("markReel", "Reel"), systemImage: "play.rectangle").frame(maxWidth: .infinity)
                    }
                }
                if let url = URL(string: place.website), !place.website.isEmpty {
                    Button { openURL(url) } label: {
                        Label(content.t("website", "Website"), systemImage: "safari").frame(maxWidth: .infinity)
                    }
                }
                if !place.phone.isEmpty, let url = URL(string: "tel:" + place.phone.filter { "+0123456789".contains($0) }) {
                    Button { openURL(url) } label: {
                        Label(content.t("call", "Call"), systemImage: "phone").frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
        }
        .controlSize(.large)
        .padding(.top, 6)
    }
}

/// A place a list named that is not on the map: a Google venue, or one its
/// author typed in. It has no write-up from Tallinn Tastebuds, so this page
/// says what the list's author said and what Google knows, and no more.
struct VenueView: View {
    @Environment(ContentStore.self) private var content
    @Environment(\.openURL) private var openURL
    let item: ListItem
    @State private var route: RouteTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(item.name).font(.title.bold()).foregroundStyle(Theme.ink)
                if !item.address.isEmpty {
                    Text(item.address).font(.subheadline).foregroundStyle(Theme.muted)
                }
                Text(content.t("appNotOnMap", "Not on the Tallinn Tastebuds map"))
                    .font(.footnote).foregroundStyle(Theme.muted)
                if let rating = item.rating {
                    Label {
                        Text(String(format: "%.1f", rating) + (item.reviews.map { " · \($0) on Google" } ?? " on Google"))
                    } icon: { Image(systemName: "star.fill") }
                    .font(.subheadline).foregroundStyle(Theme.ink)
                }
                if let today = todayHours {
                    Label(today, systemImage: "clock").font(.subheadline).foregroundStyle(Theme.ink)
                }
                HStack(spacing: 8) {
                    if let c = item.coordinate {
                        Button { route = RouteTarget(id: item.id, name: item.name, coordinate: c) } label: {
                            Label(content.t("directions", "Directions"), systemImage: "figure.walk").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.prominent)
                    }
                    if let url = URL(string: item.website), !item.website.isEmpty {
                        Button { openURL(url) } label: {
                            Label(content.t("website", "Website"), systemImage: "safari").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .controlSize(.large)
                if let url = URL(string: item.mapsUrl), !item.mapsUrl.isEmpty {
                    Button(content.t("venuesMaps", "Open in Google Maps")) { openURL(url) }
                        .font(.subheadline)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fullScreenCover(item: $route) { RouteView(target: $0) }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Today's opening hours, which the site keeps Sunday first and labels as
    /// Google's — so does this.
    private var todayHours: String? {
        guard item.hours.count == 7 else { return nil }
        let day = Calendar.current.component(.weekday, from: Date()) - 1
        if let span = item.hours[day] {
            return content.t("appTodayHours", "Today {span} (Google's hours)", ["span": span.replacingOccurrences(of: "-", with: "–")])
        }
        return content.t("venuesShutToday", "Closed today")
    }
}

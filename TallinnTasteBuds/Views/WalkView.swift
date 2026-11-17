import SwiftUI
import CoreLocation

/// A list's third view, Route: its places in the shortest order to go round
/// them, the leg into each and how far in the walk is by then, and — signed
/// in — a walk to start and check in on. The website's Route view
/// (`assets/walk.js`), drawn natively; `WalkGame` is the state and every
/// press, and `WalkBand` is the bar at the foot, which the list's map wears
/// too while a walk is on.
struct WalkRoute: View {
    @Environment(ContentStore.self) private var content
    @Environment(LocationProvider.self) private var location
    let game: WalkGame
    /// See it on the map: the list's map, with the walk drawn on it.
    let onMap: () -> Void
    @State private var now = Date()

    private var words: WalkWords { WalkWords(content: content) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                head
                if game.doors.count > 1 { rail }
                board
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            if game.loaded { WalkBand(game: game, onList: nil) }
        }
        .task {
            // The clock on the card reads to the minute.
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    // MARK: The card

    private var head: some View {
        let total = game.doors.count
        let done = game.answer?.checks.count ?? 0
        let lost = game.list.items.count - total
        return VStack(alignment: .leading, spacing: 8) {
            Text(words.t(game.finished ? "walkFinishedEyebrow" : "walkEyebrow", game.finished ? "Route · finished" : "Route"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(game.finished ? RouteView.Mode.foot.color : Theme.muted)
            Text(GoogleWords.title(game.list.id, game.list.title, content))
                .font(.title2.bold()).foregroundStyle(Theme.ink)

            if game.finished, let walk = game.answer?.walk, let end = walk.finished {
                facts(words.t("walkDoneIn", "{n} of {total} checked · finished in {took}",
                              ["n": "\(done)", "total": "\(total)", "took": words.took(end - walk.started)]))
            } else if game.started {
                facts(words.t("walkToGo", "{n} of {total} checked · {left} to go",
                              ["n": "\(done)", "total": "\(total)", "left": "\(total - done)"]))
            } else {
                facts(span(game.total))
                if total > 0 { times(game.total) }
            }

            if game.started {
                ProgressView(value: Double(done), total: Double(max(1, total)))
                    .tint(game.finished ? RouteView.Mode.foot.color : Theme.accent)
            }

            if game.finished {
                say(words.t("walkFinishedSay", "You went to every place on this list. You are on the board below."))
                if let note = game.answer?.walk?.note, !note.isEmpty, game.noting != "" {
                    Text(note).font(.subheadline).italic().foregroundStyle(Theme.ink)
                }
                howWent
            } else if total > 0, game.started, let walk = game.answer?.walk {
                facts(words.t("walkPlaying", "Started {date} · playing for {took}",
                              ["date": words.day(walk.started), "took": words.took(now.timeIntervalSince1970 * 1000 - walk.started)]))
                let toGo = WalkMath.length((location.location.map { [$0.coordinate] } ?? []) + game.left.map { $0.coordinate! })
                facts(toGo > 0 ? words.t("walkLeftSpan", "{n} left · about {distance}",
                                         ["n": "\(game.left.count)", "distance": words.distance(toGo)]) : span(game.total))
                times(toGo > 0 ? toGo : game.total)
                say(game.replanned && !game.left.isEmpty
                    ? words.t("walkReplanned", "Shortest order for the places left, starting at {place}, the nearest to you.", ["place": game.left[0].name])
                    : words.t("walkGoal", "Check in at all {total} and you are finished and on the board.", ["total": "\(total)"]))
            } else if total > 0, let first = game.stops.first {
                if game.own != nil {
                    say(game.longerBy >= 10 ? words.t("walkYours", "Your order · {more} longer than the shortest.", ["more": words.distance(game.longerBy)])
                                            : words.t("walkYoursPlain", "Your order."))
                } else {
                    say(words.t(game.from == nil ? "walkFromFirst" : "walkFromHere",
                                game.from == nil ? "Shortest order, starting at {place}, the first on the list." : "Shortest order, starting at {place}, the nearest to you.",
                                ["place": first.name]))
                }
                Text(words.t("walkHow", "Go to each place and press Check in when you are there. Any order, no need to buy anything, and it can take as many days as you like."))
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }

            tiles(total)

            if game.started {
                if game.asking {
                    VStack(alignment: .leading, spacing: 8) {
                        say(words.t("walkAgainAsk", "Start again? Your check-ins and comments on this list will be erased, your time comes off the board, and the clock starts from zero."))
                        HStack {
                            Button(words.t("walkAgainYes", "Yes, start again"), role: .destructive) {
                                Task { await game.again(words: words) }
                            }
                            .disabled(game.busy == .again)
                            Button(words.t("walkAgainNo", "Keep going")) { game.asking = false }
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button(words.t("walkAgain", "Start again")) { game.asking = true }
                        .buttonStyle(.bordered)
                }
            }

            if lost > 0 {
                facts(words.t("walkLeftOut", "Left out, with no location: {n}", ["n": "\(lost)"]))
            }
        }
        .card()
    }

    private func span(_ metres: Double) -> String {
        let total = game.doors.count
        let places = total == 1 ? words.t("listCountOne", "1 place") : words.t("listCount", "{n} places", ["n": "\(total)"])
        return words.t("walkSpan", "{places} · about {distance}", ["places": places, "distance": words.distance(metres)])
    }

    private func facts(_ text: String) -> some View {
        Text(text).font(.subheadline.monospacedDigit()).foregroundStyle(Theme.muted)
    }

    private func say(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(Theme.ink)
    }

    /// "3 h 6 min on foot · 1 h 0 min by bike · 37 min by car", the times in
    /// the ink and the words where each language puts them.
    private func times(_ metres: Double) -> some View {
        let said = words.t("walkTimes", "{foot} on foot · {bike} by bike · {car} by car",
                           ["foot": "\u{1}", "bike": "\u{2}", "car": "\u{3}"])
        let filled: [Character: String] = ["\u{1}": words.minutes(metres / WalkMath.foot),
                                           "\u{2}": words.minutes(metres / WalkMath.bike),
                                           "\u{3}": words.minutes(metres / WalkMath.car)]
        var line = Text("")
        var plain = ""
        for ch in said {
            if let time = filled[ch] {
                line = line + Text(plain).foregroundStyle(Theme.muted) + Text(time).bold().foregroundStyle(Theme.ink)
                plain = ""
            } else {
                plain.append(ch)
            }
        }
        line = line + Text(plain).foregroundStyle(Theme.muted)
        return line.font(.subheadline)
    }

    private var howWent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(words.t("walkHowWent", "How did you go round?")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            FlowLayout {
                ForEach(["foot", "bike", "car", "mixed"], id: \.self) { mode in
                    let on = game.answer?.walk?.mode == mode
                    Button { Task { await game.setMode(mode, words: words) } } label: {
                        Text(words.went(mode) ?? mode)
                            .font(.subheadline)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(on ? Theme.accent : Color.clear, in: Capsule())
                            .overlay(Capsule().stroke(on ? Theme.accent : Theme.hairline))
                            .foregroundStyle(on ? Theme.onAccent : Theme.ink)
                    }
                    .buttonStyle(.plain)
                    .disabled(game.busy == .mode)
                }
            }
        }
    }

    /// Everything else the card can do, in the order somebody would reach
    /// for it.
    @ViewBuilder
    private func tiles(_ total: Int) -> some View {
        HStack(spacing: 8) {
            if game.finished, game.noting != "" {
                tile("pencil", words.t((game.answer?.walk?.note.isEmpty ?? true) ? "walkNoteAdd" : "walkNoteEdit",
                                       (game.answer?.walk?.note.isEmpty ?? true) ? "Comment" : "Edit comment")) {
                    game.noting = ""
                }
            }
            if !game.started, game.from == nil, game.own == nil, total > 0 {
                tile("scope", words.t("walkFromMe", "Start from where I am")) {
                    location.start()
                    game.fromMe(location.location, words: words)
                }
            }
            if game.started, !game.finished, game.left.count > 1 {
                tile("scope", words.t("walkReplan", "Shortest from here")) {
                    Task { await game.replan(location.location, words: words) }
                }
            }
            if total > 0 {
                tile("map", words.t("walkOnMap", "See it on the map"), action: onMap)
            }
            if !game.started, game.own != nil || game.from != nil {
                tile("arrow.uturn.backward", words.t("walkShortest", "Reset to the shortest order")) {
                    Task { await game.shortestAgain() }
                }
            }
        }
    }

    private func tile(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent)
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center).lineLimit(3)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline))
        }
        .buttonStyle(.plain)
    }

    // MARK: The rail

    private var rail: some View {
        let stops = game.stops
        let sofar = game.sofar
        return VStack(alignment: .leading, spacing: 0) {
            cap(words.t("walkStartAt", "Start · {place}", ["place": stops[0].name]))
            ForEach(Array(stops.enumerated()), id: \.element.id) { i, item in
                if i > 0 {
                    let leg = WalkMath.metres(stops[i - 1].coordinate!, item.coordinate!)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(words.t("walkLeg", "{distance} · {time}", ["distance": words.distance(leg), "time": words.minutes(leg / WalkMath.foot)]))
                        Text(words.t("walkSoFar", "{time} in", ["time": words.minutes(sofar[i] / WalkMath.foot)]))
                    }
                    .font(.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                    .padding(.leading, 40).padding(.vertical, 8)
                    .overlay(alignment: .leading) { line }
                }
                stop(item, number: i + 1)
            }
            cap(words.t("walkEndAt", "Finish · {place} · {time} in all", [
                "place": stops[stops.count - 1].name,
                "time": game.finished
                    ? words.took((game.answer?.walk?.finished ?? 0) - (game.answer?.walk?.started ?? 0))
                    : words.minutes(game.total / WalkMath.foot)
            ]))
        }
    }

    private var line: some View {
        Rectangle().fill(Theme.hairline).frame(width: 2).padding(.leading, 13)
    }

    private func cap(_ text: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(Theme.muted).frame(width: 10, height: 10).padding(.leading, 9)
            Text(text).font(.caption).foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 6)
    }

    private func stop(_ item: ListItem, number: Int) -> some View {
        let mine = game.check(item.place)
        let isNext = game.next == item
        let notes = (game.answer?.notes ?? []).filter { $0.place == item.place }
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(mine != nil ? RouteView.Mode.foot.color : isNext ? Theme.accent : Theme.card)
                Circle().stroke(mine != nil ? RouteView.Mode.foot.color : Theme.accent, lineWidth: 1.5)
                if mine != nil {
                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.caption.bold()).foregroundStyle(isNext ? Theme.onAccent : Theme.accent)
                }
            }
            .frame(width: 28, height: 28)
            .padding(.top, 10)

            VStack(alignment: .leading, spacing: 4) {
                NavigationLink(value: route(for: item)) {
                    Text(item.name).font(.headline).foregroundStyle(Theme.ink)
                }
                if !item.address.isEmpty {
                    Text(item.address).font(.caption).foregroundStyle(Theme.muted)
                }
                if let mine {
                    Text(words.t("walkChecked", "Checked · {when}", ["when": words.day(mine.at, clock: true)]))
                        .font(.caption.weight(.semibold)).foregroundStyle(RouteView.Mode.foot.color)
                }
                if isNext {
                    Text(location.location.map {
                        words.t("walkNextFrom", "Next · {distance} from here",
                                ["distance": words.distance(WalkMath.crow($0.coordinate, item.coordinate!))])
                    } ?? words.t("walkNext", "Next"))
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                }
                ForEach(Array(notes.prefix(3).enumerated()), id: \.offset) { _, note in
                    (Text(note.name).fontWeight(.semibold) + Text(" " + note.note))
                        .font(.caption).foregroundStyle(Theme.ink)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isNext ? Theme.accent : Theme.hairline))
        }
    }

    private func route(for item: ListItem) -> Route {
        if item.map, content.place(item.place) != nil { return .place(item.place) }
        return .venue(item)
    }

    // MARK: The board

    @ViewBuilder
    private var board: some View {
        if let rows = game.answer?.board, !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(words.t("walkBoard", "Who finished it")).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    .padding(.bottom, 6)
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    Divider().overlay(Theme.hairline)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            NavigationLink(value: Route.profile(row.name)) {
                                Text("\(i + 1) · ").foregroundStyle(Theme.ink) + Text(row.name).underline().foregroundStyle(Theme.ink)
                            }
                            Spacer()
                            Text([words.went(row.mode), words.took(row.finished - row.started)].compactMap { $0 }.joined(separator: " · "))
                                .foregroundStyle(Theme.muted)
                        }
                        .font(.subheadline)
                        if !row.note.isEmpty {
                            Text(row.note).font(.caption).italic().foregroundStyle(Theme.ink)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .card()
        }
    }
}

/// The bar at the foot of a walk: the one filled action it has. Start, or
/// Sign in to start; once it is on, the nearest place left by name, how far,
/// and Check in — greyed until inside the radius but pressable, since a fix
/// lags a person walking and the server decides; after a check, the comment.
/// The list's Route view and its map both wear it.
struct WalkBand: View {
    @Environment(ContentStore.self) private var content
    @Environment(LocationProvider.self) private var location
    @Environment(AccountStore.self) private var account
    let game: WalkGame
    /// On the map: Open the list goes back to its Route view.
    let onList: (() -> Void)?
    @State private var note = ""
    @State private var signingIn = false
    /// Directions to the nearest place left, on our own map.
    @State private var way: RouteTarget?
    @FocusState private var typing: Bool

    private var words: WalkWords { WalkWords(content: content) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = game.message {
                Text(message.text).font(.subheadline.weight(.semibold))
                    .foregroundStyle(message.bad ? Theme.accent : RouteView.Mode.foot.color)
            }
            actions(for: game.writingOn)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper)
        .overlay(alignment: .top) { Divider().overlay(Theme.hairline) }
        .sheet(isPresented: $signingIn) {
            SignInView(reason: words.t("walkSignIn", "Sign in to start"))
        }
        .fullScreenCover(item: $way) { RouteView(target: $0) }
        .onChange(of: account.signedIn) { _, _ in Task { await game.load() } }
        // The position to the metre while a walk is on and on screen.
        .onAppear { if game.started && !game.finished { location.precise(true) } }
        .onDisappear { if game.started && !game.finished { location.precise(false) } }
        .onChange(of: game.started && !game.finished) { _, on in location.precise(on) }
    }

    @ViewBuilder
    private func actions(for on: String?) -> some View {
        let live = game.ready && !game.doors.isEmpty
        if live, let on, on.isEmpty ? game.finished : game.check(on) != nil {
            TextField(words.t(on.isEmpty ? "walkRouteNoteHint" : "walkNoteHint",
                              on.isEmpty ? "Say something about the whole route, if you like" : "Add a comment, if you like"),
                      text: $note, axis: .vertical)
                .focused($typing)
                .lineLimit(1...4)
                .padding(10)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline))
                .onAppear {
                    note = on.isEmpty ? (game.answer?.walk?.note ?? "") : (game.check(on)?.note ?? "")
                }
                .onChange(of: note) { _, text in if text.count > 280 { note = String(text.prefix(280)) } }
            HStack(spacing: 8) {
                Button(words.t("walkNoteSave", "Save the comment")) {
                    Task { await game.saveNote(on, note, words: words) }
                }
                .buttonStyle(.prominent)
                .disabled(game.busy == .note)
                Button(words.t("walkNoteSkip", "Not now")) { game.skipNote() }
                    .buttonStyle(.bordered)
            }
        } else if !live || game.finished {
            if let onList {
                Button(words.t("walkView", "Route"), action: onList).buttonStyle(.bordered)
            }
        } else if !game.signedIn {
            Button(words.t("walkSignIn", "Sign in to start")) { signingIn = true }
                .buttonStyle(.prominent)
        } else if !game.started {
            Button(words.t("walkStart", "Start")) { Task { await game.start(words: words) } }
                .buttonStyle(.prominent)
                .disabled(game.busy == .start)
        } else {
            let near = game.nearest(to: location.location)
            let at = near.map { $0.metres <= game.radius } ?? false
            if let near, game.message == nil {
                Text(words.t(at ? "walkAt" : "walkNearest", at ? "You are at {place}" : "Nearest: {place}", ["place": near.item.name]))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(at ? words.t("walkAtDoor", "{distance} from the door", ["distance": words.distance(near.metres)])
                        : words.t("walkAway", "{distance} away · check-in opens within {radius} m",
                                  ["distance": words.distance(near.metres), "radius": "\(Int(game.radius))"]))
                    .font(.caption).foregroundStyle(at ? RouteView.Mode.foot.color : Theme.muted)
            } else if location.status == .denied || location.status == .restricted {
                Text(words.t("walkNoLocation", "A check needs your location. Allow it in the browser and press again."))
                    .font(.caption).foregroundStyle(Theme.accent)
            }
            Button {
                location.start()
                Task { await game.checkIn(at: location.location, words: words) }
            } label: {
                Text(game.busy == .check ? words.t("walkFinding", "Finding you…")
                     : near.map { words.t("walkCheckAt", "Check in at {place}", ["place": $0.item.name]) } ?? words.t("walkCheck", "Check in here"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.prominent)
            .opacity(near != nil && !at ? 0.55 : 1)
            .disabled(game.busy == .check)
            if let onList {
                HStack(spacing: 8) {
                    if let next = near?.item ?? game.next, let point = next.coordinate {
                        Button {
                            way = RouteTarget(id: next.place, name: next.name, coordinate: point)
                        } label: {
                            Text(words.t("directions", "Directions")).frame(maxWidth: .infinity)
                        }
                    }
                    Button(action: onList) {
                        Text(words.t("walkView", "Route")).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

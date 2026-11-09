import SwiftUI

/// A new list: its name, and a line under it if you want one. Making it lands
/// you on it, empty, ready for places — the way the website does it.
struct NewListView: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss

    /// A place to put on the list as soon as it exists — "New list with Badam".
    var firstPlace: String?
    let made: (String) -> Void

    @State private var title = ""
    @State private var intro = ""
    @State private var working = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(content.t("appListName", "Name it — “Top ten burgers”"), text: $title)
                    TextField(content.t("appListIntro", "A line under the title (optional)"), text: $intro, axis: .vertical)
                } footer: {
                    if let problem { Text(problem).foregroundStyle(Theme.accent) }
                }
            }
            .paperBackground()
            .navigationTitle(content.t("appNewList", "New list"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(content.t("close", "Close")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(content.t("appMake", "Make it")) { Task { await go() } }
                        .disabled(working || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func go() async {
        working = true
        defer { working = false }
        do {
            let id = try await account.createList(title: title, intro: intro)
            if let firstPlace { try? await account.addPlace(firstPlace, to: id) }
            dismiss()
            made(id)
        } catch {
            problem = content.say(error)
        }
    }
}

/// Editing your own list: the name, the line under it, the pin, who can open
/// it, and each place's note and dish, dragged into order.
///
/// It works the way the website's editor does, for the same reasons. Adding
/// and removing a place are sent the moment they happen, because the server
/// is the one that decides whether a place may go on. Everything else is held
/// until Save and sent once, each field as its own write, so a keystroke in
/// one box never carries another box's value along with it.
struct ListEditor: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss

    let original: ListDetail
    let done: () -> Void

    @State private var title: String
    @State private var intro: String
    @State private var pin: String
    @State private var isPublic: Bool
    @State private var items: [Draft]
    @State private var picking = false
    @State private var working = false
    @State private var problem: String?
    @State private var confirmDelete = false
    /// Whether the list was public when the editor opened.
    @State private var startedPublic: Bool
    /// Places put on while the editor is open, in the order they went on —
    /// which is the order the server appended them in.
    @State private var addedOrder: [String] = []

    struct Draft: Identifiable, Equatable {
        let place: String
        let name: String
        let onMap: Bool
        var say: String
        var mustOrder: String
        var id: String { place }
    }

    init(list: ListDetail, isPublic: Bool, done: @escaping () -> Void) {
        original = list
        self.done = done
        _title = State(initialValue: list.title)
        _intro = State(initialValue: list.intro)
        _pin = State(initialValue: list.pin ?? "pin")
        _isPublic = State(initialValue: isPublic)
        _startedPublic = State(initialValue: isPublic)
        _items = State(initialValue: list.items.map {
            Draft(place: $0.place, name: $0.name, onMap: $0.map, say: $0.say, mustOrder: $0.mustOrder)
        })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(content.t("appListName", "Name it — “Top ten burgers”"), text: $title)
                        .font(.headline)
                    TextField(content.t("appListIntro", "A line under the title (optional)"), text: $intro, axis: .vertical)
                }
                Section {
                    PinPicker(selected: $pin)
                } header: {
                    Text(content.t("appPin", "Pin"))
                }
                Section {
                    Picker(content.t("appWhoCanOpen", "Who can open it"), selection: $isPublic) {
                        Text(content.t("appShared", "Anyone with the link")).tag(true)
                        Text(content.t("appPrivate", "Only you")).tag(false)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text(content.t("appWhoCanOpen", "Who can open it"))
                }

                Section {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\((items.firstIndex(of: item) ?? 0) + 1)")
                                    .font(.headline).foregroundStyle(Theme.accent)
                                Text(item.name).font(.headline)
                                if !item.onMap {
                                    Text(content.t("appNotOnMapShort", "Not on the map")).font(.caption).foregroundStyle(Theme.muted)
                                }
                            }
                            TextField(content.t("appSayWhy", "What is good about it?"), text: $item.say, axis: .vertical)
                                .font(.subheadline)
                            TextField(content.t("appWhatToOrder", "What to order (optional)"), text: $item.mustOrder)
                                .font(.footnote)
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { from, to in items.move(fromOffsets: from, toOffset: to) }
                    .onDelete { offsets in
                        let gone = offsets.map { items[$0] }
                        items.remove(atOffsets: offsets)
                        Task {
                            for item in gone {
                                do { try await account.drop(item.place, from: original.id) } catch { problem = content.say(error) }
                            }
                        }
                    }
                    if items.count < 50 {
                        Button {
                            picking = true
                        } label: {
                            Label(items.isEmpty ? content.t("appAddFirst", "Add the first place") : content.t("appAddAnother", "Add another place"),
                                  systemImage: "plus.circle.fill")
                        }
                    }
                } header: {
                    Text(content.t("appPlacesN", "{n} places", ["n": "\(items.count)"]))
                } footer: {
                    Text(content.t("appEditHint", "Hold a place to drag it into order. Swipe left to take it off."))
                }

                Section {
                    Button(content.t("appDeleteList", "Delete this list"), role: .destructive) { confirmDelete = true }
                }
            }
            .environment(\.editMode, .constant(.active))
            .paperBackground()
            .navigationTitle(content.t("appEditList", "Edit list"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    if let problem { Text(problem).font(.footnote).foregroundStyle(Theme.accent) }
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if working { ProgressView().tint(.white) }
                            Text(changed ? content.t("listsSave", "Save") : content.t("listsSaveDone", "Saved")).fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!changed || working)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.paper)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(content.t("close", "Close")) { done(); dismiss() }
                }
            }
            .sheet(isPresented: $picking) {
                PlacePicker(listID: original.id, already: Set(items.map(\.place))) { hit in
                    items.append(Draft(place: hit.id, name: hit.name, onMap: hit.map, say: "", mustOrder: ""))
                    addedOrder.append(hit.id)
                }
            }
            .confirmationDialog(content.t("appDeleteListAsk", "Delete “{title}”? There is no undo.", ["title": original.title]),
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(content.t("appDeleteList", "Delete this list"), role: .destructive) {
                    Task {
                        do {
                            try await account.deleteList(original.id)
                            done()
                            dismiss()
                        } catch {
                            problem = content.say(error)
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(changed)
    }

    // MARK: What changed, and sending it

    private var originalNotes: [String: (String, String)] {
        Dictionary(uniqueKeysWithValues: original.items.map { ($0.place, ($0.say, $0.mustOrder)) })
    }

    private var changed: Bool {
        title != original.title || intro != original.intro || pin != (original.pin ?? "pin")
            || isPublic != startedPublic || orderChanged
            || items.contains { item in
                guard let was = originalNotes[item.place] else { return !item.say.isEmpty || !item.mustOrder.isEmpty }
                return was.0 != item.say || was.1 != item.mustOrder
            }
    }

    /// The order the server holds now: what was there, less what was taken
    /// off, then what was put on. Anything else is a drag to send.
    private var serverOrder: [String] {
        let here = Set(items.map(\.place))
        return original.items.map(\.place).filter { here.contains($0) } + addedOrder.filter { here.contains($0) }
    }

    private var orderChanged: Bool { items.map(\.place) != serverOrder }

    private func save() async {
        working = true
        problem = nil
        defer { working = false }
        do {
            var edit: [String: Any] = ["action": "edit", "id": original.id]
            if title != original.title { edit["title"] = title }
            if intro != original.intro { edit["intro"] = intro }
            if pin != (original.pin ?? "pin") { edit["pin"] = pin }
            if isPublic != startedPublic { edit["public"] = isPublic }
            if edit.count > 2 { try await API.post("api/lists", edit) }

            let notes = originalNotes
            for item in items {
                let was = notes[item.place] ?? ("", "")
                if was.0 != item.say {
                    try await API.post("api/lists", ["action": "say", "id": original.id, "place": item.place, "say": item.say])
                }
                if was.1 != item.mustOrder {
                    try await API.post("api/lists", ["action": "mustOrder", "id": original.id, "place": item.place, "mustOrder": item.mustOrder])
                }
            }
            if orderChanged {
                try await API.post("api/lists", ["action": "order", "id": original.id, "places": items.map(\.place)])
            }
            await account.refreshLists()
            done()
            dismiss()
        } catch {
            problem = content.say(error)
        }
    }
}

/// The forty markers a list can wear, the website's grid.
struct PinPicker: View {
    @Binding var selected: String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
            ForEach(Pins.order, id: \.self) { name in
                Button {
                    selected = name
                } label: {
                    Text(Pins.of(name))
                        .font(.system(size: 22))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9)
                            .stroke(selected == name ? Theme.accent : Theme.hairline, lineWidth: selected == name ? 2 : 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Searching every place in Tallinn — the map's and Google's — to put one on
/// a list. A place goes on the moment it is pressed, and the server says
/// whether it may.
struct PlacePicker: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss

    let listID: String
    let already: Set<String>
    let added: (CatalogueHit) -> Void

    @State private var query = ""
    @State private var hits: [CatalogueHit] = []
    @State private var done: Set<String> = []
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            List {
                if let problem {
                    Text(problem).foregroundStyle(Theme.accent).listRowBackground(Theme.paper)
                }
                if hits.isEmpty {
                    Text(query.count < 2 ? content.t("listsSearchPlaces", "Search every place in Tallinn")
                                         : content.t("searchNone", "Nothing matches “{q}”.", ["q": query]))
                        .foregroundStyle(Theme.muted)
                        .listRowBackground(Theme.paper)
                }
                ForEach(hits) { hit in
                    let on = already.contains(hit.id) || done.contains(hit.id)
                    Button {
                        guard !on else { return }
                        Task { await add(hit) }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hit.name).font(.headline).foregroundStyle(Theme.ink)
                                Text([hit.address, hit.map ? content.t("appOnMap", "on the map") : "Google"]
                                        .filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.footnote).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(on ? Theme.muted : Theme.accent)
                        }
                    }
                    .listRowBackground(Theme.paper)
                }
            }
            .listStyle(.plain)
            .paperBackground()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: content.t("listsSearchPlaces", "Search every place in Tallinn"))
            .navigationTitle(content.t("appAddPlaces", "Add places"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(content.t("appDone", "Done")) { dismiss() } }
            }
            .task(id: query) {
                let q = query.trimmingCharacters(in: .whitespaces)
                guard q.count >= 2 else { hits = []; return }
                try? await Task.sleep(for: .milliseconds(300))
                if Task.isCancelled { return }
                if let found = try? await API.get([CatalogueHit].self, "api/places", ["q": q]) { hits = found }
            }
        }
    }

    private func add(_ hit: CatalogueHit) async {
        problem = nil
        do {
            try await account.addPlace(hit.id, to: listID)
            done.insert(hit.id)
            added(hit)
        } catch {
            problem = content.say(error)
        }
    }
}

/// From a place's page: which of your lists to put it on, or a new one.
struct AddToListSheet: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss

    let place: Place
    @State private var done: Set<String> = []
    @State private var problem: String?
    @State private var making = false

    var body: some View {
        NavigationStack {
            List {
                if let problem { Text(problem).foregroundStyle(Theme.accent) }
                ForEach(account.mine) { list in
                    Button {
                        guard !done.contains(list.id) else { return }
                        Task {
                            do {
                                try await account.addPlace(place.id, to: list.id)
                                done.insert(list.id)
                            } catch {
                                problem = content.say(error)
                            }
                        }
                    } label: {
                        HStack {
                            Text(Pins.of(list.pin))
                            VStack(alignment: .leading) {
                                Text(list.title).foregroundStyle(Theme.ink)
                                if let n = list.n {
                                    Text(content.t("appPlacesN", "{n} places", ["n": "\(n)"])).font(.caption).foregroundStyle(Theme.muted)
                                }
                            }
                            Spacer()
                            Image(systemName: done.contains(list.id) ? "checkmark.circle.fill" : "plus.circle")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                Button {
                    making = true
                } label: {
                    Label(content.t("appNewListWith", "New list with {name}", ["name": place.name]), systemImage: "plus")
                }
            }
            .paperBackground()
            .navigationTitle(content.t("appAddTo", "Add {name} to a list", ["name": place.name]))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(content.t("appDone", "Done")) { dismiss() } }
            }
            .sheet(isPresented: $making) {
                NewListView(firstPlace: place.id) { _ in dismiss() }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

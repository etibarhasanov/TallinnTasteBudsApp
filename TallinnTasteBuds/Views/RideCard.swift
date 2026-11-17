import SwiftUI

/// The card that stands where the route's bar was while a ride is recorded:
/// what recording is and Start, then the distance, time and average as they
/// grow with Pause and Finish, then Save with an optional name — or, under
/// the shortest ride worth keeping, Keep riding. The website's ride card
/// (`assets/ride.js`), in its words.
struct RideCard: View {
    @Environment(ContentStore.self) private var content
    @Environment(LocationProvider.self) private var location
    @Environment(AccountStore.self) private var account
    let ride: RideRecorder
    @State private var name = ""
    @State private var signingIn = false
    @State private var now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch ride.stage {
            case .ready:
                top(content.t("routeModeBike", "Bike"))
                title(content.t("rideTitle", "Record a ride"))
                why(content.t("rideWhy", "Your phone draws the way you really cycle, and a saved ride becomes a confirmed bike route. Keep this page open and the screen on while you ride."))
                if location.status == .denied || location.status == .restricted {
                    bad(content.t("rideBlocked", "This site may not use your location, so nothing can be recorded. Allow location for it in your browser settings and try again."))
                } else if !account.signedIn {
                    why(content.t("rideSignedOut", "Sign in first, so the ride can be saved under your account."))
                    go(content.t("rideSignIn", "Sign in")) { signingIn = true }
                } else {
                    go(content.t("rideStart", "Start recording")) { ride.start(location) }
                }
                alt(content.t("rideNotNow", "Not now")) { ride.hide() }
            case .waiting, .recording, .paused:
                HStack(spacing: 6) {
                    Circle().fill(ride.stage == .paused ? Theme.muted : Theme.accent).frame(width: 8, height: 8)
                    top(content.t(ride.stage == .paused ? "ridePaused" : "rideRecording", ride.stage == .paused ? "Paused" : "Recording"))
                }
                stats
                why(ride.stage == .waiting ? content.t("rideWaiting", "Waiting for your location…")
                    : ride.stage == .paused ? content.t("ridePausedWhy", "Nothing is recorded while paused. Locking the phone or leaving the page pauses it too.")
                    : content.t("rideScreen", "The screen stays on while this is open. Locking the phone pauses the recording."))
                if ride.stage == .paused {
                    go(content.t("rideResume", "Resume")) { ride.start(location) }
                    alt(content.t("rideFinish", "Finish")) { ride.finish(location) }
                } else {
                    go(content.t("rideFinish", "Finish")) { ride.finish(location) }
                    alt(content.t("ridePause", "Pause")) { ride.pause(location) }
                }
            case .short:
                top(summary)
                title(content.t("rideShortTitle", "Too short to keep"))
                why(content.t("rideShortWhy", "A ride has to be longer than {dist} to be kept.", ["dist": kilometres(RideRecorder.minMetres)]))
                go(content.t("rideKeepGoing", "Keep riding")) { ride.start(location) }
                alt(content.t("rideThrow", "Throw it away"), danger: true) { ride.throwAway(location) }
            case .finished, .saving:
                top(summary)
                title(content.t("rideSaveTitle", "Save this ride?"))
                why(content.t("rideSaveWhy", "A saved ride becomes a confirmed bike route, drawn faintly under the Bike tab's way. Your name is not shown, and the first and last 200 m are left off."))
                if let problem = ride.problem { bad(said(problem)) }
                TextField(content.t("rideName", "Name (optional)"), text: $name)
                    .padding(10)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline))
                    .onChange(of: name) { _, text in
                        if text.count > RideRecorder.maxName { name = String(text.prefix(RideRecorder.maxName)) }
                    }
                if ride.problem == "signed-out" {
                    go(content.t("rideSignIn", "Sign in")) { signingIn = true }
                } else if ride.problem != "fast" {
                    go(content.t(ride.stage == .saving ? "rideSaving" : "rideSave", ride.stage == .saving ? "Saving…" : "Save ride")) {
                        Task { await ride.save(name: name, summary: summary) }
                    }
                    .disabled(ride.stage == .saving)
                }
                alt(content.t("rideThrow", "Throw it away"), danger: true) { ride.throwAway(location) }
            case .saved:
                top(ride.saved ?? "")
                title(content.t("rideSaved", "Saved"))
                why(content.t("rideSavedWhy", "It is a confirmed bike route now, and shows under the Bike tab's way wherever it runs. Thank you."))
                alt(content.t("close", "Close")) { ride.hide() }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 10, y: -2)
        .sheet(isPresented: $signingIn) {
            SignInView(reason: content.t("rideSignedOut", "Sign in first, so the ride can be saved under your account."))
        }
        .task(id: ride.recording) {
            // The time ticks by the second while recording.
            while ride.recording && !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: Pieces

    private var stats: some View {
        let seconds = Int(ride.seconds)
        let kmh = seconds > 0 ? ride.metres / Double(seconds) * 3.6 : 0
        return HStack(spacing: 0) {
            stat(kilometres(ride.metres), content.t("rideDistance", "distance"))
            stat(clock(seconds), content.t("rideTime", "time"))
            stat(content.t("rideKmh", "{n} km/h", ["n": "\(Int(kmh.rounded()))"]), content.t("rideAverage", "average"))
        }
        .id(now)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(Theme.ink)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summary: String {
        content.t("rideSummary", "Ride · {dist} · {min} min",
                  ["dist": kilometres(ride.metres), "min": "\(max(1, Int((ride.seconds / 60).rounded())))"])
    }

    private func kilometres(_ m: Double) -> String { WalkWords(content: content).distance(m) }

    private func clock(_ s: Int) -> String {
        let h = s / 3600, m = s / 60 % 60, ss = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, ss) : String(format: "%d:%02d", m, ss)
    }

    private func said(_ problem: String) -> String {
        switch problem {
        case "signed-out": return content.t("rideSignedOut", "Sign in first, so the ride can be saved under your account.")
        case "often": return content.t("rideOften", "That is twenty rides today, the most one account can save in a day. The ride is kept on this phone for tomorrow.")
        case "fast": return content.t("rideFast", "That was faster than a bike rides, so it cannot be kept.")
        case "short": return content.t("rideShortWhy", "A ride has to be longer than {dist} to be kept.", ["dist": kilometres(RideRecorder.minMetres)])
        default: return content.t("rideFailed", "It did not save. The ride is kept on this phone — try again.")
        }
    }

    private func top(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.title3.bold()).foregroundStyle(Theme.ink)
    }

    private func why(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
    }

    private func bad(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent).fixedSize(horizontal: false, vertical: true)
    }

    private func go(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).frame(maxWidth: .infinity) }
            .buttonStyle(.prominent)
    }

    private func alt(_ label: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(role: danger ? .destructive : nil, action: action) { Text(label).frame(maxWidth: .infinity) }
            .buttonStyle(.bordered)
    }
}

import SwiftUI
import CoreImage.CIFilterBuiltins

/// The offer on a place's page: what it is, what it takes, and the button.
/// Everybody reads the offer; the pass behind the button is for members.
struct DealBlock: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    let deal: Deal
    @State private var showing = false
    @State private var signingIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SectionLabel(text: content.t("passTitle", "Discount"))
                if let badge = deal.badge(content.lang) { DealPill(text: badge) }
            }
            Text(deal.offerText(content.lang)).font(.headline).foregroundStyle(Theme.ink)
            if let note {
                Text(note).font(.footnote).foregroundStyle(Theme.muted)
            }
            Button {
                if account.signedIn { showing = true } else { signingIn = true }
            } label: {
                Label(buttonTitle, systemImage: account.signedIn ? "qrcode" : "person.crop.circle")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(14)
        .background(Theme.wash, in: RoundedRectangle(cornerRadius: Theme.radius))
        .fullScreenCover(isPresented: $showing) { PassView(deal: deal) }
        .sheet(isPresented: $signingIn) {
            SignInView(reason: content.t(deal.rates == nil ? "passSignIn" : "passRollSignIn",
                                         "Sign in to show this at the till. The discount is for members."))
        }
    }

    private var buttonTitle: String {
        if account.signedIn { return content.t("passGet", "Show QR") }
        return deal.rates == nil ? content.t("dealSignIn", "Sign in to use it") : content.t("dealRollSignIn", "Sign in to draw")
    }

    /// The website's note under the offer: a drawn rate is explained to
    /// everybody, a fixed one only to somebody about to be asked to sign in.
    private var note: String? {
        if deal.rates != nil {
            return account.signedIn
                ? content.t("dealRollHint", "The rate is drawn when you open it and holds for the hour.")
                : content.t("dealRollMembers", "Sign in and a rate is drawn for you when you open it. It holds for the hour.")
        }
        return account.signedIn ? nil : content.t("dealMembers", "The discount is for members. Signing in takes a username and a password.")
    }
}

/// The pass a guest holds up at the till: a QR a waiter scans with their
/// ordinary camera, the same code in large type for reading by eye, and a
/// countdown that moves — a screenshot has frozen digits and a frozen dot,
/// so staff can tell a live pass from a picture of one.
///
/// It is the website's `deal.html`, drawn natively. The site is asked first
/// whether this session may have a pass (and, for a drawn rate, which rate it
/// drew this hour); only then is the code made, the same way the website makes
/// it, and the QR points at the website's own `verify.html`. If the site cannot
/// be asked, there is no code — a pass that appeared whenever that request
/// failed would be for whoever worked out how to make it fail.
struct PassView: View {
    @Environment(ContentStore.self) private var content
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    let deal: Deal

    enum Admission: Equatable {
        case asking
        case admitted(rate: Int?)
        case signIn
        case unavailable
    }

    @State private var admission: Admission = .asking
    @State private var hour = PassCode.hour()
    @State private var brightness: CGFloat?
    @State private var signingIn = false

    var body: some View {
        ZStack {
            Theme.accent.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Text(content.t("passHeading", "Show this at the till").uppercased())
                        .font(.footnote.weight(.semibold)).tracking(1.2).opacity(0.85)
                    Text(deal.name).font(.largeTitle.bold()).multilineTextAlignment(.center)
                    stateView
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.2), in: Circle())
                    .foregroundStyle(.white)
            }
            .padding(16)
            .accessibilityLabel(content.t("close", "Close"))
        }
        .task { await admit() }
        .onAppear {
            // A QR on a dim screen is the one a camera will not focus on.
            brightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            if let brightness { UIScreen.main.brightness = brightness }
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $signingIn, onDismiss: { Task { await admit() } }) {
            SignInView(reason: content.t("passSignIn", "Sign in to show this at the till. The discount is for members."))
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch deal.window {
        case .notYet:
            message(content.t("verifyNotYetNote", "This discount has not started yet."))
        case .ended:
            message(content.t("verifyEndedNote", "This discount has ended."))
        case .open:
            switch admission {
            case .asking:
                ProgressView().tint(.white).padding(40)
            case .signIn:
                message(content.t(deal.rates == nil ? "passSignIn" : "passRollSignIn",
                                  "Sign in to show this at the till. The discount is for members."))
                Button { signingIn = true } label: {
                    Text(content.t("accountSignIn", "Sign in")).fontWeight(.semibold)
                        .frame(maxWidth: 260).padding(.vertical, 12)
                        .background(.white, in: Capsule()).foregroundStyle(Theme.accent)
                }
            case .unavailable:
                message(content.t("passUnavailable", "The draw is not available right now. Try again in a moment."))
                Button(content.t("appRetry", "Try again")) { Task { await admit() } }
                    .fontWeight(.semibold)
            case .admitted(let rate):
                pass(rate: rate)
            }
        }
    }

    private func message(_ text: String) -> some View {
        Text(text).font(.body).multilineTextAlignment(.center).padding(.vertical, 24)
    }

    private func pass(rate: Int?) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date
            let current = PassCode.hour(at: now)
            let code = PassCode.code(key: deal.key, place: deal.id, hour: current, rate: rate)
            let url = PassCode.verifyURL(base: API.base, place: deal.id, hour: current, code: code, rate: rate)
            VStack(spacing: 16) {
                Text(deal.offerText(content.lang, rate: rate))
                    .font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                QRCode(text: url.absoluteString)
                    .frame(width: 236, height: 236)
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityLabel(content.t("passScanMe", "Ask a member of staff to scan this."))
                Text(code)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .tracking(6)
                Countdown(now: now, hour: current, rolled: rate != nil)
                Text(content.t("passScanMe", "Ask a member of staff to scan this."))
                    .font(.footnote).opacity(0.85)
                if let terms = deal.termsText(content.lang) {
                    VStack(spacing: 4) {
                        Text(content.t("passTerms", "Terms").uppercased()).font(.caption.weight(.semibold)).tracking(1).opacity(0.75)
                        Text(terms).font(.footnote).multilineTextAlignment(.center)
                    }
                    .padding(.top, 4)
                }
                if !deal.live {
                    Text(content.t("passNotLive", "Preview — this discount is not published yet."))
                        .font(.footnote.weight(.semibold))
                        .padding(8).background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .onChange(of: current) { _, next in
                // A drawn rate is drawn again when the hour turns.
                hour = next
                if deal.rates != nil { Task { await admit() } }
            }
        }
    }

    /// Ask the site whether this session may have a pass, and which rate it drew.
    private func admit() async {
        #if DEBUG
        if LaunchScript.passPreview {
            admission = .admitted(rate: deal.rates.map { $0[$0.count / 2] })
            return
        }
        #endif
        if case .admitted = admission {} else { admission = .asking }
        do {
            let data = try await API.data("api/pass", ["r": deal.id])
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            if let run = deal.rates, !run.isEmpty {
                guard let draw = object["draw"] as? Int else { admission = .unavailable; return }
                admission = .admitted(rate: run[draw % run.count])
            } else {
                admission = .admitted(rate: nil)
            }
        } catch API.Failure.status(401) {
            admission = .signIn
        } catch {
            admission = .unavailable
        }
    }
}

/// "Good until 15:00" and the minutes and seconds to it, with a dot that
/// beats once a second beside them.
private struct Countdown: View {
    @Environment(ContentStore.self) private var content
    let now: Date
    let hour: Int
    let rolled: Bool

    var body: some View {
        let end = PassCode.end(of: hour)
        let left = max(0, Int(end.timeIntervalSince(now)))
        let beat = Int(now.timeIntervalSince1970) % 2 == 0
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Circle().fill(.white).frame(width: 12, height: 12)
                    .opacity(beat ? 1 : 0.25)
                    .animation(.easeInOut(duration: 0.5), value: beat)
                Text(String(format: "%02d:%02d", left / 60, left % 60))
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
            }
            Text(content.t(rolled ? "passRollUntil" : "passUntil", "Good until {time}",
                           ["time": end.formatted(date: .omitted, time: .shortened)]))
                .font(.subheadline).opacity(0.9)
        }
    }
}

/// A QR code, drawn sharp at any size.
struct QRCode: View {
    let text: String

    var body: some View {
        if let image = Self.make(text) {
            Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
        } else {
            Color.white
        }
    }

    private static let context = CIContext()

    private static func make(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Every discount switched on: the map's places and the ones off it.
struct DiscountsView: View {
    @Environment(ContentStore.self) private var content
    @State private var passFor: Deal?

    var body: some View {
        List(content.liveDeals) { deal in
            Group {
                if content.place(deal.id) != nil {
                    NavigationLink(value: Route.place(deal.id)) { row(deal) }
                } else {
                    Button { passFor = deal } label: { row(deal) }
                }
            }
            .listRowBackground(Theme.paper)
        }
        .listStyle(.plain)
        .paperBackground()
        .navigationTitle(content.t("appDiscounts", "Discounts"))
        .sheet(item: $passFor) { deal in
            NavigationStack {
                ScrollView { DealBlock(deal: deal).padding(16) }
                    .paperBackground()
                    .navigationTitle(deal.name)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
    }

    private func row(_ deal: Deal) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(deal.name).font(.headline).foregroundStyle(Theme.ink)
                Text(deal.offerText(content.lang)).font(.subheadline).foregroundStyle(Theme.muted)
                if content.place(deal.id) == nil {
                    Text(content.t("appNotOnMapShort", "Not on the map")).font(.caption).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            if let badge = deal.badge(content.lang) { DealPill(text: badge) }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

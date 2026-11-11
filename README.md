# Tallinn Tastebuds — iOS app

The iPhone and iPad app for [Tallinn Tastebuds](https://tallinntastebuds.ee).
SwiftUI, iOS 17 and later, Apple's own map, no third-party dependencies.

The app has no server of its own. It reads the same files and calls the same
Functions the website does, so anything published on the website — a place,
a translation, a list somebody made — is in the app the moment the site
deploys, with nothing submitted to Apple.

---

## What it does

Four tabs.

- **Map.** Every place on the map as the site's own mark on Apple's map, with
  the site's search box and filter chips over it. Pressing a pin raises a card
  (Open, Directions, Save); **Places** at the bottom opens the same places as
  a list, nearest first. The search box searches all of Tallinn, the way a
  maps app does: suggestions drop under it as you type — the map's own
  places, then everywhere in the city, which the website answers from
  `/api/places?q=`, the same search its own pages use. The site's answer is
  drawn on the map as soon as it arrives, the city's as plain dots beside
  the mark, so a word finds the whole city whether or not Search is pressed.
  Pressing a suggestion goes to that place; the keyboard's Search frames
  every result at once, and **Search this area** asks again once the map is
  moved. Offline, the places the app carries still answer.
- **Lists.** Everybody's lists, the most opened first, searchable by list,
  author or place — `/lists` on the website. A list opens as a numbered page
  with what its author wrote about each place and what to order, or as pins on
  a map wearing the list's own marker. The author's name opens their profile.
  A place a list names that is not on the map — one of Google's — opens with
  what the author and Google say about it, and is labelled as not on the map.
  Signed in, your own lists and the ones you saved sit above everybody's,
  with **New list** first.
- **Saved.** The places this phone saved, newest first.
- **Me.** Signing in or making an account, your profile, signing out and
  deleting the account; the language; the colour — the website's four
  styles, Red, Green, Blue and Plum; the way out to the website, Instagram and
  the privacy page.

### Discounts

A place with a discount switched on in the website's `data/deals.json` wears
the offer as a pill beside its name (**−15%**, taken from the offer line the
way the website takes it), the map grows a **Discount** chip first after
**All**, and the place's page carries the offer above **Must order** with its
button. Me lists every discount, including the ones at places that are not
on the map.

The offer is for everybody to read; the pass is for members, as on the
website. **Show QR** opens the pass full-screen in the accent colour, with the
screen turned up to full brightness and kept awake: the QR, the same five
letters in large type, and a countdown to the end of the hour with a dot
beating beside it, so staff can tell a live pass from a screenshot.

It is the website's `deal.html` drawn natively, and it makes the same code:

1. `GET /api/pass?r=<place>` with the session. `401` is the sign-in card; a
   failure is "not available right now", never a code. A deal with a `roll`
   gets its `draw` back, and the rate is the run counted up at that number.
2. `HMAC-SHA256(key, "<place>:<hour>[:<rate>]")`, the first four bytes read
   five letters at a time in the alphabet without I, L, O and U —
   `Core/PassCode.swift`.
3. The QR is `https://tallinntastebuds.ee/verify.html?r=…&h=…&c=…[&p=…]`, so
   a waiter's ordinary camera opens the website's own verify page, which
   fills green. The staff page works unchanged as the fallback.

CI compiles `PassCode.swift` on its own beside `Tools/PassCodeCheck.swift` and
holds it to codes made by the website's algorithm, because a code one letter
off is a guest turned away at the till. When the hour turns the pass makes the
next code in front of the guest, and a drawn rate is drawn again.

### Accounts and your own lists

An account is the website's account: a username and a password, checked by
`/api/account`, with the session the site hands back as its HttpOnly cookie.
`URLSession`'s shared cookie store keeps it across launches the way a browser
does, and anything done in the app is on the website at once and the other way
round.

**Continue with Google** and **Continue with Apple** end in that same cookie.
`Core/SocialSignIn.swift` says how each gets there:

- **Google** is the website's own round trip, opened in the system's sign-in
  sheet (`ASWebAuthenticationSession`) because Google will not sign anybody in
  inside a web view. The app starts it at `/api/google?app=<challenge>`; the
  site ends it at `tallinntastebuds://signin?ticket=…` rather than with a
  cookie, which would have been the sheet's and not the app's; and
  `POST /api/account` with `action: ticket` and the verifier the challenge was
  made from swaps the ticket for the session.
- **Apple** is the system's sheet, which hands back a token Apple signed for
  this app. `POST /api/apple` checks it against Apple's keys and answers as a
  sign-in does. Nothing is asked for but who this is: no name, no email.

Both need the website to have those two doors, so the buttons are drawn only
where `GET /api/account` answers `appGoogle` and `appApple`; against a site
without them the sheet is the two fields it always was. Sign in with Apple
also needs its capability on the App ID, which a paid developer team has and
a free personal one cannot: `Config/TallinnTasteBuds.entitlements` is signed
into the Release build only, so a Debug build still installs from Xcode with
an ordinary Apple ID — and on such a build the Apple button answers that the
sign-in did not finish.

Signed in, you can make a list, name it, give it a line, pick its pin from the
same forty, make it private, put places on it from every place in Tallinn (the
map's and Google's), say what is good about each and what to order, drag them
into order, take them off, and delete it — from the list's **Edit**, or from
any place page's add-to-list button. It works the way the website's editor
does: putting a place on and taking one off are sent at once, because the
server decides whether a place may go on; everything else waits for **Save**
and goes as one write per field. The heart on somebody else's list saves it to
your account; signed out, it asks you to sign in.

Signing in also folds the places the account saved on the website into
**Saved**. Saves made in the app stay on the phone for now — see below.

**The round button at the bottom right of every map** is where you are: one
press centres the map on the blue dot, a second turns the map with the phone so
the dot's beam points the way you are facing, a third lets go. MapKit's own
button is not used: it sits in the top corner, under the search field.

**On a list, pressing a place goes to the list's map, on that place**, with its
card at the bottom; the card opens the place. A list is read to decide where to
go, and where it is is the next question. A place with no point to put on a map
opens its page directly.

### Directions

**Directions** opens the way there on our own map, as the website does it: the
website's `/api/route`, with **Walk · Bus · Car** at the foot. Walking and
driving are the OpenStreetMap routing service; the bus is peatus.ee, the
national journey planner with every operator's timetable in Tallinn. A bus
journey is drawn with its walks dotted in the dot's blue and each ride solid in
its line's own colour, and the bar says which line, when and from which stop
("T4 at 13:33 from Hobujaama · 16 min in all"), with the other departures under
it to press. The mode pressed last is remembered. Apple Maps is a small link at
the foot, in the same mode, for turn-by-turn; nothing leaves for Google.

Every place page has the photos, the write-up in the reader's language, the
kinds of place, what to order, walking directions in Apple Maps, the website,
the phone and the reel, and a share link that opens the same place on the site.

### What is not in it yet

In the order they are planned:

1. **Saves that follow the account.** Saving a place from the app to the
   account needs a way past the Turnstile check `/api/saves` asks a browser
   for, which an app cannot show. That is server work on the website.
2. **Ask**, the chat. Stories are not planned for the app.
3. **App Store screenshots, the listing copy and the privacy page**, then
   submission. `docs/PRIVACY.md` says what the app does with what it knows
   and carries the English of the section about the app on the website's
   privacy page;
   `docs/APP-STORE.md` has the answers to Apple's privacy questions.

Splitwise, the flashcards, chess, the blog and the owner's pages stay on the
website.

---

## Where everything comes from

| What | From |
| --- | --- |
| The places | `data/map.json` |
| Their write-ups and the interface text, per language | `data/lang/<code>.json` |
| Which languages exist | `data/lang/index.json` |
| The kinds of place and the chip row | `data/taxonomy.json` |
| Photos | `/photos/<id>/<file>` |
| Everybody's lists, a page at a time | `GET /api/lists?all=1[&q=…][&from=…]` |
| One list, whole | `GET /api/lists?id=<id>` |
| A profile | `GET /api/profile?name=<name>` |
| Who is signed in, and the account's saves | `GET /api/account` |
| Sign in, make an account, sign out, delete it | `POST /api/account` with `action` |
| Sign in through Google | `GET /api/google?app=<challenge>`, then `POST /api/account` with `action: ticket` |
| Sign in through Apple | `POST /api/apple` |
| Your lists and the ones you saved | `GET /api/lists` (signed in) |
| Make, edit, fill, order, save or delete a list | `POST /api/lists` with `action` |
| Every place in Tallinn, to put one on a list | `GET /api/places?q=` |
| A place that search does not have — a museum, a shop — looked up on Google Maps and kept on the site | `GET /api/lookup`, `POST /api/lookup` |
| The discounts | `data/deals.json` |
| Whether this session may show a pass, and its drawn rate | `GET /api/pass?r=<place>` |
| The way there on foot, by bus or by car | `GET /api/route?from=…&to=…&mode=foot\|bus\|car` |

**Strings.** The app asks the site's `ui.json` for every string by key, so it is
in the site's eleven languages wherever the site already says the thing. The
few strings only the app needs — the tab names, the list editor's hints; their
keys start with `app` — carry their English in the code and their other ten
languages in `Seed/app-strings.json`. The site is asked first, so a key that
is later added to `ui.json` on the website is read from there with no release.
`Tools/validate-seed.mjs` fails the build if a key the app borrows from the
site is renamed there, or if an `app` string is missing in any language.

**Three layers, so it always draws something.** The files above are read from
the network on launch and every time the app comes back to the foreground,
kept on disk in Application Support, and bundled as a snapshot under
`TallinnTasteBuds/Seed/` for a first launch with no signal.
`Tools/refresh-seed.sh` pulls a fresh snapshot and a weekly workflow does it by
itself. Lists and profiles are read live and not cached, the same choice the
website makes: they change while their authors are writing them.

### What still needs an App Store release

A change to the app rather than the content: a new screen, a new layout, a
new kind of field the app has to be taught to draw. New values in the fields it
already reads never do.

---

## Building it

Never opened Xcode? [docs/RUN-ON-YOUR-PHONE.md](docs/RUN-ON-YOUR-PHONE.md)
walks through running it in the simulator and on your own iPhone.

Requires Xcode 16 or later.

```sh
git clone https://github.com/etibarhasanov/TallinnTasteBudsApp
cd TallinnTasteBudsApp
open TallinnTasteBuds.xcodeproj
```

Pick a simulator and press Run. Nothing to install, no keys. The project uses
a synchronised folder, so a Swift file dropped anywhere under
`TallinnTasteBuds/` is compiled without touching the project file.

CI (`.github/workflows/ios.yml`) checks the snapshot and builds for the
simulator on every push to a `claude/**` branch, then launches the app in the
simulator on a dozen screens and photographs each one. The pictures are the
run's `screens` artifact and, shrunk, the `ci-screens` branch (one commit,
overwritten every run), which is how a session with no Mac looks at what it
built. `App/LaunchScript.swift` reads the launch arguments that choose the
screen; a reader never launches the app with any. Nothing in that pass signs
in: an account made to be photographed would be a real account on the live
site.

---

## Layout

```
TallinnTasteBuds/
  App/TallinnTasteBudsApp.swift   entry point, the four tabs, refresh on foreground
  Core/
    API.swift                     the site's address and every request to it
    Disk.swift                    the disk cache and the bundled snapshot
    ContentStore.swift            places, kinds, languages, strings, search
    PassCode.swift                the hourly discount code, the website's to the letter
    SavesStore.swift              the places this phone saved
    AccountStore.swift            who is signed in, their lists, every write to them
    SocialSignIn.swift            the Google round trip and Apple's sheet
    LocationProvider.swift        the blue dot and distances
  Models/
    Place.swift                   a place on the map; a kind of place
    Lists.swift                   lists, list items, profiles, list pins
    Deal.swift                    a discount: its offer, its run of rates, its dates
  Views/                          one file per screen, plus Theme and Routes
  Seed/                           the offline snapshot (refreshed weekly)
Tools/
  refresh-seed.sh                 pull a current snapshot from the site
  validate-seed.mjs               check it against what the decoders need
  PassCodeCheck.swift             hold PassCode.swift to the website's codes
```

`Theme.swift` carries the website's four styles to the value, and every
colour is read through the one in use, so choosing another under Me redraws
the app — the map and the system's own controls go dark with the two night
styles. `Routes.swift` is
the one list of screens any tab can open — a place, a list, a profile, a place
off the map — so a link from anywhere goes anywhere.

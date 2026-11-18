# Tallinn Tastebuds — iOS app

The iPhone and iPad app for [Tallinn Tastebuds](https://tallinntastebuds.ee).
SwiftUI, iOS 17 and later, Apple's own map, no third-party dependencies.

The app has no server of its own. It reads the same files and calls the same
Functions the website does, so anything published on the website — a place,
a translation, a list somebody made — is in the app the moment the site
deploys, with nothing submitted to Apple.

Every route it calls is asked at its versioned address, `/api/v1/…` —
`API.versioned()` in `TallinnTasteBuds/Core/API.swift` turns the `api/<route>`
the screens write into it, `api/places` into `api/v1/find` and `api/lists`
into `api/v1/me/lists`. The site only ever adds fields to v1; a change that
would break this build is `/api/v2`, and v1 keeps answering while this build
is still on phones. The routes are named by their old `/api/` addresses in the
comments below, which still answer the same.

---

## What it does

Four tabs, and Discover in front of the first.

- **Discover**, which is where the Map tab opens, the way the website's phone
  front page does: the map as one card with **Open map** on its corner, then
  New lists, Overlooked places (the five on the map opened least), **Play**
  (lists to go round, swiped one at a time), Popular lists and New on the
  map, and Feedback and Privacy at the foot — `GET /api/discover`, plus the
  `added` date the app already carries, so New on the map is there offline.
  The search field stays live above it; Open map or a word in the field puts
  it away, and the round button beside the locate button brings it back.
  A Play route opens its list on Route, your own walks still going first.
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
  moved. From five letters the suggestions end in **Look for it on Google
  Maps**, the website's `/api/lookup`, for the museum or the bookshop the
  site's city does not have yet; what Google answers goes on the map as
  results, first, with its card up. The die beside the locate button is
  Surprise me: a place at random out of whatever the field and the chips
  allow, never a closed one and never the same one twice; the filled bubble
  beside it is **Ask**, the chat. The ✕ in the box
  clears the word and puts the keyboard away with it. Offline, the places the
  app carries still answer.
- **Lists.** Everybody's lists, the most opened first, searchable by list,
  author or place — `/lists` on the website. A list opens as a numbered page
  with what its author wrote about each place and what to order, or as pins on
  a map wearing the list's own marker. The author's name opens their profile.
  A place a list names that is not on the map — one of Google's — opens with
  what the author and Google say about it, and is labelled as not on the map.
  Signed in, your own lists and the ones you saved sit above everybody's,
  with **New list** first.
  The six lists Google's numbers write are titled in the reader's language and
  signed Google Statistics, the way the website prints them.
- **Saved.** The places you saved, newest first — on the phone, and signed
  in on the account too.
- **Me.** Signing in or making an account, your profile, signing out and
  deleting the account; **Your page** — the name you go by, your line and
  your Instagram, TikTok and Facebook, the rest of the page on the website's
  editor — **Change password** and **Change username**, each the website's
  own `/api/account` action; the language; the colour — the website's four
  styles, Red, Green, Blue and Plum; the way out to the website, Instagram and
  the privacy page.

### Going round a list

Every list with two places to stand at has a third view, **Route**, beside
List and Map: the website's `assets/walk.js`, drawn natively
(`Core/WalkGame.swift`, `Views/WalkView.swift`). It shows the places in the
shortest order to go round them — the true shortest up to twelve, worked out
on the phone, nearest-next with crossed legs uncrossed past that, from the
list's first place or from where **Start from where I am** was pressed — as a
line down the page, each leg's distance and time and how far in the walk is
by then, with the whole of it on foot, by bike and by car on the card.
Distances are the straight line stretched by 1.3 and say "about", as on the
website.

Signed in, **Start** begins a walk (`POST /api/walk`, `start`). From then the
bar at the foot names the nearest place left and how far it is, and **Check
in at …** is greyed until inside the radius the site sends (75 m) but always
pressable, since a fix lags a person walking and the server decides: it
checks whichever unchecked place is nearest, or says how far the nearest one
is. After a check the bar offers one optional comment. **Shortest from here**
puts the places left in the shortest order from where you stand; **See it on
the map** draws the walk on the list's map — a dashed line, numbers, ticks on
the places checked, the next one filled — with the same bar, and Directions
to the nearest place left. Finishing puts you on the list's board, fastest
first, and asks how you went round (on foot, by bike, by car, mixed) and for
a comment on the whole of it. **Start again** asks first, because it throws
the walk away with its checks, comments and time on the board.

Not in the app yet: dragging the order by hand (the website's Change the
order), and opening a name on the board into how that person walked it.

### Recording a ride

The Bike tab of Directions carries **Record a ride** (`Core/RideRecorder.swift`,
`Views/RideCard.swift`), the website's `assets/ride.js`: the position to the
metre while the app is open, a point kept every 12 m from a fix good to 30 m,
a jump faster than 60 km/h dropped, and the ride drawn as it grows with its
distance, time and average. The screen is kept awake while recording, and
leaving the app pauses the ride outright rather than drawing a straight line
across what it did not see. **Finish** asks whether to save it under an
optional name to `/api/rides`, where the site takes 200 m off each end, keeps
it without ever showing whose it is, and draws it faintly under everybody's
Bike tab; under 700 m it offers Keep riding instead. The ride waits on the
phone until it is saved or thrown away. Signed out, the card asks to sign in
first. Under any bike way the map then draws the rides recorded near it, and
the bar says how much of the suggestion has been ridden before.

### Ask

**Ask** is the website's chat, a sheet over the map (`Views/AskView.swift`).
Somebody types what they feel like and `/api/ask` answers with up to three
places, each with a line about why: the map's own drawn from the app's copy of
it, so a place the model invented is never shown, and Google's labelled as not
on the map. Earlier exchanges go with each question, and the thread goes when
the sheet is closed. Before a question goes, `AskReader` reads it as the
website's `assets/ask.js` does — kinds of place from the taxonomy's labels in
every language, cheap, fancy, open, near and me from the site's `askWords*` —
so the Function can narrow the city to what it could be about; the position
goes with it only when the question asks for somewhere near. It runs on
Workers AI's free daily allowance, which the website shares; when that is
spent, the answer says it is resting until tomorrow.

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
same forty-five, make it private, put places on it from every place in Tallinn (the
map's and Google's), say what is good about each and what to order, drag them
into order, take them off, and delete it — from the list's **Edit**, or from
any place page's add-to-list button. It works the way the website's editor
does: putting a place on and taking one off are sent at once, because the
server decides whether a place may go on; everything else waits for **Save**
and goes as one write per field. The heart on somebody else's list saves it to
your account; signed out, it asks you to sign in.

Signing in also folds the places the account saved on the website into
**Saved**, and sends the account the ones this phone saved before; from
then every press of the heart goes to `/api/saves` under the session, so a
save is on every device the account signs in on.

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
website's `/api/route`, with **Walk · Bike · Bus · Car** at the foot. Walking,
cycling and driving are the OpenStreetMap routing service — its bike profile
keeps to cycle paths and walks a pedestrian street — and the bus is peatus.ee,
the national journey planner with every operator's timetable in Tallinn. Each
way wears the website's colour for it, green to red by how green it is to go
that way: a walk green, a bike a lighter green, a bus amber and a car red, on
the line and on the pressed tab alike. A bus journey is drawn with its walks
dotted in a walk's green and its rides solid in amber, and the bar says which
line, when and from which stop ("T4 at 13:33 from Hobujaama · 16 min in all"),
with the other departures under it to press. A walk, a ride or a drive follows
the dot: sixty metres from where it was asked from, it is asked for again, at
most every twenty seconds. Where the router finds more than one way for a
walk, a ride or a drive, up to three, the bar has a small button for each
("9 min · 2.1 km"): the one chosen is solid and its button wears the mode's
colour, the others are faint lines in the same colour, and pressing another
makes it the solid one without moving the map. The mode pressed last is
remembered. Apple Maps is a
small link at the foot, in the same mode (a bike opens on foot there), for
turn-by-turn; nothing leaves for Google.

Every place page has the photos, the write-up in the reader's language — the
words it links drawn in the accent, a name opening that person's profile and a
list opening the list — the kinds of place, what to order, the way there, the
website, the phone and the reel, and a share link that opens the same place on
the site.

### What is not in it yet

In the order they are planned:

1. **App Store screenshots, the listing copy and the privacy page**, then
   submission. `docs/PRIVACY.md` says what the app does with what it knows
   and carries the English of the section about the app on the website's
   privacy page;
   `docs/APP-STORE.md` has the answers to Apple's privacy questions.

Stories, the radio, Splitwise, the flashcards, chess, the blog and the owner's pages stay on the
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
| A save or an unsave, signed in | `POST /api/saves` |
| A question to the chat, with the thread before it | `POST /api/ask` |
| Sign in, make an account, sign out, delete it, change the password or the username, save the page under your name | `POST /api/account` with `action` |
| Sign in through Google | `GET /api/google?app=<challenge>`, then `POST /api/account` with `action: ticket` |
| Sign in through Apple | `POST /api/apple` |
| Your lists and the ones you saved | `GET /api/lists` (signed in) |
| Make, edit, fill, order, save or delete a list | `POST /api/lists` with `action` |
| Every place in Tallinn, to put one on a list | `GET /api/places?q=` |
| A place that search does not have — a museum, a shop — looked up on Google Maps and kept on the site | `GET /api/lookup`, `POST /api/lookup` |
| Discover's shelves of lists, its overlooked places and Play's routes | `GET /api/discover` |
| A list's walk: start, check in, comment, order, how you went, start again | `GET /api/walk?list=<id>`, `POST /api/walk` with `action` |
| Your walks still going, for Play | `GET /api/walk?mine=1` |
| Rides recorded near a bike way, and saving one | `GET /api/rides?bbox=…`, `POST /api/rides` |
| The discounts | `data/deals.json` |
| Whether this session may show a pass, and its drawn rate | `GET /api/pass?r=<place>` |
| The way there on foot, by bike, by bus or by car | `GET /api/route?from=…&to=…&mode=foot\|bike\|bus\|car` |

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

**The start waits for nothing.** While iOS starts the app it draws the launch
screen, which is one colour, `LaunchPaper`: the paper of the Red style a new
install opens in, where Xcode's empty one was black on a phone set to dark.
The first screen is Discover, drawn from what is on the phone: the bundled
or kept places, and the site's last answer to `/api/discover`, kept as
`discover.json` beside them, so it opens whole with no signal. Apple's map is
under Discover where nobody sees it, and is the dearest thing the app draws,
so it is built a moment after the first screen is up, and the phone is asked
where it is then too. The site is asked for anything newer after that, and
what it answers takes the place of what was shown.

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
    SavesStore.swift              the places saved, on the phone and the account
    AccountStore.swift            who is signed in, their lists, every write to them
    SocialSignIn.swift            the Google round trip and Apple's sheet
    WalkGame.swift                going round a list: its order, checks and presses
    RideRecorder.swift            recording a bike ride, and the rides under a way
    LocationProvider.swift        the blue dot and distances
  Models/
    Place.swift                   a place on the map; a kind of place
    Lists.swift                   lists, list items, profiles, list pins
    Deal.swift                    a discount: its offer, its run of rates, its dates
    Walk.swift                    /api/walk's answer, and the shortest order
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

# Privacy — what the app does with what it knows about you

Written from the app's source and the website's, on 2026-11-10, after the app
gained accounts, lists, discounts and sign-in with Google and Apple. **Read
every line and correct anything that is not true.** You are the one declaring
it, and this is an account of the code rather than a lawyer's advice.

It has three parts: where the policy lives, the text the app adds to it, and
the facts behind each sentence, so that a change to the app can be checked
against this page.

---

## Where it lives

The website already has a privacy page, in eleven languages:
<https://tallinntastebuds.ee/privacy>. The app opens it from **Me → Privacy**,
and it is the address to give App Store Connect as the privacy policy URL.

An account in the app is the website's account, so most of that page is
already the app's policy too: what an account keeps, who else handles it, how
long, your rights. Three things on it are not true of the app, and two things
the app does are not on it:

| The website's page says | In the app |
|---|---|
| The pages load Microsoft Clarity | The app loads no analytics of any kind |
| CARTO draws the map | Apple draws the map |
| An account is a username and either a password or Google | Or Apple |
| *(nothing)* | Your location is sent to the site when you ask for the way to a place |
| *(nothing)* | Signing in with Apple |

So the page needs a section about the app before the app is submitted. The
text is below. Adding it is a change to `data/privacy.json` in the website's
repository, in all eleven languages, with its date moved — it is not done
here, because what a visitor reads on the site is the owner's to approve.

---

## The section to add to the website's page

> ### In the iPhone app
>
> The Tallinn Taste Buds app reads the same map, lists and accounts as this
> site, and an account made in one is the same account in the other. What
> this page says about accounts, about how long things are kept and about
> your rights applies to the app too. A few things are different.
>
> **No analytics.** The app does not load Microsoft Clarity or anything like
> it, shows no advertising and does not track you across other apps or sites.
>
> **The map is Apple's.** The app draws its map with Apple Maps, so Apple
> receives your device's internet address in order to send the map, as CARTO
> does on this site.
>
> **Your location.** The app asks whether it may use your location the first
> time it opens, and works without it if you say no. It is used on your
> phone to show where you are and how far each place is. When you ask for the way
> somewhere — on foot, by bus or by car — your position is sent to this site
> with that one request, so the route can be worked out. To do that the site
> passes a rounded position on to the routing service it uses: OpenStreetMap
> Germany for walking and driving, and peatus.ee, Estonia's public journey
> planner, for buses and trams. This site does not store it and does not
> connect it to your account. You can switch location off for the app at any
> time in iPhone Settings, and everything but the directions and the
> distances still works.
>
> **Signing in.** You can use the app without an account. If you make one, it
> is a username and either a password, Google or Apple. With Apple, the site
> keeps the number Apple gives you for this app — never your email address or
> your name, which the app does not ask Apple for. With Google it is the same
> as on this site. The app keeps you signed in with the same cookie the site
> uses, on your phone, for up to a year or until you sign out.
>
> **What stays on your phone.** The places you save with the heart are kept
> on your phone. Signing in brings the places your account saved on this site
> into that list; a place you save in the app is not sent to your account.
> Your language and colour are kept on your phone too. Deleting the app
> removes all of it.
>
> **Deleting your account.** Me → Delete account in the app removes your
> account, your saves, lists, profile and sign-in at once, exactly as the
> button on this site's account page does.

---

## The facts behind it

Each line is something the code does. If one stops being true, the section
above is wrong and so are the App Store answers in `docs/APP-STORE.md`.

**What leaves the phone, and where it goes.** Every request the app makes goes
to `tallinntastebuds.ee` (`Core/API.swift`), with these exceptions: map tiles
from Apple (MapKit), the Google sign-in sheet, and Apple's own sign-in sheet.
There is no analytics SDK, no advertising SDK and no third-party code in the
app at all.

- *Content.* The places, kinds of place, languages, discounts and photos, on
  launch and on returning to the app. Nothing about you is in the request
  beyond what any web request carries: your internet address, which
  Cloudflare sees in order to answer.
- *Searches.* What you type into the map's search or the list editor's is
  sent to `/api/places`, with the part of the map on screen when you press
  **Search this area**. The site answers from memory and writes nothing down.
- *Location.* The map asks iOS for permission the first time it appears, and
  reads the position while the app is open (`Core/LocationProvider.swift`),
  to within about a hundred metres. Without permission distances are
  measured from the Old Town. Distances and the blue dot are worked out on
  the phone. `Views/RouteView.swift` sends your position, to
  five decimals, to `/api/route` with the place's. The site rounds the start
  to four decimals — about eleven metres — before asking the routing service,
  keeps the answer in Cloudflare's cache under those rounded points, and
  stores nothing in its database (`functions/api/route.js` in the website's
  repository says the same in its own words). **Open in Apple Maps** hands the
  destination, not your position, to Apple's app.
- *An account.* A username and password to `/api/account`. The site keeps the
  username and a scrambled password. Signed in, the app sends what you make:
  lists, the places on them, what you wrote about each, and which lists you
  saved. Public lists and your profile can be seen by anyone.
- *Google.* The sign-in sheet is the system's (`ASWebAuthenticationSession`)
  and shares Safari's cookies, so Google may already know you there. The site
  asks Google for `openid` and nothing else, and keeps Google's number for
  you. The app never sees your Google password, email or name.
- *Apple.* The app asks Apple for no name and no email
  (`requestedScopes = []` in `Core/SocialSignIn.swift`). Apple hands back a
  signed token; the site checks it and keeps Apple's number for you with this
  developer. The token itself is not stored.
- *A discount pass.* `/api/pass` is asked whether this account may show the
  pass and, for a drawn discount, what rate it drew. The code and the QR are
  made on the phone.

**What stays on the phone.** The saved places, the language, the colour style
(`UserDefaults`); the last copy of the map's content (Application Support);
cached photos; and the session cookie (`ttb_s`, in the system's cookie store).

**What the app does not do.** It does not read contacts, photos, the
microphone or the camera. It does not use the advertising identifier. It does
not run in the background or follow your location when it is closed: the
permission it asks for is *While Using the App*. It shows no web pages inside
itself — the website, Instagram, a place's own site and its phone number open
in Safari, the Instagram app or the phone, which are outside the app and have
their own rules.

**Children.** The app is not directed at children.

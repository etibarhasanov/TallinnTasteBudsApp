# Putting Tallinn Taste Buds on the App Store

Written for someone who has never shipped an app. You will not write code. You
will fill in forms, take some screenshots, and press a few buttons in Xcode.

**Cost:** 99 USD per year, to Apple. Nothing else.
**Time:** an afternoon of your work, plus 1–2 days waiting on Apple twice —
once to be let into the developer programme, once for the app to be reviewed.

---

## 1. Join the Apple Developer Program

Go to <https://developer.apple.com/programs/enroll/> and sign in with the Apple
ID you already use.

- Choose **Individual** unless you have a registered company and want the
  company's name on the listing. Individual puts *your own name* on the App
  Store page as the seller. Changing later means re-enrolling, so decide now.
- You will be asked to verify your identity — usually a photo of your ID
  through the Apple Developer app on your iPhone.
- Pay the 99 USD. It renews yearly; if you stop paying, the app comes off the
  store.

Apple usually approves within 24–48 hours. Nothing below can start until this
is done.

---

## 2. Gather the things the listing asks for

Do this while you wait for enrolment. These are the parts that hold people up.

### Name and copy

Draft text is in [`docs/APP-STORE-LISTING.md`](APP-STORE-LISTING.md) — edit it
to sound like you, it is your voice on the page and not mine.

- **App name** — max 30 characters. "Tallinn Taste Buds" is 18. It has to be
  unique across the whole App Store; if it is taken you will find out when you
  create the record in step 3.
- **Subtitle** — max 30 characters, shown under the name.
- **Description** — up to 4000 characters.
- **Keywords** — 100 characters total, comma separated, no spaces after commas.
- **Promotional text** — 170 characters, and the one field you can change
  without submitting a new build. Good place for "new this month: …".

### URLs

- **Support URL** — required. `https://tallinntastebuds.ee/` is acceptable.
- **Marketing URL** — optional, same address.
- **Privacy policy URL** — **required, no exceptions.** There is a draft at
  [`docs/PRIVACY.md`](PRIVACY.md). Publish it on the website as
  `privacy.html` and give App Store Connect that address. Read it first and
  correct anything that is not true — it is your declaration, not mine.

### Screenshots

Take them in the simulator: run the app, then **File → Save Screen** in the
Simulator menu (⌘S), which drops a PNG on your Desktop.

Apple asks for one set at the largest iPhone size and, **because this app also
supports iPad**, one set at the largest iPad size too. App Store Connect tells
you the exact pixel dimensions it wants next to the upload box — trust that,
not this page, because the sizes change with each generation of hardware.

Five or six shots is plenty. Worth showing:

1. The map with pins, zoomed to the centre of town
2. A place open — photo, blurb, must-order
3. The list with the filter chips
4. A discount place showing the offer
5. The map in Pink

Turn the radio off before shooting: the stop icon in a screenshot invites
questions you do not need during review.

> If you would rather not produce iPad screenshots, say so and the app can be
> made iPhone-only. It runs fine on iPad either way; this is purely about how
> much you have to photograph.

---

## 3. Create the app record in App Store Connect

Go to <https://appstoreconnect.apple.com> → **Apps** → **+** → **New App**.

| Field | What to put |
| --- | --- |
| Platforms | iOS |
| Name | Tallinn Taste Buds |
| Primary language | English (or Estonian, if you prefer) |
| Bundle ID | pick `ee.tallinntastebuds.app` from the dropdown |
| SKU | anything private to you, e.g. `tallinntastebuds-ios` |
| User access | Full Access |

If the bundle ID is not in the dropdown, register it first at
<https://developer.apple.com/account/resources/identifiers/list> — **+**,
App IDs, App, description "Tallinn Taste Buds", Bundle ID explicit,
`ee.tallinntastebuds.app`. No capabilities need ticking; background audio is
declared in the app itself and is not an entitlement.

---

## 4. Send the build up from Xcode

1. Open `TallinnTasteBuds.xcodeproj`.
2. Project → target **TallinnTasteBuds** → **Signing & Capabilities**. Team
   should now be your paid team, not "(Personal Team)". Pick it.
3. In the toolbar, set the destination to **Any iOS Device (arm64)**. Archive
   is greyed out against a simulator.
4. Menu **Product → Archive**. Takes a few minutes.
5. The Organizer window opens. Select the archive → **Distribute App** →
   **App Store Connect** → **Upload** → keep every default → **Upload**.

Wait 5–15 minutes. The build appears in App Store Connect under your app's
**TestFlight** tab, first as "Processing", then ready.

**Every upload needs a higher build number than the last.** Bump
`CURRENT_PROJECT_VERSION` in the target's build settings — 1, then 2, then 3.
`MARKETING_VERSION` is the public one people see (1.0, 1.1) and only changes
when you want it to.

---

## 5. Try it yourself first, through TestFlight

Do not go straight to review. In App Store Connect → **TestFlight**, add
yourself under **Internal Testing**. Install Apple's **TestFlight** app on your
iPhone and open the invitation.

This is the same build reviewers will run, on a real phone, with no cable and
no seven-day expiry. Check the things this project cannot check for you:

- The map draws all 71 places, and tapping one opens it
- **Show my location** puts the cyan or blue dot where you actually are
- A discount place shows the offer, and the code page opens with a QR
- The radio plays, and keeps playing when you lock the phone
- Every language in the picker reads correctly
- Both Red and Pink

---

## 6. Fill in the listing and the two questionnaires

Back on the app's **Distribution** page, attach the build and complete:

**App Privacy** — a questionnaire, and it is a legal declaration. For this app
the honest answers are:

- Location is used *on the device* to centre the map and sort by distance, and
  is never sent anywhere. Under Apple's definition, data that never leaves the
  phone is not "collected".
- Saved places live only on the phone.
- There are no accounts, no advertising and no analytics in the app.

That points at **Data Not Collected**. Read each question yourself before
answering — you are signing it, and the website's own analytics do not apply
here because they run on the website, not in the app.

**Age rating** — a second questionnaire. Answer honestly. The one that gives
people pause: the app links to Instagram and TikTok posts and shows discounts
at places that serve alcohol. "Infrequent/Mild Alcohol, Tobacco, or Drug Use or
References" is the usual answer, landing at 12+ or 17+ depending on how you
answer. Do not undersell it; a wrong rating is a rejection.

**Category** — Food & Drink, with Travel as secondary.

**Export compliance** — already answered in the app itself, so this will not
ask you anything.

---

## 7. Submit

**Add for Review** → **Submit**. Apple reviews in roughly 24–48 hours.

Pick **Manually release this version** if you would rather choose the moment it
goes live, rather than it appearing the second it is approved.

---

## What review might ask about

This is not a repackaged website, which is the rejection that catches most
apps of this shape (**Guideline 4.2, Minimum Functionality**). It is a native
map, list and detail interface, and it works offline, sorts by distance, keeps
a saved list on the device and plays audio in the background. None of that a
web page on iOS can do. If a reviewer raises 4.2 anyway, reply saying exactly
that.

Two things worth knowing before they come up:

- **The radio streams other people's stations.** The URLs in
  `data/radio.json` are public internet radio streams that the website already
  plays. If a reviewer asks whether you have the rights to broadcast them, the
  answer is that the app opens a public stream in the same way a browser does.
  If that becomes a fight, the radio button can be removed in one commit.
- **The discount pages open in a web view.** That is deliberate — the rotating
  code is generated and verified on the website by the same clock — and is
  worth saying in the review notes so it does not look like laziness.

Use the **Notes for Review** box. A reviewer who understands the app in ten
seconds approves it in ten seconds. Something like:

> A hand-picked map of places to eat in Tallinn. All content is loaded from
> tallinntastebuds.ee, so the app stays current without an update. Location is
> optional and used only to centre the map. No account is needed; nothing is
> required to test every feature.

---

## After it is live

Content is not part of a release. Places, photos, blurbs, discounts and even
whole new languages come from the website, so adding a restaurant means editing
`data/restaurants.json` and pushing — the App Store is not involved.

You only go back to Xcode when the *app* changes: a new screen, a new gesture, a
bug. Then it is bump the build number, Archive, Upload, submit — and review is
usually faster for an update than for a first release.

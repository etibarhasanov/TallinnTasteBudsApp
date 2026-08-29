# Tallinn Tastebuds — iOS app

The iPhone and iPad app for [Tallinn Tastebuds](https://tallinntastebuds.pages.dev),
built from the same content the website reads.

SwiftUI, iOS 17 and later, no third-party dependencies.

---

## The short answer to "will my website edits show up in the app?"

Yes. That is the whole design.

The website is a static site with no build step: everything it shows lives in
five JSON files under `data/` in the
[tallinntastebuds](https://github.com/etibarhasanov/tallinntastebuds) repo, and
the page reads them at load time. This app reads **exactly those same files over
the network**, from the same host.

```
   etibarhasanov/tallinntastebuds  (git push)
                 |
                 v
   Cloudflare Pages — tallinntastebuds.pages.dev
                 |
        +--------+---------+
        |                  |
   data/*.json         data/*.json
   photos/*            photos/*
        |                  |
        v                  v
     website            iOS app
```

So: edit `data/restaurants.json`, push, wait for Cloudflare Pages to deploy, and
the new place is on the map in the app — on the next launch, or the next time
the app comes back to the foreground. Nothing is submitted to Apple, nothing is
reviewed, no one has to update anything.

The site serves `data/*` with `Cache-Control: must-revalidate`, so the app's
conditional request gets the truth every time rather than a stale cached copy.

### What updates by itself

| Change on the website | Shows up in the app |
| --- | --- |
| Add, edit or remove a place in `data/restaurants.json` | Yes, next refresh |
| Rewrite a blurb, add a translation | Yes, next refresh |
| Add or replace photos in `photos/<id>/` | Yes, next refresh |
| Add or retire a type in `data/taxonomy.json` | Yes — the filter chips follow |
| Any interface wording in `data/ui.json` | Yes — the app ships no strings of its own |
| **Add a whole new language** to `ui.json` | Yes — it appears in the language picker |
| Start or stop a discount in `data/deals.json` | Yes, next refresh |
| Change the radio station in `data/radio.json` | Yes, next refresh |
| Mark a place `"closed": true` | Yes — greyed out, with the site's closed note |

### What still needs an App Store release

Anything that is a change to the *app* rather than to the *content*: new screens,
a different layout, a new gesture, the app icon, the tab bar. That is the normal
trade in exchange for an app that works offline, sorts by distance, keeps a saved
list, and plays the radio behind the lock screen — none of which a web page on
iOS can do.

Adding a **new kind of field** to `restaurants.json` also needs a release, since
the app has to be taught to draw it. Adding new *values* to fields that already
exist never does.

### Three layers, so it always draws something

1. **The network.** Every launch and every return to the foreground revalidates
   all five files against their stored ETags. An unchanged file costs a 304 and
   no body.
2. **The disk.** Whatever was last fetched, in Application Support. This is what
   the first frame draws, so the app never shows a spinner where the map goes.
3. **The bundle.** A snapshot committed under `TallinnTasteBuds/Content/Seed/`,
   for a first launch on a phone with no signal. `Tools/refresh-seed.sh` pulls a
   fresh one, and a weekly workflow does it automatically.

The app is therefore useful on the plane and current in the city.

---

## Building it

Requires Xcode 16 or later on macOS.

```sh
git clone https://github.com/etibarhasanov/TallinnTasteBudsApp
cd TallinnTasteBudsApp
open TallinnTasteBuds.xcodeproj
```

Pick a simulator and press Run. There is nothing to install first — no
CocoaPods, no Swift packages, no API keys. The map is Apple's, so unlike the
website there is no tile key to keep alive.

To run it against a preview deployment instead of production, add a launch
argument in the scheme: `-ttb.contentBaseURL https://your-preview.pages.dev`.

### Before it can go to the App Store

1. Set `DEVELOPMENT_TEAM` in the target's signing settings to your team.
2. `PRODUCT_BUNDLE_IDENTIFIER` is `ee.tallinntastebuds.app` — change it if you
   registered a different one.
3. Replace `TallinnTasteBuds/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
   if you want something other than the placeholder drawn from the site's
   palette.

On App Review: the app is not a wrapper around the website. It is a native map,
list and detail UI over a public content feed, plus offline use, distance
sorting, a saved list and background audio. The two web views it does open —
the discount code and the Instagram or TikTok post — are deliberate: the
discount code rotates on a clock the staff verification page shares, and one
implementation of that is the right number.

---

## Layout

```
TallinnTasteBuds/
  TallinnTasteBudsApp.swift     entry point; refreshes on launch and on foreground
  Models/                       Place, Taxonomy, Deal, RadioStation — mirrors of data/schema.json
  Content/
    ContentSource.swift         the base URL, and every URL derived from it
    ContentClient.swift         fetch with ETags, disk cache, bundled seed
    ContentStore.swift          the app's state: content, language, filters, sort
    Strings.swift               interface text, read from the site's ui.json
    AppStrings.swift            the few words the app needs that the site has no equivalent for
    Seed/                       the offline snapshot (refreshed weekly)
  Services/                     location, saved places, radio
  Views/                        map, list, detail, saved, settings
Tools/
  refresh-seed.sh               pull a current snapshot from the site
  validate-seed.mjs             check the snapshot against what the decoders need
```

`ContentSource.productionBase` is the one line that decides where content comes
from. Point it at a different host and the whole app follows.

## Keeping it honest

`Tools/validate-seed.mjs` runs in CI on every push. It checks the snapshot the
way the website's own `tools/validate.mjs` checks its data: required fields
present, ids unique, price bands in range, every `types` entry declared in the
taxonomy, every deal pointing at a real place, and every `ui.json` key the app
reads present in English. A rename on the website that the app has not been told
about fails the build here rather than showing a bare key to a reader.

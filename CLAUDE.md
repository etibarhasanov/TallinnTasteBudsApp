# Working on the Tallinn Tastebuds app

This app has no server of its own. Everything it shows comes from
tallinntastebuds.ee, and that site's `CLAUDE.md`
(`etibarhasanov/tallinntastebuds`) is the authority on what its routes answer
— **What the app reads** there lists every route and field this app depends
on, and a route the app starts reading is added there the same week.

## Branches: develop is where the work goes, and there are no versions

- **`develop` is where all ordinary work lands.** Branch from it, open pull
  requests into it, rebase onto it. A session's own branch is cut from
  `develop`, never from `main`.
- **This app has no versions** — the owner's word, 2026-11-21. Nobody asks
  for a version number, picks one or tags one, and no change waits for a
  release. (The rule that it did was copied from Rattatee on 2026-11-20 and
  never wanted here.) The newest app is on `develop`, which is why the phone
  guide downloads from there.
- **`main` is the default branch.** Nothing is committed to it directly and
  no feature branch is merged into it; `develop` is merged into it when the
  owner says so.
- **The weekly `refresh-seed` workflow commits to `develop`**, not to the
  default branch, so a new snapshot reaches `main` when `develop` next does.
- `claude/ios-app-tallinn-taste-buds-dsywel` was the default branch until
  2026-11-20; `main` and `develop` both started from its last commit.

## Every request has a price

The site runs on Cloudflare's free plan. Its database bills every row a
request reads, and past five million rows in a UTC day every read on the
account fails until midnight: lists come back empty, saves and sign-in stop,
for the website and for every installed copy of this app at once. On
2026-11-18 the website alone did that before noon.

An app multiplies whatever it does by every phone it is on, so a request is
designed with its frequency in mind before it is written:

1. **Say how often it runs.** Once per screen visit, per foreground, per
   keystroke, per minute while riding — and multiply by a thousand phones.
   Something on every foreground is a request a day per person at least;
   something every minute is a million a day at a thousand riders.
2. **Nothing retries without a wait that grows.** A failed request is put
   off — a minute, doubling, to a cap of hours — never sent again on every
   foreground or network change. A refusal sending again cannot change is
   final and stops. A person pressing a button may go past the wait.
3. **One trigger, one request.** `.task` already runs again on every
   appearance; an `.onAppear` beside it doing the same is a second request.
4. **Typing is debounced and has a floor**: 300 ms and two letters, as the
   searches here are.
5. **Keep what does not change.** A file or roll the site serves the same to
   everybody is kept on the phone and asked again on a timer, not on every
   open.

The site's side of the same rule is **Every read has a price, set before it
is written** in its `CLAUDE.md`; `/admin/stats` there shows the day's reads by
table, which is where a change here that made the site dearer shows up.

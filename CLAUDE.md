# Working on the Tallinn Tastebuds app

This app has no server of its own. Everything it shows comes from
tallinntastebuds.ee, and that site's `CLAUDE.md`
(`etibarhasanov/tallinntastebuds`) is the authority on what its routes answer
— **What the app reads** there lists every route and field this app depends
on, and a route the app starts reading is added there the same week.

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

#!/usr/bin/env bash
# Refresh the offline snapshot bundled with the app.
#
# The app always fetches its content from the website at runtime; this snapshot
# is only what it shows on a first launch with no network. Running this keeps
# that first impression current. It is safe to run any time, and a no-op when
# the site has not changed.
#
# The files are the ones the website's own map reads — data/map.json is the
# places without their write-ups, data/lang/<code>.json one language's strings
# and write-ups — saved under seed-* names, because Xcode copies every resource
# in the app folder into the bundle flat and a bare "en.json" or "index.json"
# would one day collide with something else.
set -euo pipefail

BASE="${TTB_BASE:-https://tallinntastebuds.ee}"
SEED="$(cd "$(dirname "$0")/.." && pwd)/TallinnTasteBuds/Seed"

fetch() {
  local path="$1" name="$2" tmp
  tmp="$(mktemp)"
  echo "fetching $BASE/$path"
  curl -fsSL "$BASE/$path" -o "$tmp"
  # Never overwrite a good snapshot with something that will not parse.
  node -e "JSON.parse(require('fs').readFileSync('$tmp','utf8'))"
  mv "$tmp" "$SEED/$name.json"
}

fetch data/map.json         seed-map
fetch data/taxonomy.json    seed-taxonomy
fetch data/lang/en.json     seed-lang-en
fetch data/lang/index.json  seed-lang-index
fetch data/deals.json       seed-deals

# The round crop of the painting is what every place on the map wears as its
# pin, so it travels with the data.
tmp="$(mktemp)"
echo "fetching $BASE/assets/logo/mark-round.webp"
curl -fsSL "$BASE/assets/logo/mark-round.webp" -o "$tmp"
# A WebP begins "RIFF....WEBP"; anything else is an error page in disguise.
if head -c 4 "$tmp" | grep -q RIFF; then
  mv "$tmp" "$SEED/mark-round.webp"
else
  echo "refusing to overwrite mark-round with something that is not a WebP" >&2
  rm -f "$tmp"
  exit 1
fi

echo "seed updated in $SEED"

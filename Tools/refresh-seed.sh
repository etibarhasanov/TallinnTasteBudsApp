#!/usr/bin/env bash
# Refresh the offline snapshot bundled with the app.
#
# The app always fetches its content from the website at runtime; this snapshot
# is only what it shows on a first launch with no network. Running this keeps
# that first impression current. It is safe to run any time, and a no-op when
# the site has not changed.
set -euo pipefail

BASE="${TTB_BASE:-https://tallinntastebuds.ee}"
SEED="$(cd "$(dirname "$0")/.." && pwd)/TallinnTasteBuds/Content/Seed"

for name in restaurants taxonomy ui deals radio; do
  tmp="$(mktemp)"
  echo "fetching $BASE/data/$name.json"
  curl -fsSL "$BASE/data/$name.json" -o "$tmp"
  # Never overwrite a good snapshot with something that will not parse.
  node -e "JSON.parse(require('fs').readFileSync('$tmp','utf8'))"
  mv "$tmp" "$SEED/$name.json"
done

# The two crops of the painting travel with the data, because they are the
# pictures the app draws before it has fetched anything: the round one is worn
# by every pin on the map, and the wide one is the logo in the header.
MEDIA="$(cd "$(dirname "$0")/.." && pwd)/TallinnTasteBuds/Content/Media"
for crop in mark-round mark; do
  tmp="$(mktemp)"
  echo "fetching $BASE/assets/logo/$crop.webp"
  curl -fsSL "$BASE/assets/logo/$crop.webp" -o "$tmp"
  # A WebP begins "RIFF....WEBP"; anything else is an error page in disguise.
  if head -c 4 "$tmp" | grep -q RIFF; then
    mv "$tmp" "$MEDIA/$crop.webp"
  else
    echo "refusing to overwrite $crop with something that is not a WebP" >&2
    rm -f "$tmp"
    exit 1
  fi
done

echo "seed updated in $SEED"

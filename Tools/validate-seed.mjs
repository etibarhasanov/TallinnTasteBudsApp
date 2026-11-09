/* Checks the bundled snapshot against what the app's decoders require.
 *
 * The app is lenient at runtime — a missing optional key is fine, and a place it
 * cannot decode is a place the reader never sees — so this is the place to be
 * strict instead, before a bad snapshot ships inside a build.
 *
 * The snapshot is four of the website's own files under seed-* names; see
 * Tools/refresh-seed.sh for why.
 */
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const seed = join(dirname(fileURLToPath(import.meta.url)), '..', 'TallinnTasteBuds', 'Seed');
const read = (name) => JSON.parse(readFileSync(join(seed, `${name}.json`), 'utf8'));

const problems = [];
const fail = (message) => problems.push(message);

const places = read('seed-map');
if (!Array.isArray(places) || places.length === 0) fail('seed-map.json is not a non-empty array');

const ids = new Set();
for (const place of places) {
  const where = place?.id ?? '(no id)';
  // These are exactly the fields Place.swift decodes without a default.
  for (const key of ['id', 'name', 'lat', 'lng']) {
    if (place?.[key] === undefined) fail(`${where}: missing required field "${key}"`);
  }
  if (ids.has(place.id)) fail(`${where}: duplicate id`);
  ids.add(place.id);
  if (typeof place.lat !== 'number' || typeof place.lng !== 'number') fail(`${where}: lat/lng must be numbers`);
  if (place.price != null && typeof place.price !== 'number') fail(`${where}: price must be a number`);
  if (place.photos != null && !Array.isArray(place.photos)) fail(`${where}: photos must be an array`);
}

const taxonomy = read('seed-taxonomy');
const typeIds = new Set((taxonomy.types ?? []).map((t) => t.id));
if (typeIds.size === 0) fail('seed-taxonomy.json has no types');
for (const place of places) {
  for (const type of place.types ?? []) {
    if (!typeIds.has(type)) fail(`${place.id}: unknown type "${type}"`);
  }
}

const index = read('seed-lang-index');
if (!index.en) fail('seed-lang-index.json has no English, which everything falls back to');

const en = read('seed-lang-en');
if (typeof en.ui !== 'object' || typeof en.blurbs !== 'object') fail('seed-lang-en.json must have "ui" and "blurbs"');
// The app reads these by name from the site's strings; a rename on the site
// would show the English written into the app instead, which is a quiet
// regression in ten other languages, so it is caught here.
const usedKeys = [
  'search', 'searchNone', 'filterAll', 'noResults', 'listOpen', 'listNearYou', 'listNearOldTown',
  'mustOrder', 'directions', 'website', 'call', 'markReel', 'closedFlag', 'savePlace', 'listSaved',
  'language', 'listsTitle', 'listsAllTitle', 'listsAllFor', 'listsAllSearchHint', 'listsEmpty',
  'listsViewList', 'listsViewMap', 'listsKeptOne', 'listsKeptN', 'venuesMaps', 'venuesShutToday'
];
for (const key of usedKeys) {
  if (typeof en.ui?.[key] !== 'string') fail(`seed-lang-en.json: ui.${key} is missing`);
}

if (!existsSync(join(seed, 'mark-round.webp'))) fail('mark-round.webp is missing from the seed');

if (problems.length) {
  console.error(`The bundled snapshot has ${problems.length} problem(s):`);
  for (const p of problems) console.error('  - ' + p);
  process.exit(1);
}
console.log(`ok: ${places.length} places, ${typeIds.size} types, ${Object.keys(index).length} languages`);

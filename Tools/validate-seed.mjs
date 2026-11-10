/* Checks the bundled snapshot against what the app's decoders require.
 *
 * The app is lenient at runtime — a missing optional key is fine, and a place it
 * cannot decode is a place the reader never sees — so this is the place to be
 * strict instead, before a bad snapshot ships inside a build.
 *
 * The snapshot is four of the website's own files under seed-* names; see
 * Tools/refresh-seed.sh for why.
 */
import { readFileSync, existsSync, readdirSync } from 'node:fs';
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

// The discounts: Deal.swift needs an id and a key, and a pass made from a key
// the website's verify page would refuse is a guest turned away at the till.
const deals = read('seed-deals');
if (!Array.isArray(deals)) fail('seed-deals.json is not an array');
for (const d of deals ?? []) {
  const where = `deal ${d?.id ?? '(no id)'}`;
  if (typeof d?.id !== 'string' || typeof d?.key !== 'string') fail(`${where}: needs an id and a key`);
  else if (!/^[0-9A-HJKMNP-TV-Z]{16,64}$/.test(d.key)) fail(`${where}: key is not 16-64 characters of the code alphabet`);
  if (d?.live && !d?.offer?.en) fail(`${where}: a live deal needs an English offer`);
  if (d?.roll && !String(d?.offer?.en ?? '').includes('{rate}')) fail(`${where}: a rolled deal writes {rate} in its offer`);
}
for (const key of ['passGet', 'passHeading', 'passUntil', 'passRollUntil', 'passSignIn', 'passRollSignIn',
                   'passUnavailable', 'passScanMe', 'passTerms', 'passTitle', 'passNotLive', 'dealSignIn',
                   'dealRollSignIn', 'dealMembers', 'dealRollMembers', 'dealRollHint', 'filterDiscount',
                   'verifyNotYetNote', 'verifyEndedNote']) {
  if (typeof en.ui?.[key] !== 'string') fail(`seed-lang-en.json: ui.${key} is missing`);
}

// The app's own strings. Every key the Swift asks for under the `app` prefix
// has no entry in the site's ui.json, so its translations are the bundled
// ones or nothing: a key missing here is a sentence left in English in ten
// languages, which is how the tab bar came to read "Map" in Azerbaijani.
{
  const own = read('app-strings');
  const views = join(seed, '..');
  const swift = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory()) walk(join(dir, entry.name));
      else if (entry.name.endsWith('.swift')) swift.push(readFileSync(join(dir, entry.name), 'utf8'));
    }
  };
  walk(views);
  // The key, then the English written beside it, across a line break or not.
  const asked = new Map();
  for (const source of swift) {
    for (const m of source.matchAll(/\bt\(\s*"(app[A-Za-z0-9]+)",\s*"((?:[^"\\]|\\.)*)"/g)) asked.set(m[1], m[2]);
  }
  // A domain name reads the same in every language.
  asked.delete('appWebsite');
  if (asked.size === 0) fail('found no app strings in the Swift, so the check below checks nothing');
  const holes = (text) => (text.match(/\{[a-z]+\}/g) ?? []).sort().join(',');
  for (const code of Object.keys(index)) {
    if (code === 'en') continue;
    const strings = own[code];
    if (!strings) { fail(`app-strings.json: no "${code}", a language the site speaks`); continue; }
    for (const [key, english] of asked) {
      if (typeof strings[key] !== 'string' || !strings[key].trim()) fail(`app-strings.json: ${code}.${key} is missing`);
      else if (holes(strings[key]) !== holes(english)) fail(`app-strings.json: ${code}.${key} does not carry the same {placeholders} as the English`);
    }
    for (const key of Object.keys(strings)) {
      if (!asked.has(key)) fail(`app-strings.json: ${code}.${key} is not a string the app asks for`);
    }
  }
}

if (!existsSync(join(seed, 'mark-round.webp'))) fail('mark-round.webp is missing from the seed');

if (problems.length) {
  console.error(`The bundled snapshot has ${problems.length} problem(s):`);
  for (const p of problems) console.error('  - ' + p);
  process.exit(1);
}
console.log(`ok: ${places.length} places, ${typeIds.size} types, ${Object.keys(index).length} languages, ${deals.length} deals`);

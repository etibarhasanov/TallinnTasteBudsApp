/* Checks the bundled snapshot against what the app's decoders require.
 *
 * The app is lenient at runtime — a missing optional key is fine, and a place it
 * cannot decode is a place the reader never sees — so this is the place to be
 * strict instead, before a bad snapshot ships inside a build.
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const seed = join(dirname(fileURLToPath(import.meta.url)), '..', 'TallinnTasteBuds', 'Content', 'Seed');
const read = (name) => JSON.parse(readFileSync(join(seed, `${name}.json`), 'utf8'));

const problems = [];
const fail = (message) => problems.push(message);

const places = read('restaurants');
if (!Array.isArray(places) || places.length === 0) fail('restaurants.json is not a non-empty array');

const ids = new Set();
for (const place of places) {
  const where = place?.id ?? '(no id)';
  // These are exactly the fields Place.swift decodes without a default.
  for (const key of ['id', 'name', 'address', 'lat', 'lng', 'price']) {
    if (place?.[key] === undefined) fail(`${where}: missing required field "${key}"`);
  }
  if (ids.has(place.id)) fail(`${where}: duplicate id`);
  ids.add(place.id);
  if (typeof place.lat !== 'number' || typeof place.lng !== 'number') fail(`${where}: lat/lng must be numbers`);
  if (!Number.isInteger(place.price) || place.price < 1 || place.price > 4) fail(`${where}: price must be 1-4`);
  if (place.blurb && typeof place.blurb !== 'object') fail(`${where}: blurb must be an object of language -> text`);
}

const taxonomy = read('taxonomy');
const typeIds = new Set((taxonomy.types ?? []).map((t) => t.id));
if (typeIds.size === 0) fail('taxonomy.json has no types');
if (typeIds.has('discount')) fail('taxonomy.json claims the reserved "discount" id');
for (const place of places) {
  for (const type of place.types ?? []) {
    if (!typeIds.has(type)) fail(`${place.id}: unknown type "${type}"`);
  }
}

const ui = read('ui');
const languages = Object.keys(ui);
if (!languages.includes('en')) fail('ui.json has no English, which everything falls back to');
for (const lang of languages) {
  if (!ui[lang].langName) fail(`ui.json: "${lang}" has no langName for the picker`);
}
// The app reads these by name; a rename on the site would show the key instead.
const usedKeys = [
  'wordmark', 'listTitle', 'listNew', 'listAlphabet', 'searchPlaceholder', 'searchNone',
  'listCount', 'listCountOne', 'filterAll', 'filterDiscount', 'noResults', 'close',
  'closed', 'closedNote', 'address', 'phone', 'visited', 'mustOrder', 'notFilmed',
  'directions', 'call', 'website', 'photoOf', 'photoClose', 'reelPlay', 'videoPlay',
  'openPlace', 'randomPick', 'randomNone', 'locate', 'locateFail', 'locateAway',
  'radioPlay', 'radioStop', 'radioFail', 'language', 'styleRed', 'styleGreen',
  'styleLabel', 'loadError', 'instagramHandle', 'priceOf', 'months', 'monthYear'
];
for (const key of usedKeys) {
  if (ui.en[key] === undefined) fail(`ui.json: English is missing "${key}", which the app reads`);
}

const deals = read('deals');
if (!Array.isArray(deals)) fail('deals.json is not an array');
for (const deal of deals) {
  if (!deal.id) fail('deals.json: a deal without an id');
  else if (!ids.has(deal.id)) fail(`deals.json: "${deal.id}" is not a place on the map`);
}

const radio = read('radio');
if (!radio.default && !radio.byLanguage) fail('radio.json has neither a default nor per-language stations');

if (problems.length) {
  console.error(`${problems.length} problem(s) in the bundled snapshot:\n`);
  for (const problem of problems) console.error(`  - ${problem}`);
  process.exit(1);
}
console.log(`snapshot looks good: ${places.length} places, ${typeIds.size} types, ${languages.length} languages`);

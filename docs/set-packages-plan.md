# Set packages — a toggleable "classic expansions" card pack

Planning document (2026-09-02). Nothing in the gating/loader design below is
implemented; the **pack file format** is (see "Implemented: pack format v1"
at the end). Every statement about the codebase was verified by reading it
on that date, and every number that is not a file count is labelled as an
estimate.

## The short answers

**Can an additional, self-contained, toggleable "old MTG up to Alliances /
Fifth Edition" package be built without touching purist play when it is
off?** Yes, with two caveats. The registry loads every folder under
`res://cards/sets` unconditionally (`CardRegistry.ensure_loaded()`), so a
package needs one new thing the codebase does not have — a set-membership
table plus an "enabled packs" gate in `engine/card_registry.gd` — and the
two registry pins (`test_registry_loaded_the_pool` = 897,
`test_every_stub_has_graduated` = exactly 8 `cards/todo/` dirs) need
package-aware variants. Everything else the pack needs (Settings key,
deck-builder set filter, proxy boundary for saved decks, format legality,
per-set wave tests) already exists in a shape a pack can extend.

**Can the existing pipeline build these packages, including card art?**
Yes for cards, yes for art, with one caveat each. `tools/fetch_cards.py` →
`tools/gen_cards.py` → hand graduation works for any Scryfall set code; the
caveat is that `gen_cards.py` auto-implements only 33 of the ~707 new
names (4.7 %; the 1997 pool was 11 %), so the pack is overwhelmingly hand
work. Art today is 100 % Scryfall (`tools/fetch_card_art.py` → gitignored
`assets/cardart/`, read by `GameSkin.card_art` by card NAME), and the same
tool fetches art for new sets with no code change; the caveat is that there
is no local art source for any of these sets — the 1997 install's card art
is inside `CardArtLib.dll` / `Cards.dat` (no importer), `s30` ships only
base-set art, and `mage-go` ships none — so art stays a per-player download,
exactly as `Provenance.md` already states for the 1997 pool.

Recommended scope: **ice + fem + hml + all** (~707 new names). **5ed, chr
and 3ed add zero new card names** once those four are in (every 5ed/chr/3ed
name is either in the 1997 pool or in ice/fem/hml) and are worth at most a
"printed in" badge. **Mirage/Visions stay out** (see Open decisions).

## The pipeline as it actually is

Verified file by file; the pack plan below only extends what is listed.

| Step | Where | What it does today |
|---|---|---|
| Fetch | `tools/fetch_cards.py` — `SETS = ["2ed","4ed","arn","atq","leg","drk","past","phpr"]`, `EXCLUDED_NAMES`, `EXTRA_PRINTINGS = {"phpr": {"Nalathni Dragon": "pdrc"}}`, `KEEP_FIELDS` (name, mana_cost, type_line, oracle_text, power, toughness, keywords, colors, rarity, collector_number, artist), `fetch_set(set_code)` (Scryfall `e:<set>`, `unique=prints`, 0.1 s sleep), `fetch_one()`, `main()` | Writes `cards/data/<set>.json`, one file per set code. No image URIs are kept. |
| Generate | `tools/gen_cards.py` — `POOL` (same eight codes, in first-printing order), `DATA_DIR`/`SETS_DIR`/`TODO_DIR`, `SUPPORTED_KEYWORDS` (flying, trample, vigilance, haste, reach, defender, first strike, banding), `PROTECTION_COLORS`, `LANDWALKS`, `keyword_only()`, `is_auto_implementable()` (Creature, integer P/T, keyword-only oracle), `render_auto()` with `AUTOGEN_MARKER`, `render_stub()`, stale-stub cleanup | Auto cards into `cards/sets/<set>/`, stubs into `cards/todo/<set>/`; a name that exists in several JSONs lands in the first `POOL` set that has it. |
| Graduate | `docs/adding-cards.md` checklist; `tests/cards/test_pool_wave1.gd` … `wave74.gd` (74 wave files, ≈12 cards each) | Test-first, one card per file, header doc comment. |
| Registry | `engine/card_registry.gd` — `SETS_ROOT := "res://cards/sets"`, `ensure_loaded()` scans every non-dot subfolder, `_load_set(set_code)` loads every `.gd` not starting with `_` and stamps `data.set_code` and `data.artist`, `register()` push_errors on a duplicate name, `unload()`, `const SET_ORDER := ["2ed","arn","atq","leg","drk","4ed","past","phpr"]`, `_ensure_printings()` reads `res://cards/data/%s.json` per `SET_ORDER` code ("first set in printing order wins" for `originally_printed_in()` and `artist_of()`) | Name → `CardData`, static table; dropped by the `Lifecycle` autoload (`game/lifecycle.gd::_exit_tree`). Called from `game/main.gd`, `deck_builder_screen.gd`, `deck_store.gd`, `engine/deck_list.gd` (×2), `engine/mtg_game.gd`. |
| Pins | `tests/cards/test_2ed_cards.gd:8-14` `test_registry_loaded_the_pool` (897); `tests/cards/test_pool_wave73.gd:41-53` `test_every_stub_has_graduated` (exactly 8 dirs under `cards/todo`, all empty); `tests/cards/test_generated_pool.gd` `test_every_registered_card_is_sane` (iterates every name); `tests/test_simplified_ledger.gd` (SIMPLIFIED markers ↔ ledger rows) | |
| Set-aware UI | `CardRegistry.SET_ORDER` is the single hub: `game/set_badges.gd` (one badge per code, `NAMED := {"past": "Astral"}`), `game/deck_builder/deck_filter.gd` (`SET_LABELS`, `reset()`/`select_all()` iterate `SET_ORDER`, `matches_set(d) → set_on(d.set_code)`, sort by `SET_ORDER.find()` at line 478), `game/deck_builder/filter_bar.gd:309` (set buttons), `game/skin.gd` (`SET_LABELS := {"2ed": ["2","nd"], "4ed": ["4","th"], "phpr": ["PR",""]}`, `set_label()` falls back to `set_code.to_upper()`, `set_icon()` from the DBArt import), `game/deck_builder/card_preview.gd:252-257` | A new set code shows up everywhere with an upper-case text label and no icon until the label tables learn it. |
| Art | `tools/fetch_card_art.py` — `pool()` dedupes names across `sorted(cards/data/*.json)` (first file wins), `fetch_art_url(name, set)` (`/cards/named?exact&set`, set-less fallback), downloads `art_crop` → `assets/cardart/<snake>.jpg` and `border_crop` → `<snake>_card.jpg`, resume-safe, `--force`, 0.12 s delay. `assets/cardart/` carries a `.gdignore` and is gitignored; 1794 files / 189 MB for 897 cards today | `GameSkin.card_art(name)` (`game/skin.gd:105`) looks in `user://original_skin/cardart/`, `res://assets/original/cardart/`, then `res://assets/cardart/<snake>.jpg|.png`, and loads with `Image.load_from_file` (nothing enters the Godot import cache). Keyed by card NAME only — no set involved. |
| Decks | `engine/deck_list.gd::load_file(path, strict)` (strict → unknown names are `errors`; lenient → `proxies`), `engine/proxy_card.gd`, `game/deck_builder/deck_store.gd::_fold()` (proxies reported by name), `game/setup_screen.gd:150-159` (a deck with proxies is listed but not duelable), `deck_store.gd::deck_paths_in()` (non-recursive: `res://decks` and `user://decks` only) | |
| Legality | `engine/deck_format.gd` — five formats, `RESTRICTED` / `BANNED` name lists, `is_basic()` by `Mtg.Supertype.BASIC` (its comment already anticipates snow basics as "Manalink-era cards that no set this project reads contains") | `BANNED` already names the Ice Age and Homelands ante cards (Amulet of Quoz, Timmerian Fiends); `RESTRICTED` already names Necropotence and Brainstorm. Unknown names in these lists are harmless. |
| Rules forks | `engine/rules_options.gd` — `IMPLEMENTED` (7 forks), `FORKS` table; `game/settings.gd::rule(key)` / `set_rule()` at `user://settings.cfg` section `options`, key `rule_<fork>` | |
| Settings | `game/settings.gd` — static `ConfigFile`, `get_value/set_value/flush`, typed accessors (`sound_enabled`, `ai_pace`, `hand_style`, `rule`) ; `game/options_screen.gd` — `_add_sound_section`, `_add_coin_toss_section`, `_add_rules_section` | Options is reachable only from the main menu (`game/main.gd:60-61`); no duel or deck builder is open while it is shown. |
| Adventure | Does not exist. `game/main.gd:5` and `game/deck_builder/deck_model.gd:27` mention M5 in comments; `docs/ROADMAP.md` M5 says it gets its own design doc before code. | Reward/price tables are a design question, not a code change. |

## Package design

### The unit: a pack, made of set folders

A pack is a named list of set codes. Cards live where the rules already say
cards live — `cards/sets/<set>/` (CONTRIBUTING.md rule 4, `adding-cards.md`
"Future card packs", ROADMAP "new sets go in new folders") — and the pack is
a registry-level table over those folders:

```gdscript
# engine/card_registry.gd (planned)
const PACKS := {
    "classic": ["ice", "fem", "hml", "all"],   # Ice Age … Alliances
}
static var enabled_packs: PackedStringArray = []   # strings only: the
                                                   # static-var rule bans CardData
```

`ensure_loaded()` loads a folder iff its code is in `SET_ORDER` or in an
enabled pack, and `push_error`s on a folder that is in neither (a stray
folder can no longer silently join the pool). `_load_set` is unchanged.
A `reload(packs)` = `unload()` + `enabled_packs = packs` + `ensure_loaded()`.

Why not a second root (`packs/<pack>/cards/…`)? It would need `DATA_DIR` /
`SETS_DIR` / `TODO_DIR` switches in both tools and a second data path in
`_ensure_printings()`, for a separation the `PACKS` table already gives.
Why not a runtime `.pck` (`ProjectSettings.load_resource_pack`)? A pack
mounted into `res://cards/sets/` would be loaded by today's unfiltered scan
(so "off" would be "not mounted", which the test suite never exercises),
packs cannot be unmounted, the `.gd` inside must match the engine build,
and the test suite runs from the source tree anyway — so the cards would
have to exist in the tree regardless. A `.pck` is a distribution
convenience for exported builds and can be added later by exporting the
pack's folders; it is not a gating mechanism. An export feature tag has the
same problem in reverse (build-time, not player-time).

### Set order and labels

`SET_ORDER` stays the 1997 list — it is the definition of the default pool
and of "original printing". Add `static func active_set_order() ->
Array[String]` = `SET_ORDER` + the codes of enabled packs, in pack order.
Consumers switch to it: `SetBadges`, `DeckFilter.reset/select_all` and the
sort at `deck_filter.gd:478`, `filter_bar.gd:309`. `_ensure_printings()`
iterates `active_set_order()` too — the "first set wins" rule keeps every
1997 card's original set and artist unchanged because pack codes come
after. `DeckFilter.SET_LABELS` and `GameSkin.SET_LABELS` gain rows
(`ice` Ice Age, `fem` Fallen Empires, `hml` Homelands, `all` Alliances);
`GameSkin.set_icon` has no 1997 icon for them (`Program/DBArt` holds only
Antiquit/ArabNite/Astral/Dark/Fourth/Legends) and falls back to the text
label, which is the right look for a non-1997 set.

### The Settings toggle

`Settings.enabled_packs() -> PackedStringArray` (key `packs`, default
empty) and `set_pack_enabled(id, on)`; the Options screen gets
`_add_packs_section` with one CheckButton per `CardRegistry.PACKS` entry,
labelled `[QoL]` like every addition that is not in the 1997 game. The
engine must not read `Settings` (rule 1), so the game layer pushes the
value: `Lifecycle._ready()` sets `CardRegistry.enabled_packs` before
`game/main.gd:10` calls `ensure_loaded()`; the Options screen calls
`CardRegistry.reload(Settings.enabled_packs())` on leave. Nothing is live
while Options is open (main menu only), so a reload there is safe; the
deck builder and setup screen rebuild their lists from the registry when
opened. Headless entry points (`deck_lab.sh`, `duel_soak.sh`) get a
`--packs classic` switch that sets the same static before loading.

### Deck builder and saved decks

With the pack on, the set filter shows the new badges and the card list
includes the new cards; nothing else changes. With the pack off, a saved
deck that contains pack cards goes through the existing proxy boundary:
`DeckList.load_file(path, false)` lists the names under `proxies`,
`DeckStore._fold()` reports them, `setup_screen.gd:150-159` lists the deck
as not duelable. This is the behaviour a deck with a typo gets today and
needs no new code. One nicety is worth adding: the proxy report can say
"in pack: classic" for a name that a disabled pack would satisfy — that
needs a name → pack index built from `cards/data/<set>.json` without
loading the scripts (the printings index already reads those JSONs).

Shipped pack decks go under `decks/classic/` — `deck_paths_in()` is
non-recursive, so they are invisible today and become visible when the
setup screen and `DeckStore.all_deck_paths()` add the pack's deck folders
for enabled packs. Deck Lab ratings (`decks/ratings.txt`) should get a
separate ledger per pack folder so 1997 Elo and pack Elo never mix.

### Legality

`DeckFormat` name lists are already era-aware in the two places that
matter (ante cards banned, Necropotence/Brainstorm/Strip Mine restricted).
The 1997–98 Type I list also restricted Zuran Orb — an unknown name in a
list is harmless, so pack-era names can go in now. Snow-covered basics
count as basic lands once they carry `Supertype.BASIC` (`is_basic()`),
which is the Fifth Edition ruling and what `DeckFormat`'s comment expects.

### Rules forks

`RulesOptions` does not interact with set membership: every fork is a rule
of play, not a card rule. Cumulative upkeep, snow, and pitch costs are
defined by their cards under both the 1997 (Fifth Edition) ruleset and
modern rules the same way the rest of the pool is (oracle text, CR cited
at the site). One fork-adjacent note: the manual's ruleset IS Fifth
Edition, so a Fifth-Edition-era pack is the ruleset's home turf — no new
fork is needed for it.

### Adventure and reward tables (M5, not yet written)

The 1997 game distributes cards by colour and rarity, never by set
(`../s30/shandalar-faq.txt` §1.14: a per-town rate of 50–200 % over a fixed
per-card price, basic land 20 gold, buy = sell; §1.22: unnamed lairs give
"a card of the appropriate colour (usually a rare)", the Spectral Arena
"rare/astral cards", Nomad's Bazaar sells at normal cost; §1.8–1.9: the
computer antes no restricted cards and nobody antes basic lands;
`../docs/SHANDALAR_LORE.md`: dungeons hold three restricted cards each).
Two consequences for the M5 design doc:

1. Every table must take the active pool as a parameter, not enumerate
   the registry. Drawing "a random rare of colour X" from 897 vs ~1600 names
   halves the chance of any given 1997 card; a pack needs either its own
   weight (e.g. pack cards at 50 %) or its own bucket (shops "stock" one set
   at a time), decided in that doc.
2. Pack cards need prices. Local Tier 3 sources: Manalink
   `../shandalar-src/prices.csv` (10 947 rows, `base_sell_price`,
   `implemented_in_shandalar` — Force of Will 100, Necropotence 400,
   Jester's Cap 200, Zuran Orb 100, Hymn to Tourach 120) and s30's
   `card_tiers.toml` + `CalculateCardPrice` (Old School 93/94 tier list ×
   log-scaled Scryfall USD). Neither is a 1997 artefact; the 1997 per-card
   price table has not been located (`Provenance.md`).

Enemy decks: the pack ships its own AI decks; whether roster enemies use
them is an M5 decision. The balance rule ("added cards must not change the
balance of the original game") is met by default-off, but Necropotence,
Force of Will, Hymn to Tourach and Zuran Orb reshape any format they enter
— the pack README must say so, per `adding-cards.md`.

### Tests

- `test_registry_loaded_the_pool` stays 897 and additionally asserts
  `CardRegistry.enabled_packs.is_empty()`.
- `tests/packs/classic/test_registry_loaded_classic.gd`: `before_all`
  `CardRegistry.reload(["classic"])`, `after_all` `reload([])`, pins
  897 + N, and runs the sanity walk of `test_generated_pool.gd` over the
  bigger table (extract that walk into a `GameTest` helper). Keep all pack
  tests under `tests/packs/<pack>/` so the suite switches tables twice per
  run, not per file.
- `GameTest` gets `func packs() -> PackedStringArray` (default empty) and
  reloads in `before_all` only when it differs from the current table.
- `test_every_stub_has_graduated` must stop asserting `== 8` dirs; "every
  dir under `cards/todo` is empty" is the property it actually wants.
  During pack development `cards/todo/ice/` etc. will exist and be
  non-empty — the pack's own graduation test owns that.
- Wave files mirror the pool's: `tests/packs/classic/test_ice_wave1.gd` …
- SIMPLIFIED markers in pack cards are found by the same `grep -rlw`; the
  ledger `docs/simplified-cards.md` gets a per-pack section and
  `test_simplified_ledger.gd` keeps pinning both directions.
- Duel soak and Deck Lab runs with `--packs classic` become a second CI
  lane once pack decks exist.

## Art

Where today's art comes from: Scryfall, and only Scryfall. `assets/cardart/`
= 1794 files / 189 MB for 897 cards (art_crop + border_crop, ≈211 KB per
card), gitignored, never redistributed (`Provenance.md`). `GameSkin.card_art`
keys by snake-cased NAME, so a pack card gets art the moment its JPG exists.

Can art for new sets come from the same place? Yes: add the set codes to
`fetch_cards.py::SETS`, run it, then `fetch_card_art.py` — its `pool()`
reads every `cards/data/*.json`, and `fetch_art_url()` asks Scryfall for
the card's own printing. Zero code change. Two things to know:

- `pool()` dedupes by name across files in ALPHABETICAL order; `ice.json`
  sorts before `leg.json`, so a Legends card reprinted in Ice Age (e.g.
  Kismet) would be asked for as its Ice Age printing on a `--force` re-run.
  Resume-safety means existing art is untouched; ordering `pool()` by
  `CardRegistry.SET_ORDER` + pack order is a two-line fix worth making.
- Size (estimate): ~707 cards × 211 KB ≈ 150 MB more on disk per player,
  ~6 min of fetching at the tool's delay. Loading is `Image.load_from_file`
  on demand, so disk is the only cost.

Local alternatives checked and ruled out: the 1997/Manalink install keeps
card pictures inside `CardArtLib.dll` and `Cards.dat` (binary, "CAF" magic,
no decoder in this project; `import_original.py` says so); `Program/CardArt/`
is frames and overlays only; the ten numbered `NNNN.pic` files in the
Manalink root are native `.PIC` data, not a per-card set; `Program/DBArt`
has set icons for the 1997 sets only; `../s30/assets` covers 2ed/4ed/atq/
arn/past/phpr only (`scryfall_cards.json.zst`, 555 cards); `../mage-go` has
no images at all.

## Per-set table

Counts come from a throwaway local script (deleted) that read the repo's
`cards/data/*.json` for the 1997 pool and `../mage-go/data/{ICE,FEM,HML,ALL,
MIR,VIS}.json` for the candidate sets — Scryfall-derived local copies with
`name`, `mana_cost`, `type_line`, `oracle_text`, `power`, `toughness`,
`colors`, `keywords`, `rarity`, `set` (NOT `collector_number` or `artist`,
so they do not replace a `fetch_cards.py` run). Reprint flags for 5ed / chr
/ 3ed come from Manalink `../shandalar-src/Rarity.csv` (columns
"3rd Ed. (Revised)", "4th Edition", "a5th Edition", "Chronicles"). "Auto"
is `gen_cards.is_auto_implementable()` run unmodified over the local JSON.
There is NO local Scryfall JSON for 5ed, chr or 3ed; their totals are
knowledge-based estimates.

| Set | Printings | Unique names | Already in 1997 pool (with `.gd`) | New to the pack | Auto (`gen_cards`) | Notes |
|---|---|---|---|---|---|---|
| ice Ice Age | 383 | 373 | 27 (27) | 346 | 17 | 30 cumulative upkeep, 27 snow, 22 delayed cantrips, 33 "unless you pay" upkeeps, 3 coin flips, 22 sac-as-cost, 51 named-counter cards |
| fem Fallen Empires | 187 | 102 | 0 | 102 | 2 | 26 sac-as-cost, 25 named-counter, 8 token makers (Thrull/Saproling/Citizen), 2 coin flips |
| hml Homelands | 140 | 115 | 0 | 115 | 11 | 14 legends, 3 world enchantments, 4 token makers, 1 poison, 1 coin flip; Apocalypse Chime wants `originally_printed_in()` |
| all Alliances | 199 | 144 | 0 | 144 | 3 | 5 pitch spells (Force of Will…), 9 cumulative upkeep, 22 delayed cantrips, 4 snow, 8 token makers, 3 rampage, 1 poison |
| **pack total** | **909** | **734** | **27** | **707** | **33 (4.7 %)** | vs 140 / 1266 (11 %) for the 1997 pool |
| 5ed Fifth Edition | 449 (est.) | ~434 (est.) | 286 (Manalink flag; 282 by exact name — 4 spelling variants) | **0 once ice/fem/hml are in** (est.; its non-pool names are ice/fem/hml reprints) | — | Printing only; no folder |
| chr Chronicles | 125 (est.) | ~116 (est.) | 113 (Manalink flag; 109 exact + spelling) | 0 (remaining names are arn cards the 1997 game excluded) | — | Printing only; no folder |
| 3ed Revised | 306 (est.) | 306 | 290 (Manalink flag; 286 exact) | 0 | — | Printing only; no folder |
| mir Mirage (OUT) | 351 | 335 | 17 (17) | 313 | 19 | 18 phasing, 12 flanking, 27 sac-as-cost |
| vis Visions (OUT) | 167 | 167 | 0 | 167 | 9 | 10 phasing, 6 flanking |

Tier 3 behaviour references per set (Manalink `../shandalar-src/src/cards/`,
`int card_*` functions): `ice_age.c` 211, `fallen_empires.c` 100,
`homelands.c` 94, `alliances.c` 83 (also `mirage.c` 173, `visions.c` 105).
No chronicles/fifth-edition file exists — reprints are coded under their
first set. `../mage-go/cards/fallen_empires/` is partial (its `TODO.md`
lists ~40 unimplemented); mage-go has no ice/hml/all packages, so it is a
reference for FEM only. Provenance tier for every pack card: Tier 3 at best
(no 1997 artefact mentions any of these sets); Scryfall oracle text is the
primary source, as for the pool.

## Engine gaps

What the engine has (verified) and what the pack needs that it lacks.

| Mechanic | Cards | Today | Needed |
|---|---|---|---|
| Cumulative upkeep | 39 (ice 30, all 9) | Absent (`grep -ri cumulative engine cards` is empty). Pieces exist: `UPKEEP_START` triggers, `add_counters(inst, kind, n)` (`mtg_game.gd:6156`), `try_pay(pid, cost)` (:4609), sacrifice; Force of Nature is the "unless you pay" pattern (`cards/sets/2ed/force_of_nature.gd`) | One shared builder `with_cumulative_upkeep(cost)` in `engine/abilities/` (age counter, escalating pay-or-sacrifice; non-mana variants: Polar Kraken "sacrifice a land", Glacial Chasm); AI must decide pay/sacrifice per turn — today's "unless you pay" auto-pays if able, which is wrong for a Kraken on turn 6 |
| Snow-covered lands | 31 (ice 27, all 4) | `Mtg.Supertype { BASIC, LEGENDARY, WORLD }` — no SNOW; `ManaCost` doc says snow symbols are out of scope (Ice Age has none; `{S}` is Coldsnap) | `Supertype.SNOW` bit, `is_snow()`, five snow-covered basic land files; `DeckFormat.is_basic()` works unchanged |
| Delayed cantrips ("Draw a card at the beginning of the next turn's upkeep") | 44 (ice 22, all 22) | `delayed_triggers` + `schedule_delayed_trigger` exist (`mtg_game.gd:196-200`) | One shared effect helper; no engine change |
| Pitch / alternative costs | 5 (all) + Scars of the Veteran-style | `cast_spell(pid, inst, targets, x_value, mode)` has a `mode` but no alternative-cost hook; only `extra_cost_per_target` surcharge (`card_data.gd:652`) | `CardData.alt_cost` (can-pay / pay Callables: exile a card of colour X from hand, pay life); AI `evaluator` must learn "castable with no mana" (Force of Will is the whole point) |
| Activate from hand (Elvish Spirit Guide) | 1 (all) | `ActivatedAbility` has no zone-of-activation member; graveyard-zone triggers exist (`triggered_ability.gd:43`) | A `from_zone` on activated abilities, or a one-card special |
| Tap-another-permanent cost ("tap an untapped creature you control": Hecatomb, Karplusan Giant, Koskun Falls, Coral Reef, Vodalian War Machine) | 5 (ice 2, hml 2, fem 1) | Costs: `tap_cost`, `sacrifice_cost`/`sacrifice_filter`, `life_cost`, `exile_cost`, `discard_cost`, `random_discard_cost` (`activated_ability.gd`) | One more cost kind |
| ETB replacement "sacrifice a Plains/Swamp instead" (Kjeldoran Outpost, Lake of the Dead) | 2 (all) | Replacement effects exist for draws/damage; no ETB variant found by grep | Small |
| Search another player's library, controller chooses (Jester's Cap) | 1 (ice) | `search_library(pid, filter, prompt, to_battlefield, shuffle_after)` searches `players[pid]`'s own library | A `chooser` parameter |
| Thrull/Saproling/Serf tokens, spore/storage/tide counters, sac outlets | fem, hml | `create_token()` (:5809), named counters, `sacrifice_filter` — all present | Shared vocabulary; no engine change |
| Poison | 2 (hml Leeches, all Swamp Mosquito) | `add_poison()` (:3033), wave 48 | None |
| Coin flips | 6 | `flip_coin(pid)` (:6008) | None |
| Legends / world enchantments | hml 14 / 3 | legend rule (:6381) and world rule (:6426) | None |
| Rampage | all 3 | Present (Legends) | None |
| Phasing / flanking | mir, vis only | `phase_out()` (:3733, wave 51) exists; flanking absent | Not needed while Mirage/Visions are out |
| Draw replacement (Necropotence) | 1 (ice) | `draw_replacement` on CardData (:969) | None for the draw half; the exile-and-return end-step half is a delayed trigger |
| Random discard as a cost (Stormbind) | ice | `random_discard_cost` | None |

AI (`engine/ai/effect_intent.gd`, `evaluator.gd`): EffectIntent classifies
by effect class, so every pack card built from the shared vocabulary is
priced for free. New classes to teach it: the escalating cost of cumulative
upkeep (a per-turn liability, not a one-off), alternative costs (a
counterspell that is live while tapped out changes how the opponent's
`ai_player` sequences its turn), and snow synergy (negligible). mage-go has
no ICE/ALL heuristics to port; s30 has no such cards at all.

## Phased plan

Effort figures are estimates from this repo's own history — 897 cards over
74 waves at roughly 12 cards per wave, most waves one agent session — and
are labelled as such.

| Phase | Work | Size (est.) |
|---|---|---|
| 0 Gate | `PACKS` table, `enabled_packs`, `active_set_order()`, folder guard, `reload()`; Settings key + Options section; `Lifecycle` push; label tables; `test_every_stub_has_graduated` relaxed; pack pin test + `GameTest.packs()`; `--packs` for `deck_lab.sh` / `duel_soak.sh`; pack README with balance statement | 8–12 agent-hours |
| 0 Data | `fetch_cards.py::SETS` += ice, fem, hml, all (network); `gen_cards.py::POOL` same order appended after phpr (reprints stay in their 1997 folder); `fetch_card_art.py` `pool()` ordered by set order; run all three | 1–2 hours plus fetch time; ~150 MB art |
| 1 Homelands | 115 cards, 11 auto; no engine work | ~9 waves, 25–35 agent-hours |
| 1 Fallen Empires | 102 cards, 2 auto; shared vocabulary only | ~8 waves, 25–35 agent-hours |
| 2 Engine | SNOW supertype, cumulative upkeep builder, delayed-cantrip helper, alt-cost hook, tap-other cost, ETB replacement, `search_library` chooser, each test-first in `tests/unit/` | 20–30 agent-hours |
| 2 AI | cumulative-upkeep and alt-cost valuation in `evaluator`/`ai_player`; soak with pack decks | 10–15 agent-hours |
| 3 Ice Age | 346 cards, 17 auto | ~28 waves, 90–120 agent-hours |
| 4 Alliances | 144 cards, 3 auto | ~12 waves, 40–55 agent-hours |
| 5 Ship | 4–6 pack AI decks under `decks/classic/`, Deck Lab ledger, ledger sections, CODE_MAP rows; optional 5ed/chr "printed in" badges (data JSON only, no folders) | 8–12 agent-hours |

Total ≈ 240–320 agent-hours (estimate), about a third of it Ice Age. Phases
1 and 3/4 parallelise by set folder exactly as the pool waves did; phase 2
must precede 3 and 4.

Risks: (1) the count pin and the registry gate are the only two places the
"purist pool" is defined — if a pack folder ever loads by default, purist
play changes silently, so the folder guard and the `enabled_packs.is_empty()`
assertion must land in phase 0, not later. (2) A 1600-name registry roughly
doubles registry load time and duel-lab startup (est.) — the reload-per-switch
in tests is why pack tests live in one directory. (3) `register()` refuses a
duplicate name, so a name printed in a pack set AND the 1997 pool must live
only in its 1997 folder (gen_cards' `POOL` order guarantees this if pack codes
are appended). (4) Art volume: two crops per card is a choice; a pack could
fetch `art_crop` only. (5) The balance rule is satisfied by default-off, not
by the cards — the README must say the pack is a different game.

## Open decisions

1. **Mirage / Visions.** Recommended OUT: +480 names (nearly the pack
   again), flanking is absent, 5ed does not contain them, and the design
   brief says "up to Fourth Edition, Alliances, and maybe Fifth". Phasing
   already exists, so the engine cost of adding them later is flanking plus
   instant-speed cantrips; the `PACKS` table makes them a second pack
   (`"mirage": ["mir","vis"]`) rather than a change to this one.
2. **Chronicles / Fifth Edition / Revised.** Recommended: no folders, no
   cards — they add zero names once ice/fem/hml/all are in. Optionally add
   their `cards/data/*.json` so the printings index can show "also printed
   in 5ed"; `DeckFilter.matches_set` filters by folder (`set_code`), so a
   5ed badge would match nothing without a printings-based filter.
3. **Art source.** Scryfall via the existing tool is the only option found;
   decide whether pack art fetches both crops (today's behaviour) or
   `art_crop` only.
4. **Default state.** Off, per the balance rule; one toggle for the whole
   `classic` pack, or one per set? The table supports either; one toggle
   keeps Options honest.
5. **Where pack decks and their AI rating live**, and whether roster
   enemies (M5) may use pack cards at all.
6. **Restricted list.** Add the 1997–98 era names now (Zuran Orb, plus a
   review of the DCI list of March 1997), or keep `DeckFormat` at the
   modern Vintage list it holds today.
7. **Pack README balance statement.** Who writes the reasoning
   `adding-cards.md` requires — the pack is deliberately a different game
   (Necropotence, Force of Will, Hymn to Tourach), and it should say so.

## Implemented: pack format v1 (2026-09-02)

The first concrete step of this plan is the ARCHIVE, not the loader: every
set we have downloaded is now frozen as a self-contained `.tar.gz`, and the
eight-set 1997–98 pool is one more archive for the purists. Builder:
`tools/build_card_packs.py` (self-test `tools/test_build_card_packs.py`,
`python3 -m unittest discover -s tools -p 'test_*.py'`). It reuses the two
fetchers rather than duplicating them: `fetch_cards.scryfall_get` /
`fetch_set_raw` (the one Scryfall client — User-Agent, ≥100 ms pause) and
`fetch_card_art.fetch_missing_art` / `snake` (the art naming).

```
python3 tools/build_card_packs.py                # every cards/data set + the bundle
python3 tools/build_card_packs.py leg drk        # just these set packs
python3 tools/build_card_packs.py --bundle-only  # just dotp-1997.tar.gz
python3 tools/build_card_packs.py --offline      # never fetch; report what is missing (exit 1)
python3 tools/build_card_packs.py --force        # refetch set objects, icons, listings, art
python3 tools/build_card_packs.py --out DIR      # default ../shandalar-packs
python3 tools/build_card_packs.py --max-art-fetch N   # default 300 files; 0 = no limit
```

**Where the archives live: `../shandalar-packs/`**, a sibling of the
project like `../s30` and `../tools` — outside `res://`, so Godot's importer
never sees a pack or anything extracted from one, and outside git, as
Scryfall art must be (`Provenance.md`: images are fetched per player, never
redistributed). `packs/` inside the project is gitignored as a guard for
`--out packs`, and the builder drops a `.gdignore` into any output dir
under the project root. `<out>/cache/` keeps the raw Scryfall set object,
full card listing and icon per set, so a rebuild is fully offline
(measured: 14 s for all nine archives from cache, 31 s with the 24 fetches).
`<out>/index.json` lists every archive: file, kind, code, name, cards,
printings, art files, size, sha256, build date.

**Per-set archive `<code>.tar.gz`** (root directory `<code>/`):

```
<code>/
  set.json            pack_format 1, kind "set"; code, name, released_at,
                      set_type, block, printings, card_count (unique names),
                      scryfall_card_count, rarity_counts, excluded_names,
                      extra_printings, scryfall {id, uri, scryfall_uri,
                      search_uri, icon_svg_uri}, icon {svg, png[]},
                      art {naming, variants, files, bytes, cards_with_art,
                      cards_missing_art[]}, cards_json {superset_of,
                      base_fields, enrichment_fields}, incomplete[],
                      build {date, tool, tool_version, sources}
  cards.json          cards/data/<code>.json record-for-record, same order,
                      each record plus scryfall_id, oracle_id,
                      illustration_id, cmc, color_identity, released_at,
                      flavor_text, image_uris, scryfall_uri, reserved,
                      border_color, frame, legalities {vintage, legacy,
                      oldschool, premodern}. Extra keys are invisible to
                      gen_cards.py / fetch_card_art.py / CardRegistry, so
                      the file is a drop-in cards/data/<code>.json.
  cards.txt           one unique name per line, collector-number order
  printings.tsv       collector_number, name, rarity, artist, set — every printing
  common.txt, uncommon.txt, rare.txt   unique names by rarity (mythic.txt /
                      special.txt only when the set has them); basic lands
                      are NOT in these, they are in
  lands.txt           the basic lands
  by_color/           white, blue, black, red, green, multicolor, artifact,
                      land (.txt; only non-empty groups)
  icon.svg            Scryfall's set symbol; icon_64.png, icon_128.png when
                      rsvg-convert or cairosvg is on PATH (plain black — the
                      1997-era symbols carried no rarity colour; that
                      convention starts with Exodus, and the game draws none)
  art/<snake>.jpg     art_crop, and art/<snake>_card.jpg border_crop — the
                      two files fetch_card_art.py keeps, named exactly as
                      GameSkin.card_art / card_scan look them up
  art/index.json      name → art_crop file, border_crop file, set,
                      collector_number, scryfall_id, illustration_id, artist,
                      art_fetched_for (the printing the picture was fetched
                      for: fetch_card_art dedupes by NAME, first data file
                      alphabetically)
  README.txt          contents, reuse recipe, Scryfall / WotC attribution
```

**The purist bundle `dotp-1997.tar.gz`** (root `dotp-1997/`; name "Duels
of the Planeswalkers (1997–98) pool" — this plan had named the expansion
pack `classic` but nothing for the pool, so the pool gets a hyphenated id
no Scryfall set code can collide with):

```
dotp-1997/
  set.json            kind "bundle"; members [2ed 4ed arn atq leg drk past
                      phpr] in gen_cards.POOL order, sets[] with each
                      member's counts and path, printings 1301,
                      card_count 897, dedupe rule, art stats, build
  cards.json          the MERGED pool: 897 records, one per name, the first
                      member set in POOL order wins — gen_cards.py's rule,
                      which is why it matches the registry pin (897)
  cards.txt, printings.tsv, common/uncommon/rare/lands.txt, by_color/
                      over the merged pool (rarity = the winning printing's)
  art/                1794 files keyed by name — a drop-in for assets/cardart/
  art/index.json
  sets/<code>/        each member's set.json, cards.json, lists, icon.svg,
                      README — WITHOUT art (a reprint has one picture, at
                      the bundle root), so these are drop-ins for cards/data/
  README.txt
```

Per-set subfolders rather than nested archives because the loader this plan
describes wants `cards/data/<code>.json` per set and `assets/cardart/` flat
by name, which is exactly what `sets/<code>/cards.json` and `art/` are.

**Built 2026-09-02** (all art present locally; nothing fetched but the 8 set
objects, 8 icons and 8 listings; Scryfall refused nothing):

| Archive | Printings | Names | Art files | Size |
|---|---|---|---|---|
| 2ed.tar.gz Unlimited | 300 | 290 | 580 | 62.5 MB |
| 4ed.tar.gz Fourth Edition | 378 | 368 | 736 | 76.0 MB |
| arn.tar.gz Arabian Nights | 77 | 77 | 154 | 14.7 MB |
| atq.tar.gz Antiquities | 100 | 85 | 170 | 16.9 MB |
| leg.tar.gz Legends | 309 | 309 | 618 | 73.2 MB |
| drk.tar.gz The Dark | 119 | 119 | 238 | 24.1 MB |
| past.tar.gz Astral | 12 | 12 | 24 | 1.3 MB |
| phpr.tar.gz HarperPrism promos (+ Nalathni Dragon) | 6 | 6 | 12 | 1.3 MB |
| dotp-1997.tar.gz (bundle) | 1301 | 897 | 1794 | 194.1 MB |

450 MB in all (the JPEGs do not compress; a 4ed pack carries its reprints'
art so it stands alone). Building found one real bug on the way: the art
fetcher's `snake()` kept accented letters (`dandân.jpg`) while
`GameSkin._snake` maps them to `_` (`dand_n.jpg`), so the eight accented
Arabian Nights names had pictures the game never found. `snake()` now
matches the game, the sixteen files were renamed in place, and the builder
still recognises the old spelling (`legacy_snake`).

What a future pack needs from this: add the set code to
`fetch_cards.SETS`, run `fetch_cards.py` and `fetch_card_art.py`, then
`build_card_packs.py <code>` — no builder change. The `--max-art-fetch`
guard means the builder itself will fetch a handful of missing pictures but
refuses to become the bulk art downloader (that stays `fetch_card_art.py`).
A `classic` bundle would be `BUNDLE_*` constants made a table; not done
until the pack exists.

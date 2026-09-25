# Pack 6 — Portal & Second Age

We included the **first Portal set** for its beautiful illustrations and
distinctive card design—especially the basic lands with their large mana
symbols. Its straightforward creatures and spells can also offer new
players a gentler introduction to Magic and Shandalar.

Try the [Portal starter decks](portal-starters.md) and their illustrated
guides in **Help → Contents → Portal starter decks**, then explore the
wider card pool at your own pace. Gameplay still uses the game's normal
rules, not a separate Portal ruleset.

Pack revision **2.0.0** includes original **Portal (1997): 200 names / 215
printings**, and **Portal Second Age (1998): 155 names / 165 printings**.
Together: **318 distinct names, 355 set entries and 380 printings**. Second
Age adds 117 rules identities; the pack supplies 290 new identities in total.
Core plus Pack 6 has 1,252 set entries / 1,193 unique cards; all six packs
have 2,359 set entries / 1,898 unique cards. The core remains 897 cards.

Requires **Shandalar 0.40.9 or later**. Rebuild older Pack 6 ZIPs using the
matching tool; the filename and saved decks do not change. Original Portal
remains independently selectable. Portal Three Kingdoms is not included.
The snapshots contain English numbered printings only: POR 1–215 and P02
1–165, excluding demo, starter-text and foreign variants.

## Build and enable

Using Python 3.10+ from the matching source or extracted game folder:

```sh
python3 tools/pack_6_portal.py fetch-art
python3 tools/pack_6_portal.py build cardpacks/Pack-6-Portal.zip
python3 tools/pack_6_portal.py verify cardpacks/Pack-6-Portal.zip
```

On Windows, `py -3` may replace `python3`. Leave the ZIP intact and enable
it through **Options → Card Packs → Rescan**. On Mac, `cardpacks/` belongs
beside the app, not inside it. Web players construct the ZIP on their own
computer and use the existing card-pack upload flow. The rules and source
tools are platform-independent; no network service is needed to play.

With no explicit output path, the builder writes
`../shandalar-packs/Pack-6-Portal.zip`; its reusable cache is
`../shandalar-packs/cache/pack_6_art/`. An explicit `--art-dir` overrides
the cache. `fetch` is a maintainer operation: it refreshes trusted metadata
and requires reviewing the rules and rebuilding the matching game.

The menu badge is **6-POR**. In Deck Builder → **Extras**, leave Portal
on and turn the other sources off to browse exactly its 200 names. The
circular portal emblem follows the original set symbol, redrawn in the
existing gold and carved-stone styles for the card icon and On/Off buttons.

## Art and printings

All 380 numbered English printings are pinned by Scryfall ID: an art crop
plus a full-card scan, **760 physical images**. Each basic land has all four
Portal illustrations and all three Second Age illustrations. Separate set
namespaces preserve both versions of shared cards such as Archangel.
The artwork ZIP and downloaded pictures stay local; only builder source,
metadata and original interface assets are distributed.

Portal basic-land previews display the original full scan, preserving the
large mana symbol in the text box. Animated lands use the normal live card
frame so power/toughness and game effects remain visible.

Hover/select a card in the Deck Builder, then press the **Card variant** stone
medallion just below its lower-right corner. Preview a printing, then choose
**Use variant**, or choose
**Automatic** to follow the set filter again. The chooser includes reprints
from other installed, enabled sets, even when the inventory filter hides
those sets. The inventory still shows 200 distinct Portal cards and reports
215 printings; alternate art never adds extra copies to the pool.

One preferred printing per card name is saved with each deck, shared by its
main deck and sideboard. Different copies of the same name cannot yet use
different art within one deck. Other packs expose the artwork they already
supply per name/set, not every historical illustration of those sets.

`.deck` files keep optional `# printing: ["Forest","por:215"]` comments;
`.dec` exports use `// printing:`. Undo, deck slots, local duels, matches,
Gauntlets, LAN tables and tournament decks retain the preference. Legacy
`.dck` exports cannot retain it. Counts, formats, draft verification and
game rules remain name-based. Missing or disabled artwork falls back to
the normal face without making an otherwise playable deck illegal; the
saved preference survives. LAN protocol 24 sends printing IDs only with
visible card faces; hidden hands and masked cards reveal no art preference.

Six reprints reuse trusted earlier-pack definitions even when those packs
are disabled: Dry Spell, Elvish Ranger, Mountain Goat, Nature's Lore,
Pyroclasm and Storm Crow. Shared identities are deduplicated when several
packs are enabled. Other core reprints keep their original implementation.

## Rules and computer player

Second Age has its own Extras stone medallions and gold set symbol, inspired
by its five-notched gate emblem. Switch off Portal and other sources to see
155 Second Age names / 165 printings. Draft pools can select either set.
The [seven original Second Age decks](portal-second-age-decks.md) live under
**Portal Second Age decks**. Help's clickable Contents includes illustrated
set, theme-deck and two-player-starter guides.

Second Age adds extra combat/main phases, optional whole-combat-damage
assignments (Lone Wolf, Deathcoil Wurm, Cunning Giant), and Piracy's permission
to tap opponents' lands for spell-only mana without changing control.
Local and LAN interfaces share these choices. Characteristic power works
in other zones as well as on the battlefield for the four Second Age stars.
Its before-attack tap abilities, sacrifice choices, random discard, tutors,
two-target spells and destruction-dependent life changes use the shared
engine. See the [Second Age inventory](pack-6-second-age-audit.md).

The [Portal starter decks](portal-starters.md) include both unchanged
35-card teaching lists and clearly labelled 40-card play adaptations.
**Help → Contents → Portal starter decks** provides illustrated guidance.

Gameplay uses the current Oracle snapshot, not the obsolete starter-only
rules printed on some original cards. Several original sorceries are now
instants. The special after-being-attacked restriction on cards such as
Assassin's Blade, Deep Wood and Defiant Stand is enforced during Declare
Attackers, before blockers. Help explains this in player-facing terms.

New shared mechanics include a maximum number of blockers per attacker,
direct battlefield/library-top movement, next-turn combat restrictions,
and Last Chance's loss trigger tied to its own extra turn. Extra turns now
follow most-recently-created-first order and resume the correct normal turn.
The [mechanics inventory](pack-6-mechanics-audit.md) maps every identity.

The computer player's semantic estimates cover dynamic damage and drawing,
public board counts, restricted instants and risky extra turns. Last Chance
is not treated as a free Time Walk. Planning reads public information and
its own hand, never an opponent's hidden cards or future library order.
Looking, revealing and searching occur only while a legal card effect
resolves. These are heuristic policies, not a claim of perfect play.

## Archive contract

The ZIP contains four metadata entries plus 1,352 artwork entries: 760
set-namespaced entries and 592 fallbacks for the 296 identities Pack 6 must
supply without earlier packs. There are **1,356 entries total**. The archive
never supplies executable scripts. The loader checks exact inventory,
trusted metadata, minimum version and SHA-256 hashes. Uncompressed sizes
are checked before reading members: 8 MiB per member, 256 MiB total.

Builds are staged, verified and atomically replaced; identical inputs
produce identical ZIP bytes. Metadata-only archives are accepted solely
under the explicit isolated test feature, never as ordinary player packs.

## Second Age verification (2026-09-24)

Godot 4.7.2: **336 distinct targeted tests passed**, with successful wrapper
exit codes and no engine errors or leaked-object reports in those runs.

| Scope | Tests |
|---|---:|
| New Second Age rules, decisions, LAN choices and exact deck lists | 44 |
| Existing Portal catalogue, mechanics, choices, AI and integration | 47 |
| Combat damage and mana planning | 30 |
| LAN protocol, packs, socket tables and shared duel screens | 74 |
| Printing preferences, Help and original Portal starters | 72 |
| Ice Age blocking interactions and Fallen Empires/Extras regressions | 69 |

The `pack_6` selection also reruns twelve new Second Age cases; these are
counted only once above. The Python checks passed **29 tests**: eight Pack 6
builder checks, fifteen release-toolkit tests and six tree/privacy checks.
The real artwork ZIP passed verification. Extracted construction tools can
build the combined pack without a source checkout.

`tools/pack_6_duel_audit.gd --second-age --seed 68000` completed **14 full
Wizard-versus-Wizard duels**, using all seven original decks: modern seeds
68000–68006 and fifth-edition seeds 168000–168006. Games finished in 15–28
turns without stalls or engine errors. This is bounded flow coverage, not
proof that every card was drawn or every strategic decision was optimal.

Six real native macOS captures checked the Deck Builder, Extras, and all
three illustrated Help pages at 1280×800, plus Extras at 960×600. The full
Second Age land scan, separate set counts, buttons and footer are readable.
Three distinct P02 Forest scans were checked against the original Portal
scan. The player's normal profile was not used.

A combined test-selection attempt unexpectedly expanded discovery; it was
stopped, and affected scripts were checked individually. The resulting
Extras test fixes replace assumptions about the old fixed dialog nesting.
No full-suite gate, exported-binary test or new release is claimed here.

## Earlier Portal verification

The artwork-selector follow-up passed 250 selected deck, rendering and LAN
tests, eight Python builder checks and six tree/privacy checks. It includes
an actual socket exchange, saved tournament metadata, missing-art fallback
and masked-card rejection. One live human-seat duel completed with selected
Portal land printings. Native macOS captures checked the chooser at both
1280×800 and 960×720 and verified four different Forest scans.

The focused tests live in `test_pack_6_catalogue`, `test_pack_6_mechanics`,
`test_pack_6_choices`, `test_pack_6_ai` and `test_pack_6_integration`.
They exercise standalone/all-pack counts, real casting and stack resolution,
combat timing, choices, last-known sacrificed power, undo, extra-turn order,
menus, filters and hidden-information-invariant planning.

`tools/pack_6_duel_audit.gd` provides reproducible complete Wizard games
with five Portal deck themes and both rulesets. Initial seeds 67000–67004
and 167000–167004 all completed, taking 11–22 turns, without engine errors.

The 2026-09-23 feature check passed **159 focused GUT tests** (47 Portal,
112 existing/integration) and **29 Python checks** (8 pack builder,
15 release packaging, 6 tree/privacy). A live human-seat interface soak
completed a Portal duel in 10 turns and 90 automated clicks (seed 67676),
with no engine errors or warnings. Native rendered screenshots checked the
200-card filter, original Forest scan, pack menus and the Extras dialog at
960×720; its Close button remains inside the frame. A normal resource export
loaded all 200 Portal identities, its metadata and three interface glyphs
outside the source checkout.

This is bounded feature verification, not exhaustive testing of every
combination with the older pool. The full release suite and new platform
release exports are separate release-preparation work.

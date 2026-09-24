# Pack 6 — Portal (1997)

Portal is an optional, independent beginner-oriented set with **200 card
names from 215 original English printings**. It adds **173 new identities**
and reprints 27 previously supported names. Core plus Portal has 1,097 set
entries and 1,076 unique cards; all six packs have 2,204 set entries and
1,781 unique cards. The original core remains 897 cards.

Requires **Shandalar 0.40.7 or later**. This is the first Portal set, not
Portal Second Age or Portal Three Kingdoms. The snapshot includes English
collector numbers 1–215, excluding demo, starter-text and foreign variants.

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

All 215 numbered English printings are pinned by Scryfall ID: an art crop
plus a full-card scan, **430 physical images**. Each basic land has all four
original illustrations. Pack revision 1.1.0 adds those fifteen alternate
land printings; rebuild an older local Portal ZIP with the current tool.
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
saved preference survives. LAN protocol 23 sends printing IDs only with
visible card faces; hidden hands and masked cards reveal no art preference.

Six reprints reuse trusted earlier-pack definitions even when those packs
are disabled: Dry Spell, Elvish Ranger, Mountain Goat, Nature's Lore,
Pyroclasm and Storm Crow. Shared identities are deduplicated when several
packs are enabled. Other core reprints keep their original implementation.

## Rules and computer player

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

The ZIP contains four metadata entries plus 788 artwork entries: 430
set-namespaced entries and 358 fallbacks for the 179 identities Portal must
supply without earlier packs. There are **792 entries total**. The archive
never supplies executable scripts. The loader checks exact inventory,
trusted metadata, minimum version and SHA-256 hashes. Uncompressed sizes
are checked before reading members: 8 MiB per member, 256 MiB total.

Builds are staged, verified and atomically replaced; identical inputs
produce identical ZIP bytes. Metadata-only archives are accepted solely
under the explicit isolated test feature, never as ordinary player packs.

## Verification

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

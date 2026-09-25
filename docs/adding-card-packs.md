# Adding a numbered card pack

A pack is **optional catalogue data and locally downloaded artwork**, not a
plug-in containing executable code. Its reviewed rules ship in the game;
the ZIP only enables those rules and supplies printings and images. Dropping
an arbitrary new set ZIP into an old executable cannot add mechanics.

Use this guide with [CONTRIBUTING](../CONTRIBUTING.md),
[adding a card](adding-cards.md), [architecture](ARCHITECTURE.md),
[fair play](fair-play.md), and [provenance](../Provenance.md). Read those
before changing the rules engine or AI. This is a development checklist, not
a promise that every Scryfall set can be supported without engine changes.

## 1. Reserve the identity and measure the catalogue

Choose an unused number, exact ZIP name, Scryfall set code and short label.
Keep the number permanent even if a title changes. For example:

| Field | Alliances example |
|---|---|
| Pack ID | `pack-5` |
| File | `Pack-5-Alliances.zip` |
| Set code | `all` |
| Menu label | `5-ALL` |
| Source metadata | `packaging/card_packs/pack_5_alliances/` |
| ZIP namespace | `card_packs/pack_5_alliances/` |
| Dedicated builder | `tools/pack_5_alliances.py` |
| Trusted loader | `game/alliances_pack.gd` |
| Rules | `cards/sets/all/` |

Fetch the official Scryfall set endpoint and **every page** of its search
results using the existing rate-limited helper. Check the returned set code,
reported total, duplicate records, collector numbers and name normalization.
Do not infer completeness from the number of downloaded images.

Record these separately:

- **Published printings:** all ordinary set records, including alternate art.
- **Named set entries:** one membership per distinct card name in this set.
- **Unique playable identities:** name-based rules across enabled sets.
- **Reprints:** names already supported by the core or another pack.
- **New rules identities:** genuinely new names requiring reviewed scripts.

Alliances has 199 printings but 144 names. A set with reprints does **not** add
its whole name count to the global unique total. Check overlap against the
core **and every earlier pack**, and test enabling packs in different orders.
Do not overwrite a shared identity with a second competing script.

A pack may be **reprints alone**. Fifth Edition (Pack 7) adds no identity:
its loader's `scripts()` list the 147 Ice Age, Homelands and Fallen Empires
originals it reuses, keyed by name to their set in `shared_names.json`,
with `"set"` set to the pack's own code so the card wears the pack's
symbol when that pack is its only provider. `CardPacks._configure_registry`
walks the original expansions first, so their scripts win when both are
on; `_shared_source` and `_shared_provider` answer which pack a deck needs
and whether disabling one loses a card's last provider. Such a pack still
ships fallback pictures (`skin/cardart/`) for the shared names, since the
original pack's artwork may be absent.

Commit metadata and the reviewed reprint checklist, not downloaded art.
Card headers must retain the actual Oracle text, including Unicode names;
filenames must use the same ASCII normalization as `GameSkin` and the
builder. Test punctuation, accents, split names and filename collisions.

Keep the builder's metadata snapshot paired with the game revision: runtime
readers compare it with their compiled trusted snapshot. `fetch` is a
maintainer refresh that requires reviewing Oracle changes and rebuilding the
game, not a necessary step for a player constructing a ZIP for an older
installed version. Player instructions should normally start with `fetch-art`
from the matching source revision, then `build` and `verify`.

## 2. Build a separate Python construction tool

Use the latest numbered builder as a structural example, not an unreviewed
search-and-replace template. Audit every number, namespace, filename, count,
error message and release-exclusion test after copying it.

The public commands should be:

```sh
python3 tools/pack_5_alliances.py --help
python3 tools/pack_5_alliances.py fetch
python3 tools/pack_5_alliances.py fetch-art
python3 tools/pack_5_alliances.py build
python3 tools/pack_5_alliances.py verify
```

For another pack, substitute its own script. Keep an explicit output-path
option and a resumable local art cache. Never silently replace the last good
ZIP with a partial download. Build to a temporary sibling, verify, then
atomically replace the destination. Use deterministic ordering, timestamps
and serialization so identical input yields identical ZIP bytes.

Include a versioned manifest, catalogue, set information and a local-use
README. At minimum validate pack ID, format version, pack version, minimum
game version, expected inventory, name counts, metadata SHA-256 and the
sorted artwork-inventory checksum. Recompute checksums from the actual ZIP
bytes, not from filenames or image dimensions alone.

The current builder selects one representative printing per name and fetches
two complementary image types: an **art crop** for the game's own card frame
and a **full printed-card scan** for enlarged views. Those are not two
playable cards or necessarily two alternate illustrations. If implementing
selectable printings, give them explicit printing IDs and test the lookup;
do not claim all alternate art is included merely because all metadata is.

Reject missing images, duplicate members, path traversal, absolute paths,
unexpected namespaces, unexpected files, scripts, excessive sizes and
unverified bytes. A metadata-only fixture must be restricted to the isolated
test feature; it is not a distributable game pack.

The existing numbered readers enforce exact membership and checksums, but
do not yet impose a decompressed-byte budget. Before accepting arbitrary
third-party downloads, add bounded archive inspection rather than treating
these locally constructed ZIP readers as a complete hostile-archive sandbox.

Offline Python tests must cover real tiny image fixtures, exact inventory,
determinism, corruption, duplicate members, injected paths, unsupported
versions, preserving the previous ZIP after failure and the release guard.
Also test the production ZIP against the Godot reader: Python agreement
alone does not prove the runtime accepts it.

## 3. Extend the trusted loader and discovery

Create a pack-specific loader matching the Python contract. JSON is data:
never evaluate a script path from the ZIP. Derive allowed resource paths
from a reviewed name list and the compiled game tree. Deep-copy returned
metadata or cache serialized data, so callers cannot mutate the trust cache.

Wire the pack into `game/card_packs.gd`:

- exact filename and ID discovery;
- inspection and readable rejection reasons;
- enabled-state persistence and registry reconfiguration;
- name-to-required-pack mapping and current-deck conflict checks;
- namespaced artwork lookup and fallback;
- compatible registry provider ordering.

Keep `game/skin_pack.gd` from treating the numbered gameplay ZIP as a UI
skin. Disabled or absent packs must not register their new names. Enabling
one pack must not silently enable another. Handle a removed or replaced ZIP
on Rescan without retaining stale data, cached textures or enabled state.

Set `minimum_game_version` to the first build that actually ships this pack's
trusted rules. A version string alone does not establish support: the build
must also contain the loader/provider and dormant scripts. Test both gates.

## 4. Implement and audit every card

Make an inventory of every Oracle clause before implementation. Group
mechanics by reusable effects, triggers, costs, replacements, continuous
layers, combat restrictions, delayed actions, hidden-zone choices and
cross-card interactions. A creature with stats is not implemented if its
rules text has been ignored.

Use one metadata/header script per new name and small shared family modules.
Keep unsupported work **fail-closed** during development. Do not remove the
guard until the mechanic has an implementation and regression coverage.
The final catalogue test must reject every remaining pending guard.

For new engine mechanisms:

1. Reproduce the missing behavior in a failing test and save the output.
2. Check the source hierarchy and relevant Comprehensive Rules.
3. Add a reusable, declarative API rather than card-name branches in the
   engine. Preserve the printed mana cost when adding alternative costs.
4. Validate all costs and choices before mutating anything. Costs occur at
   announcement, not resolution; triggers raised by paying them wait above
   the resulting spell/ability. Held human choices must resume atomically.
5. Mutate through journaled `MtgGame` helpers. Use live characteristics and
   the seeded game RNG. Keep engine/card code independent of scenes/Nodes.
6. Test refused actions, optional choices, legal/illegal targets, protection,
   shroud, source departure and re-entry, control changes, copied spells,
   multiple stacked activations, turn expiry, simultaneous events and undo.
7. Exercise both Modern and Fifth Edition rules where behavior differs.

For genuinely difficult digital adaptations, use an explicit `SIMPLIFIED`
comment and add the exact difference to [the ledger](simplified-cards.md),
the pack audit and player-facing help/text. Document the gameplay trade-off;
do not label a card faithful when timing, targets or resource costs differ.
Revisit the adaptation when a later pack adds the missing mechanism.

## 5. Teach the fair AI the new effect shapes

Card availability is not AI support. Check casting, alternate payments,
response windows, modes, X, divided targets, activations, nonmana costs,
upkeep choices, combat and how a new card changes existing evaluations.

Expose semantic roles/parameters or typed effects from card rules. Policy
must reason from the public board and its own hand, not special-case card
names or read the opponent's hidden hand or either library's order. A library
search resolution can offer the legally visible search choices; a planner
cannot inspect future cards to decide whether to activate it.

Use an existing appropriate capability gate where possible. Follow the
repository's named-knob, null and unaffected-control protocol for actual
policy changes; do not invent a second difficulty scale. Add action-level
tests proving the AI uses the ability effectively and refuses harmful or
unpayable choices. Include hidden-information permutation tests.

## 6. Finish every player-facing surface

- **Menu:** pack badge, title/version/details and accurate set-entry/unique
  counts. Keep numbered packs below the original 1997 set strip, wrapping
  after five buttons. Hide the row when no packs are available; Rescan must
  add/remove badges and refresh counts without reopening the screen.
- **Deck Builder:** independent Extras On/Off row, centered medallions, live
  source/set filtering, search, count and preview. Original 1997 cards also
  have an independent visibility toggle. Visibility is not global enabling.
  The switches are remembered between visits and across restarts
  (`deck_builder_extras` in `settings.cfg`, since 2026-09-17); a pack that
  is off in Options has no switch to remember, and turned on again its
  cards come back on.
- **Deck storage:** decks stay name-based unless a printing is explicitly
  pinned. Save required-pack metadata; loading an unavailable/disabled-pack
  deck must explain it and offer the appropriate enable flow. Disabling a
  pack must warn about affected current-deck cards, including sideboards.
  Rescan must also update an open deck's faces, preview and legality while
  preserving all names. See the [no-pack audit](pack-menu-no-packs-audit.md).
- **Options → Card Packs:** Open Folder, Rescan, enabled state, version,
  missing/incompatible/invalid status and a readable rejection reason.
- **Art:** gold set glyph on cards plus matching stone On/Off medallions.
  Extend `tools/draw_our_art.gd` for the established code-native style;
  update `game/art/README.md` provenance and checksums.
- **Help:** explain new abilities and any digital adaptations, not only
  their internal engine names.

Test the smallest supported window as well as the normal one. Long set names
and additional rows must scroll or resize rather than cover Close/Done.

## 7. Verification and evidence

Use separate scratch/profile directories outside the source tree. On macOS,
`XDG_DATA_HOME` alone is not sufficient isolation: use the repository's
`SHANDALAR_TEST_DATA_HOME` wrapper and `shandalar_test` feature. Never rewrite
the player's settings or saved decks to make a screenshot/test pass.

- Add the new Python tests and metadata fixture to `run_tests.sh`.
- Run focused catalogue, engine, AI, loading/metadata and UI tests first.
- Run the **full wrapper** after the final code change. Its exit status is
  authoritative: GUT can skip a script that fails to load and still print
  a misleading passing summary. Investigate script errors and leaks.
- Run all Python tests and formatting/whitespace checks.
- Run seeded in-engine campaigns with decks that actually contain the new
  mechanics under both rules profiles; log completion, stalls and errors.
- Run matched Deck Lab candidate/null/control arms with the same seeds and
  seat swaps, `--no-elo`, no challenge information. Record results honestly;
  a small sample does not establish a universal win-rate improvement.
- Run real duel-screen soaks with both stock and pack decks. They cover
  human payment/target/choice flows that headless AI-only duels cannot.
- Capture real rendered menu, Extras, filtered collection and card previews.
- Export a desktop build, give an isolated profile the **real** ZIP and probe
  every dormant script, texture and image. Editor success is not export
  success. Verify the build signature where applicable.
- Confirm the ordinary player's settings/decks are unchanged and the
  release archive cannot contain generated packs or downloaded art.

Do not edit rules files while a running test or duel may lazily load them.
Run tests sharing an isolated profile sequentially. Keep logs outside Git;
write the commands, counts, failures/fixes, adaptations and evidence paths
(portable relative paths) in the pack's audit document.

## 8. Document, review and publish source only

Update README, the pack audit, Help, CODE_MAP, the dated ROADMAP entry,
mechanics/simplification documentation and provenance in the same change.
Separate verified results from remaining limitations. Check every tracked
path for accidental art caches, ZIPs, player files, absolute home paths and
private author details. Use the repository's pseudonymous Git identity.

The source commit includes the dedicated construction tool, metadata,
trusted rules, tests, authored UI assets and documentation. **It does not
include or attach the constructed pack or fetched card art.** Users build
their local ZIP with the supplied script. Commit and push only when asked;
publishing a release or uploading an asset requires its own authorization.

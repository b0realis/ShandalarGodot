# Pack 4 — Homelands

Homelands (`hml`, October 1995) contributes **115 distinct card names across
140 published printings**. All 115 names are new to the original 897-card
game. Original + Pack 4 is **1,012 unique cards**. With all four packs enabled,
the pool is **1,860 named set entries · 1,464 unique cards**. Repeated printings
and cross-set reprints do not create independently playable identities.

## Build it locally

```sh
python3 tools/pack_4_homelands.py fetch
python3 tools/pack_4_homelands.py fetch-art
python3 tools/pack_4_homelands.py build
python3 tools/pack_4_homelands.py verify
```

The dedicated standard-library Python tool defaults to
`../shandalar-packs/Pack-4-Homelands.zip`. Artwork downloads resume safely;
ZIP creation is deterministic and atomic. Verification checks the exact
inventory, metadata and artwork SHA-256 digests, pack version and minimum
game version. A metadata-only test fixture is not a valid player pack.

The ZIP holds **230 selected-printing images**: one illustration crop and
one full-card scan per name. These are two views of the same printing, not
two different artworks. Alternate printings remain in the metadata. Legacy
art aliases make 460 artwork paths in the archive, not 460 distinct images.
Only construction scripts and metadata belong in the repository or public
release; **never distribute the generated ZIP or downloaded artwork**.

Use the updated game checkout/export containing the Homelands loader and
trusted rules; the already published 0.20.0 release predates optional packs.
No other pack is required. Installing the archive does not enable it silently.

## Player-facing integration

- The main menu has a compact **4-HML** information/enable button beside the
  original set strip. The strip keeps its old height.
- Options → Card Packs exposes status, version, enable/disable, rejection
  reasons, Open Folder and Rescan for all four packs.
- Deck Builder → Extras has five centered On/Off rows: 1997 and Packs 1–4.
  Hide every other source to see exactly 115 Homelands names. These are view
  filters; they do not silently edit decks or disable gameplay packs.
- A gold globe marks Homelands cards; matching bright/dim stone medallions
  follow the existing crown and snow-crystal buttons. No external art is
  required for those UI symbols.
- Set filtering selects the appropriate printing artwork. Saved decks stay
  name-based, with existing explicit printing pins and required-pack metadata.
- Two final Help pages explain Homelands resources, locks, redirection,
  shroud permission, costs, graveyard targets and ownership.

## Engine audit

Every new identity has executable rules; catalogue tests and the exported
probe reject the `_pending` guard. This is coverage of the complete set,
not an assertion that every possible cross-card interaction is proven.

The audit adds or verifies:

- Memory Lapse counters directly to library top, without a false graveyard visit.
- Timmerian Fiends moves the actual cards from their current zones and changes
  ownership, not just battlefield control. Its owner chooses whether to ante.
- Optional multi-target triggers choose count and distinct targets before
  entering the chain; held human choices replay safely. Graveyard/exile and
  battlefield incarnation stamps prevent an old trigger hitting a returned card.
- Giant Oyster's independent lock ends on the first untap/departure; retapping
  does not restart it. Release removes all -1/-1 counters on the original target.
- Hazduhr and Daughter use metered creature redirection. Split packets keep
  original source, incarnation, combat status and shared prevention receipts.
  A replacement cannot apply to its own split again; classic redirected damage
  opens its second prevention window. Journal undo restores every budget.
- Player-bound “your next untap” delays survive control changes correctly.
  Other ordinary untap restrictions remain distinct.
- Counter-removal events support Orcish Mine's last-counter trigger, including
  costs and replacement removals without premature mid-payment state checks.
- Last attachment and combat-pair snapshots support Funeral March, Mammoth
  Harness, Labyrinth Minotaur and end-of-combat Clockwork/Werewolf effects.
- All 350 catalogue creature types can be chosen for An-Zerrin Ruins, even
  when the chosen type has no current representative on the battlefield.
- Marjhan's no-Island sacrifice is a respondable state trigger. Regeneration,
  sacrifice and destruction-without-regeneration remain separate operations.
- Shroud permission is per player; Irini's surcharge applies once to a
  green-and-white enchantment; Koskun Falls' full attack cost is aggregated.
- Tribal and flying bonuses use current characteristics, not printed names.
  Token creation, upkeep sacrifices, world rules, poison removal, delayed
  draws, coin choices and Homelands' five mana-filter lands reuse shared rules.

### Explicit adaptation

**Timmerian Fiends: token copies cannot participate in ownership exchanges.**
The ordinary nontoken ownership/ante flow is implemented. The restriction is
visible in the card, manifest, Help and [simplified-card ledger](simplified-cards.md).
Existing engine-wide adaptations remain documented in the roadmap.

## AI audit

Card-local effects expose semantic roles and parameters; the AI policies do
not switch on card names. Ordinary typed effects continue through the shared
AI. The existing `forecasts_tactics` switch provides a previous-policy/null
arm; standard difficulty presets and their mistakes are unchanged.

The new layer handles sustained locks, finite-counter attacks, minimum useful
redirection X, bounded Clockwork recharging, own-hand tribal deployment,
escaping a public creature ban, paid untapping, pre-block evasion, tribal
pumps, delayed damage, public sweep value and custom spell timing/targets.
Negative Auras aim at opponents. Regeneration recognizes an Aura's host;
shroud permission is bought for a known useful own Aura, not repeatedly.
An optional life-for-combat-damage offer must not throw away a lethal attack.
The attack budget retains an affordable subset instead of trying an
unaffordable army and falling back to no attackers.

Forecasts are bounded, journaled public-damage/characteristic comparisons,
not game-copy search. They do not read opposing hands, either library's
contents, future coin flips or future random state. Unmodelled damage
replacement ordering is conservative. This is useful heuristic play, not
optimal strategy or exhaustive combo planning; rare ownership offers,
long-term lock choices and some cantrip timing remain conservative.

## Reproducible campaigns

`tools/pack_4_duel_audit.gd` runs nine themed 60-card decks with rotating
opponents under modern and Fifth Edition rules and records actual casts and
activations. `tools/pack_4_deck_lab.gd` wraps the existing candidate/null/control
instrument, requires the isolated test profile, enables Pack 4 in memory and
forces `--no-elo --procs 1`; `--jobs` may select worker threads.
`tools/pack_4_ui_soak.gd` reuses the real DuelScreen and existing human
clicker with four Homelands deck themes. Run it separately from GUT and
other UI soaks because they share the disposable settings profile.

```sh
. tools/runtime.sh
shandalar_find_godot
shandalar_find_timeout
shandalar_test_profile
export SHANDALAR_PACK_4="../shandalar-packs/Pack-4-Homelands.zip"
"$SHANDALAR_TIMEOUT" -k 5 900 "$GODOT" --headless --path . \
  --script res://tools/pack_4_duel_audit.gd -- --rounds 10 --seed 54000
"$SHANDALAR_TIMEOUT" -k 5 900 "$GODOT" --headless --path . \
  --script res://tools/pack_4_ui_soak.gd -- --rules modern --count 3 --mode both --pace 0
# Repeat the UI command with --rules fifth.
```

The export has a `--verify-pack-4` probe for the real ZIP: all 115 dormant
scripts, all 230 selected-printing images, three UI textures and new effect
types must load. It changes pack selection only in memory.

```sh
./build_release.sh --macos --out ../shandalar-build/pack-4-macos
# With SHANDALAR_PACK_4 pointing to the real ZIP:
../shandalar-build/pack-4-macos/Shandalar.app/Contents/MacOS/Shandalar \
  --headless -- --verify-pack-4
```

The measured Lab decks each contain 24 of the named basic land and four
copies of each of the following nine cards. They are study fixtures, not
new shipped starter decks:

- `hml-blue.deck` (Island): Giant Oyster; Reveka, Wizard Savant; Sea Sprite;
  Coral Reef; Wall of Kelp; Memory Lapse; Merchant Scroll;
  Serrated Arrows; Clockwork Swarm.
- `hml-white.deck` (Plains): Hazduhr the Abbot; White Knight; Abbey Matron;
  Aysen Bureaucrats; Serra Paladin; Ambush; Serrated Arrows;
  Clockwork Steed; Serra Bestiary.
- `hml-red.deck` (Mountain): Anaba Shaman; Anaba Bodyguard;
  Anaba Spirit Crafter; Didgeridoo; Lightning Bolt; Ambush Party;
  Dwarven Pony; Dwarven Trader; Retribution.

Use the ordinary `4 Card Name` deck-file syntax, preserving the order above
(basic land first) for exact seeded replay, then run:

```sh
"$SHANDALAR_TIMEOUT" -k 5 900 "$GODOT" --headless --path . \
  --script res://tools/pack_4_deck_lab.gd -- \
  --deck-a /absolute/path/hml-blue.deck --deck-b /absolute/path/hml-red.deck \
  --games 200 --jobs 4 --seed 55000 --sweep forecasts_tactics=on,off \
  --control-deck-a big_green.deck --control-deck-b white_knights.deck \
  --no-elo --out /absolute/path/results-blue
# White study: hml-white.deck in seat A, seed 56000, a separate output folder.
```

## Acceptance record

Verified locally on 2026-09-15, Godot 4.7.2, macOS:

- Full GUT: **6,789/6,789 tests**, **264,578 assertions**, 404 scripts,
  398.512 seconds, wrapper exit 0. Existing orphan/deprecation warnings
  remain; this is not a warning-free-suite claim. Pack-focused gate:
  **98/98 tests / 2,232 assertions**, including 13 AI regressions.
- Python tool gate: **250 tests**, one platform-specific skip, exit 0.
- The real ZIP passes the dedicated verifier, including all art checksums.
- **180/180 complete Homelands duels**: nine decks, ten rotating rounds,
  90 modern seeds 54000–54089 and 90 Fifth Edition seeds 154000–154089.
  No failed, stalled or unfinished games. Actual-use counts include Giant
  Oyster 113, Serrated Arrows 247, Didgeridoo 80, Drudge Spell 48, Reveka 54,
  Willow Priestess 32, Joven's Tools 49 and Hazduhr 1 activations. Clockwork
  recharging is proved by an actual-action unit test, but was not observed
  in this campaign. Timmerian Fiends was not in these study decks.
- **2,400 matched Lab games** in two final-runtime studies: 200 games per
  arm, three arms (null/off/on), test and control pair, alternating play/draw.
  Zero stalls/draws. The control is Big Green versus White Knights; every
  arm reproduces all 200 null fingerprints, in both studies. Off also
  reproduces the test null. No Elo writes. The first blue study was repeated
  after the final packet fixes; its full game CSV replayed identically.

| Test pair (seat A vs B) | Null | New layer | Delta vs null |
| --- | ---: | ---: | ---: |
| Homelands blue vs red, seed 55000 | 9.0% | 38.5% | +29.5 ±7.8 points |
| Homelands white vs red, seed 56000 | 6.5% | 18.0% | +11.5 ±6.3 points |

Intervals above are the Lab's reported 95% delta intervals. These are positive
results in two deliberately mechanic-rich matchups, not a general strength
ranking or proof of optimal play. Only seat A changes; seat B keeps the old
policy. Both white policies still lose most games against the red study deck.

Native viewport captures verified the compact four-pack main menu, the
115-name Homelands-only Extras filter, selected-printing artwork and gold
emblem, final Help page and scrolled Options entry. The locked-Mac capture
skill renders fresh real scenes; it does not capture an existing duel or
unlock the desktop. Player settings remain byte-identical.

A fresh local macOS debug export smoke-boots successfully. Its real-ZIP
`--verify-pack-4` probe passed: 1,012 loaded identities, all 115 trusted dormant
Homelands scripts, all 230 decoded art images and three UI textures, zero
pending rules, with the typed redirection effect and public AI annotations
present. The temporary test-profile override was removed; the app's ad-hoc
signature then passed strict verification. The ZIP was not placed inside the
bundle. This tests macOS locally, not Windows/Linux/Web exports or notarization.

**24/24 real-DuelScreen UI soak duels passed**: 12 original-deck controls
and 12 Homelands games. Each pool ran seeds 1000, 1037 and 1074 in demo and
fuzzed-human modes under both modern and Fifth Edition rules. All four runs
reached `SOAK done`, exited 0, and had no ERROR/WARNING/STALL lines. The
Homelands human seed 1037 ran 45 turns and 492 clicks in each ruleset. These
were renderer-free UI soaks; the separate native captures check presentation.

Local evidence is under `../shandalar-build/pack-4-work/` relative to the
checkout: `gut-final.log`, `python-full.log`, `duel-audit-final.log`,
`lab-blue-final/`, `lab-white/`, `soak-{stock,hml}-{modern,fifth}.log`,
`export-pack4-probe.log`, `build-macos.log` and `hml-*.png`. Generated study
decks, results, screenshots, exported app, card artwork and ZIP are not
checked into the source repository. No release or online push was performed.

## Sources

[Scryfall Homelands catalogue](https://scryfall.com/sets/hml), its checked-in
Oracle snapshot and [creature-type catalogue](https://api.scryfall.com/catalog/creature-types).
Forge cross-check details and the original procedural UI artwork are recorded
in the [historical source audit](https://github.com/b0realis/ShandalarGodot/blob/04305db4599868acdcc8c84b698982188c9e4030/Provenance.md#homelands-pack-4-2026-09-15)
and the [art inventory](../game/art/README.md).

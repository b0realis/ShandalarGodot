# Pack 9 — The Tempest Block

`Pack-9-Tempest-Block.zip` brings the whole Tempest block as one optional,
independent expansion: **Tempest** (October 1997), **Stronghold** (March
1998) and **Exodus** (June 1998) — the block that followed the 1997 game to
the table. Three Scryfall sets in one pack, as Pack 8 holds the Mirage
block:

| Set | Code | Printings | Names | Reprints | New identities |
|---|---|---|---|---|---|
| Tempest | `tmp` | 350 | 335 | 5 basics + 31 | 299 |
| Stronghold | `sth` | 143 | 143 | 6 | 137 |
| Exodus | `exo` | 143 | 143 | 5 | 138 |
| **Pack 9** | | **636** | **621** | **47** | **574** |

No name repeats across the three sets. Core + Pack 9 is 1,518 set entries /
1,498 unique cards (the 897 of the core, 574 new identities and the 27
shared reprints Pack 9 provides on its own); all nine packs have **4,083
set entries / 3,093 unique cards**, 574 more than eight.

Only the construction source, reviewed metadata and rules and original UI
symbols are distributed. The generated ZIP and downloaded card pictures
remain local. The pack requires **Shandalar 0.50.15 or later**.

## Construct and install

From the project root (or the extracted game folder), with Python 3.10+,
network access and source matching the game version you will run:

```sh
python3 tools/pack_9_tempest_block.py fetch-art
python3 tools/pack_9_tempest_block.py build
python3 tools/pack_9_tempest_block.py verify
```

`python3 tools/pack_9_tempest_block.py fetch` is the maintainer's
catalogue-refresh command. It rewrites the trusted source metadata
(`cards.json`, `cards_sth.json`, `cards_exo.json` and the three `set*.json`
files): review any upstream Oracle or data changes and rebuild the matching
game, rather than refreshing that snapshot under an older installed
executable. Ordinary local construction uses the checked-in snapshot and
does not require `fetch`.

The default ZIP is `../shandalar-packs/Pack-9-Tempest-Block.zip`; the
resumable art cache is `../shandalar-packs/cache/pack_9_art/` (one folder
per set, about 125 MB). Supply a positional output path and `--art-dir` to
change those locations — for a portable game,
`build cardpacks/Pack-9-Tempest-Block.zip`. Every one of the 636 printings
is pinned by Scryfall ID and fetched as an **art crop and a full-card
scan**: 1,272 pictures under the pack's own `art/tmp/`, `art/sth/` and
`art/exo/` namespaces, plus `skin/cardart/` fallbacks (1,202 files) for the
574 new identities and the 27 shared names, so those cards draw a picture
with no other pack installed. With the four metadata files the archive
holds **2,478 entries**, never a script. Two image forms do not mean two
playable copies of a card.

Use **Options → Card Packs → Open Folder**, put the exact-named ZIP there,
then **Rescan** and enable Pack 9. Development runs may instead set
`SHANDALAR_PACK_9` to the absolute ZIP path. No other pack is required. On
Windows `py -3` may replace `python3`; on Mac `cardpacks/` belongs beside
the app, not inside it; the web build offers no import path for numbered
packs (see [card-art-and-packs](card-art-and-packs.md)).

The main menu shows **9-TMP**. Deck Builder → **Extras** has a separate
On/Off row for each set — *Tempest Pack 9*, *Stronghold Pack 9* and
*Exodus Pack 9*. Turn the other sources off to browse exactly a set's
names (335, 143 and 143). These visibility filters do not unload a globally
enabled pack or edit an existing deck. Tempest has four illustrations for
each basic land, chosen as `tmp:<number>` variants (331–350) through the
**Card variant** medallion below the Deck Builder's preview; every other
name has one printing. Decks stay name-based and record required packs;
loading while disabled offers the enable flow.

The emblems are our own drawings: Tempest a heaped **storm** cloud with a
lightning bolt, evocative of the set; Stronghold an arched **gateway** with
a portcullis and Exodus an arched **bridge**, the sets' own marks redrawn
to the owner's reference on 2026-10-10 (they were a fortress keep and a
bird in flight until the owner asked for them *"more like originals"*).
`tools/draw_our_art.gd` (`_storm`, `_gateway`, `_bridge`) draws each in
the gold card relief and the lit/dim carved-stone medallions; the hashes
are in `game/art/README.md`.

## Rules, reprints and providers

Every new identity has one trusted file, `cards/sets/<set>/<snake_case>.gd`,
whose header carries the exact Oracle text of the snapshot. Each set's
`_rules.gd` is a fail-closed dispatcher that asks its family modules in a
fixed order — `_basic`, `_spells`, `_creatures`, `_auras`, `_artifacts`,
`_lands_mana`, `_combat`, `_triggers`, `_choices`, `_costs`, `_buyback`,
`_shadow`, `_licids`, `_slivers`, `_spikes`, `_misc` — and puts a
`_pending` cast guard ("Tempest block rules integration is not yet
complete for this card") on any card no module claims. A pending card is in
the pool, visible and deck-buildable, but cannot be cast.
`tests/cards/test_pack_9_catalogue.gd` ends with the catalogue gate that
refuses any remaining guard.

The 47 reprints keep their existing scripts; no competing script is
written. Twenty are in the 1997 pool (the five Circles of Protection,
Counterspell, Dark Ritual, Disenchant, Gaseous Form, Giant Strength, Power
Sink, Shatter, Spell Blast, Stone Rain, Tranquility and the five basic
lands) and need no pack. The other 27 live only in an optional pack —
Portal (21), the Mirage block (4: Dream Cache, Enfeeblement, Pacifism,
Rampant Growth), Portal Second Age (Coercion) and Ice Age (Dark Banishing)
— and are keyed to the folder of their script in
`packaging/card_packs/pack_9_tempest_block/shared_names.json`, exactly as
Fifth Edition's and the Mirage block's reprints are.
`TempestBlockPack.scripts()` loads them with the block set they were
printed in; `CardPacks._configure_registry` walks the earlier packs first,
so their script and symbol win when both are on. A deck that uses a shared
card needs **any one** enabled provider (`CardPacks._shared_provider`): the
original pack first, then Portal, Fifth Edition, the Mirage block and the
Tempest block.

## Archive contract

The loader (`game/tempest_block_pack.gd`) checks the exact inventory,
trusted metadata, minimum version and SHA-256 hashes, with the central
directory's declared sizes checked before reading a member
(`PortalPack.bounded_zip`): 8 MiB per member, 2,478 entries at most, and a
**384 MiB** budget like Pack 8's. The real archive measured 237.3 MiB of
members (248,379,150 bytes on disk, 2026-10-06), 92.7% of the 256 MiB the
first seven packs allow — too close to that bound to share it. Builds are
staged, verified and atomically replaced; identical inputs produce
identical ZIP bytes. Metadata-only archives are accepted solely under the
isolated test feature, never as player packs.

## Engine review

Every one of the 574 names is implemented: no card carries the pending
guard (`test_pack_9_catalogue.gd::test_no_tempest_block_card_is_pending`).
A read-only inventory first sorted every Oracle clause into capabilities
the engine already had and ones it lacked: 474 cards were buildable on the
existing engine, 100 needed 28 missing capabilities. Those were built as
reusable engine mechanisms (packages E1–E8, `tests/unit/test_pack_9_engine_*.gd`)
before or alongside the cards that use them; twelve card batches then
filled the family modules, each with its own test scripts
(`tests/cards/test_pack_9_B*_*.gd`). Several mechanics the block is known
for needed no new engine: Slivers grant their abilities — keywords,
anthems, shroud and granted activated abilities — to every Sliver on the
battlefield, both players', through the existing class-grant shape;
Spikes, Mox Diamond's entry payment, the Oaths, Living Death, Cataclysm,
Recurring Nightmare, Survival of the Fittest, Scroll Rack, Volrath's
Stronghold, Furnace of Rath, Coat of Arms and Mind Over Matter were built
on existing mechanisms.

**New engine mechanisms** (`docs/mechanics.md` has a row for each):

- **Shadow** (CR 702.28) as a keyword, printed or granted, both ways: a
  creature with shadow can be blocked only by creatures with shadow and can
  block only them. "Can block creatures with shadow as though it had
  shadow" (`CombatState.blocks_shadow`), and a dying creature's keywords
  remembered for "whenever a creature with shadow dies" (`had_keyword`).
- **Combat requirements:** "blocks each combat if able", "blocks this turn
  if able" (Provoke, Invasion Plans) and Magnetic Web's conditional attack
  requirement, enforced by `declare_blockers`/`declare_attackers` and
  honoured by the AI's attack and block repair.
- **Payment rows:** **buyback** as an additional cost the caster chooses
  (resolved → owner's hand; countered, fizzled or copied → not returned),
  Memory Crystal's buyback discount, granted alternative costs (Dream
  Halls, Aluren) and granted flash (Rootwater Shaman), all as payment rows
  picked through the existing casting path — `cast_spell` gained no
  parameter (`MtgGame.payment_rows`, `payment_option_for`).
- **Licids** (`CardData.as_licid`, `MtgGame.become_licid_aura`): a creature
  becomes an Aura on the target creature and keeps its other abilities;
  "pay to end this effect" is a special action any time its controller has
  priority; Volrath's Curse's "sacrifice a permanent to ignore" is another
  (`MtgGame.special_actions`).
- **Layers:** ability-removing effects such as **Humility apply in
  timestamp order** (CR 613.7) — an ability granted later than Humility
  survives, one granted earlier is lost, and P/T-setting effects apply in
  timestamp order too; P/T-defining abilities that count abilities apply
  after ability changes (Dauthi Warlord); a permanent that becomes a copy
  of the top card of a graveyard in place (Volrath's Shapeshifter).
  Triggered abilities granted after a silencing effect fire; older packs'
  ability grants were flagged so the ordering sees them, and Animate
  Artifact's type change moved to its own layer.
- **Stack:** a delayed spell put back on the stack by the card itself
  (Ertai's Meddling), "can't be countered" (Scragnoth), and a copy of a
  permanent spell resolving as a token (CR 608.3f).
- **Costs and targets:** random discard, a card from hand on top of the
  library and removing a counter as costs; an ability cost reduction with a
  mana floor (Heartstone); a target count fixed by an earlier choice
  (Reap); a trigger's target chosen by another player (Pandemonium);
  retargeting a spell or ability (Silver Wyvern).
- **Durations:** an untap cap over any permanents (Static Orb), a text
  change until end of turn (Whim of Volrath), control while a creature is
  enchanted (Rootwater Matriarch).

**Engine-wide fixes found on the way:** state-based actions are checked
whenever a player would receive priority, including after a mana ability's
counter cost (CR 704.3, CR 117.3c); continuous effects are recalculated
when a hand changes and as attackers and blockers are declared, so
hand-size statics (Ensnaring Bridge, Maro) are judged live; a cost record
keeps a sacrificed creature's toughness, so a token is counted after it
ceases to exist (CR 111.7).

### Explicit digital adaptations

Engine-wide row (`docs/ROADMAP.md`): *A licid keeps its entry timestamp
when it becomes an Aura* (`become_licid_aura`). Card rows
(`docs/simplified-cards.md`): *Living Death (Pack 9)* — the returned cards
enter one after another; Skeleton Scavengers joining *Debt of Loyalty;
Matopi Golem*; Whim of Volrath joining *Text changes*. Help → Abilities
explains each in plain words. Humility, which the inventory offered as a
fallback candidate, is implemented as printed.

## AI review

Two modules teach the fair AI the block's new shapes, both behind the
existing `forecasts_tactics` capability (no new difficulty scale; with the
gate off the AI plays exactly as before Pack 9, which every test file pins
with a null arm). Policies read the public board and the AI's own hand
only; the tests that could be swayed by a hidden zone replay the decision
with the opponent's hand and the library order changed.

- `engine/ai/tempest_spells.gd` (casting and spell readers, hooked from
  `AiPlayer`): responses pay through the payment row they were offered;
  Dream Halls and Aluren rows when what they eat is worth less than the
  mana saved; buyback paid only when it can afford to recast and keep
  developing (X sized first, Forbid's two cards, a life floor); Memory
  Crystal valued from the AI's own buyback cards; counterspells not wasted
  on Scragnoth; Ertai's Meddling at its best X; Reap's count from the
  opponent's black permanents; symmetric sweepers (Cataclysm, Living
  Death, Fade Away, Limited Resources, Price of Progress, Apocalypse…)
  priced by what each side loses; combat tricks (Kor Chant, Fighting
  Chance, Temper, Rebound…) held for their moment; hostile Auras —
  Volrath's Curse, Contempt, Torment, Shackles, Paroxysm — on the
  opponent's creatures; Mox Diamond only with a spare land; Hatred's life
  kept above the opponent's attack.
- `engine/ai/tempest_tactics.gd` (board, combat, activations): shadow as
  evasion and its tricks before blocks only (CR 506.4); Reality Anchor;
  Magnetic Web's dragged attackers priced and Exalted Dragon attacking;
  licids on its own creatures and **hostile licids on the opponent's**,
  priced by the attack they deny, and a licid's effect ended to save it;
  Volrath's Curse ignored for a worthwhile attack; **Spikes' counters**
  spent only when the Spike would die anyway, and in combat only the
  counters its kill does not need (read from the combat forecast); Sliver
  grants valued on both sides; the Keepers' opponent condition, Starke of
  Rath, Pandemonium's aim, the en-Kor and Silver Wyvern redirects, Cold
  Storage, Jinxed Idol, Echo Chamber (the opponent's weakest creature is
  what it copies) and about twenty more activations.

Deck Lab, matched candidate/null/control arms (`--sweep
forecasts_tactics=on,off`, Wizard v Wizard, 200 games an arm, Pack 9 only,
`--no-elo`; the Big Green v White Knights control replayed byte-identically
in every arm). As with Pack 8, the study caught a regression the unit tests
missed: Spikes cashing every counter before combat damage, losing the kills
they were about to make, cost the Spikes deck −9.5 ± 7.6 against the
Licids deck (seed 98100). An ablation pinned it on that policy. With the
fix:

| Study | Seed | Null/off | On | Delta, 95% margin |
|---|---:|---:|---:|---:|
| Spikes v Licids | 98100 | 85.5% | 87.5% | +2.0 ± 6.7 |
| Buyback v Humility | 98000 | 25.0% | 33.5% | +8.5 ± 8.8 |
| Licids v Humility | 98200 | 76.0% | 78.0% | +2.0 ± 8.2 |
| Humility v Licids | 98300 | 26.5% | 25.0% | −1.5 ± 8.5 |

The AI agents' own studies on their decks (200 games an arm unless noted):
W/B v G/R +9.5 ± 7.9, U/W v B/R +1.5 ± 9.2, G/R v W/B +5.0 ± 8.1, B/R v
U/W +13.0 ± 9.2; and at 100 games an arm, blue-red +13.0 ± 12.9 and
white-black +14.0 ± 12.5. Most deltas sit inside their margins; the
samples are small and do not establish a universal improvement, only that
no measured pairing is significantly worse.

**Known AI limits** (rules complete; the AI simply does not use these
well): a Sliver lord is cast without weighing the opponent's Slivers it
also arms; Mounted Archers' extra block and Tempting Licid's lure are not
read by the combat planner; Altar of Dementia's sacrifice picks the
cheapest creature, not the doomed one; Excavator, Mogg Cannon, Crazed
Armodon, Carrionette, Vhati, Fylamarid, Amok, Sword of the Chosen,
Tortured Existence, Volrath's Gardens, Volrath's Shapeshifter's discard,
Flowstone Blade, Phyrexian Splicer and Shaman en-Kor's second ability are
not activated, nor Ephemeron's and Thalakos Scout's discard-cost abilities
(the AI refuses discard costs outside Fallen Empires and Ice Age); Hand to
Hand, Light of Day, Nature's Revolt, Storm Front, Crossbow Ambush, Leap,
Ruination, Provoke, Reconnaissance, Peace of Mind, Volrath's Dungeon,
Nausea, Reclaim and Renegade Warlord use the generic readings; Whim of
Volrath and Fling are deliberately never cast. (The Tempest bug pass
taught it the Oaths, Furnace of Rath, Ensnaring Bridge, Jinxed Idol, Spike
Cannibal, Coffin Queen, Recurring Nightmare and Volrath's Stronghold.)

## Known engine limits

- One end cost is kept per licid: two licid effects from DIFFERENT licid
  abilities on one object (the licid untapped in response and its text
  changed between the activations) both use the first one's cost.
- `_rebuild_battlefield_index` stops registering a card's statics after a
  type-changing or silencing one on the same card; no pool card has that
  order.
- Animate Artifact's size half decides "a creature without this Aura" from
  its own types and until-end-of-turn animations, so on an artifact
  another effect animated it applies the same mana-value size; only its
  ordering against a Humility can differ.

## Verification

- `python3 tools/test_pack_9_tempest_block.py`: offline builder tests
  (exact three-set inventory and counts, reprint and shared lists against
  the core and every earlier pack, deterministic art archive,
  metadata-only refusal, injected/duplicate entries, failed-build
  preservation, size bound).
- The catalogue (`tests/cards/test_pack_9_catalogue.gd`, 10/10 — no
  pending card), the integration and Help scripts, the engine scripts
  (`tests/unit/test_pack_9_engine_*.gd`), the twelve batches'
  (`tests/cards/test_pack_9_B*_*.gd`), the AI's
  (`tests/ai/test_ai_pack_9_*.gd`, each with a null arm) and the duel-screen
  and SGManalink scripts, all inside the gate below.
- The duel audit (`tools/pack_9_duel_audit.gd --rounds 12 --seed 97000`):
  432 complete duels — 216 a rules profile, Wizard v Wizard and Wizard v
  Apprentice over nine themed decks — no stall, no error, no refusal loop;
  160 of the 163 block names in the decks cast or played. Per profile
  (modern / fifth): 517 / 513 shadow attackers, 152 / 89 buybacks paid,
  89 / 94 Dream Halls and Aluren rows, 503 / 403 attackers carrying a
  Sliver's granted keyword, 289 / 211 Oath triggers, 33 / 17 Humilities,
  465 / 384 untap steps under Static Orb; after the AI fixes Volrath's
  Curse is cast 52 times and the licids activated 16.
- The duel-screen soaks (`tools/pack_9_ui_soak.gd`, both profiles, ten
  human-seat duels more, and the stock soak): every run exit 0, with the
  human seat taking 33 buyback casts, 29 Dream Halls/Aluren rows, 13
  licid-end special actions, 14 Reaps and 166 payment rows in all.
- An exported Linux build with an isolated profile and the **real** ZIP
  (`--verify-pack-9`): *PACK 9 EXPORT RESOURCES OK — 1498 identities;
  601/601 dormant scripts loaded; 1272/1272 artwork pictures and 1202/1202
  skin fallbacks decoded; 9/9 UI textures; 0 rules pending*; the same
  build's `--verify-pack-8` stays OK.

## Reproduce the checks

Use the repository's isolated profile, never the player's settings or decks:

```sh
SHANDALAR_TEST_DATA_HOME=../shandalar-build/pack-9-work/gate-testdata \
  SHARDS=4 SUITE_TIMEOUT=3600 ./run_tests.sh
python3 -m unittest discover -s tools -p 'test_*.py'
git diff --check

. tools/runtime.sh
shandalar_find_godot
shandalar_find_timeout
shandalar_test_profile
export SHANDALAR_PACK_9="$PWD/../shandalar-packs/Pack-9-Tempest-Block.zip"
"$SHANDALAR_TIMEOUT" -k 5 5400 "$GODOT" --headless --path . \
  --script res://tools/pack_9_duel_audit.gd -- --rounds 12 --seed 97000 --pilots both
xvfb-run -a "$SHANDALAR_TIMEOUT" -k 5 1500 "$GODOT" --path . \
  -s res://tools/pack_9_ui_soak.gd -- --rules modern --count 5 --mode both --pace 0
# Repeat with --rules fifth; also run the stock tools/duel_soak.gd both ways.

DeckLab/deck_lab.sh --deck-a p9_spikes.deck --deck-b p9_licids.deck --packs 9 \
  --games 200 --seed 98100 --sweep forecasts_tactics=on,off \
  --control-deck-a big_green.deck --control-deck-b white_knights.deck --no-elo \
  --out ../shandalar-build/pack-9-work/lab-spikes
# And p9_buyback v p9_humility (98000), p9_licids v p9_humility (98200),
# p9_humility v p9_licids (98300).

./build_release.sh --out ../shandalar-build/pack-9-work/linux64
# With the real ZIP in SHANDALAR_PACK_9 and an isolated XDG_DATA_HOME:
../shandalar-build/pack-9-work/linux64/Shandalar.x86_64 --headless -- --verify-pack-9
```

The audit's nine themed decks (Shadow, Slivers, Licids, Spikes, Buyback,
Oaths, Humility, Stronghold, Artifacts) are the `DECKS` table of
`tools/pack_9_duel_audit.gd`; the study's `p9_*.deck` files are those lists
written one `count name` per line. With four shards the suite needs a longer
per-shard guard than the default 30 minutes (`SUITE_TIMEOUT=3600`).

## Acceptance record — 2026-10-06

- **Gate** (`SHARDS=4 SUITE_TIMEOUT=3600 ./run_tests.sh`): 737 scripts,
  12,198 tests, 550,522 asserts, every shard exit 0 — and after the bug
  pass (`docs/bug-pass-2026-10-06-tempest.md`, 42 findings fixed) **758
  scripts, 12,410 tests, 559,259 asserts**, every shard exit 0. The first run
  (default per-shard guard) timed one shard out at 30 minutes while it was
  still working, and showed four reading-pins the pack changes: two X-entry
  0/0 creatures (Krakilin, Shifting Wall) joined the generated pool's
  reviewed list of counted bodies, and the three damage-gate surveys were
  re-taken with the new writers named (prevention pools 24 → 29, combat
  shields 13 → 15, the Circle family 12 → 13).
- **Python**: 608 tests, 15 skipped, OK.
- **Counts**: core + Pack 9 1,518 set entries / 1,498 unique cards; all
  nine packs 4,083 / 3,093 (pinned in `test_sgmanalink_packs.gd`).
- **Deck Lab**: the four study rows above, all inside their margins or
  positive after the Spikes fix; controls byte-identical.
- **SGManalink**: protocol 28, `RULES_REVISION`
  `sgmanalink-tempest-block-2026-10-06`.
- **Version**: 0.50.15; the pack's `minimum_game_version` is 0.50.15.

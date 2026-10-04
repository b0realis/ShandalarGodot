# Pack 8 — The Mirage Block

`Pack-8-Mirage-Block.zip` brings the whole Mirage block as one optional,
independent expansion: **Mirage** (October 1996), **Visions** (February
1997) and **Weatherlight** (June 1997) — the sets a 1997 Shandalar player
was opening at the table. Three Scryfall sets in one pack, as Pack 6 holds
Portal and Second Age:

| Set | Code | Printings | Names | Reprints | New identities |
|---|---|---|---|---|---|
| Mirage | `mir` | 350 | 335 | 5 basics + 23 | 307 |
| Visions | `vis` | 167 | 167 | 13 | 154 |
| Weatherlight | `wth` | 167 | 167 | 7 | 160 |
| **Pack 8** | | **684** | **669** | **48** | **621** |

No name repeats across the three sets. Core + Pack 8 is 1,566 set entries /
1,549 unique cards (the 897 of the core, 621 new identities and the 31
shared reprints Pack 8 provides on its own); all eight packs have **3,462
set entries / 2,519 unique cards**, 621 more than seven.

Only the construction source, reviewed metadata and rules and original UI
symbols are distributed. The generated ZIP and downloaded card pictures
remain local. The pack requires **Shandalar 0.50.11 or later**.

## Construct and install

From the project root (or the extracted game folder), with Python 3.10+,
network access and source matching the game version you will run:

```sh
python3 tools/pack_8_mirage_block.py fetch-art
python3 tools/pack_8_mirage_block.py build
python3 tools/pack_8_mirage_block.py verify
```

`python3 tools/pack_8_mirage_block.py fetch` is the maintainer's
catalogue-refresh command. It rewrites the trusted source metadata
(`cards.json`, `cards_vis.json`, `cards_wth.json` and the three `set*.json`
files): review any upstream Oracle or data changes and rebuild the matching
game, rather than refreshing that snapshot under an older installed
executable. Ordinary local construction uses the checked-in snapshot and
does not require `fetch`.

The default ZIP is `../shandalar-packs/Pack-8-Mirage-Block.zip`; the
resumable art cache is `../shandalar-packs/cache/pack_8_art/` (one folder
per set). Supply a positional output path and `--art-dir` to change those
locations — for a portable game, `build cardpacks/Pack-8-Mirage-Block.zip`.
Every one of the 684 printings is pinned by Scryfall ID and fetched as an
**art crop and a full-card scan**: 1,368 pictures under the pack's own
`art/mir/`, `art/vis/` and `art/wth/` namespaces, plus `skin/cardart/`
fallbacks (1,304 files) for the 621 new identities and the 31 shared names,
so those cards draw a picture with no other pack installed. With the four
metadata files the archive holds **2,676 entries**, never a script. Two
image forms do not mean two playable copies of a card.

Use **Options → Card Packs → Open Folder**, put the exact-named ZIP there,
then **Rescan** and enable Pack 8. Development runs may instead set
`SHANDALAR_PACK_8` to the absolute ZIP path. No other pack is required. On
Windows `py -3` may replace `python3`; on Mac `cardpacks/` belongs beside
the app, not inside it; the web build offers no import path for numbered
packs (see [card-art-and-packs](card-art-and-packs.md)).

The main menu shows **8-MIR**. Deck Builder → **Extras** has a separate
On/Off row for each set — *Mirage Pack 8*, *Visions Pack 8* and
*Weatherlight Pack 8* — beside the 1997, tDotP and earlier pack rows. Turn
the other sources off to browse exactly a set's names (335, 167 and 167).
These visibility filters do not unload a globally enabled pack or edit an
existing deck. Mirage has four illustrations for each basic land, chosen as
`mir:<number>` variants (Plains 331–334 … Forest 347–350) through the
**Card variant** medallion below the Deck Builder's preview; every other
name has one printing. Decks stay name-based and record required packs;
loading while disabled offers the enable flow.

The emblems are our own drawings, evocative of each set and not copies of
any printed set symbol: Mirage a desert **palm** on a dune, Visions an open
**eye** under three rays, Weatherlight a sailing **skyship** with a swept
wing. `tools/draw_our_art.gd` (`_palm`, `_eye`, `_skyship`) draws each in
the gold card relief and the lit/dim carved-stone medallions; the hashes
are in `game/art/README.md`.

## Rules, reprints and providers

Every new identity has one trusted file, `cards/sets/<set>/<snake_case>.gd`,
whose header carries the exact Oracle text of the snapshot (Unicode
included; `Bösium Strip` is `b_sium_strip.gd`, the same ASCII rule as
`GameSkin` and the builder). Each set's `_rules.gd` is a fail-closed
dispatcher that asks its family modules in a fixed order — `_basic`,
`_spells`, `_creatures`, `_auras`, `_artifacts`, `_lands_mana`, `_combat`,
`_triggers`, `_phasing`, `_choices`, `_costs`, `_misc` — and puts a
`_pending` cast guard ("Mirage block rules integration is not yet complete
for this card") on any card no module claims. A pending card is in the
pool, visible and deck-buildable, but cannot be cast.
`tests/cards/test_pack_8_catalogue.gd` ends with the catalogue gate that
refuses any remaining guard.

The 48 reprints keep their existing scripts; no competing script is
written. Twelve are in the 1997 pool (Boomerang, Dark Ritual, Disenchant,
Divine Offering, Drain Life, Firebreathing, Fog, Healing Salve, Power Sink,
Regeneration, Sandstorm, Stone Rain) and need no pack. The other 31 live
only in an optional pack — Ice Age (4), Homelands (1), Portal (21) and
Portal Second Age (5) — and are keyed to the folder of their script in
`packaging/card_packs/pack_8_mirage_block/shared_names.json`, exactly as
Fifth Edition's reprints are. `MirageBlockPack.scripts()` loads them with
the block set they were printed in, so with Pack 8 alone Archangel wears
the Visions eye and Flare the Mirage palm; `CardPacks._configure_registry`
walks the original packs first (Ice Age, Homelands, Portal, then Fifth
Edition), so their script and symbol win when both are on.

A deck that uses a shared card needs **any one** enabled provider
(`CardPacks._shared_provider`): the original pack first, then Portal,
Fifth Edition and Pack 8. Disabling Portal while Pack 8 is on raises no
warning for Archangel; disabling the last provider warns. Flare, Incinerate,
Ray of Command and Dark Banishing have three providers (Ice Age, Fifth
Edition, Pack 8), Memory Lapse likewise (Homelands, Fifth Edition, Pack 8).

## Archive contract

The loader (`game/mirage_block_pack.gd`) checks the exact inventory,
trusted metadata, minimum version and SHA-256 hashes, with the central
directory's declared sizes checked before reading a member
(`PortalPack.bounded_zip`): 8 MiB per member, 2,676 entries at most, and
**384 MiB** in all. The earlier packs allow 256 MiB; the real archive
measured 253.7 MiB of members (265,757,168 bytes on disk, 2026-10-03),
2.3 MiB under that bound — one re-scanned picture set away from refusal —
so Pack 8 alone carries the larger budget (`MAX_BYTES`, the same number in
the Python builder). Builds are staged, verified and atomically
replaced; identical inputs produce identical ZIP bytes. Metadata-only
archives are accepted solely under the isolated test feature, never as
player packs.

## Engine review

Every one of the 621 names is implemented: no card carries the pending
guard (`test_pack_8_catalogue.gd::test_no_mirage_block_card_is_pending`).
A read-only inventory first sorted every Oracle clause into capabilities
the engine already had (102) and ones it lacked (51); the missing ones were
built as reusable engine mechanisms before any card used them, then ten
card batches filled the family modules with their own test scripts
(`tests/cards/test_pack_8_b*_*.gd`).

**New engine mechanisms** (`docs/mechanics.md` has a row for each):

- **Phasing** (CR 702.26) as a keyword, printed or granted: the untap-step
  action, one-shot phase-outs that return at their controller's next untap
  step, Auras and Equipment riding indirectly, `PHASED_IN`/`PHASED_OUT`
  events, "can't phase out", simultaneous batches (Time and Tide). A
  phased-out permanent is treated as though it doesn't exist
  (`MtgGame.is_present`); the mutation helpers, combat, state-based actions,
  "for as long as" durations, continuous-effect adders, play bans and
  redirects respect it. An audit of the 441 older `zone == BATTLEFIELD`
  sites fixed 104 of them in 64 card files
  (`test_phasing_liveness_audit_2026_10_03.gd`,
  `test_phasing_engine_gaps_2026_10_03.gd`).
- **Turn structure:** skip a turn, skip an untap step (summoning sickness
  still ends, CR 302.6), "as you untap" actions, a main-phase event, and
  triggers from the untap step joining the upkeep's batch in the order
  their controller chooses (CR 503.1a).
- **Flanking** (CR 702.25) as one stack trigger per instance, granted
  instances counted separately; "becomes blocked", the per-blocker life
  tax, "attacks if others attack" and multi-target triggers.
- **Flash**, the Mirage "as though it had flash" rider and seat-wide flash
  grants. **The cleanup step** now orders its turn-based actions as CR 514.3a
  says — discard, damage removal, then triggers with a priority window and
  another cleanup — which also lifted the Bounty of the Hunt / Thawing
  Glaciers simplification of Pack 5.
- **Bans:** activation bans that reach mana abilities and the mana planner
  (Null Rod stops a Mox in auto-pay too), floating play bans, player target
  bans and a `BECAME_TARGET` event.
- **Costs:** return-to-hand, exile from hand or the top of a graveyard,
  X object costs, discarding a hand, alternative costs, life per target,
  once-a-turn and instant-only mana abilities, non-mana cumulative upkeep
  with a "wasn't paid" event; the mana planner considers a source's richer
  row (Crystal Vein).
- **Zones and the stack:** dies-to-library, graveyard-to-exile
  replacement, casting from a graveyard, milled triggers, counter
  destinations (exile, the counterer's battlefield), face-down exiled
  plays, a discard special action and a card becoming an Aura.
- **Damage:** one registry of damage replacements and preventions over any
  victim, used up by an EVENT rather than a packet and ordered by the
  affected player (CR 616.1); damage modifiers, redirects, damage into
  counters, divided prevention, statics that work on the stack, and
  `MtgGame.predict_damage` for the AI.
- **Player state and colour:** per-turn trackers, "can't gain life",
  additive land types, colour outside the battlefield (Celestial Dawn) and a
  seat's colourless-only spending rule.

**Pool-wide fixes found on the way:** an Aura whose enchant restriction
names its controller (Relic Bind, Cocoon, Fire Whip) now falls off on a
control change (CR 303.4d); printed and granted "additional" blocks add up
(CR 509.1b); "loses <keyword>" removes every instance; undo now restores
two cost-question fields it used to leave behind.

### Explicit digital adaptations

Engine-wide rows (`docs/ROADMAP.md`): *A shield's rider runs per packet*;
*Two dying-card replacements are applied in a fixed order*; *Phase-out
look-back is per permanent*. Card rows (`docs/simplified-cards.md`): *Debt
of Loyalty; Matopi Golem (Pack 8)* and Mind Bend joining *Text changes*.
Help → Abilities explains each in plain words. Celestial Dawn, Necromancy
and Torrent of Lava, which the inventory had flagged as fallback
candidates, are implemented faithfully.

## AI review

`engine/ai/mirage_tactics.gd` teaches the fair AI the block's new shapes. It reads
public board state, the stack and its own hand, never a hidden card or library
order, and it names no card. Cards declare roles (`phase_out`,
`phase_out_self`, `phase_out_host`, `phase_swap`, `life_bid_steal`,
`land_balance`, `tariff`, `library_build`) or the policy reads typed effects
(`MakeBlockedEffect`, `SourceShieldEffect`, the flash forms) and printed
lines (the BECAME_TARGET "sacrifice it", Karoo bounces, "skip your next
turn"). Two existing gates cover everything, so difficulty presets are
unchanged. `forecasts_tactics` (every rung) gates correctness readings, and
`reads_gaze` (Sorcerer, Wizard) gates combat readings. With both off, the
pilot plays exactly as before Pack 8.

- **Phasing.** The AI phases its own creature out of a removal spell or a
  lost combat. It phases out their attacker before blocks, which also keeps
  that creature out of our next turn, and their blocker at our beginning of
  combat when the damage this opens through their best blocks is worth the
  card. It casts Time and Tide by the swing. A phasing creature is worth
  about half (`Evaluator.PHASING_SHARE`). Phased-out creatures count as
  returning attackers in the race and crack-back reads, a present phaser of
  theirs is no attacker next turn, and a sweeper waits while most of its
  targets are away.
- **Flash.** A flash creature waits for the opponent's turn only when the
  hold pays for its tempo. Their board must offer an ambush (an attacker it
  would block, kill and survive) and nothing else in our hand may want the
  mana; otherwise it is cast in our main phase. A waiting creature is cast
  as a surprise blocker when it kills an attacker and lives or stops lethal
  damage, and otherwise at their end step. A flash-rider pump Aura waits out
  the first main phase only while one of our attackers could be blocked (the
  attack may count on it, as on a Giant Growth). It is cast after blocks as a
  one-turn trick where it wins or saves a fight (it is sacrificed at
  cleanup), and otherwise in the second main phase for keeps. A shroud or
  chosen-colour ward Aura answers a targeted removal spell.
- **Targets and bans.** The AI never targets its own Skulking Ghost or Tar Pit
  Warrior. An opposing one counts as killable by any harmful spell and by any
  cheap targeted ability. Null Rod, Cursed Totem and City of Solitude are cast
  by the swing of abilities they stop (its own instants count against City).
  Peace Talks is cast against a lethal or clearly faster clock. Solfatara and
  Abeyance are cast at the opponent's upkeep.
- **Damage (E5).** Burn targeting and combat kill checks ask
  `MtgGame.predict_damage` from the AI's own seat whenever the table can
  change damage. Source shields (Honorable Passage, Shadowbane, Circle of
  Despair, Kithkin Armor) are held as responses, never cast into an empty
  main phase. They answer burn, a big unblocked attacker (Reflect Damage
  counts the damage it sends back) and lethal combat, including in the 1997
  prevention window. Each threat gets one shield, and a "source of your
  choice" is never a source that cannot deal damage. Sabertooth Cobra's ransom is paid at the opponent's
  end step. Torrent of Lava's granted shield is used when one point decides
  whether a creature lives.
- **Combat (E2/E9).** The AI counts flanking triggers still on the stack and
  prices the Ekundu Cyclops that joins every attack. It spends Heat Wave's
  life tax only on a block that kills, stops more damage than it costs, or
  keeps it alive. Dazzling Beauty and Choking Vines block their biggest
  attackers, never a trampler. It uses the Searing Spear Askari's menace and
  Knight of Valor's shrink when they decide a combat.
- **Costs and mana.** Lotus Vale, Scorched Ruins, the Karoos and Pack 5's
  entry-sacrifice lands are played only when payable, and two-for-one lands
  only when they unlock a cast. Fireblast and Spinning Darkness pay with the
  row their own picker names, and never with both rows. Object-cost fuel
  (Zombie Scavengers, Necratog) is spent. Kaervek's Spite is cast as lethal
  life loss. `MtgGame.targeting_surcharge_floor` prices Kaervek's Torch for
  every castable check. The Lion's Eye Diamond is cracked only into an empty
  hand for an activated ability it pays for, and the mulligan never counts it.
  Magma Mine, Triangle of War, Natural Balance, Tariff and Illicit Auction
  are priced. Doomsday is never cast. Chronatog and Avizoa are used only when
  the pump is lethal.
- **Self-harm (the 2026-10-04 bug pass).** Final Fortune carries Last
  Chance's `extra_turn_then_lose` role: it is cast only when the extra turn
  wins, at every rung, and an opponent's is countered only when its turn
  would kill us. Infernal Contract carries Cruel Bargain's
  `draw_four_half_life` role. Reign of Terror (`color_sweep_life_toll`)
  prices the 2 life each death costs, its hint never names a colour whose
  deaths are its caster's last life, and it is not cast into its own death.
  Waiting in the Weeds (`cats_per_untapped_forest`) counts our Forests after
  paying for it. Three Wishes (`impulse_exile`) is cast in our own main
  phase with a land drop or two mana left to play its cards, never held for
  their end step. A doomed token spell (Tidal Wave) is a surprise blocker on
  their attack, never a main-phase cast. Zombie Mob and Phyrexian
  Dreadnought are not cast to die on arrival. A held Spinning Darkness books
  the row it can pay, or nothing. An Aura's own toughness loss is not hung
  on a body it kills. Torrent of Lava's X beats the {T} shield it grants. A
  modal instant's combat-trick mode never overrides the card's own pick in
  the main phase. Under mana burn a cast whose spare mana would burn our last
  life is refused. Goblin Grenadiers name themselves, never another creature
  of ours, and Pillar Tombs of Aku takes a creature at ten life or less.

Limits:
- The tempo values are one-ply readings, not searches.
- The AI never activates Winding Canyons, so a seat's flash grant is not
  planned for.
- A trick Aura is priced by its printed P/T only.
- Ventifact Bottle's X is never sized, so the AI never charges it.
  Energy Vortex's {X} is not activated either, so the AI's Vortex never
  bills anyone, and Preferred Selection is never cashed in (it keeps
  filtering the library at every upkeep).
- No mana is kept open on our turn for a held Tidal Wave.
- Mob Mentality's all-out pump is not planned for.
- The Torch floor can under-report (but never over-report) when two slots
  must name different spells.

Deck Lab, matched candidate/null/control arms (`--sweep
forecasts_tactics=on,off`, Wizard v Wizard, 200 games an arm, Pack 8 only,
`--no-elo`; the Big Green v White Knights control replayed byte-identically
in every arm). The first measurement found a regression: holding every flash
creature for the opponent's turn cost the Flash deck −14.5 ± 9.3 against
the Costs deck (seed 89000). An ablation pinned it on that hold. With the
hold limited as above:

| Study | Seed | Null/off | On | Delta, 95% margin |
|---|---:|---:|---:|---:|
| Flash v Costs | 89000 | 70.0% | 69.5% | −0.5 ± 8.9 |
| Shields v Knights | 88000 | 9.0% | 14.0% | +5.0 ± 6.3 |

Neither delta clears its interval; the samples are small.

Tests: `tests/ai/test_ai_pack_8_*.gd` (each with its null arm, plus
hidden-information permutations for the phasing blocker read and the flash
ambush). The audit was two seeded probes (100 Wizard-v-Wizard and
Wizard-v-Apprentice duels over five themed Mirage decks, both rule
profiles), with zero script errors.

## Verification (2026-10-03, infrastructure)

- `python3 tools/test_pack_8_mirage_block.py`: 10 offline tests (exact
  three-set inventory and counts, reprint and shared lists against the core
  and every earlier pack, deterministic art archive, metadata-only refusal,
  injected/duplicate entries, failed-build preservation, size bound,
  tampering).
- Boot smoke, isolated profile, metadata-only ZIP: pool 897 with the pack
  off, 1,549 with Pack 8 alone, 2,519 with all eight packs against 1,898
  with Packs 1–7 — exactly 621 more.
- `tests/cards/test_pack_8_catalogue.gd` and
  `tests/ui/test_pack_8_integration.gd`: at the infrastructure stage
  everything but the catalogue gate passed, the gate reporting the 595
  names still pending, as intended. Since the card batches it passes too:
  no Pack 8 name is pending.

## Reproduce the checks

Use the repository's isolated profile, never the player's settings or decks:

```sh
SHANDALAR_TEST_DATA_HOME=../shandalar-build/pack-8-work/gate-testdata SHARDS=6 ./run_tests.sh
python3 -m unittest discover -s tools -p 'test_*.py'
git diff --check

. tools/runtime.sh
shandalar_find_godot
shandalar_find_timeout
shandalar_test_profile
export SHANDALAR_PACK_8="$PWD/../shandalar-packs/Pack-8-Mirage-Block.zip"
"$SHANDALAR_TIMEOUT" -k 5 3600 "$GODOT" --headless --path . \
  --script res://tools/pack_8_duel_audit.gd -- --rounds 10 --seed 87000
xvfb-run -a "$SHANDALAR_TIMEOUT" -k 5 1500 "$GODOT" --path . \
  -s res://tools/pack_8_ui_soak.gd -- --rules modern --count 3 --mode both --pace 0
# Repeat with --rules fifth; also run the stock tools/duel_soak.gd both ways.

DeckLab/deck_lab.sh --deck-a p8_flash.deck --deck-b p8_costs.deck --packs 8 \
  --games 200 --jobs 8 --seed 89000 --sweep forecasts_tactics=on,off \
  --control-deck-a big_green.deck --control-deck-b white_knights.deck --no-elo \
  --out ../shandalar-build/pack-8-work/lab-flash
# And p8_shields.deck v p8_knights.deck with --seed 88000.

./build_release.sh --out ../shandalar-build/pack-8-work/linux64
# With the real ZIP in SHANDALAR_PACK_8 and an isolated XDG_DATA_HOME:
../shandalar-build/pack-8-work/linux64/Shandalar.x86_64 --headless -- --verify-pack-8
```

The audit's nine themed 60-card decks (Phasing, Knights, Flash, Costs,
Shields, Karoo, Charms, Jamuraa, Weatherlight) are the `DECKS` table of
`tools/pack_8_duel_audit.gd`; the study's `p8_*.deck` files are those lists
written one `count name` per line. The audit reports actual casts,
activations and mechanic events rather than equating loading with play, and
fails on a stall, a turn cap or any logged engine error.

## Acceptance record — 2026-10-04

Final full GUT gate: **10,205/10,205 tests / 473,522 asserts / 635
scripts**, six shards, strict wrapper exit 0 (`gut-final.log`), with no
parse error, skipped script, failing test or leaked-object line. Python:
**508 tests**, eight platform skips. `git diff --check` clean.

The final in-engine campaign completed **180 full Wizard-v-Wizard duels**,
90 per ruleset, seeds 87000–87089 (modern) and 187000–187089 (fifth), 11–52 turns, with no stall and
no engine error (`duels-final2.log`). 137 of the 141 Mirage-block names in
the decks were cast or played; actual mechanic counts across both rulesets:
1,329 phasing events (494 by the untap step, 110 by an effect, 127 Auras
riding a host, 494 phase-ins), 144 flanking triggers, 12 flash-rider casts
at instant speed and 9 cleanup-step sacrifices, 15 alternative-cost casts,
12 object-cost casts, 206 cumulative upkeep triggers (31 unpaid), 87 damage
replacements, 328 nonbasic land and 217 mana artifact taps.

The two matched Wizard studies used 200 games per arm and a stock-deck
control pair whose every arm replayed the null game for game: **2,400
games**, no stall, no Elo written. The first run of the Flash study showed
the Pack 8 policy costing the Flash deck 14.5 points (holding every flash
creature for the opponent's turn); the hold now waits only for a real
ambush, and the final rows are:

| Study | Seed | Off/null | On | Difference, 95% margin |
|---|---:|---:|---:|---:|
| Pack 8 Flash / Costs | 89000 | 140/200 (70.0%) | 139/200 (69.5%) | −0.5 ± 8.9 points |
| Pack 8 Shields / Knights | 88000 | 18/200 (9.0%) | 28/200 (14.0%) | +5.0 ± 6.3 points |

Neither difference is clear of zero at this size; the studies show the
policy no longer costs the Flash deck, not that it makes either deck
stronger. These narrow study decks are not tournament recommendations.

All **24 real-screen UI soak duels** completed under Xvfb: six Pack 8 and
six stock games per ruleset, each split between demo and fuzzed-human play,
seeds 1000, 1037 and 1074, with no error beyond Xvfb's V-Sync and input
method notices, no leak and no stall (`ui-soak-*.log`). The Pack 8 network
soak played 15 duels through the SGManalink referee with 8,241 commands and
no refusal.

A fresh **0.50.11 Linux debug export** (`build_release.sh`, its own smoke
boot passing) passed the real-ZIP probe: **1,549 identities, 652/652
dormant scripts, 1,368/1,368 artwork pictures and 1,304/1,304 skin
fallbacks, 9/9 UI textures, 0 rules pending, 5/5 payment and 5/5 AI
metadata checks** (`export-pack8-probe.log`).

The ordinary player's `settings.cfg` and decks were not written (their
timestamps predate the work). Evidence is local under
`../shandalar-build/pack-8-work/`. Only source, metadata, tests,
documentation and original UI icons are intended for Git; generated ZIPs,
downloaded artwork, captures and logs stay local.

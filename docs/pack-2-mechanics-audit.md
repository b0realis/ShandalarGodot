# Fallen Empires — rules and AI audit, 2026-09-15

Scope: the 102 unique names in the checked-in Scryfall Fallen Empires snapshot,
their dormant scripts, `_rules.gd`, engine payment/combat/trigger hooks and the
AI's actual activation paths. The 187 printings are metadata/art variants,
not 187 different rules implementations. This is a source audit plus selected
behavioral regressions, **not an exhaustive proof of every card interaction**.

## Rules coverage

All 102 names register from the real validated ZIP. Cards with only creature
stats and keywords use ordinary creature rules; static restrictions use the shared
engine. Card-local choices use the same player-choice flow as the base pool.

| Family | Representative cards | Engine path / regression coverage |
|---|---|---|
| Counters and recurring resources | Thallids, Javelineers, Moneychanger, Merseine, Homarid, Tidal Influence | Named counters, unusual permanent P/T counters, upkeep triggers, responseable state-trigger resets, counter costs before resolution |
| Tribal token production | Icatian Town, Breeding Pit, Goblin Warrens, Night Soil, Homarid Spawning Bed | Token creation; two sacrifices; exile two creature cards from one graveyard; sacrificed mana-value snapshot |
| Compound and non-tap-symbol costs | Hand of Justice, Vodalian War Machine, Tourach's Gate | Extra creature/land taps; summoning sickness applies to the tap symbol, not a helper-tap cost; costs paid before the stack |
| Mana | Storage/sacrifice lands, High Tide, Rainbow Vale, Farrelite Priest, Initiates, Implements of Sacrifice | Counter-based output; sacrifice mana; immediate delayed mana triggers; end-step control transfer and sacrifice; mana conversion |
| Combat | War Drums, Orgg, Brassclaw Orcs, Orcish Veteran, Flotilla, Dwarven Soldier, Skirmishers | Minimum blockers; legal attack/block predicates; first strike; banding; defender permission distinct from removing defender |
| Attack substitutions / prevention | Farrel cards, Delif artifacts, Spore Cloud/Flower, Elvish Scout, Heroism, Tidal Flats | Unblocked triggers; damage-assignment suppression; prevention; optional payments; delayed effects |
| Persistent effects | Seasinger, Thrull Champion, Spirit Shield, Zelyon Sword, Thelonite Monk, Thelon's Curse | Leashed control; held bonuses; indefinite land-type changes; untap restrictions and paid escape |
| Spells and targeting | Hymn, Goblin Grenade, Soul Exchange, Dwarven Catapult, Raiding Party | Random discard; additional sacrifice/exile; reanimation and Thrull bonus; simultaneous divided damage; source-color target bans |

New correctness fixes in this pass:

- A white spell using a spell-or-permanent target specification cannot bypass
  Raiding Party's source-color ban.
- Dwarven Catapult applies its divided damage as one simultaneous batch.
- Control activations do not acquire a new leash if the source changed
  controller or left and reentered before resolution.
- High Tide's public delayed mana bonus is included in same-color mana plans,
  and expires with the actual delayed trigger.
- Conch Horn's returned card is treated as a loss by the AI's chooser.

### Second engine/AI pass

The follow-up read compared all 102 unique Oracle entries with their scripts
again, then exercised these newly identified failures through real engine
actions. Timing and identity decisions follow the official
[Comprehensive Rules](https://media.wizards.com/2026/downloads/MagicCompRules%2020260819.txt),
particularly 400.7 (new objects), 603.7 (delayed triggers), 611.2b (continuous
duration that has already ended), and 701.21a (sacrifice requires control).

- Rainbow Vale, Goblin Kites and fourth-use converter sacrifices now create
  ordinary responseable end-step triggers. They retain the original controller
  and battlefield incarnation. Kites still flips after the creature leaves;
  neither it nor a converter can sacrifice an opponent-controlled permanent.
- Seasinger, Thrull Champion, Spirit Shield and Zelyon Sword cannot restart a
  duration after an intervening untap or control loss merely because the source
  is tapped/ours again at resolution. Monotonic continuity counters are undo-safe.
- Counter/upkeep triggers, self shroud, self pump/regeneration, Merseine escape,
  Gate counters, War Machine permission and Retainer regeneration do not apply
  to a new battlefield incarnation. Breeding Pit and Moneychanger retain the
  controller of their trigger, not the source's subsequent controller.
- Delif's delayed payoff survives the attacker leaving after it triggers;
  only the original attacker loses its damage assignment. Flotilla watches
  original creatures, and Skirmishers retain their original band. Dwarven
  Soldier receives one bonus for multiple Orcs in a blocking declaration,
  without a whole-turn lockout. Raiding Party and War Machine destroy their
  affected groups in simultaneous batches.
- The shared mana planner now chains explicitly described converters, paying
  each activation first with the actual `ManaPool` payment policy. It works
  with non-tap converters that are tapped or summoning-sick, respects source
  exclusions and restricted mana, and preserves surplus multi-mana output.
  Rainbow Vale and Implements expose five explicit colour modes.
- The full AI cast test caught Hymn's new discard effect being classified as
  friendly: aimed discard is now harmful, and fixed discard waits against an
  empty opposing hand. Goblin Kites has a pre-block, expected-risk evasion
  policy; it never reads the next coin, repeats redundant flying, or assumes
  flying removes an already-declared block. Spore Flower ignores attackers
  whose combat damage is already prevented.
- Triggered abilities can capture per-occurrence context before responses.
  Farrel's Mantle remembers the original attacker after the Aura leaves and
  uses the attacker's last known power if it leaves. Mindstab Thrull/Necrite
  cannot pay an old trigger by sacrificing a returned, new incarnation.
- Heroism and Elvish Scout do not repeatedly pay for already-prevented damage.

## AI decisions

`engine/ai/fallen_empires_tactics.gd` supplies bounded public-board policies.
It returns gross benefit; the shared activation scorer subtracts mana,
sacrifice, discard and helper-tap prices. Costs are still paid and validated
by the engine. No search executes random outcomes or reads an opposing hand
or library. Random discard is valued from the average of the AI's own hand.

| Decision | Policy |
|---|---|
| Seasinger / Thrull Champion | Take a valuable legal enemy creature; never "steal" our own creature |
| Deep Spawn / Homarid Warrior / Svyelunite Priest | Shroud only in response to a hostile targeted stack object, accounting for the actual ability's timing restrictions |
| Vodalian Mage / Thrull Wizard | Read target legality and visible payable taxes; do not repeatedly buy a counter the opponent can pay for |
| Fungal Bloom / Thallids | Finish a useful spore cycle; spend surplus end-step mana on progress; create tokens using the shared scorer |
| Merseine | The enchanted creature's controller can find and pay the escape ability even when the Aura is on the enemy battlefield; stop at zero nets |
| Vodalian War Machine | Reserve enough crew to both permit and power an attack; do not buy permission twice; price further combat boosts |
| Elvish Hunter | Freeze a tapped threat; don't pay to refresh an already-pending skipped untap |
| Moneychanger / Praetor / Spawning Bed | Cash counters when life is needed; repair upkeep decay using affordable fodder; value tokens against sacrificed mana value and body price |
| Shield / Sword / permanent counters | Select friendly beneficiaries; price sacrificed bodies and discarded cards |
| Delif artifacts / Spore Flower / Elvish Scout / Heroism / Tidal Flats | Use actual combat windows and visible attackers/blockers; avoid spending these outside their useful window |
| River Merfolk / Druid / Monk / Raiding Party | Recognize relevant land types, useful animation, nonbasic disruption, and Plains that visible white creatures can save |
| Orcish Captain | Expected-value removal against a fragile enemy Orc; no knowledge of the next coin |
| Goblin Kites | Pre-block evasion against ground blockers; price a 50% lost body, decline redundant flying/reach blockers, prioritise lethal damage |
| Hymn to Tourach | Aim at the enemy; value cards actually available and hold against an empty hand; never read hidden card identities |
| Mana conversion / Rainbow Vale | Executable cost-first plans and all five colour options; the same planner serves AI and human auto-tap |
| High Tide | Pay for the Tide first, then determine whether remaining Islands unlock a worthwhile spell in our hand |
| Dwarven Catapult | Choose the smallest X producing the best lethal divided-damage result; never treat the opponent target as face damage |
| Regeneration | Price expendable Goblins, Thrull Retainer and discard costs against the saved creature; respect resource availability |

## Limits, not hidden promises

- This remains a heuristic pilot, not an expert combo solver. Converter search
  is capped at 2,048 queued/expanded states and 64 actions; an exotic payable
  combination may be declined, never paid speculatively. It models fixed,
  explicitly opted-in outputs, not arbitrary sacrifice/counter/choice chains.
  Generic payment uses the engine's deterministic colour policy, not a new
  player-selected payment interface. The pilot does not globally optimise
  future converter loss after a fourth use. High Tide planning remains
  conservative about leftover mana and mixed output colours.
- Orcish Spy resolves its private look for the activating seat, but the fair
  AI does not yet maintain a known-top-of-library memory or build plans from
  that information.
- Optional-payment prompts retain heuristic choices; large multi-card tribal
  plans and long-horizon resource banking are not claimed to be optimal.
- Source-leave, attachment-change, control-change and repeated-blink interactions
  across every triggered ability are not exhaustively covered by this pass.
- No new intentional card simplification was introduced. The existing
  [simplification ledger](simplified-cards.md) still records Pack 1's physical
  dexterity/subgame adaptations and other base-game limitations. AI strategy
  limitations are not changes to the legal rules of a card.

## Verification

On macOS this worktree's `shandalar_test` feature uses **Shandalar Pack Tests**
as its test-only profile, separate from a concurrent base-game checkout's
**Shandalar Tests**. Normal/exported builds still use **Shandalar**. The
separation avoids tests in different checkouts rewriting each other's settings
or card-pack fixtures. Parallel runs within this same worktree/profile still
need to be serialized. Use a separate `SHANDALAR_TEST_DATA_HOME` for run logs
and generated ZIP fixtures as well.

`tests/cards/test_pack_2_fallen_empires.gd` covers catalog independence, every
name's visibility, source-filter combinations, artwork/set membership, UI
layout and the shared rules families. `tests/cards/test_pack_2_ai.gd` exercises
real activation decisions, cost payment, target selection and resolution,
including negative/no-repeat cases. `tests/cards/test_pack_2_integration.gd`
adds 34 second-pass regressions, including complete AI casts and real ordered
mana payments, not just effect classification. The full repository suite and constructed
Fallen Empires AI duels are the integration gates; the exported desktop probe
must still use the real art-complete ZIP, not the metadata-only test fixture.

### Current verification — second engine/AI pass

- Full isolated GUT suite: **6,429/6,429 tests**, **242,000 assertions**, 374
  scripts, 245.355 seconds, exit 0. Log: `second-audit-full-suite.log`.
- Focused Pack 2 suite: **97/97 tests**, including **34 new integration
  regressions**. Log: `second-audit-final-focused.log`; the full suite also
  covers the subsequent converter-search bounds and export-probe changes.
- **10 completed Wizard-vs-Wizard duels**: modern seeds 42000–42004 and
  fifth-edition seeds 42100–42104. Log: `second-audit-duels.log`.
- Python builder and release packaging: **14/14 tests**. The actual local
  `Pack-2-Fallen-Empires.zip` passes the builder's `verify` command unchanged.
- Fresh **189 MB macOS debug export**, ad-hoc signed, smoke-booted. The real-ZIP
  probe loaded all **102 dormant scripts**, decoded **204 artwork files** and
  **7 crown/medallion textures**, and executed Forest → Implements of Sacrifice
  → two black mana using the shipped cost-first planner. Log:
  `second-audit-export-probe.log`.
- Build/log artifacts live in `../shandalar-build/pack-2-work/`; the app is
  `second-audit-macos/Shandalar.app`. `git diff --check` is clean. The player's
  saved enabled-pack preference remains **Pack 1 only**, unchanged by testing.

### Earlier verification history

Verified after the three-row source-panel redesign (before this second pass):

- Isolated full GUT suite: **6,395/6,395 tests**, 240,050 assertions,
  239.94 seconds, exit 0. The focused run passed all 63 Pack 2 tests.
- Ten completed Wizard-vs-Wizard Fallen Empires duels from the preceding
  mechanics pass: five modern and five fifth-edition, seeds 42000–42004
  and 42100–42104. This UI revision does not change AI decisions.
- Dedicated Pack 2 Python builder: five tests; release packaging: nine tests;
  real ZIP verification succeeded.
- Local macOS export: all 102 dormant scripts and 204 real artwork files
  loaded successfully with the art-complete pack; all five shipped crown
  and source-medallion textures were decoded from the exported game.
- Native 1280×800 Deck Builder captures: **897 original-only cards** and
  **102 Fallen Empires-only cards**, three matching On/Off rows centered
  at 390/480px panel widths, Close and emerald Done. Player pack preferences
  were not modified. Pack 1-only membership/artwork, repeat clicks, empty
  all-Off state, unavailable packs and unchanged decks are regression-tested.

The source controls are **1997**, **tDotP Pack 1**, and **Fallen E. Pack 2**.
Pack-only browsing includes Pack 1's 373 added set entries (372 unique names),
not just its four new identities. Source switches preserve other live filters.

The subsequent graphical-only refinement follows the owner's set-strip photo:
square blue-grey bevelled tiles, gold rings, dark 97/card-fan/crown emblems,
and On/Off captions below. All **104 focused pack/art/skin tests** passed.
The native screenshot verifies the revised 390/480px layout and the unchanged
102-card Fallen Empires-only view. The historical 6,395-test result predates this
art refinement; source filtering and game/AI rules were not changed by it.
The refreshed macOS export passed the real-ZIP probe, including all seven
crown/medallion textures, 102 dormant card scripts and 204 decoded art files.

Distribution remains construction scripts plus metadata only. No pack ZIP or
downloaded card art is to be committed or attached to a release.

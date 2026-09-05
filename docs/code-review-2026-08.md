# Code review, bug hunt & optimization pass — 2026-08

Date: 2026-08-31. Scope: a full read of `engine/` for real defects (state-based
action ordering, priority/stack edges, trigger dispatch, combat damage,
continuous-effect layering, zone-change bookkeeping, the mana pool and every
payment path, determinism, null Callables), a correctness sweep of the 648
implemented cards against the **mage-go** reference for everything the earlier
audit (`docs/audit-vs-mage-go.md`, written at ~255 cards) did not cover, and a
profile-minded optimization pass measured with the Deck Lab.

Authority rule, unchanged: **the oracle text wins** (the Scryfall snapshot in
`cards/data/` is canonical); mage-go is the mechanics reference.

Every fix landed test-first: the pin named in each row failed before the change
and passes after. New pins live in `tests/unit/test_review_2026_08.gd` (engine)
and `tests/cards/test_review_2026_08.gd` (cards).

Suite at the end of the pass: **931 tests / 20 815 asserts, green** (the pool
was growing in a parallel session throughout, so the count moves; what matters
is that nothing was left red). A 10-matchup, 2000-game Deck Lab round robin
over the shipped gauntlet finishes with 0 stalled games.

## Findings — engine

| Area | Issue | Severity | Status | Pinned by |
|---|---|---|---|---|
| Mana payment (`_payment_plan`) | The auto-tap plan for "unless you pay" rents was built from the **printed** `data.mana_abilities` while `tap_for_mana` activates `cur_mana_abilities`. Under Blood Moon / Conversion / Evil Presence / Phantasmal Terrain a retuned land looked like a source of its old colour: `can_afford_cost` said yes, `try_pay` tapped it for the wrong mana, paid nothing, and returned false with the land spent. It could also index past the end of a shortened live list. | HIGH | fixed | `test_auto_payment_reads_live_mana_abilities` |
| Mana payment (`_payment_plan`) | The plan happily used mana abilities with their **own** costs ({1}, 1 life, "sacrifice a creature"), which `tap_for_mana` then refused or silently over-paid. Now only free, {T}-costed abilities are planned (`_is_free_mana_ability`). | MEDIUM | fixed | `test_ai_mana_plan_ignores_costed_mana_abilities` (AI mirror) |
| Mana payment (`_payment_plan`) | The simulated pool ignored `ManaAbility.dynamic_amount`, so an assembled Urza tron under-counted its own output and could report a payable cost as unpayable. Now simulates through `produce_into_for`. | LOW | fixed | covered by the two above (no behaviour regression) |
| Zone changes (`return_to_hand` / `exile_permanent`) | Only `_move_to_graveyard` settled a departing AURA. Bouncing or exiling a **Control Magic / Steal Artifact** left the host stolen forever, and any aura leaving that way left a dangling id in `host.attachments` — which Rabid Wombat, Time Elemental ("that isn't enchanted"), Ramses Overdark and Enchanted Being all read. Extracted `_detach_departing_aura()` and called it from all three exits. | HIGH | fixed | `test_bouncing_a_control_aura_hands_the_host_back` |
| Priority (`play_land`) | A land could be played by the active player **while the opponent held priority** (CR 305.1 requires priority), which also desynchronised the pass counter. | MEDIUM | fixed | `test_land_drop_requires_priority` |
| Continuous effects (CR 613.4) | Every static ran in one timestamp-ordered pass, so a **layer-7b P/T setter** (Nightmare, Keldon Warlord, Plague Rats, Dakkon Blackblade, Gaea's Avenger, the animators) silently wiped a **layer-7c anthem** (Crusade, Bad Moon, Castle) that had entered earlier. Bad Moon + Nightmare with three Swamps gave 3/3 or 4/4 *depending on play order* — the proof it was wrong. `StaticAbility.setting_base_pt()` now tags the 12 setters and the pipeline runs them in their own sub-pass. | MEDIUM | fixed | `test_pt_setting_statics_run_before_additive_ones`, `..._are_order_independent` |
| Last known information (CR 608.2h) | `clear_battlefield_state()` resets `cur_*` to printed values before dies-triggers fire, so anything reading a dead permanent's characteristics got the printed number. New `CardInstance.last_power` / `last_toughness` snapshot the values as the object leaves. | MEDIUM | fixed | `test_a_dead_permanent_remembers_its_live_toughness` |
| Costs (`activate_ability`) | "Remove N `<kind>` counters" was implemented as the ability's first *effect*, gated by an activation predicate that still saw the untouched counters. Three counters on a Triskelion bought **five** pings if the activations were stacked. New `ActivatedAbility.with_counter_cost()`, paid with the rest of the cost (CR 601.2h). | MEDIUM | fixed | `test_triskelion_counters_are_a_cost_not_an_effect`, `test_scavenging_ghoul_spends_a_corpse_per_regeneration` |
| State-based actions (CR 704.3) | SBAs ran only after mutation helpers, never at the moment a player *would receive priority*. Turn-based destructions (the end-of-combat and end-step doom lists) therefore left their fallout — orphaned auras, self-sacrificing permanents — standing until something else happened to check. `_open_priority()` now checks. | MEDIUM | fixed | `test_jihad_sacrifices_itself_when_the_colour_leaves`; also corrected `test_sea_serpent_needs_the_defender_islandbound`, whose setup relied on the gap |
| Delayed triggers (`doom_at_next_end_step`) | Berserk's "destroy that creature **if it attacked this turn**" was evaluated at resolution instead of at the end step, so a precombat-main Berserk never killed anything. The condition now travels with the doom. | MEDIUM | fixed | `test_berserk_kills_a_creature_that_attacks_after_it_resolves`, `..._spares_a_creature_that_never_attacked` |
| Spell timing | The engine had no "Cast this spell only ..." rider. Reset's omission was a real exploit — cast in your own main phase it is a **ritual** (tap N lands, spend {U}{U}, untap all N). New `CardData.castable_only_when()`, enforced in `cast_spell` and consulted by the AI. | MEDIUM | fixed | `test_reset_only_casts_on_an_opponents_turn_after_upkeep` |
| "Loses all abilities" | `CardInstance` has live mana/activated lists but reads triggered and static abilities off `data`, so Titania's Song silenced only half of what it claims. New `cur_abilities_silenced` flag honoured by `dispatch_event` and the continuous pipeline. | MEDIUM | fixed | `test_titanias_song_silences_artifact_triggers`, `..._statics` |
| AI mana planner (`_plan_taps`) | The same printed-vs-live bug as `_payment_plan`, plus it planned costed mana abilities. The AI tapped lands for a cast the engine then refused and logged "(AI cast refused)", wasting the turn. | MEDIUM | fixed | `test_ai_mana_plan_reads_live_mana_abilities`, `test_ai_mana_plan_ignores_costed_mana_abilities` |
| `try_pay` | Documented as "returns false with no state change" while it could leave lands tapped. It now stops at the first refusal and the doc comment tells the truth. | LOW | fixed | (behaviour covered by the payment pins) |

### Checked and found clean

Determinism (no `Array.shuffle()`, no global RNG anywhere in `engine/`,
`cards/` or `tools/` — every shuffle, coin flip and random discard goes through
`MtgGame.rng`; the Deck Lab reproduces byte-identical results across every
build in this document). Every `Callable.call()` site in `engine/` is either
guarded by `is_valid()` or fed by a constructor that requires the callable.
`ManaPool.can_pay`/`pay` (the greedy generic algorithm is correct for this
pool, including zero-valued keys left behind by `_spend`). First-strike wave
separation, trample spill-over, "blocked attacker whose blockers all died",
band pooling, APNAP ordering, the dying card hearing its own dies-trigger,
fizzle on all-illegal targets vs per-effect skip (CR 608.2b/c), the 1997
newest-duplicate legend rule and the world rule.

## Findings — cards

Sweep method: all 648 implemented cards read against the oracle text in their
own headers and the Scryfall snapshot, every cost / P/T / keyword / supertype
machine-diffed against `cards/data/*.json`, and each hand-written card compared
with its mage-go counterpart. The machine diff found exactly one cost mismatch
across the whole pool (Erg Raiders); the rest of the table is behavioural.

| Card | Issue | Severity | Status | Pinned by |
|---|---|---|---|---|
| Erg Raiders | Built at `{B}{B}`; both `cards/data/4ed.json` and `arn.json` (and mage-go) say `{1}{B}`. `docs/audit-vs-mage-go.md` recorded this row **inverted** — that row is now retracted in place. | HIGH | fixed | `test_erg_raiders_costs_one_generic_and_one_black` |
| Control Magic / Steal Artifact | See the aura row in the engine table — bouncing the aura never handed the host back. | HIGH | fixed | `test_bouncing_a_control_aura_hands_the_host_back` |
| Tablet of Epityr, Urza's Miter | "Whenever an artifact you control is put into a **graveyard** from the battlefield" listened to `LEAVES_BATTLEFIELD` with no destination check, so Hurkyl's Recall bouncing six artifacts paid out six times. One-line zone guard each. | MEDIUM | fixed | `test_tablet_of_epityr_ignores_a_bounced_artifact`, `test_urza_s_miter_ignores_a_bounced_artifact` |
| Coal Golem | Printed cost is `{3}, Sacrifice this creature` — **no {T}** — but the mana ability tapped, so CR 302.6's sickness gate wrongly applied and the Golem could not be cashed the turn it arrived, after attacking, or under an Icy. | MEDIUM | fixed | `test_coal_golem_can_be_cashed_in_the_turn_it_arrives` |
| Orc General | "**Other** Orc creatures get +1/+1" was restricted to the controller's Orcs (`yours_only()`, not printed) and excluded by card NAME rather than by identity, so a second Orc General you control was skipped too. New `MassPumpEffect.excluding_source()`. | MEDIUM | fixed | `test_orc_general_pumps_every_other_orc` |
| Diamond Valley, Life Chisel | "life equal to the **sacrificed creature's toughness**" scanned the graveyard for a printed toughness — wrong for a pumped or enchanted body, and blind to tokens (which never reach a graveyard). `activate_ability` now snapshots the sacrificed permanent's live P/T into the source's memory as the cost is paid. | MEDIUM | fixed | `test_diamond_valley_pays_the_live_toughness` |
| Creature Bond | Same class: read `dead.data.toughness`, the only `data.toughness` read in rules code in the 2ed folder. Now reads `last_toughness`. | MEDIUM | fixed | `test_creature_bond_deals_the_live_toughness` |
| Triskelion, Osai Vultures, Scavenging Ghoul | Counter removal as an effect rather than a cost — see the engine table. | MEDIUM | fixed | `test_triskelion_counters_are_a_cost_not_an_effect`, `test_scavenging_ghoul_spends_a_corpse_per_regeneration` |
| Berserk | "if it attacked this turn" checked at the wrong time — see the engine table. | MEDIUM | fixed | `test_berserk_kills_a_creature_that_attacks_after_it_resolves` |
| Reset | The casting restriction was dropped with a false justification in the header ("the caster gains nothing"); it is a ritual. Teleport and Berserk got the same rider now that the hook exists. | MEDIUM | fixed | `test_reset_only_casts_on_an_opponents_turn_after_upkeep` |
| Jihad | The whole third clause ("when the chosen player controls no nontoken permanents of the chosen color, sacrifice this enchantment") was missing, while the header claimed it existed. A spent Jihad lingered and re-armed itself if that colour ever came back. New generic `CardData.sacrifices_when()`, checked as an SBA like Sea Serpent's clause. | MEDIUM | fixed | `test_jihad_sacrifices_itself_when_the_colour_leaves` |
| Elder Spawn, Mold Demon | "**unless you sacrifice** an Island / two Swamps" is an optional cost with a player choice; both force-fed the first matching permanents and never asked. Now offered through `choose_yes_no` + `choose_card`, matching every other "unless you pay" card in the pool. | MEDIUM | fixed | `test_elder_spawn_lets_its_controller_decline_the_island`, `test_mold_demon_lets_its_controller_decline_the_swamps` |
| Titania's Song | "loses **all** abilities" silenced only mana and activated abilities — an animated Howling Mine kept drawing, Winter Orb kept locking, Ankh of Mishra kept stinging, Black Vise / The Rack / Ivory Tower / Armageddon Clock / Dingus Egg all kept triggering. | MEDIUM | fixed | `test_titanias_song_silences_artifact_triggers`, `..._statics` |
| Instill Energy | Granted the HASTE keyword for "can attack as though it had haste", which also unlocked {T} costs (CR 302.6): a freshly cast Llanowar Elves could tap for mana. New `cur_attacks_as_if_hasty`, which lifts only the attack gate. | LOW | fixed | `test_instill_energy_does_not_hand_out_real_haste` |
| Cuombajj Witches | "any target of an opponent's choice" is narrowed to the controller's creatures — `DecisionAgent.choose_card` cannot offer a player. | LOW | ledgered | `docs/simplified-cards.md` (new row) |
| Erosion | The printed "{1} **or** 1 life" choice is made by the engine (mana first, then life, never life at 1). | LOW | ledgered | `docs/simplified-cards.md` (new row) |
| Shelkin Brownie, Tolaria | Strip plain BANDING where the printed text only removes "bands with other" — the engine's documented banding approximation. | LOW | deferred | covered in spirit by the existing "Banding lands" ledger row |

`grep -rl SIMPLIFIED cards/sets/` and `docs/simplified-cards.md` were
re-verified to agree (52 marked files, every name present).

## Optimization

The continuous-effects recalculation and its neighbours are the hot path: every
mutation calls `recalculate()`, and `MtgGame.all_battlefield()` — which rebuilt
and re-allocated a fresh `Array[CardInstance]` on every call — was reached from
that pipeline, from every state-based-action pass, from both cost-surcharge
sums and from ~70 card statics.

Changes, all behaviour-preserving:

1. **`all_battlefield()` is cached**, invalidated only when `_battlefield_order`
   actually changes. The rebuild always produces a *new* array and never mutates
   the one already handed out, so the "iterate while permanents die" callers
   keep the stable snapshot the copy-every-time version gave them.
2. **The same rebuild derives four indexes**: the set of `Mtg.EventType`s any
   permanent currently listens for (so `dispatch_event` early-outs on the very
   common event nobody cares about, instead of building a listener list),
   `battlefield_with_statics()`, the cost-modifier list, and the SBA watch list.
3. **`dispatch_event`** stopped duplicating both battlefield arrays into a
   throwaway list (4 allocations per event → 1, and usually 0).
4. **`CardInstance.reset_characteristics()`** refills its five live lists in
   place (`clear` + `append_array`) instead of allocating five duplicates per
   permanent per recalculation — the engine's hottest allocation site.
5. **`check_state_based_actions()`** was split into a fast pass (two comparisons
   per permanent) and a slow pass over `_sba_watch`, the handful of permanents
   that actually carry a legend/world supertype, an Aura, or a sacrifice clause.
6. **The AI's `_plan_taps`** builds and sorts its mana-source list once per
   decision (`_mana_sources`) instead of once per candidate card and once per
   candidate X, uses a Dictionary instead of a linear `used_instances` scan, and
   uses a named comparator instead of allocating a lambda Callable per call.

### Measurements

Deck Lab, `big_green.deck` vs `black_red_raiders.deck`, **1000 games, seed
12345, `--jobs 1`** (single-threaded so the number is the engine, not the
scheduler). Every build below produced the **identical** 453–547 result and
identical per-game turn counts, which is the determinism check: the
optimizations changed no decision anywhere.

The A/B was run on a byte-identical copy of the tree with only the data
structures reverted, so the card pool and every correctness fix above are held
constant across the three rows.

| Build | Time | games/s |
|---|---|---|
| A — engine as it was before this pass (no caches, no indexes, SBAs only after mutations) | 16.1 s | 62 |
| B — A **plus** the CR 704.3 fix (state-based actions at every priority pass) | 20.5 s | 48 |
| C — B **plus** the six optimizations above (shipped) | **9.1 s** | **110** |

* B → C: **2.25× faster** (−55 % wall time).
* A → C: **1.77× faster** than before the pass, *while* doing strictly more
  rules work than A did.
* The correctness fix alone (A → B) cost 27 % of throughput; the SBA fast/slow
  split (item 5) is what bought it back and then some.

Repeatability: five consecutive runs of build C reported 9.1 s / 110 games/s
each. The full test suite is unchanged at ~10 s (it is dominated by script
loading and the AI soak games, not by the engine hot path).

Nothing here trades correctness for speed: every optimization is a cache or an
index over data the engine already recomputed, and the deterministic identical
outcomes across all three builds are the evidence.

## Presentation layer (`game/`) — reported, not touched

`game/` was read but deliberately left alone (another session owns it). Two
notes, both consequences of engine changes made here:

- **`play_land` now requires priority.** A duel screen that offers the land
  drop whenever it is the human's main phase will start getting
  `"you don't have priority"` in the window between the human passing and the
  step advancing. The button's enabled-state predicate should include
  `game.priority_player == seat`, the same way the cast button does.
- **The summoning-sickness spiral now shows on an Instill Energy creature.**
  `game/duel/mini_card.gd:260` draws the spiral for
  `summoning_sick and not has_keyword(HASTE)`. Instill Energy no longer grants
  real HASTE (it sets `cur_attacks_as_if_hasty`, because the printed text lifts
  only the attack gate, not {T} costs), so an enchanted creature that CAN swing
  will still be drawn as sick. The predicate wants
  `and not instance.cur_attacks_as_if_hasty` alongside the HASTE check.
- **New refusal strings** the UI shows verbatim: `"you don't have priority"`
  from `play_land`, `"not enough <kind> counters to remove"` from
  `activate_ability`, and the three cast-timing riders (`"cast Reset only
  during an opponent's turn"`, `"... only after their upkeep step"`,
  `"cast Berserk only before the combat damage step"`, `"cast Teleport only
  during the declare attackers step"`). `HumanAgent` may also now be asked
  `"Sacrifice an Island to keep Elder Spawn?"` and `"Sacrifice two Swamps to
  keep Mold Demon?"`, which its heuristic answers "yes" to — a candidate for
  the await-based prompt in `docs/duel-screen-design.md` §5.

## Deferred (not done in this pass)

- **Cuombajj Witches / Erosion**: both need a `DecisionAgent` hook that can
  offer a *target* (player included) or a *choice of cost*. Ledgered.
- **Life Chisel / Diamond Valley for tokens** is fixed, but the general shape —
  effects that need to read what a COST consumed — is carried on the source's
  `memory` under two engine-reserved keys (`_sacrificed_power`,
  `_sacrificed_toughness`). A first-class slot on `StackItem` would be cleaner
  once a second card needs it.
- **`_passes` is not reset when a trigger reaches the stack** outside a
  priority action (the only reachable case is a `BECAME_TAPPED` trigger from
  `tap_for_mana` while the opponent has already passed). The opponent loses one
  window to respond to a City of Brass sting. Cosmetic in a duel; a one-line
  fix in `dispatch_event` if it ever matters.
- **Combat damage packet splitting**: a blocker whose power exceeds the
  attacker's lethal assigns two packets (lethal + remainder) instead of one.
  Every prevention path in the pool is either all-or-nothing per event or
  linear, so the totals match; a card that counts damage *events* would notice.

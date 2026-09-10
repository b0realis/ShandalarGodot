# The next wave of the AI — a plan, written 2026-09-08, to be done later

The Deck's third pass is merged (ROADMAP: THE DECK, THIRD PASS,
2026-09-08) and the Forge study is read (`docs/forge/`, a reference and
not a port). What follows is the work that comes next, in the order it
will be built, with each item's knob, rung and measurement pinned to the
paragraph that designed it — so that starting is a matter of opening
this file. Nothing here is built. The owner's word starts it.

The rules of the ladder hold for every line (`docs/ai-difficulty.md` §1,
`CONTRIBUTING.md`): a knob on `AiProfile`, off below the rung named and
on above it; no card name in any decision; nothing read that the seat
may not see; ported from a source with a marker at the site (`[forge]`
naming file, lines and commit; `[1997]`; `[s30]`) rather than invented;
measured in the Deck Lab before it is kept — the candidate pair, the
null pair, the control pair replayed game for game (`--sweep`), and the
no-harm matrix — and a cut that measures nothing is written down and not
kept. The two Weissman controls: the Winter 1994–95 list loads; the
1995-05 and 1996 lists hold one proxy each (Chaos Orb, Zuran Orb) and
do not, a pool fact.

---

## Wave 1 — a day of small deterministic wins (all S)

The cheapest first day, in the order the casting note ranks it: P10,
P12, P11's sweep, then the rest.

| # | Knob | Designed in | Rung | What it fixes | Measured by |
|---|---|---|---|---|---|
| 1 | ~~counter order + Power Sink's X, inside `holds_instants`~~ **DONE 2026-09-10, `ranks_counters`** | casting P10 | Magician+ | ~~Mana Drain on the Serra and Power Sink on the Bear, not the first in hand order; Sink's X = their open mana + 1, and no Sink at all when they can pay it and a hard counter is in hand~~ REPRODUCED on one board: a Wizard on eight Islands answering a Serra Angel spent the Drain from a hand of `[Mana Drain, Power Sink]` and the Sink from `[Power Sink, Mana Drain]`, and paid the Sink's X at SEVEN to make a price of one unpayable. Built as a SORT over the counters that can answer this spell (`AiPlayer._counter_order`), five keys and no card name: can we pay for it, does it actually stop the spell, what it costs us now with its X, the narrow card before the wide one, the card we would rather keep. The unless-cost is the card's own oracle line (`_unless_price`) against the planner's source list asked of the other seat (`_their_open_mana`), and the X is that plus one. A THIRD thing the probe found that the plan did not name: the loop RETURNS what `_cast_response` gives it, so a legal counter the mana did not cover ended the search with a PASS — one Island, a Counterspell and a Force Spike in hand, and the Serra resolved. Key 1 fixes it. MEASURED, seed 11: the pairs the plan named cannot see the knob, and the reason is a pool fact — Blue Skies' main deck is two Counterspells and nothing else (0 of 1,000 games differ, and 0 of 1,000 with `--best-of 3 --sideboard on` too), The Deck's counters are four Counterspells plus a Mana Drain that ties them on every key and one Red Elemental Blast that counters BLUE spells (0 of 1,000 against Black-Red Raiders and against White Knights), and `sligh_geeba_1996` cannot be played at all (9 proxies). The pair that CAN see it is Kevin Bane's **Coral Reef** (4 Counterspell, 3 Power Sink, 2 Spell Blast): vs White Knights **35.3% → 36.4% at 4,000 games an arm (+1.1 ±2.1)**, vs Big Green 35.9% → 37.4% at 1,000 (+1.5 ±4.2), with 140 of 1,000 games differing from the null and 14 flipped to a win against 4 flipped away. Control `big_green` vs `mountain_artillery` byte-identical to its own null in every arm of six runs |
| 2 | ~~the mulligan's low-land escape, in `AiMulligan.KEEP_LANDS`~~ **DONE 2026-09-10 — a plain correction, no knob** | casting P12 | all | ~~a Channel/Lotus deck keeps its one-lander when the library holds fewer than one land in seven~~. THE NOTE'S OWN ESCAPE MEASURES NOTHING HERE: Forge's `library / landsInDeck > 6` fires on ONE of the 217 decks this pool can load, and `wc1994_lestree` — the deck named to measure it on — is at 3.05 cards per land and does not load at all (Chaos Orb). What was actually wrong is one line up from it: the keep band read `land_count` at BOTH ends where its floor meant MANA, so five Moxen, a Black Lotus and a Mana Crypt counted for nothing and a seven of one Island and two Moxen went back as "1 land in 7". The floor now reads `AiMulligan.mana_sources`, the ceiling still the lands (a Mox is a spell), and the colour check reads the free sources too. Named by shape, one-directional, and no knob invented — `mulligans` already owns the judgement at every rung | measured: 69 of 217 loadable decks hold one of the seven cards, nineteen of them 1997 enemy decks. Sevens thrown back, 4 000 hands a deck: The Deck 20.2 → 8.3%, 22.6 → 9.8%, 36.2 → 16.6%; Dracur 33.6 → 22.2%, Prismat 30.5 → 17.9%, Kiska-Ra 29.6 → 21.1%; the landless `twist_of_fire` 100 → 3.1% (mean kept hand 4.00 → 6.97); the shipped five unchanged to the tenth. The Lab, `--mulligan on --sweep mulligans=on,off` at 2 000 games an arm over four pairs, two trees: a WASH (669 won / 630 lost of the 1 299 games that ended differently), with every `off` arm and every arm of `big_green` vs `white_knights` byte-identical across the trees — 24 000 games, not one different |
| 3 | ~~`W_HAND` sweep 1.5 / 2.0 / 2.5~~ **DONE 2026-09-10 — swept, NO CHANGE, the incumbent 1.5 stays** | casting P11 | — | ~~may move the Deck mirror more than any knob~~ — it moves it by −0.2 ±3.1. `Evaluator.position_score` now takes an optional profile and reads `AiProfile.w_hand`, so the question is one command; the answer is that the three arms are indistinguishable. The finding under it: `W_HAND` has exactly TWO readers — `_combat_tolerance`'s `> 5.0` posture flag and `_level_value`'s Balance price — so a full point on the weight changes 6 games of 2 000 on the control pair | 2 000 games an arm, seed 11, control `big_green` vs `mountain_artillery` (`sligh_geeba_1996` does not load — Dwarven Ruins — so Mountain Artillery is the aggro seat, and the Deck mirror is `the_deck_playable` vs `the_deck_weissman_1996_02` since the 1996 list does not load either): mirror 51.8 / 51.8 / 51.6 / 51.6, vs Mountain Artillery 39.2 / 39.2 / 39.4 / 39.1, `big_green` vs `white_knights` 53.8 / 53.8 / 53.8 / 53.8. The 1.5 arm is byte-identical to the null on all three pairs and on the control (0 of 2 000, four times over); 2.0 and 2.5 move the control by 6 and 12 games, which is why P11 said it can have no true control |
| ~~4~~ | ~~`reads_gaze`~~ **DONE 2026-09-10** | combat P3 | Sorcerer+ | ~~attacking into a Cockatrice, ignoring rampage, tapping into a Royal Assassin~~ — all three built at `_dies_to` / `_best_block_for` / `_attack_risk` / `_build_combat_model`, each a printed line read as a shape. Measured: `docs/ai-difficulty.md` §4 — Big Green vs Forest Dragon 77.8% → 79.3% (+1.5 ±2.5), vs A Royal Pain 65.8% → 68.3% at 2 000 and **66.6% → 69.1%, +2.4 ±2.0 clear of zero, at 4 000** | the note's pairs at 2 000 games; control `big_green` vs `white_knights`, byte-identical in every arm. Measured at EVERY RUNG as the note asked: −1.2 / +2.1 / +2.7 / +2.6, monotone and negative at the Apprentice, so the numbers and the ramp ruling agree. The RAMPAGE half is not measurable at all — no deck in `decks/` holds one of the pool's seven rampage cards — and is pinned by `tests/ai/` alone |
| ~~5~~ | ~~`reads_manlands`~~ **DONE 2026-09-10** | combat P7 | Sorcerer+ | ~~a Factory with `{1}` up counted as a blocker~~ — and, in the same knob, ours animated to BLOCK: the two halves of one fact, shipped together because either alone is a lie. Measured: `docs/ai-difficulty.md` §4 — The Deck vs Big Green 42.0% → 44.5% (+2.5 ±3.1, 56 games won against 6 lost of the 62 that turned) | `the_deck_playable` vs `big_green`; **`sligh_geeba_1996` CANNOT BE PLAYED — nine proxies, the Lab exits 2** — so Mountain Artillery stands in (39.4% → 40.4%), and Big Green vs The Deck is the ATTACK half on its own (−0.1 ±3.1, 0 games won of the 3 that turned: the proof that the halves must ship together). Control `big_green` vs `white_knights`, byte-identical in every arm |
| 6 | `tutors_for_the_turn` | casting P9 | Sorcerer+ | Demonic Tutor takes a land when short, then a card castable next turn, then the card worth most on THIS board | The Deck vs `white_knights`, `sligh_geeba_1996`; `necropotence_1996` vs The Deck; control `big_green` vs `white_knights` |
| 7 | ~~`holds_x_burn` (the hold half; the chain is wave 3 work)~~ **DONE 2026-09-10** | casting P7 | Sorcerer 3, Wizard 5 | ~~the two-point Disintegrate at a Bear on turn three; `in_danger` must read their clock~~ REPRODUCED (a Wizard on three Mountains Fireballed a Grizzly Bears for two) and built as a hold inside `_size_x_burn`'s creature branch, on the REACH rather than on the shot: gating on the X actually paid refuses a Fireball for four at a Serra Angel for a game's first nine turns, which `test_ai_capabilities.gd` has pinned as correct since the Fireball was first sized — and Forge's `dmg` is its own maximum X too. `AiPlayer._in_danger` is [member AiProfile.chump_threshold] read a fourth time against `_damage_after_value_blocks`: their whole board as attackers, ours as blockers, so a swing three Walls of Stone eat is no clock. Lethal is returned before the hold is asked and the face arm still runs under it. MEASURED, seed 11, 1,000 games an arm: a WASH on both pairs (White Knights 53.9% null / 52.9% at 3 / 53.6% at 5, ±4.4; Big Green 48.0 / 48.0 / 47.6) with the knob plainly firing — 119 and 296 of 1,000 games differ from the null at 3 and 5 against White Knights, 39 and 189 against Big Green — and the null replayed game for game (the `0` arm is byte-identical to the null in 1,000 of 1,000, both pairs). Control `blue_skies` vs `white_knights` 701-299 byte-identical in every arm of both runs. The CHAIN half stays wave 3's |
| 8 | the next-attack test, inside `levels_boards` | casting P14 | Sorcerer+ | Wrath at a board that kills us next turn even when we are ahead on value; Armageddon only when our creatures out-value theirs | The Deck vs `sligh_geeba_1996` / `white_knights`; the originals gauntlet; control `big_green` vs `mountain_artillery` |

Two of the third pass's open rows belong here, being the same size:

* ~~**Animating a Factory to BLOCK** — the mirror of
  `_would_attack_once_animated` probed at the moment
  `_defensive_combat_response` already owns; goes with `reads_manlands`
  (row 5), the two halves of the same read.~~ **DONE 2026-09-10**, under
  `reads_manlands` and exactly as described: `AiPlayer._combat_animation`
  at their declare-attackers, `AiPlayer._would_block_once_animated` as
  the probe, and the body bought only when the declaration would use it
  AND it comes back — `_animation_value`'s own refusal mirrored, because
  what animates is almost always a land.
* ~~**`trusts_abyss` and the shelter cast** — a creature let through as
  the next meal sheltered by a cheaper creature cast after it (Blue
  Skies' fliers, the −0.3), and a second copy let through as level with
  its twin: the "after" board read once more after our own main
  phase.~~ **DONE 2026-09-10**, both halves, as an EXTENSION of
  `trusts_abyss` rather than a knob of its own — the knob's promise is
  *the counter is kept because the feeder answers this creature*, and
  both rows are boards where it does not. The twin is one comparison in
  `AiPlayer._is_next_meal` (`<` became `<=`: a feeder takes one body a
  turn); the shelter is the "after" board read once more
  (`AiPlayer._shelter_swing`), priced at what the displacement buys them
  and read BEFORE `counter_threshold`, because the whole point of it is
  a one-drop the bar would never look at. Measured on the pair the third
  pass flagged with its −0.3: The Deck (playable) vs Blue Skies at 1 000
  games an arm, seed 11, run on both trees — the knob's own delta goes
  from **−1.9 ±4.4 to +0.9 ±4.4**, every `off`, `null` and control arm
  byte-identical between the two trees (5 000 games, not one different),
  and of the 36 `on`-arm games that end differently **32 are won and 4
  lost**.

## Wave 2 — timing and the counter's mind (M)

The two gaps a human notices first (`docs/forge/README.md`, verdict 3
and 4).

| Knob | Designed in | Rung | What it fixes |
|---|---|---|---|
| `develops_late` | casting P1 | Sorcerer+ | everything cast in main 1; the land drop played before it is needed; instants at their end step |
| `EffectIntent.wheels` — the field first | casting P5 | — | a prerequisite of the next two rows, beside `extra_turns`, which the third pass built for Time Walk's draw step (`engine/ai/effect_intent.gd`) |
| `counters_by_shape` | casting P2 | Wizard (the ALWAYS half at Sorcerer if it measures) | counter by what the spell does; Weissman's rule — the counter is kept when a card in hand answers the spell later |
| `reads_lethal_x` | casting P6 | Sorcerer+ | Channel-Fireball as the pilot; "X equals my life" as the defender |

With it, the third pass's **Time Walk's worth beyond the draw** — the
untap, the attack and the land drop priced, so a Walk waits for a
Factory attack instead of going off on an empty board — which is
`extra_turns` read on our own side.

## Wave 3 — the combat reads (M)

| Knob | Designed in | Rung | What it fixes |
|---|---|---|---|
| `reads_race` | combat P1 | Sorcerer+ | the tolerance moves with the two clocks, the block trade margin with it |
| `reads_pumps` | combat P2 | Sorcerer+ | a bear into a Frozen Shade with Swamps up |
| `reinforces_blocks` | combat P4 | Sorcerer+ | Wall of Stone plus Grizzly Bears kill the Craw Wurm |
| `holds_tricks` | combat P5 / casting P13 | Wizard | the bait attacker sent on the strength of the Giant Growth, its mana booked |
| `crack_back_margin` | combat P8 | Wizard | the crack-back search asked below lethal, at the chump line |
| `holds_x_burn`, the chain half | casting P7 | Sorcerer+ | two burn spells that kill together: the first sized for its share, the second's cost booked |

And the third pass's **Disk deferral**: `times_sweeps` holds an activated
sweeper only from the moment it is offered in their combat, so a Disk
worth firing in our main phase still fires there; the deferral is the
relief read one phase earlier, and the "after" board must apply the
statics the sweep removes (a Moat the Disk takes no longer holds the
ground).

## Wave 4 — the old loops (S–M; `docs/arzakon.strategy` §4)

Forge knows none of them; these are ours. The measure is the median turn
the loop first runs, from `games.csv`, beside the win rate.

| Knob | Designed in | Rung | Loop |
|---|---|---|---|
| `counts_the_race` | casting P3 | Sorcerer+ | decking as the clock: Millstone, Braingeyser at us, a Timetwister into the smaller library. **Two liability rows were closed onto this one on 2026-09-10** and both want the same thing from it — a HORIZON, the turns a game has left. A toll with no printed escape (a Serendib Efreet's point a turn) cannot be subtracted from a snapshot without one, and a SYMMETRIC toll (Copper Tablet, the pool's only card of the shape once the count-reading and the beat rule have refused the other five) needs to know whose race the shared clock is winning. Nothing in the engine estimates turns today: `_face_damage_value` scales a hit by a share of a life total, `position_score` is a snapshot, `CombatSearch` sees one turn, and `PACE_HORIZON` counts cards of a library |
| `minds_the_vise` | casting P4 | Sorcerer+ | the hand under a Vise or a Rack, the board under a Moat |
| `runs_loops` | casting P5 | Wizard | Time Walk priced as a turn; Regrowth on the Walk; the Twister that restarts it |

## Wave 5 — the veto and the evaluator (M / L)

| Knob | Designed in | Rung | What it fixes |
|---|---|---|---|
| `checks_before_casting` | casting P8 | Wizard | Forge's one-ply safety veto on `Evaluator.position_score` with a projected position — no game copy |
| evaluator constants | combat P6 | all, no knob | Terror on the Wall of Stone (7.0) instead of the Hypnotic Specter (5.5): a toughness-scaled defender discount, +0.5 per ability; L for the measurement at every preset |
| ~~a liability reading~~ **DONE 2026-09-09, `prices_liabilities`** | the owner's Detonate, 2026-09-08 | all, on at every rung | ~~`Evaluator.permanent_value` never goes below zero, so `spares_own`'s one door — a permanent of ours a harmful spell may take because giving it up is worth LESS than nothing — never opens.~~ Built as three readings in `AiPlayer._own_value`, the board score untouched: THE RECKONING (a printed "you lose the game" on leaving — the Lich, and the pool's only one), THE DEAD WEIGHT (tapped, not untapping, every ability needing the {T} it cannot pay — the Mana Vault, a creature under a Paralyze) and THE TOLL, priced for the turns our mana needs to reach the price the card itself prints. Of the four candidates named here only the Vault survived: the **Lich is the OPPOSITE of a liability** (destroying it loses the game, and the old evaluator's 3.2 had the AI feeding it to its own trigger), **Illusions of Grandeur is not in the pool**, and **Pestilence is not a liability** — its harm is an activated ability nobody makes it use. `_cast_value` charges the own-side victim and the sting the card deals its controller (`EffectIntent.damage_to_target_controller`). Measured: a wash on the Detonate pairs with 13 own-side Detonates in 150 games where there had been 0, **+3.2 ±2.2 on Azaar Lichlord at 4 000 games an arm, clear of zero**, control byte-identical, the null replayed game for game over 6 000 games |
| ~~`EffectIntent` controller damage~~ **DONE 2026-09-10, both halves** | the same look | `prices_liabilities` | ~~no field says "damage to the target's controller"~~: `EffectIntent.damage_to_target_controller` exists, Detonate carries `controller_damage: -1`, and since 2026-09-10 BOTH sides of it are read through one line (`AiPlayer._controller_sting`) under the knob that owns the field — ours charged at the reaper's rate, theirs credited on the AI's own clock (`_face_damage_value`) and worth `LETHAL_WORTH` when it is lethal. The objection that deferred it ("pricing it moves the shipped pilot on both arms") was an objection to a KNOBLESS reader change; gated on `prices_liabilities` the null is untouched and the Lab can run it. Measured on the pass's own Detonate pair, War Mage vs Crag Hydra at seed 11: the `off` arm replays the published 45.3% and the control 525-475 byte-identical, the `on` arm 45.5% → 47.1% at 1,000 games. Against Big Green — a deck with no artifact for the card to point at — the arm does not move at all (11.5% either tree) |

Here too **the planner's tie-break** from the third pass — a Factory, a
Library of Alexandria or a Strip Mine worth more untapped than a Forest;
`engine/mana_planner.gd` takes equal sources in battlefield order — an
engine change measured at every rung, not a knob.

## THE ANGEL — its own item, when a deck wants it

The census (ROADMAP, THE DECK, THIRD PASS §6): The Deck's wins come at
turn 48–58 on the mean, its losses at 16–22, and 35 of the 42 short
losses were keeps of one to three lands. An Angel shortens the win by
ten to twenty turns and changes nothing about the loss. When wanted: a
`the_deck_serra.deck` variant (two Angels for two of the four Factories,
the Winter list's shape) and a finisher rule on the cast — the closer is
held while their board can still race it (the crack-back search's
reading of their untapped attackers against our life over the turns the
Angel needs) and cast when the board is locked (a Moat or an Abyss on
the table with a counter in hand). Control pair `big_green` vs
`white_knights`. The short losses are a mulligan question with a deck in
it — whether a control deck's keep should want three — and go with wave
1's row 2, measured, not assumed.

## The engine pass (all S; `docs/forge/rules.md` §4)

Not Wizard work, but each closes a ledger row: the waiting-trigger queue
with one APNAP flush (row 2679); the affected player's choice among
replacements (rows 2672, 2660); timestamp order within a layer with the
bounded type-dependency step (rows 2666, 2680, 2682);
`EffectBase.unless_paid(cost, payer)`. Only if wanted: a `decider` on
`StackItem` for Word of Command (M); Shahrazad as a second `MtgGame` (S
in the engine, L in the screen).

## What is not in this plan

The Forge study's "not to be copied" list stands (`docs/forge/README.md`):
no random rolls, no card-name hints, no hand reads, no per-turn memory,
no first-playable picker, no CMC buckets, no game-copy simulation, no
string DSL, no modern-only machinery, no Forge resource file. The ledger
rows that are rulings (the text-change prompt, 2026-09-07) stay rulings.

## Gates, as for every pass

`./run_tests.sh` whole after the last item and the AI suites after each;
both soaks; `python3 -m unittest discover -s tools`; the boot smoke; the
counts in `README.md` and `docs/CODE_MAP.md` from the last gate; a dated
ROADMAP section per wave with every number, every cut and what was not
kept. A worktree needs the checkout's `assets/` symlinked and the eight
empty `cards/todo/` set folders before its first suite (the third pass's
lesson).

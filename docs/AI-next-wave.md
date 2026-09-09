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
| 1 | counter order + Power Sink's X, inside `holds_instants` | casting P10 | Magician+ | Mana Drain on the Serra and Power Sink on the Bear, not the first in hand order; Sink's X = their open mana + 1, and no Sink at all when they can pay it and a hard counter is in hand | `blue_skies` vs `white_knights`, The Deck vs `sligh_geeba_1996`; control `big_green` vs `mountain_artillery` |
| 2 | the mulligan's low-land escape, in `AiMulligan.KEEP_LANDS` | casting P12 | all | a Channel/Lotus deck keeps its one-lander when the library holds fewer than one land in seven | `--mulligan on --sweep mulligans=on,off`, `wc1994_lestree` vs `white_knights`, `big_green` vs `white_knights` |
| 3 | `W_HAND` sweep 1.5 / 2.0 / 2.5 (a number exposed to `apply_overrides`, not a knob) | casting P11 | — | the hand:life weight is 2.5 in Forge and 1.5 in ours; may move the Deck mirror more than any knob | `--sweep w_hand=1.5,2.0,2.5` over the Deck mirror, The Deck vs `sligh_geeba_1996`, `big_green` vs `white_knights` |
| 4 | `reads_gaze` | combat P3 | Sorcerer+, measured at every rung | attacking into a Cockatrice, ignoring rampage, tapping into a Royal Assassin — three structural reads at `_build_combat_model` / `_dies_to` | the note's pairs, 2 000 games; control `big_green` vs `white_knights` |
| 5 | `reads_manlands` | combat P7 | Sorcerer+ | a Factory with `{1}` up counted as a blocker (the mirror of `animates_to_attack`) | `the_deck_playable` vs `big_green` and vs `sligh_geeba_1996`; control `big_green` vs `white_knights` |
| 6 | `tutors_for_the_turn` | casting P9 | Sorcerer+ | Demonic Tutor takes a land when short, then a card castable next turn, then the card worth most on THIS board | The Deck vs `white_knights`, `sligh_geeba_1996`; `necropotence_1996` vs The Deck; control `big_green` vs `white_knights` |
| 7 | `holds_x_burn` (the hold half; the chain is wave 3 work) | casting P7 | Sorcerer 3, Wizard 5 | the two-point Disintegrate at a Bear on turn three; `in_danger` must read their clock | `mountain_artillery` vs `white_knights` / `big_green` (`--sweep holds_x_burn=0,3,5`); control `blue_skies` vs `white_knights` |
| 8 | the next-attack test, inside `levels_boards` | casting P14 | Sorcerer+ | Wrath at a board that kills us next turn even when we are ahead on value; Armageddon only when our creatures out-value theirs | The Deck vs `sligh_geeba_1996` / `white_knights`; the originals gauntlet; control `big_green` vs `mountain_artillery` |

Two of the third pass's open rows belong here, being the same size:

* **Animating a Factory to BLOCK** — the mirror of `_would_attack_once_animated`
  probed at the moment `_defensive_combat_response` already owns; goes
  with `reads_manlands` (row 5), the two halves of the same read.
* **`trusts_abyss` and the shelter cast** — a creature let through as the
  next meal sheltered by a cheaper creature cast after it (Blue Skies'
  fliers, the −0.3), and a second copy let through as level with its
  twin: the "after" board read once more after our own main phase.

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
| `counts_the_race` | casting P3 | Sorcerer+ | decking as the clock: Millstone, Braingeyser at us, a Timetwister into the smaller library |
| `minds_the_vise` | casting P4 | Sorcerer+ | the hand under a Vise or a Rack, the board under a Moat |
| `runs_loops` | casting P5 | Wizard | Time Walk priced as a turn; Regrowth on the Walk; the Twister that restarts it |

## Wave 5 — the veto and the evaluator (M / L)

| Knob | Designed in | Rung | What it fixes |
|---|---|---|---|
| `checks_before_casting` | casting P8 | Wizard | Forge's one-ply safety veto on `Evaluator.position_score` with a projected position — no game copy |
| evaluator constants | combat P6 | all, no knob | Terror on the Wall of Stone (7.0) instead of the Hypnotic Specter (5.5): a toughness-scaled defender discount, +0.5 per ability; L for the measurement at every preset |
| ~~a liability reading~~ **DONE 2026-09-09, `prices_liabilities`** | the owner's Detonate, 2026-09-08 | all, on at every rung | ~~`Evaluator.permanent_value` never goes below zero, so `spares_own`'s one door — a permanent of ours a harmful spell may take because giving it up is worth LESS than nothing — never opens.~~ Built as three readings in `AiPlayer._own_value`, the board score untouched: THE RECKONING (a printed "you lose the game" on leaving — the Lich, and the pool's only one), THE DEAD WEIGHT (tapped, not untapping, every ability needing the {T} it cannot pay — the Mana Vault, a creature under a Paralyze) and THE TOLL, priced for the turns our mana needs to reach the price the card itself prints. Of the four candidates named here only the Vault survived: the **Lich is the OPPOSITE of a liability** (destroying it loses the game, and the old evaluator's 3.2 had the AI feeding it to its own trigger), **Illusions of Grandeur is not in the pool**, and **Pestilence is not a liability** — its harm is an activated ability nobody makes it use. `_cast_value` charges the own-side victim and the sting the card deals its controller (`EffectIntent.damage_to_target_controller`). Measured: a wash on the Detonate pairs with 13 own-side Detonates in 150 games where there had been 0, **+3.2 ±2.2 on Azaar Lichlord at 4 000 games an arm, clear of zero**, control byte-identical, the null replayed game for game over 6 000 games |
| `EffectIntent` controller damage — HALF DONE 2026-09-09 | the same look | reader, no knob | ~~no field says "damage to the target's controller"~~: `EffectIntent.damage_to_target_controller` exists and Detonate carries `controller_damage: -1`. Only the OWN-side half is priced (the sting we pay to relieve ourselves of a liability). An **enemy** Detonate's X is still an unpriced bonus, because pricing it moves the shipped pilot on both arms of every sweep and wants its own measurement |

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

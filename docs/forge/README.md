# Forge, read as a reference (2026-09-08)

The owner's sentence, the day after the first release: *"we will work on
this further, mainly AI and AI engine gameplay so it feels like a competent
human tournament-level player at top difficulty … there is an open source
MTG very good game engine called Forge. Examine it, maybe we can use it as
inspiration for our AI and rule engine?"*

Forge (`github.com/Card-Forge/forge`, GPL-3.0, Java) is the largest open
Magic engine there is: every card ever printed as a text script, a rules
engine that plays them, and an AI that has been tuned by hand for fifteen
years. It was cloned shallow beside the other references
(`../forge`, commit `b09a3d3f0093b7ba26a0debc82d80996b8826b37`) and read in
three slices, each an engineering note of its own in this directory:

| Note | Slice | Length |
|---|---|---|
| [`combat.md`](combat.md) | attacking, blocking, and pricing creatures — `AiAttackController`, `AiBlockController`, `ComputerUtilCombat`, `CreatureEvaluator` | 1 480 lines |
| [`casting.md`](casting.md) | what to cast, when, what mana to hold — `AiController`, the per-effect `*Ai` classes, `ComputerUtilMana`, the four `.ai` profiles, `AiCardMemory`, the mulligan, the simulation AI, the cards of our pool | 2 020 lines |
| [`rules.md`](rules.md) | the rules engine and the card model — stack, triggers, replacements, layers, state-based actions, combat, costs, the script DSL, `GameCopier`; every row of the fidelity ledger and every card of `difficult_cards.someday` checked against Forge's script | 1 020 lines |

Every claim in them carries a `file:line` pointer, into the clone
(`forge/forge-ai/...`, `forge/forge-game/...`, or abbreviated `fai/`, `fg/`,
`cards/` in `rules.md`) or into this repository (`shandalar/engine/...`,
`engine/...`). The line numbers are those of commit `b09a3d3f`; if the clone
is updated they drift, so the commit is the thing to check out when a
pointer is followed. Formulas and thresholds are quoted verbatim where they
matter.

This page is the summary and the programme: what Forge knows that ours does
not, what ours knows that Forge does not, the ranked list of knobs the
Wizard could take from it, the engine mechanisms worth carrying, and what
is not to be copied. Provenance is at the end.

---

## The verdict in five lines

1. **The AI is worth reading; the rules engine is not worth porting.** Forge's
   AI has fifteen years of hand-tuned reads a competent player makes — when to
   develop, what a counter is for, what the other side's open mana can do in
   combat, when a race favours attacking. Its rules engine is a string DSL
   resolved at run time, modern-rules only, and larger than ours by an order
   of magnitude for no fidelity gain on a 1995 pool.
2. **Ours is ahead in exactly the places Forge's own code marks with TODOs**:
   reserving mana for a counter (`ComputerUtil.java:3167`,
   `GameStateEvaluator.java:177`, `ManaAi.java:96` — three TODOs; ours has
   `_held_reserve`), a memory that outlives the turn (`AiCardMemory` is
   wiped every end of turn; ours `AiMatchMemory` persists with a fairness
   rule), priced chump blocks, a cohort-priced attack, a deterministic
   crack-back search, a hidden-information rule with tests, and every 1995
   rule (legend rule, prevention step, mana burn — Forge has three old-rules
   switches to our seven).
3. **The biggest single gap is timing.** Forge develops in main 2 by default
   (`PermanentAi.java:38`, `castPermanentInMain1` `ComputerUtil.java:1141-1297`)
   and casts instants at the opponent's end step; ours casts everything in
   main 1 except the held instants. A human notices this before anything else.
4. **The second is the counter's mind.** Forge counters by what a spell DOES
   (its `ApiType`) rather than what it costs; ours compares one number with
   `counter_threshold`. Weissman's rule — a card in hand that answers the
   spell later means the counter is kept — is in neither engine and is what
   The Deck IS.
5. **Forge's simulation AI is not the way.** It is off by default, depth 3,
   copies the game by re-parsing every card (its own comment calls that the
   "vast majority of GameCopier execution time"), and reads the opponent's
   hand and library (`PRUNE_HIDDEN_INFO = false`). We already have the two
   cheaper shapes it lacks — `GameSnapshot` rewind and the `UndoLog` journal
   — and the one piece worth taking is its one-ply safety veto, which needs
   no copy at all.

---

## What Forge sees that ours does not

Named by the seam in our code where it would go; the notes give the Forge
pointer and the quoted rule for each.

**Combat** (`combat.md` §1-3)

- *The other side's pumps are public.* Forge adds every activated pump its
  controller can pay for right now to a combatant's power before any kill
  test (`ComputerUtilCombat.java:955-991`); ours reads open mana for
  regeneration only (`_shieldable`), so a Shivan Dragon with Mountains up is
  a 5/5 to `_dies_to`.
- *Destroy-on-block, rampage, tap-to-destroy.* Forge consults a Cockatrice's
  trigger before the damage maths (`canDestroyAttackerBeforeFirstStrike`,
  1546-1592), counts rampage, and tests whether an attacker would tap into a
  Royal Assassin — all as shape reads, no card name (`ComputerUtilCard.java:911-938`).
  Ours reads none of the three.
- *Manlands are blockers.* An untapped Mishra's Factory with `{1}` open is a
  blocker to Forge (`AiAttackController.java:130-177`) and invisible to our
  attack and crack-back.
- *The race.* Forge chooses an aggression level 0-6 from a race read —
  how many of their swings we survive against how many of ours they survive
  (`ratioDiff`, 1117-1136) plus an unblockable clock (1214). Our
  `_combat_tolerance` is `(aggression - 0.5) * 6 + posture`, the same at any
  clock.
- *Reinforcing a block.* Forge's `reinforceBlockersToKill`
  (`AiBlockController.java:795-858`) adds a second safe body to a blocked-but-
  unkilled attacker; ours stops at the first survivor.
- *The held trick is remembered.* Forge books a Giant Growth's mana until
  blockers and remembers which attacker was sent on its strength; ours holds
  the instant but `_declare_attacks` does not know the trick exists.

**Casting** (`casting.md` §1-3, §7)

- *Main 2 by default* — permanents, draw, discard, tutors, Regrowth and the
  unused land drop wait until after combat; only haste, a pump for this
  turn's attackers, a Mox, an aura that changes this combat, or floating mana
  go in main 1.
- *Counter by type* — sweepers, X burn, decking draw, extra turns, wheels
  always; cheap creatures never — and the counters in hand ordered hard
  before unless-cost, cheap before dear, with Power Sink's X set to their
  open mana plus one (`CounterAi`, §3.2).
- *Bolt to the face when it leaves them under five*, else at their end step;
  *hold the X burn under five before turn ten* because the same card is the
  finisher (`HOLD_X_DAMAGE_SPELLS_THRESHOLD`); *chain two burns* at one
  victim with the second's mana booked (§3.1).
- *Wrath when their next attack is lethal after our best blocks*, not only on
  board value (`DestroyAllAi.java:116-145`) (§3.3).
- *Tutor for the turn* — a land when short, else the best card castable with
  next turn's mana, else the deck's key card (§3.9); ours takes the highest
  `card_value` blind.
- *The mulligan's one escape* — a one-land hand is kept when the library has
  fewer than one land in seven (`scoreHand`, §5.1); ours has the colour
  check Forge lacks and mulligans every one-land hand.

**Engine** (`rules.md` §3-4)

- Cost-payment triggers go ABOVE the spell (CR 603.3): Forge freezes the
  stack while costs are paid and flushes the waiting triggers after the
  spell is on it (`MagicStack.java:120-167`); ours appends them below
  (ROADMAP ledger row, `cast_spell` ~1948 vs 1990).
- The affected player chooses among several applicable replacements
  (`ReplacementHandler.java:193-222`); ours applies a fixed order.
- Layer statics in timestamp order within a layer, with a bounded
  dependency step for the type-changing ones (`GameAction.java:1273-1387`);
  ours has a by-construction order and a "loss beats later grant" rule.
- One "unless a player pays" path (`AbilityUtils.handleUnlessCost` 1403-1441);
  twelve pool cards write the pair by hand.

## What ours sees that Forge does not

Recorded so nobody "fixes" them toward Forge.

- Mana reservation for a counter (`_held_reserve`, `_blue_after_plan`).
- A match memory with a fairness rule (`AiMatchMemory`, `copies_seen`).
- The priced chump (`chump_threshold`), the knapsack damage order, the
  cohort-priced attack (`_cohort_value`), the crack-back search
  (`CombatSearch`), all deterministic — Forge rolls `MyRandom` in a dozen
  combat and casting decisions and its four profiles are mostly chances.
- X sized to the victim (`_size_x_burn`), the draw paced to the library
  (`paces_draws`, `counts_cards`), the level (`levels_boards`) as a
  deterministic Balance.
- The whole 1995 rule set: the 1995 legend rule, the prevention step, the
  window of the damage-prevention request, mana burn, ante, the seven
  `RulesOptions` switches.
- `GameSnapshot` (3.44 ms rewind) and `UndoLog` (0.13 µs per field); Forge
  copies by re-parsing cards and the shipped AI never copies at all.
- A card is one readable file with its own test; Forge's is a script whose
  abilities are strings resolved at run time, with the AI's hints inside it.
- The knob discipline of `docs/ai-difficulty.md`: every capability a boolean
  on `AiProfile`, monotone up the ladder, measured with a control pair that
  must replay the null byte for byte. Forge has profiles; it has no ladder.

---

## The programme for the Wizard

Twenty-two proposals across the two AI notes, merged and de-duplicated
(`holds_tricks` was proposed by both), ordered by the owner's measure —
what a human at the table notices first — with the cheapest deterministic
work first inside each wave. Sizes: S a day, M a week, L more. Each note
gives every proposal its design, its knob, its rung, its risk and its Deck
Lab plan (candidate pair, control pair, no-harm matrix); the numbers here
(`combat.md` P-numbers, `casting.md` P-numbers) point at those paragraphs.
The rules of the ladder hold throughout: a knob on `AiProfile`, off below
the rung named, no card name in any decision, nothing read that the seat
may not see, measured before kept.

**Wave 1 — a day of small deterministic wins (all S).**

| Knob | Note | Rung | What it fixes |
|---|---|---|---|
| counter order + Power Sink X, inside `holds_instants` | casting P10 | Magician+ | Mana Drain on the Serra, Sink on the Bear; Sink's X = their open mana + 1 |
| `reads_gaze` | combat P3 | measure every rung | attacking into a Cockatrice, ignoring rampage, tapping into a Royal Assassin |
| `reads_manlands` | combat P7 | Sorcerer+ | the Factory with `{1}` up counted as a blocker |
| `tutors_for_the_turn` | casting P9 | Sorcerer+ | Demonic Tutor takes a land when short, a castable card, then the key card |
| `holds_x_burn` (the hold half) | casting P7 | Sorcerer 3, Wizard 5 | the two-point Disintegrate at a Bear on turn three |
| next-attack test, inside `levels_boards` | casting P14 | Sorcerer+ | Wrath at a board that kills us next turn even when we are ahead on value |
| the mulligan's low-land escape | casting P12 | all | a Channel/Lotus deck keeps its one-lander |
| `W_HAND` sweep 1.5 / 2.0 / 2.5 | casting P11 | — | the hand:life weight is 2.5 in Forge, 1.5 in ours; a sweep, not a knob |

**Wave 2 — timing and the counter's mind (M).** The two gaps a human
notices first.

| Knob | Note | Rung | What it fixes |
|---|---|---|---|
| `develops_late` | casting P1 | Sorcerer+ | everything cast in main 1; the land drop played before it is needed |
| `counters_by_shape` (+ `EffectIntent.wheels`, `extra_turns`) | casting P2 | Wizard (ALWAYS half Sorcerer if it measures) | counter by what the spell does; Weissman's rule — keep the counter when a card in hand answers it later |
| `reads_lethal_x` | casting P6 | Sorcerer+ | Channel-Fireball as the pilot; "X equals my life" as the defender |

**Wave 3 — combat reads (M).**

| Knob | Note | Rung | What it fixes |
|---|---|---|---|
| `reads_pumps` | combat P2 | Sorcerer+ | a bear into a Frozen Shade with Swamps up |
| `reads_race` | combat P1 | Sorcerer+ | the tolerance moves with the two clocks; the block trade margin with it |
| `reinforces_blocks` | combat P4 | Sorcerer+ | Wall of Stone plus Grizzly Bears kill the Craw Wurm |
| `holds_tricks` | combat P5 / casting P13 | Wizard | the bait attacker sent on the strength of the Giant Growth, its mana booked |
| `crack_back_margin` | combat P8 | Wizard | the crack-back search asked below lethal, at the chump line |

**Wave 4 — the old loops (S-M; `docs/arzakon.strategy` §4).** Forge knows
none of them — Channel is `AI:RemoveDeck:All`, Time Walk, Regrowth and
Timetwister never see each other — so these are ours to build; the note
gives each its loop decks and its measure (the median turn the loop first
runs, from `games.csv`, not only the win rate).

| Knob | Note | Rung | Loop |
|---|---|---|---|
| `counts_the_race` | casting P3 | Sorcerer+ | decking as the clock: Millstone, Braingeyser at us, a Timetwister into the smaller library |
| `minds_the_vise` | casting P4 | Sorcerer+ | the hand under a Vise or a Rack, the board under a Moat |
| `runs_loops` | casting P5 | Wizard | Time Walk priced as a turn; Regrowth on the Walk; the Twister that restarts it |

**Wave 5 — the veto and the evaluator (M / L).**

| Knob | Note | Rung | What it fixes |
|---|---|---|---|
| `checks_before_casting` | casting P8 | Wizard | Forge's one-ply safety veto on `Evaluator.position_score` with a projected position — no game copy |
| evaluator constants | combat P6 | all, no knob | Terror on the Wall of Stone (7.0) instead of the Hypnotic Specter (5.5): a toughness-scaled defender discount, +0.5 per ability; L for the measurement at every preset |

**The engine pass (all S; `rules.md` §4).** Not Wizard work, but each closes
a ledger row: the waiting-trigger queue with one APNAP flush (row 2679); the
affected player's choice among replacements (rows 2672, 2660); timestamp
order within a layer with the bounded type-dependency step (rows 2666,
2680, 2682); `EffectBase.unless_paid(cost, payer)`. Two more only if wanted:
a `decider` field on `StackItem` for Word of Command (M), and Shahrazad as a
second `MtgGame` (S in the engine, L in the screen). `rules.md` §3 checked
every row of `docs/simplified-cards.md` and every card of
`docs/difficult_cards.someday` against Forge's script and effect class: all
use the decomposition the someday file already sketches; Illusionary Mask
needs only a `StackItem` that resolves as a face-down permanent; the
text-change row is a ruling, not a debt (Forge's `ChangeTextEffect` works
only because its abilities are strings).

**Where it meets THE DECK, THIRD PASS.** The third pass (running the same
day) builds the extra-turn reading for Time Walk's draw step — the
`extra_turns` field that `counters_by_shape` and `runs_loops` need — the
Factory's animation following the attack cohort (the mirror of
`reads_manlands`), and the Disk's pressure term (a cousin of the sweeper's
next-attack test). Whatever lands there is the base these build on.

---

## Not to be copied

The notes' §5 / §10 lists, condensed. The random rolls in combat and
casting decisions (`MyRandom`, the 65 % trick hold, the 30/75/100 % counter
chances by converted cost — the ladder is deterministic and measured);
`pilotsNonAggroDeck` by deck NAME (`PlayerControllerAi.java:73`) and every
`AILogic$` / `SpecialCardAi` / `AI:RemoveDeck` hint keyed on a card name
(our rule: no card name in a decision); the hand read in `hasAFogEffect`
(1505-1507) and `CHEAT_WITH_MANA_ON_SHUFFLE` (the seat may not read what it
cannot see); the per-turn memory; the first-`WillPlay` picker (ours ranks
the hand); the CMC buckets; the full game-copy simulation; the string `SVar`
DSL and `CardFactoryUtil`'s double expansion; the modern-only machinery
(planeswalkers, 704.5q, mutate, the cycle library); one-activation pump
prediction (count what the open mana pays for); kill-in-order damage
assignment (ours is the knapsack). No Forge resource file ever ships.

---

## Licence and provenance

Both projects are GPL-3.0; `forge/LICENSE` is the same text as ours, and
Forge's card scripts are in its repository under the same licence (the
Oracle text inside them is Wizards of the Coast's, as in ours). A port is
permitted; the project's rule is that it is RECORDED. Forge is now a row in
`Provenance.md`'s Tier 3 table beside s30 and mage-go, pinned to
`b09a3d3f`.

Two words to keep apart, as the notes define them:

- **Ported** — code, an algorithm with its constants, a table, or a
  decomposition carried closely enough that a reader of the Forge file would
  recognise it. Needs the Provenance row AND a marker at the site naming the
  Forge file and lines, in the style of `[s30]`/`[1997]`/`[QoL]`:
  `# [forge] after fai/AiBlockController.java:795-858 (reinforceBlockersToKill) at b09a3d3f`.
  The GPL obligations are met by the repository licence; the marker is for
  the reader and for the day the Forge line moves.
- **Inspired by** — the idea only, built from the rules text in the engine's
  own shape. A sentence in the ROADMAP row or the function's doc comment
  pointing at the note is enough.

Nothing in these notes was ported. Every quotation is attributed by file and
line so that either path can be taken later with the pointer in hand.

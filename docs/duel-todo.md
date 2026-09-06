# Duel to-do — the prioritized list

The dueling system is the heart of the game. This file is the standing
work list for it: everything the duel is missing, each item traceable to
a source, sized, and labelled by which layer it lives in.

**The adventure/story layer is out of scope here.** Where a reference's
feature belongs to the world map, the quest system or the ante economy's
outer shell, it is listed once under §7 and then dropped.

## How to read an item

Every item carries four tags.

| Tag | Meaning |
|---|---|
| **[1997]** | FAITHFUL TO THE ORIGINAL. The 1997 game did this; we are reimplementing it. The owner's complete-reimplementation pass wants these first. |
| **[s30]** | AN s30 IMPROVEMENT. The 30th-anniversary remake added it; the 1997 game did not have it, or had something else. Divergence — labelled, never silently mixed in. |
| **[QoL]** | OUR OWN quality-of-life. Neither reference has it. Divergence, and the last tier to land. |

Plus: **SIZE** S (an afternoon) / M (a day) / L (a week or a milestone),
and **LAYER** UI / engine / both.

Sources, and how they are cited:
- `duel.go:NNNN` — `../s30/game/screens/duel/`
- `pkg/mage/...` — `../mage-go/`
- **manual p.N** — the 1997 MicroProse instruction manual, the PRIMARY
  authority for anything the player reads. Its duel material is ch. 8
  "The Duel" (pp. 59-106, the rules), ch. 9 "Dueling in Shandalar"
  (pp. 107-132, the screen), the Glossary (pp. 159-186) and "Appendix:
  Sequence of Play" (pp. 187-194). **Printed pages** throughout
  (`printed = PDF page − 6` in the owner's scan). Copyrighted: it is not
  in the repo, and only our prose and items derived from it are.
- `Duel.hlp` — the game's OWN shipped help file (`../shandalar-src/`),
  i.e. the "Dueling Help" the manual points at. Same authority.
- `UIStrings.txt:N`, `promptsX1.txt:N` — the original's shipped string
  tables. **Always the `Program/` copies** — the top-level ones are
  Manalink 3 (§6 opens with the provenance rule).
- **guide p.N** — the 1998 *Advanced Strategy Guide*. Secondary colour
  only: it is a card-strategy book about PAPER Magic and contains
  **nothing** about the MicroProse game (verified by full-text search).
  Evidence about what expert play needs surfaced, never a UI spec.

**Naming**: the original's own word for a thing beats ours. The
term-by-term mapping lives in **`docs/glossary-1997.md`**; §9 turns the
mismatches into work, ordered by how visible each is to the player.

---

## The short answer — the first ten things to do

If you read nothing else. Everything here is **[1997]** except where
marked; the reasoning and the exact wording are in the sections cited.

| | What | Size | Layer | § |
|---|---|---|---|---|
| 1 | **Ask the player what to discard.** DONE 2026-08-31. | — | both | 1.1 |
| 2 | **Make graveyards clickable.** DONE 2026-08-31. | — | UI | 1.2 |
| 3 | **Swap Enter and Done.** DONE 2026-08-31 — Return is the manual's Done: a standing instruction that stops at a Stop, at a required decision, or at a fast effect you can afford. | — | UI | 6.20a |
| 4 | **Give the player the mid-resolution choices.** DONE 2026-08-31, FINISHED 2026-09-01 — the engine PRE-FLIGHTS each resolution over a rewind point, finds what it will ask, and holds it open on `awaiting_choice`; the four COST payments that never touch the stack are held open the same way by a pending-action record that `answer_choice` replays. All 109 call sites now reach the player through one overlay; only an as-enters replacement run outside a resolution is left. §1.3. | — | both | 1.3 |
| 5 | **Sort the hand and the battlefield.** DONE 2026-08-31 — and the tag was wrong: the 1997 game has no auto-sort but ships an on-demand `Arrange Cards`, so the owner's toggle is `[1997]` with an `[s30]` order. | — | UI | 2.3 |
| 6 | **The arrows.** DONE 2026-08-31. | — | UI | 2.1 |
| 7 | **Manual combat damage assignment.** DONE 2026-08-31, with the original's `%d points left` loop. | — | both | 1.4, 6.9 |
| 8 | **The mulligan** — the Shandalar rule. DONE 2026-08-31. | — | both | 1.5, 6.2 |
| 9 | ~~**A damage-prevention window**, and damage as a targetable object.~~ **BUILT 2026-09-01**, all four slices of §6.8a, as the seventh `RulesOptions` fork (`damage_prevention_window`, default modern). What remains is the damage-MARKER widget, which is UI and is ledgered in `docs/ROADMAP.md`. | XL | both | 6.8, 6.20b |
| 10 | **Stops and a real "run to phase"**, replacing the blind pass loop. DONE 2026-08-31, on BOTH bars. | — | UI | 6.1, 6.3 |

Those next five are now **DONE (2026-08-31)**: §2.3 the arrange toggle,
§3.1 deselect, §3.2 the Escape ladder, §6.11 the Cancel button and the
keyboard contract, and §6.3's `Go to:` list (plus `Go to: next phase`,
the one 1997 verb we had no equivalent for). **§2.9 is done too, with its
premise reversed** — the manual settles the P/T question in our favour and
the real defect was on the Showcase — and it shipped alongside §2.10,
§2.11 and §6.15's `@CUECARD_SMALLCARD` half, which are one component.

**§6.8 is built too** (2026-09-01), all four slices of its own design:
damage is a `DamagePacket`, the prevention and regeneration steps are real
priority windows with a restricted allow, and a packet is a legal target.
It is the seventh `RulesOptions` fork and it is off by default, so an
untouched duel plays modern Magic exactly as before. What is left of it is
the damage-MARKER widget, which is UI (`docs/ROADMAP.md`).

Both "things to decide" are decided: the Fifth-Edition-vs-modern
divergences (§6.20n) are **RULES FORKS** in `engine/rules_options.gd`,
each defaulting to the modern answer and each carrying its manual page —
SEVEN of them now that §1.4's `free_damage_assignment` and §6.8's
`damage_prevention_window` have joined them —
and attacker selection stays revocable as a labelled fork
(`attackers_revocable`).

## The S sweep (2026-09-01)

Every **S** item in the file was worked to completion in one pass — §2.7,
§2.12, §2.13, §2.14, §2.15, §3.3, §3.6, §3.7, §3.8, §3.10, §6.4 and §6.7
— plus the evidence searches that settled §3.4, §3.9 and §4.2 without a
line of code. Five of them turned out to be wrong in a way worth
recording, and each section says so in place:

| § | What the source said that the item did not |
|---|---|
| 2.12 | `Duel.hlp`'s **Original Type** mini-menu entry proves the ORIGINAL redraws a retuned card, so this is [1997], not [s30] |
| 2.14 | *"Cards drawn into your hand are displayed when you draw them"* — the 1997 Showcase fills itself on a draw, which we did not do at all |
| 2.15 | both gestures are 1997's, and `@MENU_SMALLCARD` prints one of them as an accelerator: `Show full card\tR DblClk` |
| 3.7 | `allow_cancel` (`defs.h:2390`) is a two-bit spec — "is Done applicable?" is a 1997 question, so the item is [1997], not [QoL] |
| 3.8 | the five colour `.wav`s we played on every SPELL CAST are the enum's own `// Land sounds.`; a spell sounds like its card TYPE |
| 6.7 | `@PROMPT_TURNSEQUENCE` is not a set of Done labels — `engine.c:1519` passes its entries as response-window CAPTIONS |
| 3.10 | both "missing" targeting states were already there, in the original's wording rather than s30's |

## The M sweep (2026-09-01)

The four **M** items in the file — §2.4, §2.6, §6.10, §6.14 — plus the
unbuilt remainders of §6.3 and §6.12, worked in one pass. **Four of the
six had something wrong with them**, and in two cases the item's central
claim was the thing that was wrong:

| § | What the source said that the item did not |
|---|---|
| 2.4 | filed **[1997]**; the 1997 duel is a Win32 app of registered window CLASSES, its ONE animation switch is `Show coin flip animations`, and `Duel.hlp` closes the Showcase question with *"a display only; it has no other function"*. The flight is **[s30]** — but the DESTINATION is 1997's: the Spell Chain window, which s30 does not have |
| 2.6 | right as written; `DuelConfig.pace` maps onto s30's MIDDLE tier because an AI action IS the opponent acting, so the two named defaults keep their exact meaning |
| 6.10 | **they do not concatenate.** Every one of `validate_target_impl`'s sixty failure sites ends in `goto epilog`, so ONE reason is printed. The 29 are a diagnostic PRIORITY ORDER, which is the half of the item that was load-bearing |
| 6.14 | **two widgets merged into one.** `@DIALOG_FIREBALL` is X + target count with the arithmetic shown; the divided-damage dial is `@PYROTECHNICS`, a CLICK LOOP of `Select (1st of 4)…` prompts. Split, both built |
| 6.3 | `Show all cards' summoning sickness` is not an on/off switch for the spiral — `ShowAllCardsSummonSickness` is *all cards*, i.e. whether non-creature permanents wear the mark |
| 6.12 | the table lists six menus; `UIStrings.txt` has **fourteen**, and the four it misses are the window menus (`@MENU_ATTACK`, `@MENU_SPELLCHAIN` and their minimized twins) |

Two bugs surfaced that no item had reported. **Fireball could not be cast
for more than one target at a payable X** — the X dialog priced the pool
without the per-target surcharge, so a full-value Fireball aimed at two
creatures was always refused. And **`_on_cancel` leaked a pending cast**
whenever the player backed out of the mode menu, the tutor picker or the X
question, because it only cleared in TARGETING mode and none of those
three rungs has entered it yet.

## WHERE THIS LIST STANDS (2026-09-02)

**Two of the items this section listed as open on 2026-09-01 have since
been built**, and both were on the "what comes next" list below:

- **§3.5's ability targeting** — a human can now click an ability on the
  chain (`_on_chain_ability_clicked`, plus the highlight that makes it
  *look* like a target, which was the second half of the gap). Rust and
  Ayesha Tanaka are playable by a person, not only by the AI.
- **One-to-many blocks** (CR 509.1b) — `CombatState.extra_blocks`, both
  the printed grant (Two-Headed Giant of Foriys) and the granted one
  (Blaze of Glory). The last hole in combat. Two ledger rows lifted.

**The Gauntlet** — the fourth 1997 mode, absent since the project began —
was built the same day from `docs/gauntlet-design.md`.

**The duel to-do is cleared.** §1 (all six), §2, §3, §4, §6 and §9's Tier 1
are stamped; §6.8 — the damage-prevention window, the largest 1997 rules
structure the project lacked — was built the same day as a `RulesOptions`
fork and measured at scale.

**Three items are NOT built, each deliberately, each with its evidence:**

| § | Why it stays open |
|---|---|
| 3.4 | Menace pre-flight would mean first inventing the restriction it pre-flights. No card in our pool has menace. Revisit only if one arrives. |
| 3.9 | The stack's description reaching the message bar. Verified WORSE than the item claimed: `StackItem.description` carries neither targets nor X, so there was never anything to forward. Weighed twice more (§6.10, §6.8) and still not cheap; it needs a naming function plus two description sites, and every test that reads the log. |
| 9.8 | `auto-cast` / `Don't Auto Tap` / `locked land`. Blocked behind `@MENU_MANAPOOL`'s per-mana spends, which our one-call `cast_spell` has no half-paid state to spend into — a held-open payment of §1.3's shape. |

Two sections are reference rather than work: **§6.0** (the names the original
gives its own screen) and **§6.20** (what the manual adds), and they stay.

### What comes next, now that the list is clear

The duel is not the frontier any more. In rough order of what would change
the game most:

1. **`docs/ROADMAP.md`'s "OPEN FINDINGS FROM THE 2026-09-01 AUDITS"** —
   verified defects that four concurrent passes reported but could not
   fix, because another agent owned the file. **Its HIGH entry (the
   cost-payment records) was fixed on 2026-09-02**; the latent and
   small-but-real entries below it are still unowned, which makes them
   the likeliest thing here to rot.
2. **`docs/simplified-cards.md`** — the fidelity ledger, now 55 rows over
   86 card files (was 88 over 128 on the morning of 2026-09-01; defensive
   banding and the durations cluster both landed). This is where the
   remaining *rules* divergence lives now that the pool is complete. Its
   grep invariant is ONE-DIRECTIONAL — see the ROADMAP section above.
3. **AI sideboarding** (`docs/ROADMAP.md`, M4 phase 2.x) — designed, not
   built. It gates `--best-of` and `--sideboard` in the Deck Lab and makes
   the between-duels step meaningful against an AI seat.
4. **AI phase 2.x/3 generally** — activation breadth, trick anticipation,
   deck-aware mulligan, and the search-based phase 3.
5. **M5, the adventure layer** — the overworld, which is out of this
   file's scope by its own opening rule and gets its own design doc.
6. **The 1997 ruleset as a playable whole.** Seven forks exist and
   `--rules fifth` runs them; what has never been done is a full pass
   asking whether the fifth-edition side is as finished as the modern one.

## The heading audit (2026-09-01)

Agents landed work across several sections without updating every heading,
so the headings had drifted from the code. Every open heading was checked
against the tree on 2026-09-01 and the ones that were wrong now carry a
stamp saying so. Three were finished work still advertised as to-do
(§2.5, §2.8, §4.1, §6.11 — the last already announced as done in the
top-ten table while its own heading still said otherwise), five more had
been done under another section's name (§6.2, §6.13, §6.16, §6.17,
§6.18), and two had moved from "none of this exists" to "some of it does"
(§6.3, §6.12 — both finished by the M sweep above).

**Where the audit stopped, and why that matters.** Headings are checkable
by grep; BEHAVIOUR is not. Six items are about how something behaves
rather than whether it exists — §3.3 (does a one-target Counterspell still
open targeting?), §3.4, §3.6, §3.7 (is `Done` lit outside combat?), §3.9,
§3.10 — and grepping for a symbol cannot answer any of them. They are left
at their original status, which may be pessimistic. Do not treat their
headings as verified; play the duel.

**The six were played on 2026-09-01, and none of them was already done.**
A throwaway GUT probe drove the real `DuelScreen` through each path and
printed what the screen actually did; every heading's pessimism was
earned. What the probe printed, verbatim:

| § | The probe | What it printed |
|---|---|---|
| 3.3 | opponent's lone Lightning Bolt on the chain, click Counterspell | `mode=TARGETING  prompt="Select target spell."` — no auto-cast |
| 3.4 | `Mtg.Keyword.keys()` | no `MENACE`; eleven keywords, none a blocker-count restriction |
| 3.6 | `H` pressed with the stack hand on screen | `collapsed=false` — the key does nothing |
| 3.7 | NORMAL mode, human holds priority | `done.modulate=(1,1,1,1)` — unlit |
| 3.9 | a spell on the chain, then read the bar | item description `"Black Wizard casts Lightning Bolt"`, bar `"Upkeep Phase"` |
| 3.10 | one-target and any-number targeting | `"Select any target."` / `"Select any target. (1 so far)"` |

Two of the six came back with their premise only PARTLY right, and the
sections say so in place: **§3.9** is worse than written (the engine's own
`StackItem.description` has no target list and no `for N` either, so there
was nothing to forward), and **§3.10** is better (we do have a targeting
prompt, in the original's `(%d so far)` wording, which outranks the s30
form the item asked for — only the `(Cancel)` affordance was missing).

## 1. Priority one — the duel is WRONG or UNPLAYABLE without these

**ALL SIX LANDED ON 2026-08-31** (§1.3 in two halves the same day — the
ledger in the morning, the pre-flight that actually asks in the evening —
plus a third, the COST hold, on 2026-09-01, which closed its last four
call sites).
Each entry keeps its
original diagnosis, because that is the evidence that justified the work,
and then says what was built and what the building PROVED — several of
these entries were written from reading rather than from building, and
three of them turned out to be wrong in a way worth recording.

### 1.1 [1997] The player is never asked to choose their own discard — DONE (2026-08-31)

At cleanup with more than seven cards, `DecisionAgent.choose_discard`
(`engine/decision_agent.gd:27-34`) picks for the human: highest mana
value first. The player never sees the choice.

The original made this a NAMED PHASE. The owner's own reference
screenshot reads `Done | Fast Effects?...Discard Phase`, and the original
phase bar carries a dedicated discard icon (§4.1). Already ledgered on
the engine side as `Cleanup discard is automatic (_cleanup_step)`
(`docs/ROADMAP.md`), but it has never been read as a *duel-screen* defect,
which is what it is: the single most visible place where the game plays
itself.

Reference: `pkg/mage/player.go:82-146` (mage-go asks the seat);
`duel.go:2596-2762` (s30's generic choice overlay).

**BUILT.** The cleanup step now HOLDS OPEN, the way declare-attackers and
declare-blockers already did: `MtgGame.awaiting_discard` + `discard_count`,
answered by `MtgGame.discard_to_hand_size(pid, cards)`, and everything
cleanup does after the discard moved into `_finish_cleanup`. The screen has
a `Mode.DISCARD` that lights the hand, counts the picks and says
`Select card to discard. (%d of %d)` — `@PROMPT_DISCARDACARD` entry 1.

The gate is a property of the SEAT, not of the engine:
`DecisionAgent.wants_to_choose_discard()` is false by default and true on
`HumanAgent`, so the AI, the Deck Lab and every headless test are byte-for-
byte unchanged and no test needed rewriting. That pattern — "the turn
machine stops only for a seat that asked to be asked" — is what §1.4 and
§1.5 then reused, and it is the answer to the synchronous-engine problem
wherever the choice happens at a STEP rather than mid-resolution.

Pinned by `tests/unit/test_discard_phase.gd` and
`tests/ui/test_duel_prompts.gd`.

### 1.2 [1997] Cards in a GRAVEYARD cannot be targeted — DONE (2026-08-31)

The engine has four graveyard target kinds
(`engine/core/target.gd:30-38`: `CREATURE_IN_YOUR_GRAVEYARD`,
`CARD_IN_YOUR_GRAVEYARD`, `CREATURE_IN_ANY_GRAVEYARD`,
`CARD_IN_ANY_GRAVEYARD`) and the cards that use them are implemented —
Raise Dead, Animate Dead, Resurrection, Adun Oakenshield, Ashes to Ashes.
But the duel screen renders a graveyard as a `TextureRect` with a tooltip
(`duel_screen.gd:1902-1914`); nothing in it is clickable. Casting Raise
Dead puts the screen into TARGETING with **no legal target reachable** —
the player's only move is Cancel.

s30 solves it exactly: `duel.go:2082-2149` `graveyardViewLayout` +
`2946-2995` `drawGraveyardView` (a full-screen dim, a per-player section
titled `"%s's Graveyard (%d)"`, a grid of 150px cards),
`3715-3733` `handleGraveyardClick` (click a non-empty pile to open, the
same pile again to close, anywhere outside to close),
`2305-2328` `handleGraveyardTargetClick` (a valid card selects and, for a
1-of-1 target, submits and closes immediately; an invalid one is a
no-op), and `3699-3712` (while targeting, a pile holding a legal target
wears a 2px `RGBA{255,255,0}` outline).

The same hole exists for `CARD_IN_ANTE` (`engine/core/target.gd:41`).

**BUILT.** `game/duel/graveyard_view.gd` — a full-screen dim (s30's
`RGBA{0,0,0,160}`), one titled section per player per zone, a grid of real
MiniCards. Clicking a pile opens it and the same pile closes it; a click
anywhere outside closes it; Escape peels the view BEFORE the pending cast
(§3.2's one-layer rule, at least for this layer). While targeting, a card
that is a legal target is outlined and a click on it submits; an illegal
one gets `Illegal target (%s).` rather than being silently inert. The pile
itself wears a 2px yellow ring whenever it holds a legal target
(`DuelScreen._pile_holds_a_target`) — otherwise nothing on screen tells the
player the answer is not on the battlefield.

**The item was one view short.** `@MENU_GRAVEYARD` (`UIStrings.txt:901`) is
`View the graveyard` / `View exiled cards` / `View both antes`, so the
overlay shows all THREE zones in that order, and the `CARD_IN_ANTE` hole
this section flagged is closed by the same file rather than needing its
own. Section titles are `@CUECARD_OTHER`'s: `Your graveyard (%d)` /
`%s graveyard (%d)`, with the menu's nouns for the other two.

**[QoL] THE PILE IS MADE OF OUR OWN CARDS** (2026-08-31, the thirty-third
pass of `docs/duel-screen-design.md`). A **deliberate divergence from
1997**, chosen by the owner in these words: *"graveyards should be
composed of our mini cards, 5 in a row, with arrow on the left and arrow on
the right to scroll through graveyards if they are extensive. And a number
which card of all in the graveyard it is, in the center card of the 5. Now
the graveyard has its own format — no! Only big preview and mini cards
with names, art, icons, power/defense etc. Let's be consistent. This is a
divergence from the original but this is what we want — enhanced game with
old feel and good QoL."* The 1997 game gives the graveyard a presentation
of its own; **the owner chose consistency with our own card widgets over
the original's separate graveyard format**, and this line is that choice on
the record.

What it cost the old build: the view forced `Vector2(96, 134)` on every
card — taller than wide, where `MiniCard.SIZE` is `132 x 106`, wider than
tall — so the name band, mana stripes, badges, damage marker and P/T were
all drawn at fractions of a shape the widget never has. Now: five plain
`MiniCard`s at their TRUE size, ◀ ▶ page buttons in the 1997 button art
(manual p.114's scroll arrows, turned horizontal), the whole-pile position
`13 / 35` on the centre card, and hover filling the duel's own docked
`CardPreview`. **A card here is never scaled** — the owner again: *"do not
make them smaller — if they are too big then let's display only 3 at once
and have arrows to scroll through graveyard!"* — so `cards_across()` costs
the row out (784px for five, 504 for three) against the board's real width
and drops the COUNT, never the size.

Pinned by `tests/ui/test_graveyard_view.gd`, which casts Raise Dead end to
end through the screen and pins the shelf's arithmetic, its paging, its
counter and its unscaled cards. Screenshots: `shot_graveyard_view.png`,
`shot_graveyard_paged.png`.

### 1.3 [1997] Every unanticipated mid-resolution choice is answered by a heuristic — DONE (2026-08-31), LAST FOUR CLOSED (2026-09-01)

`HumanAgent` (`game/duel/human_agent.gd`) is a pre-selection mailbox: it
can only answer a choice the UI *saw coming* (today, a library search).
Everything else falls through to `DecisionAgent`'s defaults — `yes` to
any affordable "you may pay", the caller's hint for any colour choice,
the first candidate for any card choice. Roughly fifty cards ask a
question the human never sees (`docs/ROADMAP.md`).

s30 has one generic overlay for all of it (`duel.go:2596-2762`
`handleChoiceRequest` / `initChoiceUI` / `respondToChoice` /
`drawChoiceUI`): dim `RGBA{0,0,0,160}`, the reason as the title, the
reason's card image, `"%d. %s"` buttons at 40px pitch, number keys 1-9.
mage-go's engine asks fifteen typed questions (`pkg/mage/player.go:82-146`)
against our four (`engine/decision_agent.gd:28-58`).

Engine work first: our call sites are synchronous, so the UI cannot open
a dialog mid-resolution. Either the choice points become awaitable, or
every one of them grows a pre-flight the UI can fill.

**BUILT, in two passes on the same day, and the diagnosis above understated
the size of the pool.** "Roughly fifty" was the `choose_yes_no` count alone.
The measured total is **109 call sites** — 68 yes/no, 28 card, 8 discard,
5 colour — of which **103 are asked inside a stack resolution** and 45 of
those by an `UPKEEP_START` trigger. The other six are COST payments and the
as-enters replacement; five of the six are closed too (see the table below),
by a second, much smaller hold.

**Morning: nothing is decided off the record.** Every ask became a
[PlayerChoice] built by a FUNNEL (`DecisionAgent.choose_*`, over
overridable `answer_*`) and filed on the game: announced on
`MtgGame.choice_requested`, kept in `choice_log`, and — when the seat that
was asked wanted to answer for itself and did not — in `unanswered_choices`
AND in the game log as `(decided for P0) …`. `choice_history` remembers
what each card asked so a UI could answer the same question in advance
**from that card's second resolution onward**. That left the first ask
falling to the heuristic, and it only fired when the player clicked Done.

**Evening: the fork this entry names, decided — PRE-FLIGHT, NOT AWAIT.**

*Why not awaitable.* A GDScript function containing `await` returns a
coroutine to its caller the moment it actually suspends. Every one of these
asks is made from inside a `Callable` several frames deep in a card's
effect — `_resolve_top` → `trigger.on_resolve.call()` →
`game.agents[pid].choose_yes_no()` — and `Callable.call()` on a suspended
function does not propagate the suspension: the caller gets nothing and
carries on with the wrong state. Making one ask awaitable therefore makes
`_run_effects`, `_resolve_spell`, `dispatch_event`,
`check_state_based_actions` and `pass_priority` coroutines too, and 1800
synchronous tests with them. s30 can block because Go has goroutines: its
`s.human.ChoiceResponses() <- resp` is a real channel write to a real
second thread. GDScript's only equivalent is a `Thread` mutating game state
off the main thread, which is a far worse trade than this item is worth.

*Why the pre-flight is COMPUTED, not written 109 times.* The engine
resolves the top of the stack TWICE. The first run is a PROBE over a
`GameSnapshot` rewind point: it answers with the heuristic (so it always
terminates and always follows a real branch), records what was asked, and
is undone — no log lines, no events, no state signals, no ledger entries,
and `rng.state` put back (`MtgGame.is_probing()` is what the rest of the
engine reads to hold still). What survives the rewind is the QUESTION. It
goes on `MtgGame.awaiting_choice`, the item goes back on the stack
untouched, and every action is refused until `answer_choice(value)` —
the same hold-open contract as `awaiting_attackers`, `awaiting_discard`
and `awaiting_damage_assignment`. The answer is parked on the seat's own
agent (`DecisionAgent.accept_answer`) and the item resolves for real.
Branching falls out for free: the answer changes what the next probe
finds, so "pay" and "don't pay" can lead to different second questions
without any card knowing the mechanism exists.

`GameSnapshot` (`engine/game_snapshot.gd`) is reflective —
`get_property_list()` over every mutable state object reachable from the
game — and restores IN PLACE, writing the saved values back onto the same
objects, so every reference anyone else holds stays valid and anything the
probe created simply becomes unreferenced. Card DEFINITIONS are not walked
(`CardData`, abilities, effects are shared and never written to, CONTRIBUTING.md
rule 5); the `DecisionAgent`s ARE, which is what makes a probe invisible to
the seat being probed. The whole design is guarded by one test — **a probed
duel is the same duel**: eight turns of a rent-heavy board played twice
from one seed, with and without the pre-flight, compared line for line in
the game log.

It is opt-in (`MtgGame.interactive_choices`, off by default, switched on by
`DuelScreen` when a human is at the table) and it only fires for a seat
that says `wants_to_be_asked()`. The AI, the heuristic agent and every
headless test resolve exactly as they always did.

**THE FOUR THAT FELL THROUGH — CLOSED THE NEXT DAY, AND NOTHING FALLS
THROUGH NOW.** This entry said SIX until an adversarial re-read on
2026-09-01 found that two of the rows were never fall-throughs at all; the
remaining four were closed the same day by the SECOND hold described below.

| Site | Card / caller | Kind | Why the pre-flight cannot reach it | Now |
|---|---|---|---|---|
| `tap_for_mana` | "Sacrifice a *X*" mana cost | CARD | A mana ability never uses the stack (CR 605.3a) | COST HOLD |
| `tap_for_mana` | Fellwar Stone's colour | COLOR | Same — and the card used to ask from inside the mana ability, after the source was tapped | COST HOLD (`ManaAbility.color_options`) |
| `cast_spell` | `additional_sacrifice` | CARD | Cost paid at cast time, before the spell is on the stack (CR 601.2h) | COST HOLD |
| `activate_ability` | `sacrifice_filter` | CARD | Same, for an activation | COST HOLD |

**What is left is what was always outside this item: `CardData.as_it_enters`
run from a NON-resolution path** (a test dropping a permanent in, a token
made outside `_run_item`). Reached the ordinary way — a creature resolving —
it is inside the probe and the hold works. No other call site of any of the
five funnels can now be answered by the heuristic for a seat that says
`wants_to_be_asked()`.

**The two that were wrong, and why.**

- `_apply_enters_as_copy` (Clone, Copy Artifact, Vesuvan Doppelganger) is
  reached by the probe and always was. The row reasoned about the METHOD —
  "`_put_on_battlefield` is reached from non-resolution paths too" — and the
  question is asked on the CARD's path, which is a Clone RESOLVING, inside
  `_run_item`. The hold works: the duel stops, the player is offered both
  bodies, and the Clone copies the one they pick.
- `_cleanup_step`'s discard has held the turn open since §1.1. Any seat that
  says `wants_to_choose_discard()` — the human seat does — stops the turn
  machine on `awaiting_discard` and never calls `choose_discard` at all.

Both are now pinned by `tests/unit/test_cost_choice_contract.gd`, so the
table and the engine cannot drift apart again.

**Closing the last four was CHEAPER than this entry claimed, and the reason
is a bug that was fixed on the way.** All four are cost payments, and all
four used to ask the seat BEFORE the rest of the cost had been checked — so
a cast the engine then refused for mana still filed a `PlayerChoice`, still
put an entry on `unanswered_choices`, and still wrote
`(decided for P0) Sacrifice a creature — Grizzly Bears` into the log for a
sacrifice that never happened (CR 601.2h: the game returns to the moment
before). Every one of them now asks only once NO REFUSAL IS LEFT.

That reorder changed the shape of the remaining work. At the moment the
question is put, nothing has been mutated — so the hold one level down does
NOT want a rewind point, as this entry originally guessed. It wants a
PENDING-ACTION record, and that is what shipped on **2026-09-01**.

**THE SECOND HOLD — `MtgGame._pending_action`.** Where the pre-flight re-runs
the STACK ITEM over a `GameSnapshot`, this re-runs the whole ACTION over
nothing at all. At the ask site the engine builds the `PlayerChoice`
(`_cost_question`), offers it to `_hold_cost_choice` with a record of the
call — `{"kind": "cast"/"activate"/"mana", "pid", "inst", "targets", "x",
"mode"/"index"}` — and, if the seat wants to answer it and its front end can
show the kind, sets `awaiting_choice` and returns `""` having changed
nothing. `answer_choice(value)` parks the answer on the agent
(`accept_answer`) and calls `_replay_cost_action`, which simply issues the
same action again; the funnel now serves the parked answer instead of asking.
It may stop again on the next cost question — `_cost_answers` / `_cost_asked`
count how many of this action's questions are already answered, so the replay
serves those and holds on the one after, and an action with two cost
questions stops twice rather than looping. The gates are the pre-flight's own:
`interactive_choices`, not probing, `wants_to_be_asked()`,
`DecisionAgent.can_answer`. `tap_for_mana` skips `_act_precheck` on purpose
(CR 605.3a lets a mana ability run mid-payment) and so grew its own
`awaiting_choice` refusal.

Verified before building, at all three engine sites, that "nothing has been
mutated" is true — and it was true at three of the four asks and FALSE at the
fourth. `cast_spell` and `activate_ability` ask after every refusal and
before every payment (`cast_spell` has stamped `memory["x_value"]`, which is
idempotent and replay-safe; `TargetPlan` is pure). `tap_for_mana`'s SACRIFICE
ask is likewise clean. But **Fellwar Stone's colour was asked from inside the
card's `ManaAbility.dynamic_color`, which `tap_for_mana` calls after the
source is tapped, the pool paid, the counters removed and the life spent** —
a replay there would have been refused with "already tapped". It was also
asked TWICE per activation (once for the mana trigger's colour, once inside
`produce_into_for`), so a parked answer would have been served to the first
and the heuristic to the second, and the mana would have come out the wrong
colour. Both are fixed by moving the ASK out of the card and into the engine:
the card supplies only the CENSUS (`ManaAbility.color_options` →
`Array[Mtg.ManaColor]`), `tap_for_mana` asks once, before anything is paid,
and hands the answer to `produce_into_for(..., forced_color)`. The overlay
lists only the colours the census actually offers, because a line the engine
would then have to substitute away is worse than no line.

**The 1997 words, per site.** `@SACRIFICE_CREATURE` / `@SACRIFICE_ARTIFACT` /
`@SACRIFICE_ENCHANTMENT` / `@SACRIFICE_LAND` (`Program/Text.res:2645-2659`)
are all `Select <what> to sacrifice.`, and `@SACRIFICE_LANDS` (`:2661-2667`)
spells the five basics in lower case — `Select swamp to sacrifice.` Every
per-card tag says the same sentence (`@SACRIFICE` promptsX1.txt:364,
`@METAMORPHOSIS` `:256`, `@ASHNODS_ALTAR` `:45`, `@ATOG` `:53`,
`@PRIEST_OF_YAWGMOTH` `:312`, `@ORCISH_MECHANICS` `:291`, `@SAGE_OF_LAT_NAM`
`:368`, `@GATE_TO_PHYREXIA` `:182`, `@FALLEN_ANGEL` promptsX2.txt:46,
`@LIFE_CHISEL` `:81`), so the wording is generic in the original too and
`PlayerChoice.sacrifice_prompt` builds it from the cost's own description.
The colour question is `@MULTIMANA` (`Text.res:2057-2059`),
`%s: What kind of mana?` — which `@FELLWAR_STONE` (`prompts.txt:372-374`)
spells out as `Fellwar Stone: What kind of mana?`
(`PlayerChoice.mana_color_prompt`). `DuelScreen.choice_question` keeps
`Select a color.` (`@ALCHORS_TOMB`) for every colour question asked inside a
resolution and uses the source's own line for a cost's, told apart by
`PlayerChoice.is_cost`.

Pinned by `tests/unit/test_cost_choice_contract.gd` (17) and two more in
`tests/ui/test_duel_prompts.gd`. Screenshot: `shot_choice_sacrifice.png` —
Metamorphosis cast with three creatures out.

**A FIFTH KIND ARRIVED (2026-09-01), AND THE OVERLAY NEEDS ONE `match`
CASE FOR IT.** `PlayerChoice.Kind.OPTION` — "choose one of these labelled
things", answered by INDEX, with the labels on `PlayerChoice.options` — is
what Shapeshifter's *"choose a number between 0 and 7"*, Tetravus's *"remove
any number of counters"*, Wood Elemental's *"sacrifice any number of untapped
Forests"*, Nameless Race's *"pay any amount of life"*, Power Leak's *"pay any
amount of mana"* and Petra Sphinx's *"chooses a card name"* ask through
(`DecisionAgent.choose_option`, with `choose_number` as sugar over it).

Until the overlay has a case, those questions must NOT reach it:
`DuelScreen.choice_options` returns `[]` for a kind it does not know, which
would raise a dialog with no buttons and no Cancel and stop the duel dead.
So the pre-flight now asks `DecisionAgent.can_answer(choice)` before holding
anything open, and its default is exactly the four kinds this section
shipped with. An OPTION question therefore falls to the heuristic and is
ledgered in `unanswered_choices` like the six sites below — honest, and not
a hang.

**THOSE THREE EDITS LANDED THE SAME DAY.** `DuelScreen.choice_options` has
its `PlayerChoice.Kind.OPTION: return Array(choice.options)` case,
`_on_choice_option` answers with the raw INDEX, and `HumanAgent` has an
`answer_option` in the shape of `answer_color` plus a `can_answer` override
that adds OPTION to the base four. The prompts were already the cards' own
words, so nothing needed wording. The base `DecisionAgent.can_answer` stays
at four kinds on purpose: a front end without the case must not be handed a
question it can render no buttons for.

Shapeshifter is the end-to-end pin (`tests/ui/test_duel_prompts.gd`), and it
is a BRANCHING hold — its upkeep trigger asks a YES_NO ("you may choose a
number") and only then the OPTION, so the duel stops twice in one
resolution and the second question is found by re-probing with the first
answer parked. That is the mechanism §1.3 was built for, working on a card
that did not exist when it was built.

**THE OVERLAY** is s30's: dim the board to `RGBA{0,0,0,160}`, the REASON
at the top, the reason's CARD, and the options as `"%d. %s"` lines
answerable by the number keys 1-9 — wearing the 1997 window that already
asks this kind of question (the Primal Clay modal screen, enlarged card
left and choice lines right, `prompts.txt:670`), because the original had
no generic chooser of its own. One overlay carries all four kinds; the
options scroll, because a library search offers thirty names where an
upkeep cost offers two. It is raised from `_refresh()`, so it comes up
whatever drove the resolution — a pass, a Run To, a Done order, the AI's
own turn — which the old Done-only dialog did not. It is also the one
popup with **no Cancel**: `@PROMPT_PAYUPKEEP` has two entries and neither
of them is an escape.

The words are the original's, per kind — `@PROMPT_PAYUPKEEP`
(`UIStrings.txt:1129`) for an upkeep cost, `Yes`/`No` (`@CYCLONE`,
`promptsX1.txt:88-90`) otherwise, `Select a color.` (`@ALCHORS_TOMB`,
`promptsX2.txt:11`) over `White`/`Blue`/`Black`/`Red`/`Green`
(`UIStrings.txt:610-614`), `Select target card.` with `Cancel.`
(`prompts.txt:949`) where declining is legal, and `Select card to discard.`
(`@PROMPT_DISCARDACARD` entry 1, `UIStrings.txt:1106`). `PlayerChoice.step`
is what tells an upkeep rent from Urza's Chalice's `Pay {1} to gain 1
life?`, which keeps the general pair.

Pinned by `tests/unit/test_choice_preflight.gd` (12), the §1.3 half of
`tests/ui/test_duel_prompts.gd` (12 of its 18) and
`tests/unit/test_cost_choice_contract.gd` (17). Screenshots:
`shot_choice_upkeep.png`, `shot_choice_card.png`,
`shot_choice_sacrifice.png`. Two numbered passes in
`docs/duel-screen-design.md`.

### 1.4 [1997] Combat damage among several blockers is assigned by the engine, not the attacker — DONE (2026-08-31)

`engine/combat.gd:22-23` auto-assigns lethal-first in declaration order,
marked `SIMPLIFIED`. CR 510.1c gives the *attacking player* the ordering
and the split, and with two blockers the choice decides which creature
dies.

Both references implement it. mage-go: `pkg/mage/player.go:26-35`
`CombatDamageAssigner` (`GetBlockerOrder`, `GetCombatDamageAssignment`),
consumed at `pkg/mage/combat.go:410-482` and validated at `:547-580`
(lethal-to-each-before-the-next; all blockers lethal before trample).
s30's UI: `duel.go:868-885` seeds a suggested split (lethal to each
blocker in order, all remainder onto the last), `1845-1907` puts a
−/+ pair on each blocker (18×18 boxes at `pos+4` and `pos+fieldCardW-22`,
`RGBA{0,0,0,210}` fill, white 1px stroke), where **increment moves a
point from another blocker so the total is conserved**, and `2545-2565`
sorts the blockers lethal-first before submitting the order.

Already half-tracked in `docs/ROADMAP.md` ("Damage-order & band-spread are
auto lethal-first → Player choice via the DecisionAgent"); the UI half is
new here.

**BUILT, and it turned up a RULES FORK this entry missed.**

The 1997 game ran Fifth Edition rules (manual p.108). **Fifth Edition had
no damage assignment order at all** — the attacker divided the damage among
the blockers however they liked, which is exactly what a `%d points left`
click loop IS. The announced order with "lethal to each before the next"
is CR 509.2/510.1c, a SIXTH EDITION invention from 1999, two years after
this game shipped. So §1.4 is not one behaviour but two, and it is now
`RulesOptions.free_damage_assignment` (default modern, as every fork does).
Trample's own rule — every blocker lethal before a point spills to the
player — holds under both, because the original enforced it too (`Assign
trample damage to blockers` is its own later prompt).

The engine half: `_combat_damage_step` now PLANS every division of the step
before anything is dealt (`_collect_damage_requests`), asks each division's
assigner in turn (`_resume_damage_assignment`), and applies them all at
once (`_apply_damage_requests`) so damage stays simultaneous (CR 510.4).
The seat's hooks are `DecisionAgent.order_blockers` (CR 509.2, stored in
`CombatState.damage_order`) and `assign_combat_damage`, whose default is
the engine's old lethal-first spread — `MtgGame.default_damage_split` —
so the AI and every existing test are unchanged. An agent answer the
engine judges illegal falls back to that default rather than stalling the
duel. A seat that says `wants_to_assign_combat_damage()` (the human) makes
the step HOLD OPEN instead: `awaiting_damage_assignment`,
`damage_assignment_request()`, `assign_combat_damage(pid, split)`.

The UI half: `Mode.DAMAGE`, one click per point, the counter counting down
in the original's exact words — `%s: Assign damage to blockers, %d points
left` and the trample variant — and the division submitting itself when the
last point is spent. The screen only offers clicks the engine will accept,
so it never has to refuse a whole division after the fact. Trample's spill
is a click on the opponent's life register (`@MENU_LIFE`'s "Target %s").

Two things the entry got wrong, worth recording: the split is NOT only
meaningful "with two blockers" (a single blocker plus trample is a real
division too, and the original prompts for it), and the blocker-side pass
§6.9 names — `%s: Assign damage to attackers` — is a BANDING pass in our
model, so it goes through the same hook but is credited to the blocker's
controller (documented in `combat.gd`).

Pinned by `tests/unit/test_damage_assignment.gd` (9 tests, both rulesets)
and `tests/ui/test_duel_prompts.gd`. Screenshot:
`shot_damage_division.png`.

### 1.5 [1997] No mulligan — DONE (2026-08-31)

`engine/mtg_game.gd:30,247` says so outright. Every duel starts from an
unfiltered seven, so a no-land hand is simply a loss.

`docs/ROADMAP.md`'s target rule — "the 1997 rule: only 0-land or all-land
hands may redraw" — is **CONFIRMED CORRECT** by the shipped `Duel.hlp` and
by the 1997 string table; §6.2 has the exact wording and the eight
announcement strings. One redraw each, and the opponent may follow.

Do NOT copy s30's London mulligan (`duel.go:3918-4074` — bottoming step,
AI heuristic at `3947-3994`, 120px card layout, opposite-side magnifier):
that whole shape is **[s30]**. Do not copy the `mulligan to %d` strings
either — those are Manalink 3, not 1997 (§6.2).

**BUILT.** `MtgGame.start` split into `deal_opening_hands` → the mulligan
offers → `start_duel(first_player)`; `start()` still does both in one call
for the Deck Lab and every test. The rule is `Duel.hlp`'s, verbatim:
`hand_is_a_mulligan_hand` (no land, or all land), `may_mulligan` (your own
hand qualifies OR the opponent redrew — *"The other player has the option
to do so as well"*), `take_mulligan` (seven for seven, shuffled with
`game.rng`), `decline_mulligan` (*"once that's used or waived"* — a waiver
is as final as a redraw). `DecisionAgent.choose_mulligan` gives the AI the
decision, defaulting to "redraw a mulligan hand, keep an ordinary one".

`game/duel/opening_hand.gd` runs the sequence after the coin toss and owns
every string: `@DIALOG_PLAYORDRAW`'s nine and `@DIALOG_MULLIGAN`'s twelve,
quoted exactly. **The toss winner now chooses play or draw** (§6.2, and
manual p.110 which §6.20m settles), so the coin only reports the win —
`You won the coin toss.` — and the choice is its own two-button dialog.

Two corrections to this section. It says the coin-toss dialog should
announce `%s will play first`; it should not — that line is the REPORT of
the winner's choice (`@DIALOG_PLAYORDRAW` entries 8-9), and it now comes
after the dialog rather than instead of it. And the ante the mulligan
dialog shows (`%s ante:` / `Your ante:`) is now real: the duel stakes one
(§6.19) and the whole opening happens in ONE window that carries both
antes as full cards — see §6.2.

Pinned by `tests/unit/test_mulligan.gd` (the rule) and
`tests/ui/test_opening_hand.gd` (the sequence and every string).

### 1.6 [1997] First-strike damage has no priority window — DONE (2026-08-31)

`Mtg.STEP_ORDER` (`engine/core/mtg.gd:60-90`) has one `COMBAT_DAMAGE`
step, and `MtgGame._combat_damage` runs both waves back to back. CR 510.4
makes them two steps with priority in between, which is when you
regenerate the survivor, or Giant Growth after the White Knight connects.
Not currently in `docs/mechanics.md §14` or the ROADMAP.

Reference: `pkg/mage/turn.go:107-123` (`case FirstStrikeDamage:` …
`runPriorityRound(false)`, then `case CombatDamage:`), membership via
`pkg/mage/combat.go:218-251` `HasFirstStrikers`/`DealsDamageInStep`.

**BUILT.** `Mtg.Step.FIRST_STRIKE_DAMAGE` sits between DECLARE_BLOCKERS and
COMBAT_DAMAGE in `STEP_ORDER` and `PRIORITY_STEPS`, and per CR 510.5 it is
SKIPPED outright when nobody in combat has first strike — so a combat
without first strikers stops for damage exactly once, as it always did, and
no existing test changed. Membership is frozen when the first step begins
(`MtgGame._first_strike_ids`), so a creature that gains or loses first
strike in the window between them still strikes exactly once. Fog is
checked per STEP, so one cast in the window stops only the normal damage.

Two follow-ons the split unlocked, both one-liners: `CombatBar.Slot.
FIRST_STRIKE_DAMAGE` is no longer a dead icon (its own comment said it
would light "once §1.6 lands"), and `TargetArrows` keeps the blocker arrows
up through the new step.

Pinned by `tests/unit/test_first_strike_step.gd`, whose sharpest test kills
the blocker in the window so the first striker walks away untouched — an
outcome that was unreachable while both waves ran back to back.

---

## 2. Priority two — the duel is hard to READ

### 2.1 [1997] THE ARROWS — DONE (2026-08-31)

`game/duel/target_arrows.gd`, ported from `duel.go:3449-3554`. Red
blocker→attacker, amber caster→target, a targeted player terminating on
their life panel. Recorded here because it was priority one until it
landed; see `docs/duel-screen-design.md` (twenty-sixth pass).

### 2.2 [s30] Attacker / blocker LIFT — SUPERSEDED (2026-08-31)

**The manual answered this item's own question and the answer is no.** It
ends "check the manual first: if the original marked attackers some other
way (a border, a turn), that wins" — it did: the original MOVES them, out
of the territory and into the **Combat window** (§6.5, now built). s30's
20px slide is its substitute for a window it does not have (s30 fights in
place). Nothing lifts because nothing in combat is left on the board to
lift. Retained below only as the record of what s30 does.

Nothing on our board moves when it attacks. s30 slides a selected or
declared attacker 20px toward the centre line over 150ms
(`duel.go:69-72`, `684-728` `attackerLiftY`/`startAttackerLift`/
`syncAttackerLifts`), and re-targeting mid-flight starts from the current
interpolated offset so a toggle never jumps
(`duel_attacker_lift_test.go:65-84`). The rules for *which* cards lift
(`duel.go:730-776` `attackerLiftTargets`) are the interesting part: during
your declare-attackers only pending attackers lift; in any other combat
step every attacking or blocking creature lifts — yours by −20, theirs by
+20, both toward the line; at end of combat previous lifts freeze so
nothing drops mid-step. Hit-testing must add the live offset
(`duel.go:1589-1617`).

Note this is **[s30]**, not 1997 — but check the manual first: if the
original marked attackers some other way (a border, a turn), that wins.

### 2.3 [1997]+[s30] Hand and battlefield are unsorted — DONE (2026-08-31)

**The tag was wrong in BOTH places, and the correction is in our favour.**
The heading said `[1997]` and the summary table said `[s30]`; the truth
is that the CONTROL is 1997's and only the ORDER is s30's. The original
sorts nothing automatically — its hand window merely scrolls (`Duel.hlp`,
topic **Hands**: *"This is a 'revolving' scroll"*) — but it ships an
**on-demand** arrange, `@MENU_TERRITORY` (`UIStrings.txt:908`) entries
15-16 `Arrange your cards\tDblClk` / `Arrange opponent's cards\tDblClk`,
which `Duel.hlp`, topic **Territory**, defines: *"**Arrange Cards**
straightens up the cards in play in the territory where you
right-clicked. This has no effect on the duel, it just makes things
neater. (You can also double-click on a territory to do this.)"*

So the owner's click-to-sort **toggle** is closer to the original than
the item it came from. Shipped as: `[1997]` command, `[s30]` order (no
1997 source records what "straightened" looked like), `[s30]` for the
hand half (the 1997 hand window has no arrange), `[QoL]` for toggling it
back off.

- `game/duel/board_order.gd` — hand: lands first by name and stop there,
  then colour rank (W=1…G=5, gold 6, colourless 7), mana value, name;
  creatures: power desc, toughness desc, name; lands: name, then
  untapped before tapped. Other permanents keep play order, as the
  reference leaves them. Ported from `duel.go:1438-1544`, pinned against
  s30's own fixtures in `tests/unit/test_board_order.gd`.
- Two corrections to the reference: the creature order reads **live**
  P/T (CONTRIBUTING.md rule 5; s30 reads printed and gets Crusade wrong), and
  every key ends on the instance id because `sort_custom` is not stable.
- `game/duel/arrange_button.gd` is the toggle, right-aligned in
  `DuelScreen._qol_reserve` — the strip's first tenant. Icon drawn, not
  imported: three cards askew / three squared up.
- **Restore semantics:** nothing is snapshotted. The engine's zone arrays
  are the unarranged order and are never touched, so untoggling restores
  it exactly, and a card that arrives while arranged takes its arranged
  place at once and its engine position when the toggle goes off.
- Per territory underneath (the 1997 command is), so §6.3's two
  `Arrange` entries drive one half each; the sidebar toggle does both.

### 2.4 [1997] The spell-cast animation — DONE (2026-09-01), AND IT IS [s30]

The original's signature moment: the card you cast flies to the enlarged
card window. s30 reproduces it in `duel_spell_animation.go`: a new
non-ability stack item tweens from its hand slot to the magnifier rect
(x=0, y=188, 245×342) over 300ms `ease.OutCubic`, holds 200ms, then tweens
to its destination in another 300ms, interpolating position AND size
(`:17-22`, `:36-91`). The source rect is the controller's hand panel plus
`index * 20` for that card's hand index (`:162-193`); the destination is
resolved when the item leaves the stack — its new battlefield slot, an
attached aura at `host.Y-14`, or a graveyard rect (`:195-248`). Crucially
`spellIsAnimating(id)` (`:250-261`) makes `drawBattlefield` skip the
permanent and `drawGraveyard` fall through to the next card, so it is
never drawn in two places at once.

**THE TAG IS WRONG, AND THE EVIDENCE IS THREE-DEEP.** Nothing in the 1997
sources describes a card in motion:

 * the 1997 duel is a Win32 application whose windows are registered
   window CLASSES — `MAGICGAME_SpellChainClass`,
   `MAGICGAME_BigCardCardClass` and `MAGICGAME_BigCardChoiceClass` are all
   in `Program/Magic.exe`'s string table. A window opens; it does not fly.
 * `@DIALOG_DUELOPTIONS`'s nineteen strings contain exactly one animation
   switch — `Show coin &flip animations` — and `coin_flip(player,
   dialog_title, show_dialog_if_animation_is_off)`
   (`shandalar-src/src/manalink.h:266`) is the only 1997 entry point that
   takes an "animation is off" argument. The coin is the duel's one
   animated thing.
 * `Duel.hlp`, **Showcase**, lists the ways it fills — hover, and *"Cards
   drawn into your hand are displayed when you draw them"* — and then
   closes the question: *"The Showcase is a display only; it has no other
   function."* Casting is not one of them.

So the flight is **[s30]**, and it is kept because it is good.

**BUILT** as `game/duel/spell_flight.gd`, with the 1997 DESTINATION
substituted for s30's. s30 flies the card to its magnifier and holds it
200ms there because s30 has no chain window; the original has one —
*"the Spell Chain window opens. The spell in progress, any other spells in
the batch, and all their targets are displayed"* (`Duel.hlp`, **Spell
Chain**; manual p.122 says it again) — so the card flies to THE CHAIN, and
the hold is unnecessary because the card stays on the chain for as long as
the chain holds it. When the object leaves the chain it flies on to where
it landed: its battlefield slot, or its owner's graveyard pile.

Three things are worth the ink:

 * **Size is not interpolated, and that is a fidelity GAIN.** s30 grows
   the card from 83px to 342px because its magnifier is a different
   widget. The original has one card size for the whole duel
   (`set_smallcard_size`, `windows.c:1088` — the forty-second pass's
   finding), so ours is a `MiniCard` at `MiniCard.SIZE` at both ends and
   only the position moves.
 * **A spell that resolves mid-flight re-routes** rather than losing its
   animation. With nobody responding, a chain object can leave the chain
   before the flight that put it there has landed; the second journey
   starts from wherever the first had got to. s30 pushes `resolvedAt` out
   past the first tween instead.
 * **A headless run does no work at all.** The per-frame widget scan is
   the layer's only cost and it is off without a display (the same gate
   `_run_coin_toss` uses), so with no samples nothing is ever queued.

Pinned by `tests/ui/test_spell_flight.gd` (12 tests) and verified in
motion under `xvfb` — hand slot → chain slot → graveyard plate.

### 2.5 [1997] The ability chooser and the X chooser are bare Godot widgets — DONE (verified 2026-09-01, heading audit)

Both are `OriginalDialog`s now (`duel_screen.gd`'s `_x_dialog`
and the mode chooser), captured by the tour as `shot_dialog_x.png` and
`shot_dialog_modes.png`. The heading outlived the work.

Our ability menu is a `PopupMenu` at the mouse
(`duel_screen.gd:1055-1066`) and our X prompt is an `AcceptDialog` with a
`SpinBox` (`:1014-1032`, `:1656-1662`). We already own the right shell —
the modal-choice dialog built for Primal Clay (`:775-830`, the reference's
enlarged card beside glowing choice lines). Both should move onto it.

s30's versions: `duel_ability_chooser.go:20-45,110-144` (dim
`RGBA{0,0,0,160}`, a 24px "Choose Ability" title, the full card image,
one button per option labelled `"%d. %s"` at 40px pitch, **number keys
1-9 select directly**, `:56-63`) and `duel_xspell.go:20-49,118-152`
("Choose X", the card, one `"X = %d"` button per affordable value, digit
keys `:61-68`).

Ours computes the payable X bound in the UI; s30 gets `MaxXValue` from the
engine. Our bound was already wrong once (`docs/duel-screen-design.md`,
twenty-fifth pass) — moving it into `MtgGame` beside `can_afford` would
stop it drifting again. **[QoL]**, S, engine.

**STILL OPEN, and it has now been wrong TWICE.** §6.14 found the second
one: the bound ignored Fireball's per-target surcharge, so a full-value
Fireball at two or more targets was a guaranteed refusal. Fixed inside
[FireballDialog], which asks for the count in the same window and prices
both — but the arithmetic is still in `game/`, which is exactly the
argument this paragraph makes. The X dialog is now the 1997 one
(`@DIALOG_FIREBALL`), so what is left here is only the bound's home.

### 2.6 [s30] Pacing is one flat delay, not per-event dwell — DONE (2026-09-01)

`config.pace` is a single 0.35s gap between AI actions
(`duel_config.gd:18`, `duel_screen.gd:958-971`). s30 gives each game
*message* a minimum dwell (`duel.go:497-514`, `555-574`): 100ms normally,
300ms when the active player is not you, and **600ms when either life
changed, any permanent's marked damage changed, or a new log line matches
`" deals "` + `" damage to "`** (the diff detectors are at `:576-611`).
That is what makes an opponent's turn legible instead of a flicker.

**BUILT.** We have no message queue, so the thing that waits is the one
wait the duel already had: the AI's own pacing timer. **`DuelConfig.pace`
keeps meaning exactly what it meant** — the ordinary gap between AI
actions — and it maps onto s30's MIDDLE tier, because an AI action is by
definition the opponent acting. The other two are its multiples, in s30's
own ratios: `DWELL_QUIET` 1/3 (100/300), `DWELL_ENEMY` 1, `DWELL_EVENT` 2
(600/300). So `demo_default()`'s 0.8 is still 0.8 between actions and
`vs_ai_default()` is still `Settings.ai_pace()`.

What CHANGES is the two ends. An AI acting inside the HUMAN's turn — it is
only passing priority — drops to a third of the pace, which is s30's
`phaseDisplayDelay` and is what stops your own turn feeling sluggish; and
a step where either life total or any permanent's marked damage moved
lingers for double, which is s30's `lifeChangeDelay`. A demo has no "you",
so every turn is somebody else's and every ordinary gap is unchanged.

The detector is s30's, one simplification lighter: s30 asks three
questions (either life, any permanent's marked damage, and a log line
matching `" deals "` + `" damage to "`) and the third is a consequence of
the first two, so two diffs answer all three. The damage record is per
PERMANENT and not a total, because a sum would cancel a heal against a
wound — s30 builds the same id→damage map.

**`_maybe_schedule_ai` still creates exactly one timer, and there is no
`await` anywhere near it** — a test asserts that over the source text,
because "a headless run must not gain a single wait it did not have" is
the constraint the whole item hangs on. Pinned by
`tests/ui/test_pacing.gd` (12 tests).

### 2.7 [s30] The losing life total does not count down — DONE (2026-09-01)

Ours jumps to the final number and prints one line
(`duel_screen.gd:183-188`). s30 interpolates the dying player's numeral
from its previous value to the final negative one over 900ms, then holds
500ms, and refuses to leave the duel until it finishes
(`duel.go:613-682`, `1218-1234`). `start` is idempotent so it never
restarts.

**BUILT**, with s30's own two durations (`LOSS_COUNT_SECONDS` 0.9,
`LOSS_HOLD_SECONDS` 0.5) and its own gate: only a seat at or below zero
life is counted, so a duel lost to an empty library or to poison — where
no number moved — opens its window at once. `DuelScreen._run_death_countdown`
tweens the numeral and `_on_game_over` AWAITS it before building the End
of Duel window, which is s30's *"refuses to leave the duel"*.

**The interesting part is where the count starts from.** s30 reads
`prev.State`, the previous message. We have no message log, so
`_last_life` records the life each `_refresh` PAINTED — and it is one
repaint behind the engine by construction: `MtgGame` deals the lethal
damage, emits `game_ended`, and only then emits `state_changed`. So when
`_on_game_over` runs, `_last_life` still holds the pre-damage number.
That invariant is pinned by its own test, because it is the thing that
would break silently if the engine ever emitted in the other order.

Pinned by `tests/ui/test_life_countdown.gd` (6 tests).

### 2.8 [1997] There is no end-of-duel screen at all — DONE (verified 2026-09-01, heading audit)

Built as `_over_dialog` on `Winbk_Endduel` — the only ground in the
set with a SUNKEN bevel, because the duel's verdict is carved in rather
than raised. Its three lines are `@DIALOG_SHANDALARENDDUEL`'s, the draw
included (see §6.16).

A duel ends with a sentence in the message bar. Both references end with
a screen. s30's are adventure-flavoured (`duel_win.go`, `duel_lose.go` —
cards won/lost, gold, bonus) and therefore out of scope as written, but
the *existence* of a win/loss sequence is not: the manual (§6) is the
authority on what the 1997 game showed.

### 2.9 [1997] Creature stats and damage — DONE (2026-08-31), premise reversed

**The to-do had this backwards, and the manual says so.** It asked whether
to adopt s30's `power/(toughness − damage)` (`duel.go:3398-3432`, pinned
by `duel_stats_test.go`). Manual **p.114**: *"The Show Power/Toughness
check box determines whether or not the **current** power and toughness of
each creature is displayed on the card in play. (The SHOWCASE always shows
the **original** power and toughness.)"* — and `Damage: %d` is its own
`@CUECARD_SMALLCARD` entry. So the original prints LIVE P/T *and* a
separate damage marker, which is what we already did; porting
`displayedCreatureStats` would double-count against the dagger.

**The real defect was the other half of that sentence, and it is fixed.**
`CardPreview._power_toughness` returned LIVE values for a battlefield
card, against p.118: *"the Showcase always displays the original card
text. Any changes made to a card after it was put into play … are noted on
the representation of the card **in play, not here**."* It now returns the
printed values always, keeping the `*/*` quirk. A Crusade'd Savannah Lions
reads 3/2 on the table and 2/1 in the Showcase.

**[s30] taken:** the pump colouring — live vs PRINTED, green when pumped,
red when weakened, white otherwise, an OR across both stats with pumped
tested first (`duel.go:3402-3416`). `MiniCard.pt_color`.

Pinned by `tests/ui/test_mini_card.gd`, including
`test_damage_does_not_change_the_printed_toughness` — the anti-s30 pin.

### 2.10 [1997] The small-card state machine — DONE (2026-08-31)

*(Was tagged `[s30]` and framed as "four states, not nine". There is a
1997 source, it names TEN, and it is better; §6.15 was the same item and
they were shipped together.)*

**The overlays.** `@CUECARD_SMALLCARD` (`UIStrings.txt:732`) names ten
states a card on the table can be in, and five ship as art that had never
been imported — `Dying.pic` (silver cracks), `CantTarget.pic` (an orange
circle-slash), `WillUntap.pic` (a blue arrow), `Target.pic` (the crosshair
we only used as a cursor) and `Poison.pic`. `MiniCard.State` /
`STATE_CUE` / `STATE_SPRITE` now draw **eight of the ten**, each with its
verbatim cue card as a tooltip. The two missing are recorded at
`MiniCard.active_states()`.

**CORRECTION (2026-09-01, building §6.20b): one of those two was not
unanswerable, it was in the wrong place.** This item read `Damage to
player` as *"the life register's state (§6.5)"*. It is not:
`@CUECARD_LIFE` (`UIStrings.txt:678`) declares its eight entries and that
is not one of them, and the importer's own note guessing `Poison.pic` as
its art was guessing. It sits in `@CUECARD_SMALLCARD` because the thing it
describes is a small card — the DAMAGE MARKER, manual p.119's *"yellow
'card' on or near the target of that damage"*, when the damage is aimed at
a player rather than at a permanent. `DamageMarker` (§6.20b) carries both
of the table's damage cues: `Damage: %d` and `Damage to player`. Nine of
the ten are drawn now.

Only `Phased` is still unanswerable, and for the reason recorded: it
cannot reach a widget, because `MtgGame.phase_out` removes the instance
from `players[pid].battlefield` and there is no `Mtg.Zone.PHASED_OUT`.

**The borders.** `MiniCard.Highlight` is now
`NONE / OPTIONAL / MANDATORY / COMMITTED / TARGET_LEGAL / TARGET_CHOSEN`,
with the MANUAL's colour code (p.128: *"Mandatory effects are highlighted
in **orange**, while optional effects are in **yellow**"*) over s30's
coverage, and s30's one width distinction (3px for a chosen target). The
`[s30]` orange-means-"something to do" reading is replaced by the
manual's orange-means-"you must" — `must_attack_this_turn` /
`Mtg.Keyword.MUST_ATTACK` for the attacker, `cur_must_be_blocked` for the
defender. The cue we lacked entirely, s30's block 2b, is
`DuelScreen._can_act_on`: an ACTIONABLE PERMANENT, narrowed to activated
(not mana) abilities so the mana base does not light up.

### 2.11 [1997] Missing ability icons: regeneration and protection from artifacts — DONE (2026-08-31)

**Two icons, not three.** Slot **17** of `Abilities.pic` — where s30 maps
Menace (`duel.go:1047-1121`) — is **484/484 px of solid black, one unique
colour**, on the s30 conversion and on our import alike. The 1997 game had
neither the keyword nor the icon; §3.4 already records that no card in
this pool needs menace. `test_menace_is_not_badged` pins it.

Added: **15 regeneration** (`MiniCard.REGENERATION_SLOT`) and **10
protection from artifacts** (`ARTIFACT_PROTECTION_SLOT`). Neither could go
in `BADGE_SLOT`/`PROTECTION_SLOT`, because the engine has no flag for
either — there is no `Mtg.Keyword.REGENERATION` (regeneration is an
activated ability with a `RegenerateEffect`) and `cur_protection` is a
colour bitmask with no non-colour entry (Artifact Ward expresses its
clauses on `cur_damage_immunity` / `cur_target_bans`). The predicates are
`MiniCard.regenerates_itself()` and `warded_from_artifacts()`.

**And the defect the same pass fixed:** every cell of the sheet is a disc
on an OPAQUE NEAR-BLACK SQUARE and `badge_from_slot` built a bare
`AtlasTexture`, so every badge had been drawing a dark 22px block behind
its disc. Measured across all eighteen cells: the furthest non-black pixel
sits at r=11.068 and the nearest black one at r=11.34 in a 22px cell, so a
cut at `cell * 0.51` removes the corners and nothing else.

### 2.12 [s30] Land art does not follow a changed basic subtype — DONE (2026-09-01)

Our art lookup is always by `data.card_name` (`mini_card.gd:284`). s30
draws the NEW basic land's art when a land's live subtypes differ from
its printed ones — City of Brass turned into a Forest draws Forest, and
reverting restores the printed name (`duel.go:337-371` `permanentArtName`,
pinned by `duel_land_art_test.go`).

**BUILT** as `MiniCard.art_name(inst)`, s30's algorithm on our live
`cur_subtypes`: collect the basic land types the permanent HAS, compare
with the ones it was PRINTED with, and on any difference draw the first
live type the printed card did not carry. Only the art window follows —
the name band still reads the printed name, because the card is still
called Tundra.

**AND THE TAG IS HALF WRONG: the ORIGINAL supports it, from the other
end.** `Duel.hlp`, topic **Territory**, lists a card mini-menu entry for
exactly this situation — *"**Original Type** shows you what this card was
when it was cast, before any spells and effects changed it."* An entry
that exists to show you what a card USED to be only earns its place on a
table where the card in play already shows what it has BECOME. So this is
[1997] behaviour that s30 happened to describe first; `Original Type`
itself belongs to §6.12's `@MENU_SMALLCARD`.

CR 305.7 is why it is worth drawing at all: a land retuned to a basic land
type loses the abilities from its rules text, so under Blood Moon a Strip
Mine really is nothing but a Mountain. Pinned by
`tests/ui/test_land_art.gd` (6 tests: Blood Moon, Evil Presence, the
basics it must leave alone, and the restoration when the effect goes).

### 2.13 [s30] Rows wrap instead of squeezing — DONE (2026-09-01)

Our `HFlowContainer`s wrap to a new line when a row overflows. s30 keeps
one row and shrinks the pitch until it fits (`duel.go:1424-1435`: 120px in
the creature row, 35px elsewhere; below `duelBoardW-30-fieldCardW` = 591
the spacing shrinks so cards overlap). A wrapped row breaks the board's
reading order, which is the one thing §2.3 is trying to fix.

**BUILT** as `game/duel/squeeze_row.gd` — a `Container` that never wraps.
Under its natural width it lays out normally and honours an END alignment
(the land and artifact rows gather beside the hand window); over it, the
pitch becomes `(available - last child's width) / (n - 1)` and the cards
slide under one another, exactly s30's arithmetic. All six board rows are
now `SqueezeRow`s.

**ONE GENERALISATION over s30, and it was necessary.** s30 assumes every
card in a row is the same width, so a single `spacing` serves. Our
non-creature rows group into the original's strip-stack piles
([CardPile]), which are several times wider than one card, so the pitch is
computed from the ACTUAL widths — otherwise the piles would overlap into
rubble. There is deliberately no MINIMUM pitch, which is also s30's
choice: with enough permanents the row becomes one stack, and that is the
honest picture of a board with forty lands on it.

**AND THE ORIGINAL AGREES.** `Duel.hlp`, topic **Territory**, offers
**Arrange Cards**, which *"straightens up the cards in play in the
territory where you right-clicked"* — a verb that only means anything on
a row whose cards are allowed to lie on top of one another.

Pinned by `tests/ui/test_squeeze_row.gd` (11 tests, including the
mixed-width case and "the board's rows really are these").

### 2.14 [s30] Hover-examine has no top-of-stack fallback — DONE (2026-09-01), AND THE 1997 RULE IT WAS MISSING

s30's hover chain ends with: if nothing is hovered, show the TOP STACK
ITEM (`duel.go:1930-1954`), so the card currently resolving is always the
one in the magnifier. Ours only updates on a card's `mouse_entered`
(`duel_screen.gd:1339-1344`).

**BUILT**, both halves — and the second half is the one the item did not
know about.

1. **s30's fallback.** Leaving a card now calls
   `DuelScreen._show_top_of_chain()`. With an empty chain it does nothing,
   so the docked Showcase keeps the last card examined, which is the
   owner's own rule; it only takes over while something is genuinely
   waiting to resolve, which is the moment the player most needs to read
   it.
2. **THE ORIGINAL FILLS THE SHOWCASE ON A DRAW.** `Duel.hlp`, topic
   **Showcase**: *"Whenever the mouse cursor pauses long enough over a
   card in play, in a visible hand, or even in a graveyard, that card is
   displayed here. **Cards drawn into your hand are displayed when you
   draw them.**"* That second sentence is the only time the 1997 game
   fills the Showcase unasked, and we did not do it at all. It needed one
   engine change: `CARD_DRAWN` now carries `instance` as well as `player`
   (no rules code reads it; triggers still key off `player`).

   Gated on `hidden_hands`, not on "is it a human": at a hotseat both
   hands are open and each player should see their own draw, while the
   AI's seat is hidden and so is its card. And gated on
   `turn_number >= 1`, which excludes the opening deal and every mulligan
   redraw — seven cards cannot be shown one at a time, and the opening
   window is over them while they are dealt.

Pinned by `tests/ui/test_showcase.gd`.

### 2.15 [s30] No right-click / long-press "just look at it" — DONE (2026-09-01), AND IT IS [1997], NOT [s30]

`duel.go:1909-1928` loads the preview for whatever is under the cursor
without performing its action — and it is the touch path too, which
matters for the Steam Deck and Pi targets in
`docs/duel-screen-design.md §1`.

**THE TAG WAS WRONG.** The 1997 game has both gestures and names them
twice over:

- `Duel.hlp`, topics **Hands** and **Territory**, both end with the same
  sentence: *"You can also right-click and hold to bring a card in your
  hand to the front for as long as you hold the mouse button."*
- `Duel.hlp`, **Territory**, on the card mini-menu: *"**Show full card**
  displays the card in the Showcase. (When you're using the Advanced
  Layout, this opens a temporary Showcase in which to display the card.
  **You can also double-right-click to perform the same function.**)"* —
  and the accelerator is printed inside the string table itself:
  `@MENU_SMALLCARD` entry 2 (`Program/UIStrings.txt:937`) is
  `Show full card\tR DblClk`.

**BUILT** as `DuelScreen._on_card_look`, wired onto every [MiniCard]:
a right PRESS shows the card in the Showcase and lifts it clear of its
neighbours (`z_index = LIFT_Z`) for as long as the button is held; the
release puts it back, and so does a board rebuild, because a rebuild frees
the widget the release would otherwise have arrived at. A face-down card
stays face down.

**A single right-click is deliberately NOT handled here.** It belongs to
`@MENU_SMALLCARD`, the card mini-menu (§6.12) — these two gestures are
shortcuts PAST that menu, not replacements for it, and building them the
other way round would put the menu's entry point out of reach.

Pinned by `tests/ui/test_showcase.gd`.

---

## 3. Priority three — interaction correctness

### 3.1 [s30] Targets cannot be DESELECTED or REPLACED — DONE (2026-08-31)

`DuelScreen._try_take_target` now removes a target that is clicked again
(s30 `selectTarget`, `duel.go:2248-2266`). The refusal it replaces used
the right SENTENCE — `@CUECARD_SMALLCARD` entry 7, "Is a target, can't
target again", is the cue card the original prints under a card that is
already a target (§6.15) — but the wrong ACTION: a misclick cost the
whole cast, on a screen that had no Cancel button to recover with either
(§6.11, landed with it).

**s30's other half needs no counterpart.** "With a maximum of one, a new
click replaces the previous choice" only matters because s30 holds every
selection open until Done; `_advance_pending` closes a slot the instant
its maximum is met, so a one-target slot is never still open to
re-click.

Still open, and deliberately not taken: s30 also clears the selection by
clicking the message bar (`duel.go:2330-2367`). No 1997 source has it,
and the Cancel button that landed in §6.11 covers the need with a
control the original does have.

### 3.2 [s30] Escape aborts everything instead of unwinding one layer — DONE (2026-08-31)

`DuelScreen._on_escape` is s30's ladder (`duel.go:1329-1350`) with our
own two popups slotted into the cast chain: graveyard view → modal-choice
overlay → library picker → the X question → **the picked targets only**
→ the pending action. With nothing open it does nothing; it never leaves
the duel. The ability menu needs no rung — it is a real `PopupMenu` and
Godot closes it before the handler runs.

**Two of those rungs were dead, not merely missing.** The X question and
the library picker are `OriginalDialog`s rather than Popups, and the mode
is still NORMAL while they are up, so Escape sailed past them into an
`_on_cancel` with nothing to do and the dialog would not close at all.
Return was worse: it reached `_on_pass_turn` and fast-forwarded several
priority windows with the question still on screen. Both are pinned in
`tests/ui/test_cancel_contract.gd`.

### 3.3 [s30] Counterspell with one legal target should not open targeting — DONE (2026-09-01)

`duel.go:2006-2041` `autoCounterTarget`: if the opponent controls exactly
one valid stack item, the counter is cast at it immediately; with two or
more, targeting opens normally. Pinned by `duel_counter_target_test.go`.

**VERIFIED FIRST (the Phase-0 probe).** Clicking Counterspell with the
opponent's lone Lightning Bolt on the chain put the screen into
`Mode.TARGETING` with `Select target spell.` — the item's premise held.

**BUILT** as `DuelScreen._lone_counter_target`, called from
`_advance_pending` before it opens the targeting cursor. Three guards,
all s30's, and each one load-bearing:

1. the slot's kind is `TargetSpec.Kind.SPELL`. It is **not** generalised
   to "any slot with exactly one legal target": a Terror aimed at the
   board's only creature would then fire without the player ever seeing
   the cursor, and there is no undo after a cast. The chain is the one
   zone where the candidate is already named on screen, in its own
   window, which is what makes skipping the aim safe there and nowhere
   else. `Kind.SPELL_OR_PERMANENT` (the Laces) is out for the same
   reason — its candidates are mostly on the battlefield.
2. the slot wants exactly one, undivided.
3. the OPPONENT controls exactly one legal chain object. s30's loop
   `continue`s on everything else, so your own spells are neither counted
   nor eligible — countering your own is legal (Counterspell says "target
   spell", not "target spell an opponent controls") but it is never what
   "the only sensible target" means.

Pinned by `tests/ui/test_auto_target.gd` (5 tests, including the Terror
guard and the one-of-each case).

### 3.4 [s30] Menace pre-flight on Done — NOT BUILT, AND DELIBERATELY (verified 2026-09-01)

Pressing Done with a menace attacker blocked by fewer than two creatures
should flash `"Menace: must be blocked by 2 or more creatures!"`, drop
those assignments and NOT submit (`duel.go:2433-2482`, fired at
`:2583-2587`). Needs §5.10 (minimum-blocker restrictions) in the engine
first, which no 1997 card requires — so this is **[s30]**, low.

**PROVED (2026-09-01, the Phase-0 probe).** `Mtg.Keyword` holds exactly
eleven keywords — `FLYING REACH VIGILANCE HASTE TRAMPLE DEFENDER
FIRST_STRIKE MUST_ATTACK BANDING UNBLOCKABLE FEAR` — and not one of them
is a blocker-COUNT restriction; a tree-wide search for `menace` finds it
only in `mini_card.gd:1201-1204`, where the icon map deliberately omits it
and `test_menace_is_not_badged` pins the omission.

**So this item stays unbuilt on purpose, and that is the finding.**
Building the pre-flight would mean first inventing the restriction it
pre-flights: a `MENACE` keyword no card in the 1997 pool has, an engine
rule (§5.10) nothing would exercise, and a warning string no player could
ever see. That is the "never invent what the references already answer"
rule pointing the other way — the reference (s30) has menace because
s30's pool has menace. **Do not build this until a card needs it.** When
one does, §5.10 comes first and this becomes a twenty-line pre-flight in
`_on_confirm`.

### 3.5 [s30] Pending attackers/blockers are not cleared when the step moves under us — DONE (2026-08-31)

`duel.go:1629-1656` clears `pendingAttackers` the moment the declare-
attackers step ends and `pendingBlockers`/`selectedBlocker` when the
blockers prompt ends. We cleared only on confirm or cancel, so a step
advanced by anything else left stale selections — and stale arrows — on
screen. `DuelScreen._refresh` now drops a declaration whose declare step
has ended, on s30's own gate (the STEP, not the awaiting flag). It became
urgent with the Combat window: a stale lineup would put phantom creatures
in it. Pinned by `tests/ui/test_combat_window.gd`.

Related: `duel.go:1193-1197` drops targeting mode when the card being
targeted no longer has any legal action.

### 3.6 [1997] Hand collapse has no keyboard or header-click route — DONE (2026-09-01)

StackHand's ▲/▼ zones do it (`stack_hand.gd:129-156`). s30 also binds
`H` and a click anywhere on the hand header (`duel.go:1672-1706`), and
keeps the header clickable while collapsed. Collapsing exists so the hand
stops covering your own attackers — it needs to be reachable in one
keystroke mid-combat.

**VERIFIED FIRST (the Phase-0 probe):** pressing `H` with the stack hand
on screen left `collapsed = false`. Nothing was bound.

**BUILT.** `H` is bound in `DuelScreen._unhandled_key_input` and a click
on the header toggles the fold — but the header click had a 1997
constraint s30 does not have to respect. `Duel.hlp`, topic **Hands**:
*"Both of these windows are movable. **To move a hand window, click and
drag on the bar at the top of the window.**"* That bar is our drag handle,
and s30 binds a plain click on the whole header to `toggleHand()` only
because s30's windows do not move. The two are told apart by MOVEMENT: a
press that never travels more than `StackHand.DRAG_SLOP` is a fold, a
press that does is a drag. Both gestures survive.

**AND THE ARROWS ARE NOT WHAT WE THOUGHT THEY WERE.** `Duel.hlp`,
**Hands**, continues: *"Each window has a maximum size. If there are too
many cards in your hand to display all at once, **use the scroll arrows at
the top** to see the rest. This is a **revolving** scroll, which means
that the top cards cycle to the bottom; the number of cards in your hand
is always noted on the top bar."* So the ▲/▼ painted into the 1997
`Hand_<colour>` sheet are SCROLL arrows, not collapse/expand — the fold
itself is s30's idea, and the original's answer to a hand too long for its
window is a revolving scroll. Ours keeps the fold on those zones for now,
because nothing else claims them and the pile has no maximum size to
scroll past; **the revolving scroll is unbuilt and is not tracked
anywhere else — it belongs to a future §2 item.**

Pinned by five new tests at the foot of `tests/ui/test_stack_hand.gd`,
one of which drives the `H` key through the real duel screen.

### 3.7 [QoL] Done is only lit during combat declarations — DONE (2026-09-01), AND IT IS [1997]

We brighten Done in ATTACKERS/BLOCKERS mode (`duel_screen.gd:1187-1188`).
s30 outlines it yellow 2px **whenever the human has any option at all**
(`duel.go:3122-3138`) — the standing "it's on you" cue. Check the manual
(§6) for what the original's Done button did.

**VERIFIED FIRST (the Phase-0 probe):** in `Mode.NORMAL`, with the human
holding priority in their own main phase — the commonest moment in the
whole duel, and one where Done is the only thing to click — the button's
modulate read `(1,1,1,1)`. Unlit.

**THE SOURCES CHECKED, AND THE TAG IS WRONG.** `Duel.hlp`, topic
**Situation Bar**: *"At the rightmost end of this bar is a **Done**
button, a **Cancel** button, or both, **depending on the situation**."*
Manalink states the same thing as a bit spec — `allow_cancel`
(`shandalar-src/src/defs.h:2390`): 0 no buttons, 1 Cancel, 2 Done, 3
both. So "is Done applicable right now?" is a 1997 question with a 1997
answer, and s30's yellow outline is just a different way of showing the
same bit. Not [QoL].

**BUILT** as `DuelScreen._done_applies()`, written as the deliberate
COMPANION of `_can_cancel()` — the two predicates ARE the two bits, and
keeping them side by side is what stops them disagreeing. We light the
button rather than hide it, because Done is also the duel's only Pass
control and a control that vanishes is worse to aim at than one that dims.

One refinement over "whenever the human has an option": in TARGETING,
Done is lit only for a slot it can actually CLOSE — a variable slot whose
minimum is met. On a fixed one-target slot the slot closes itself and Done
has nothing to do, which is the honest half of the old condition and is
kept.

Pinned by `tests/ui/test_situation_bar.gd`.

### 3.8 [s30] Missing sound cues — DONE (2026-09-01), AND THE MAP WE HAD WAS WRONG

We map engine events to per-colour cast, summon, tap, attack, damage,
dies, end-of-turn and win/lose (`duel_screen.gd:216-238`). s30 derives its
cues from state DIFFS in a fixed order (`duel.go:887-978`): damage,
creature death, **land play**, summon, cast, **counter (the stack shrank
by ≥2)**, **mana-ball (either pool grew)**.

**WHAT BUILDING IT FOUND.** `shandalar-src/src/defs.h:2179` is the 1997
sound enum, headed *"Constants for play_sound_effect(). Named identically
to their filenames in DuelSounds/"*, and the call sites in
`src/functions/` say what every entry is FOR. Two rules fall out, and the
first of them corrected what we had:

1. **A SPELL SOUNDS LIKE ITS CARD TYPE.** `engine.c:1784-1802` fires
   `WAV_SUMMON` / `WAV_ARTIFACT` / `WAV_ENCHANT` / `WAV_INSTANT` /
   `WAV_INTERUPT` / `WAV_SORCERY` off the type mask.
2. **A LAND SOUNDS LIKE THE COLOURS IT MAKES.**
   `play_land_sound_effect_force_color` (`functions.c:14387-14453`),
   called from `mana_producer`'s `EVENT_RESOLVE_SPELL`
   (`produce_mana.c:57`): colourless → `WAV_GREY`, one colour → that
   colour's file, two → the pair's own file, and *"five colors - going
   with gembazar, even though **City of Brass is silent**"* — so a
   five-colour land makes no sound in the 1997 game, and ours makes none.

**OUR CAST SOUND WAS THE LAND TABLE.** `White/Blue/Black/Red/Green.wav`
were imported as `sfx_cast_<colour>` and played on every SPELL_CAST. The
enum groups those five files under a literal `// Land sounds.` comment.
Casting a Mountain and casting a Lightning Bolt made the same noise, while
`Sorcery.wav`, `Instant.wav`, `Enchant.wav`, `Interupt.wav` and
`Grey.wav` sat unimported. The five keys are now `sfx_land_<colour>`, ten
dual-land files and `Grey.wav` joined them, and the four type sounds were
imported — sixteen new files, all listed in `tools/import_original.py`
with their provenance.

**TWO OF s30's THREE NAMED CUES ARE NOT 1997 CUES AT ALL.**
- *counter (the stack shrank by ≥2)* wants `Counter.wav` — but the enum
  annotates that entry itself: `WAV_COUNTER = 37, // "a counter has been
  added to a card", not "a spell has been countered"`, and its only call
  site is `counters.c:2085`. The original's countering sound is
  `WAV_INTERUPT`, because in 1997 Counterspell WAS an Interrupt; rule 1
  therefore covers it. The modern oracle folded Interrupt into Instant, so
  `DuelAudio.cast_sound_key` (`DuelScreen._cast_sound_key` until the
  2026-09-02 pass below moved it) keys it off the counter EFFECT rather than
  inventing a type we do not model.
- *mana-ball (either pool grew)* wants `ManaBall.wav`, **which is not in
  the 1997 duel enum at all**. Mana appearing already has a cue there and
  we already play it: `WAV_TAP`, on `TAPPED_FOR_MANA`.

Only *land play* survived, and the original's version of it is richer than
s30's single `land_play.ogg`. Two more 1997 cues were wired while the map
was open: `WAV_DRAW` on `CARD_DRAWN` (`deck.c:728`) and `WAV_BLOCK2` on
`BLOCKERS_DECLARED` (`engine.c:1539`, `ai.c:398` — the "declared" event,
not `BLOCKED`, which fires once per pair and would stack the sample on
itself).

**STILL UNPLAYED, and now catalogued rather than forgotten:**
`Discard.wav`, `Destroy.wav` (which `deck.c:1158` records is *"the rfg
sound effect, despite its name"*), `Kill.wav`, `Regen.wav`,
`Sacrfice.wav`, `Shuffle.wav`, `LifeLoss.wav`, `ManaBurn.wav`,
`Control.wav`, `ChangeC/ChangeT.wav`, `EndPhase.wav`, `FastFX.wav`,
`Cancel.wav`. Each needs an engine event we do not dispatch yet.
`LifeGain.wav` is **not** a 1997 sound — `Duelsounds/sounds.txt` credits
it as a Manalink addition, and there is no `WAV_LIFEGAIN` in the enum.

Pinned by `tests/ui/test_duel_sound.gd` (12 tests, including one that
asserts no spell may ever borrow a land sound again, and one that loads
every key the screen names so a typo is a failure rather than silence).

---

#### 3.8b — THE SECOND PASS (2026-09-02): the mixer, the timings, the music

§3.8 got the cue NAMES right and left three things wrong: how they were
mixed, when three of them fired, and how much of the original's audio
nobody had looked at.

**THE MIXER: one voice for the whole duel.** `duel_screen.gd` owned a
single `AudioStreamPlayer` for every effect, so any two cues that
overlapped cut each other off — a tap during a damage sound killed it —
and volume was copied onto it once at build time, so an Options slider
changed nothing that was already on screen.

*What the original did, now known from both directions.* The Manalink
wrapper (`shandalar-src/src/functions/windows.c:1268-1317`) asks
`IsSndLoaded(soundnum, &adj_soundnum)` for the SLOT a WAV occupies, loads
it into one if it is not there, and calls `PlaySnd(adj_soundnum)`; the
deck builder drives the same interface with five slots at once — music on
1, draw on 2, discard on 3, button on 4, cancel on 5
(`src/deck/deckdll.cpp:2040-2056`). The **decompilation confirms it from
inside**: `MAGSND.DLL` keeps a 272-entry table of one descriptor per
loaded sound id, `IsSndLoaded` returns that descriptor's slot, `GetLRUSnd`
evicts within a caller-chosen sub-range, and `PlaySnd` re-triggers the
existing buffer for an id rather than allocating a second one. So 1997 was
**polyphonic across different sounds and monophonic per sound**.

*Built* as `game/audio.gd` (`GameAudio` — the `Music` and `SFX` buses and
the settings behind them) and `game/duel/duel_audio.gd` (`DuelAudio` — up
to eight voices on the SFX bus, plus the cue map, which came out of
`duel_screen.gd` so it can be tested without building a screen). A cue may
take **one voice per frame** and different cues layer freely, which is
the 1997 slot behaviour exactly: a five-way combat is one `Damage.wav`
rather than five copies phase-locked into one hit five times as loud, and
the opening deal is one `Draw.wav` rather than fourteen.

**THREE CUES FIRED AT THE WRONG MOMENT.**

1. **Every creature announced itself twice.** The type sound played on
   `SPELL_CAST` *and* `sfx_summon` played again on `ENTERS_BATTLEFIELD`.
   `engine.c:1786` sits inside the RESOLUTION path — the block that sets
   `STATE_IN_PLAY` and calls `resolve_top_card_on_stack()` — so a
   permanent is announced when it ARRIVES, which is also when §2.4's
   spell flight puts the card down. An instant or a sorcery keeps its cue
   on the cast, and that is **labelled**: it never enters the battlefield,
   and we dispatch no "spell resolved" event to hang one on.
2. **Every permanent arrived sounding like a creature.** The
   `ENTERS_BATTLEFIELD` branch played `sfx_summon` for every non-land.
   `engine.c:1788`/`:1794` give an artifact and an enchantment their own
   files.
3. **Damage to a player was the wrong file.** `damage_effects.c:524` is
   labelled *"// Damaging a player."* and plays `WAV_LIFELOSS`; only
   `:705`, damage to a card, plays `WAV_DAMAGE`. `lose_life`
   (`functions.c:9871`) plays `WAV_LIFELOSS` as well. We played
   `Damage.wav` for both, and `LifeLoss.wav` sat imported and unused.

**FOUR CUES THE ORIGINAL HAD AND WE DID NOT PLAY:** `Untap.wav` on the
untap step (`WAV_UNTAP`, one sweep per step thanks to the frame
coalesce); `Tap.wav` when a permanent taps to pay for an ABILITY, not
only for mana (`engine.c:1917` — a Prodigal Sorcerer pinging used to be
silent until its damage landed); `Shuffle.wav` at the duel's opening
(`functions.c:9121-9127`, which plays it and then runs the exe's own
shuffle animation); `Discard.wav` on the hand-size discard
(`functions.c:14861`).

**THE MUSIC SURVEY — one duel loop was not the whole of it.** The
original's tunes all live in `Sound/`, and `strings Shandalar.exe` names
them in its own resource list:

| File | Where it plays | Ours |
|---|---|---|
| `Dueltune.wav` | the duel, looped | already played |
| `LocMus0`–`LocMus19` | the overworld, keyed to terrain (`index % 20`, looped); **the deck builder picks one of 1..19 at random and loops it** (`deckdll.cpp:2047`, `RANDRANGE` inclusive at `:746`) | **built** — the deck-builder half, as `music_location_N` |
| `Tmplmus1.wav` | terrain slot 19 — a Temple | [M5] |
| `Bcastle`/`Ucastle`/`Gcastle`/`Rcastle`/`Wcastle` | near a castle, by colour, looped | [M5] |
| `Dngnduel.wav` | a ONE-SHOT stinger on the "you encounter…" text, **not** dungeon-duel music | [M5] |
| `Wingame.wav` | winning the whole game | [M5] |
| `Winduel.wav`/`Loseduel.wav` | the shell's win/lose screens, beside `winbak01.pic`/`losedul2.pic` | the DUEL's own pair is `DuelSounds/Shell_WinDuel.wav`/`Shell_LoseDuel.wav` — different audio of the same length, and now what we import |

Everything else in `Sound/` is adventure ambience — castle beds, per-colour
world-map and land loops, bird calls, footsteps, `Dice`, `Treasure`,
`Reward`, `Scroll`, `Findcard`, `Newsflash` — catalogued in
`tools/import_original.py` and left for M5. `Manalink.wav` is Manalink's
own and never 1997.

**AND ONE ASSET WE SHOULD NEVER HAVE IMPORTED.** `strings Magic.exe`
names exactly 69 `.wav` files — `WAV_ARTIFACT = 0` through
`WAV_EXP1_BACKINPACK = 68`, the enum's own `WAV_HIGHEST_EXE`. Everything
above 68 in `defs.h` is Manalink's, and `Duelsounds/sounds.txt` credits
each one to freesound.org or to a re-edit of an adventure sound.
`sfx_life_gain` ← `LifeGain.wav` was in our manifest on that mistake; it
is out, and the manifest says why so it does not come back.

**THE SETTINGS.** `music_enabled` joins `sound_enabled`, because the 1997
game had two switches and not one: `&Music` and `Sound &Effects` are
entries 8 and 9 of `@DECKSURFACE_STANDALONE`
(`s30/assets/text/Menus.txt:169-179`) and of `@MAINMENU_STANDALONE`
(`:218-228`), and `deckdll.cpp:1296` persists the first by that literal
name. Both switches are now in **two views of one value**: the deck
builder's mini-menu, where 1997 put them and where they tick like the
`CHECKMENU_IF` items they were (`deckdll.cpp:6085`), and the `[QoL]`
Options screen, which is an aggregator. The two volume sliders stay ours
— there is no volume control anywhere in the original — and they set bus
volumes, so dragging one is audible in a duel that is already running.

Pinned by `tests/ui/test_duel_sound.gd` (28 tests: the cue map, the three
corrected timings, the frame coalesce, a missing sample handled silently,
and a headless run that allocates no audio player at all) and
`tests/ui/test_game_audio.gd` (11 tests: the buses, the settings
round-trip, a bus born already carrying the player's volume, the two
switches muting their own bus only, and the `M`-key hush that never
writes a preference).

### 3.9 [1997] The stack's description never reaches the message bar — VERIFIED WORSE THAN WRITTEN (2026-09-01), NOT BUILT

s30 prefixes every status message with
`"<controller> casts|activates <name>[ for N][ targeting A, B]. "` per
stack item (`duel.go:3799-3825`). Our chain items carry that information
only in a tooltip (`duel_screen.gd:1252`) — and `for N` (the chosen X) and
the target list appear nowhere on screen.

**THE PHASE-0 PROBE FOUND IT WORSE THAN THE ITEM SAYS.** With a Lightning
Bolt on the chain, `StackItem.description` reads
`"Black Wizard casts Lightning Bolt"` and the bar reads `"Upkeep Phase"`.
So there was nothing to forward: the ENGINE's own description
(`mtg_game.gd:1003`, `:1170`) carries neither the target list nor the
chosen X, and the tooltip the item credits us with is showing the same
short sentence. Two defects, not one.

**AND THE 1997 SOURCES DO NOT WANT s30's SENTENCE.** The Situation Bar's
whole vocabulary is `@PROMPT_FASTEFFECTS` + `@PROMPT_CHECKFEPHASE` (§6.7),
and its way of naming what is on the chain is three words —
`Cast %s` / `Activate %s` / `Process %s` — which the bar ALREADY prints
(`Fast Effects?...Cast Lightning Bolt`, verified by the probe and pinned
in `tests/ui/test_situation_bar.gd`). There is no 1997 string of the form
`X casts Y targeting Z`, and prefixing every status message with one would
be s30's running commentary in place of the original's bar.

**So the item splits, and only one half is worth doing:**
- **Worth doing, and NOT DONE:** put the target list and the chosen X into
  `StackItem.description`, which is an ENGINE change (it is also the game
  LOG's sentence, so it improves the log at the same time) and would then
  reach the chain window's caption and tooltip for free. Left for a future
  pass, deliberately, because it touches `mtg_game.gd`'s two description
  sites and every test that reads the log.
- **Declined:** s30's message-bar prefix. The 1997 bar has its own words
  for the same fact and already says them.

**CHECKED AGAIN WHILE BUILDING §6.8 (2026-09-01), AND IT DID NOT GET
CHEAPER.** §6.8 gives targets a third kind (a `DamagePacket`) and makes
`TargetRef` compare identity in one place, but it adds nothing that names
a target in card English — `TargetRef._to_string()` says `damage #7`,
which is a debugging string, not something a description may print. The
work §3.9 still needs is a naming function for a target plus the two
description sites, and the reason it was deferred (every test that reads
the log) is untouched. **Still ledgered, deliberately** — and the future
pass now has three target kinds to name, not two.

### 3.10 [s30] Missing status-bar states — DONE (2026-09-01), PREMISE HALF WRONG

`duel.go:3126-3171` orders the bar: red warning → `"targeting %s
(Cancel)"` / `"Selected %d of %d targets (Cancel)"` → the targeting prompt
→ the status message. We have the warning flash and the status message but
neither targeting state. See §6 for what the ORIGINAL said here, which
outranks s30.

**THE PROBE FOUND BOTH TARGETING STATES ALREADY PRESENT, in the
ORIGINAL's wording rather than s30's** — which is exactly what the item's
own last sentence asked for. Aiming Lightning Bolt the bar reads
`Select any target.`; aiming Pyrotechnics it reads
`Select any target. (1 so far)`. The first is the form every entry of
`promptsX2.txt` uses (`:24` is `Select target creature.`); the second is
`@PROMPT_GRABMANA` (`UIStrings.txt:1090`), `%s(%d so far)` and
`%s(%d so far, max %d)`. The item was written before that landed.

**`(Cancel)` IS DECLINED, with a reason.** `Duel.hlp`, **Situation Bar**,
puts Cancel on a BUTTON that appears *"depending on the situation"* — and
§6.11 already shows it exactly then (`_can_cancel`). Writing the word into
the prompt duplicates a control the original has and we have.

**WHAT WAS GENUINELY MISSING, and is now built — the WARNING state.**
s30 paints `warningMsg` in `RGBA{255,100,100}` and every other bar state
white (`duel.go:3145-3168`). Ours wrote refusals in the bar's own pale
stone, so *"not enough mana for Lightning Bolt ({R})"* and *"Main phase
(before combat): cast spells"* arrived in the same voice. Refusals are now
red (`DuelScreen.WARNING`) and everything else is not.

**AND THE FLASH NEVER ENDED.** `_flash_until_ms` only ever gated the
status line INSIDE `_refresh`, so a refusal sat on the bar until something
else happened to call it — press an illegal card in a quiet main phase and
the line was permanent. A one-shot [Timer] now repaints the bar when the
flash runs out. (s30 has no timer: it redraws every frame and clears
`warningMsg` on the next action, which a retained-mode UI cannot copy.)

Pinned by `tests/ui/test_situation_bar.gd`.

---

## 4. Priority four — fidelity details found in the original's own art

### 4.1 [1997] The phase strip has no per-slot tooltips — DONE (verified 2026-09-01, heading audit)

Same work as §6.1, which was already marked done: `phase_bar.gd` sets
the per-slot `tooltip_text`. This heading was the duplicate that never
got the stamp.

**Settled by the owner: our modern step naming and our slot count STAY.**
"Declare Attackers" is clearer than "Main phase (combat)", and keeping the
modern words while publishing the mapping is the transparent choice. The
full 1997↔ours correspondence is recorded in `docs/glossary-1997.md`; no
item on this list renames a step or changes the strip.

What IS missing is the strip's own labelling. The original gave every slot
a tooltip — that is exactly what `@CUECARD_PHASEBAR`
(`Program/UIStrings.txt:707-730`) is, 23 entries of `%s Untap phase` /
`Your Main phase (declare combat)` / `Resolve 1st strike damage`. Our strip
is display-only (`duel_screen.gd:1619-1652`): no tooltip, no hover, no
click.

For the record, since it took reading the art to establish it: the icons in
our own imported `assets/original/phase_bar.png` (82×760, two colour
columns, eight 35×40 icons per seat at a 41px pitch) are, in order — a hand
turning a curved arrow (untap), a hammer over an anvil (upkeep), an open
hand palm up (draw), a crescent moon (main; the phases-of-the-moon pun), a
sword in a shield (combat), the same crescent MIRRORED (second main), an
open hand palm down (discard), a broom (cleanup). Eight per seat, sixteen
in all, which is what we already render — the marker rides in the active
seat's half (`duel_screen.gd:1167`).

### 4.2 [1997] The board halves read the same order; the original mirrors them — LOOKED FOR THE EVIDENCE (2026-09-01); NOT CHANGED

`duel_screen.gd:1577-1596` deliberately gives both halves the same
top-down order (piles, then creatures), measured off the owner's
screenshot in the thirteenth pass. s30 mirrors them
(`duel.go:1372-1436`): the player's creatures nearest the centre line and
lands at the outside, the opponent's the exact mirror. Both cannot be
right. This is a **measurement dispute to settle against the manual's own
screen figure** (§6), not a change to make blind.

Note s30 also puts animated lands (`IsCreature && IsLand`, Mishra's
Factory) in the CREATURE row — we put them there too via
`inst.is_creature()`, so that part already agrees.

**THE SEARCH, AND WHY IT CAME BACK EMPTY (2026-09-01).** Three sources
were checked for a statement about where cards sit INSIDE a territory:

- `Duel.hlp`, topic **Territory**, is the only place the file describes
  them, and it settles only which half is whose: *"The largest areas of
  the dueling table are your territory and your opponent's territory. The
  lower territory is yours, the upper belongs to your adversary. These
  areas contain all of the cards in play."* Nothing about rows.
- The Manalink source has no territory layout: `windows.c` only holds the
  two `TerritoryClass` window handles and their card-handle arrays
  (`:13-21`, `:1427-1433`); the arrangement is inside the 1997 exe.
- The string tables say nothing either — `@MENU_TERRITORY`'s only layout
  verb is `Arrange your cards`.

**So the dispute is unsettled by anything in the repo, and the only
measurement anyone has taken stands.** The thirteenth pass measured the
owner's reference screenshot region by region
(`docs/duel-screen-design.md`: player's piles at y 290-350 of 563, their
creatures at y 450-520) and a screenshot IS the manual's screen figure —
it is the same evidence, at the same fidelity. s30's mirror is s30's.
**Do not change this without a NEW measurement**; changing it on s30's
authority would be replacing evidence with a reference.

**One thing WAS wrong and is fixed: the code's own comment.** The `Row`
enum was documented as *"creatures nearest the battle line, lands
furthest"*, which is true of the opponent's half and false of the
player's — the only thing in the tree claiming the board is mirrored.

---

## 5. Engine work the duel needs (beyond §1)

Everything here is cross-checked against `docs/mechanics.md` and is NOT
already implemented. Where `docs/ROADMAP.md` or `docs/audit-2026-09.md`
already tracks an item, that is said so we do not double-count it.

| # | Item | Reference | Status | Why the duel cares | Size |
|---|---|---|---|---|---|
| 5.1 | **Game-state deep clone** with copy-on-write battlefield | `pkg/mage/clone.go:20-198`; COW at `game.go:518-559` | none in `engine/`; ROADMAP names it under M4 phase 3 | Prerequisite for search AI, "would this kill me", undo, and §5.3 | L |
| 5.2 | **Cost payment as a validate-on-clone transaction** | `pkg/mage/payment_transaction.go:15-175`; `spell_payment.go:150-197` `lockPaymentCosts` | PARTIAL — riders are checked before paying, but per-site; the 2026-09 audit found `tap_for_mana` half-paying | Makes "half-paid then refused" impossible as a class | M |
| 5.3 | **Exact mana solver / auto-tapper** (A\* with an admissible heuristic) | `pkg/mage/mana_solver.go:105-496`; pool-side `mana.go:180-264` | PARTIAL — ours is greedy one-pass (`mtg_game.gd:2195-2240`, `ai/ai_player.gd:726-758`); ROADMAP tracks only the "lands only" half | A greedy planner REFUSES casts that are payable, and it drives the duel's castable highlight through `can_afford` | M |
| 5.4 | **Trigger batching** — accumulate since last priority, then stack APNAP | `pkg/mage/game.go:2006-2105`, `:2232-2248` `PutTriggersOnStack` | PARTIAL — `dispatch_event` stacks each trigger immediately | Decides which of two simultaneous triggers resolves first | M |
| 5.5 | **Real delayed triggers** (stack objects with event matchers) | `pkg/mage/game.go:325-338`, `:2001-2005`, `:2108-2165` | ALREADY TRACKED (ROADMAP, audit-2026-09) | Nobody can respond to Berserk's destruction or Rukh Egg's bird | M |
| 5.6 | **Generic replacement-effect pipeline** | `pkg/mage/action.go:11-41`; `effect_manager.go:768-811` | ALREADY TRACKED (`mechanics.md §14`) | Blocks ten stubbed damage cards (Forcefield, Eye for an Eye, Rock Hydra…) | L |
| 5.7 | **"If you would draw a card…" replacement** with an `isNormalDraw` flag | `pkg/mage/game.go:3559-3601`; `replacement.go:621-767` | ALREADY TRACKED (ROADMAP) | Four `cards/todo/` files wait on exactly this: Sylvan Library, Aladdin's Lamp, Island Sanctuary, Chains of Mephistopheles | M |
| 5.8 | **Reveal primitives** (top-of-library and hand) | `pkg/mage/reveal.go:28-203` | MISSING (`grep reveal engine/` is empty) | Sylvan Library, Nebuchadnezzar, Petra Sphinx; and a hidden-information UI needs a legal way to show a reveal | M |
| 5.9 | **Control layer as a fixed-point loop**, plus `cant_change_control` | `pkg/mage/effect_manager.go:624-679`; `effect_control.go:11-60` | PARTIAL — leashed control exists and the FLAG landed 2026-09-01 (`CardInstance.cur_cant_change_control`, gated in `MtgGame.change_control`, which lifted Guardian Beast's ledger row); no convergence loop | Chained control (Old Man of the Sea + Rubinia) still resolves by pipeline order | M |
| 5.10 | **One blocker blocking several attackers**; **minimum-blocker restrictions**; **defensive banding** | `pkg/mage/game.go:3754-3763`; `combat_restrictions.go:50-66`; `combat.go:396-676` | ALREADY TRACKED (ROADMAP, simplified-cards) | Two-Headed Giant of Foriys, Blaze of Glory, Wall of Caltrops | M |
| 5.11 | **Effect durations beyond EOT/EOC**, plus conditional durations | `pkg/mage/core/layer.go:19-27`; `effect_manager.go:60-90` | ALREADY TRACKED for the enum; the CONDITION slot is not | Xenic Poltergeist, Brine Hag, Wall of Tombstones | M |
| 5.12 | **Explicit layer enum with per-layer iteration** | `pkg/mage/core/layer.go:5-16`; `effect_manager.go:429-622` | ALREADY TRACKED (`mechanics.md §7`) | Our pass order was re-ordered twice by the 2026-09 audit; a declarative layer tag stops that | L |
| 5.13 | **Turn schedule** — insertable/skippable steps | `pkg/mage/turn_schedule.go:16-142`; `game.go:92-141` | PARTIAL — `extra_turns` + the whole-turn skip (`_begin_turn`/`_skip_turn`, Time Vault, 2026-09-02), plus two conditional SKIPS hard-coded in `_advance_step` (no attackers → jump to end of combat; no first strikers → skip `FIRST_STRIKE_DAMAGE`). `STEP_ORDER` is still a const walked by index | §1.6 landed WITHOUT this, which is evidence the const array is not the blocker the entry assumed; what a real schedule buys is per-turn insertion, not conditional skipping | M |
| 5.14 | **Targeted / modal / optional TRIGGERED abilities** | `pkg/mage/triggered.go:49-188`; `game.go:2261-2289`, `:2456-2504` | ALREADY TRACKED for targeting; modal + a first-class `Optional` flag are NOT | Oubliette, Halfdane; ~50 cards do "you may" ad hoc via `choose_yes_no` | M |
| 5.15 | **Events we never dispatch**: ability-activated, sacrifice-as-cause | `pkg/mage/core/event.go:19,35,36` | ALREADY TRACKED (ROADMAP) | Powerleech, Haunting Wind, Urza's Miter are permanently incomplete | S |
| 5.16 | **Counter-placement replacements** (`AddCountersWithReplacement`) | `pkg/mage/game_mutator.go:525-566`; `replacement.go:949-1070` | MISSING — `add_counters` mutates directly | No 1997 doubler exists; it is the discipline that makes §5.6 tractable | S |
| 5.17 | **"As this enters, choose ___"** as a pre-ETB replacement (CR 614.12) | `pkg/mage/etb_choice.go:29-125` | PARTIAL — ours is an ETB trigger writing to `CardInstance.memory` | Unobservable for Black Vise / The Rack today, but the shape is wrong | S |
| 5.18 | **State-triggered abilities** with arm/disarm (CR 603.8) | `pkg/mage/game.go:2178-2212`; `triggered.go:203-232` | PARTIAL — we model the era's as SBAs, which is right but can't be responded to | Correct today; the arming rule is what stops future ones re-firing | S |
| 5.19 | **Empty-library loss as an SBA** | `pkg/mage/game.go:3380-3386` | PARTIAL — `draw_cards` loses immediately (`mechanics.md §8`) | Identical for this pool; changes what an over-draw does mid-resolution | S |
| 5.20 | **Priority during cleanup + a repeated cleanup step** (CR 514.3a) | `pkg/mage/turn.go:144-152` | ALREADY TRACKED (`mechanics.md §14`) | One line of recursion; closes a documented hole | S |
| 5.21 | **Optional additional costs** with an "if you do" latch, and either/or costs | `pkg/mage/cost_optional.go:16-81`; `cost.go:564-627` | PARTIAL — mandatory additional costs only | No kicker in this pool, but "discard a card or pay {5}" recurs | S |
| 5.22 | **Alternative costs / casting from a non-hand zone** | `pkg/mage/alternate_cost.go:26-109`; `effect_cast_alt.go:122-299` | MISSING for cast-from-zone; PARTIAL for lands | Low era pressure; the clean home for `cards/todo/drk/gaea_s_touch.gd` | S |
| 5.23 | **Attack costs** ("can't attack unless you pay", CR 508.1e) | `pkg/mage/combat_restrictions.go:67-206` | MISSING | No Propaganda in the pool; the right home for Hasran Ogress-style taxes we do as triggers | S |
| 5.24 | **`DecisionAgent` breadth**: choose a number, name a card, choose a permanent, distribute damage at resolution, order blockers | `pkg/mage/player.go:82-146` (15 questions vs our 4) | PARTIAL — **order blockers and distribute COMBAT damage landed 2026-08-31** (`order_blockers` / `assign_combat_damage`, §1.4), as did `choose_mulligan` (§1.5) and the two "hold the turn open" switches (§1.1, §1.4). Our four primitives are now seven, all funnelled through `PlayerChoice` and, since the §1.3 pre-flight landed, all actually PUT TO THE PLAYER. Still missing as TYPES: choose a number, name a card, choose a permanent, distribute damage at RESOLUTION — each needs a new `PlayerChoice.Kind` and a row in `DuelScreen.choice_options`, which is now the one place a new kind has to be worded | Directly blocks the Balance / Eureka / Juxtapose / Nebuchadnezzar stub cluster — several need a HOOK, not just a UI | M |

### Where mage-go is NOT ahead of us — do not chase these

Checked and deliberately not filed:
- **Determinism: we are ahead.** mage-go shuffles with Go's global
  `math/rand` (`pkg/mage/player.go:298-306` and five other sites), so its
  library order is not reproducible. `MtgGame.rng` + our Fisher-Yates is
  the stronger design, and the seeded-duel work (twenty-fifth pass) has
  no counterpart there.
- **CR 613.8 dependency analysis** — absent in mage-go too. We are at
  parity, not behind.
- **CR 616.1 replacement-ordering choice** (the affected player picks) —
  absent in mage-go; scope §5.6 knowing this is not included.
- **Mana burn** — absent in mage-go. Our `mechanics.md §14` note stands
  as a deliberate era choice.
- **Split second, snow, Phyrexian, hybrid, scry/surveil, ward,
  planeswalkers** — all out of era, none implemented in mage-go either.
- **Undo/rollback** — mage-go's is a shallow TUI convenience
  (`interactive/types.go:118-127`), not a rules-level rollback. §5.1 plus
  §5.2 is the model to copy, not that.

---

## 6. What the 1997 sources say

Three primary sources, and they corroborate each other: the 1997 MicroProse
**manual**, the shipped **`Duel.hlp`** (the in-game "Dueling Help" the
manual points at), and the game's **own string tables**. Everything quoted
below was read directly out of the files and is quoted EXACTLY — a
paraphrase here would poison the port.

**PROVENANCE — READ THIS BEFORE CITING ANYTHING.** `../shandalar-src/`
holds two copies of every string file:

| | Path | What it is |
|---|---|---|
| **1997** | `shandalar-src/Program/UIStrings.txt` (1426 lines) | the original-era file. **Cite this one.** |
| **Manalink 3** | `shandalar-src/UIStrings.txt` (1470 lines) | the fan patch's. It inserts 44 lines after line 238, so `manalink_line = 1997_line + 44` thereafter |

Every `UIStrings.txt:N` below means the **`Program/`** copy.
`promptsX1.txt`, `promptsX2.txt` and `Duel.hlp` are byte-identical in both.
Known Manalink-only additions, do NOT port: `@ABILITYWORDSX` /
`@ABILITYWORDS2` (Shroud, Infect, Prowess…), `@ACTIVATE_TYPE`, the Paris
mulligan strings, and all of top-level `config.txt`. Our badge table
(`mini_card.gd:653`) should stay on the 1997 seventeen `@ABILITYWORDS`.
`Menus.txt`, `CueCards.txt`, `HINTS.TXT`, `FaceButtons.txt` and
`MP_UIStrings.txt` contain **no duel UI** at all — checked, don't re-read
them. `ManaLink.txt` is a network-lobby string table, not a changelog.

**GREP `Program/UIStrings.txt` WITH `-a` OR IT WILL LIE TO YOU.** The file
is latin-1, not UTF-8 (a `0xa9` © at byte 19354), so GNU grep decides it is
binary and prints **nothing at all** — not even "Binary file matches" when
`-n` is on. `grep -n '^@MENU_PHASEBAR$' Program/UIStrings.txt` exits 1;
`grep -an '^@MENU_PHASEBAR$' Program/UIStrings.txt` answers `947`. A pass
on 2026-08-31 hit exactly this, concluded the `@PROMPT_*` / `@MENU_*` tags
were missing from `UIStrings.txt`, found them in `Program/Text.res`
(plain ASCII, so it greps fine) and reported every citation in this file as
wrong. **They are not wrong.** `Program/Text.res` is a SECOND, LARGER table — 461
`@` tags against `UIStrings.txt`'s 152, and it carries the shell tags
(`@GAMETITLE`, `@SHELLSCREEN_*`) too.

**CORRECTED 2026-09-02: it is not a 1997 superset. It is MANALINK 3's
table, and it must not be QUOTED.** It carries `Momir Basic` (a 2006
format), `&Challenge Mode` **where the 1997 gauntlet page has `&Ante`**,
`Highlander`, the network row `&Send Parameters` / `&Agree` / `&Disagree`,
a tag that does not exist in 1997 at all (`@SHELLPAGE_MULTIDUEL`), and
`199 unique / 499 total` cards where 1997 says `200 / 500`. **Use it to
FIND a tag when the latin-1 grep is inconvenient; quote the tag from
`Program/UIStrings.txt`.** Its `@SHELLPAGE_*` and `@SHELLSCREEN_*` blocks
are the most rewritten. Evidence, and the shipped citations that rest on
it: `docs/gauntlet-design.md` §0 and §6.21 below.

One more from the same pass: **`Program/UIStrings.txt` itself carries a
few light Manalink edits** — `Reach` for the 1997 `Web`, `View exiled
cards` for `View the out-of-play cards`, `Mutation (-1/-1) counters`
shortened, an expanded `@LANDWORDS`, an added `@GROUPMOVE`. The clean 1997
copy is **`s30/assets/text/Uistrings.txt`**, which is line-for-line
aligned with the `Program/` one **up to line 1183** and
`Program_line − 40` after it. Every `UIStrings.txt:N` citation in this
file is below 1183 and reads the same in both.

### 6.0 The names the original gives its own screen

`Duel.cnt` (the help contents, lines 686-701) lists the duel screen's
parts, and these are the original's words for them:

> `Map of the Dueling Screen`, `Combat Bar`, `Dueling Options`,
> `Graveyard`, `Hands`, `Library`, `Life Registers`, `Lich Register`,
> `Duelist's Face`, `Mana Pool`, `Phase Bar`, `Showcase`,
> `Situation Bar`, `Stop`, `Territory`

Full term-by-term mapping onto our own names, with sources, is in
**`docs/glossary-1997.md`**. Three of these name things we do not have at
all — the **Combat Bar**, the **Lich Register** and the **Duelist's Face**
— and each gets an item below.

### 6.1 [1997] The phase strip has no tooltips, and no click — DONE (2026-08-31)

`UIStrings.txt:706` `@CUECARD_PHASEBAR`, 23 entries. The first sixteen are
the strip's own tooltips, eight per seat:

```
%s Untap phase              Your Untap phase
%s Upkeep phase             Your Upkeep phase
%s Draw phase               Your Draw phase
%s Main phase (precombat)   Your Main phase (precombat)
%s Main phase (combat)      Your Main phase (declare combat)
%s Main phase (postcombat)  Your Main phase (postcombat)
%s Discard phase            Your Discard phase
%s Cleanup phase            Your Cleanup phase
```

and the last seven are the **Combat Bar**'s (§6.5) — one per icon, in this
order (left column first, then the right):

```
Choose attackers phase        Resolve 1st strike damage
Attacker fast effects phase   Resolve normal damage
Assign defenders phase        Main phase (postcombat)
Blocker fast effects phase
```

These are LIVE now (`game/duel/combat_bar.gd`); it is the sixteen Phase
Bar tooltips above that are still missing.

Two facts worth having on record, neither of which is a to-do: the 1997
game has **no combat phase** — combat is a state of the main phase, which
is why the strip's fifth slot reads `Main phase (combat)`; and the strip is
**sixteen slots, eight per seat**, which is exactly what we already render
(`duel_screen.gd:1167` rides the marker in the active seat's half).

**Our modern step names and slot count stay** — settled by the owner:
"Declare Attackers" is clearer than "Main phase (combat)", and keeping the
modern words while publishing the mapping is the transparent choice. The
mapping lives in `docs/glossary-1997.md`. Nothing on this list renames a
step.

**ALL OF IT IS BUILT** — `game/duel/phase_bar.gd` (the strip, now its own
class like `CombatBar`), `game/duel/phase_stops.gd` (the model) and the
driver in `duel_screen.gd`. The strip was inert: no tooltip, no hover, no
click. It now carries all sixteen `@CUECARD_PHASEBAR` cue cards, runs on a
left-click, and opens `@MENU_PHASEBAR` on a right-click.
`UIStrings.txt:947` `@MENU_PHASEBAR`, verbatim:

```
Run to this phase
Mark this phase to always stop
Help for this phase...
Help...
```

`Duel.hlp`, topic **Stop**: *"You can right-click on any phase and select
Mark from the mini-menu to put a Stop marker on that phase… that phase does
not end until you tell it to manually; it cannot pass automatically… In
Shandalar, there is no way to back up a phase… A Stop on your opponent's
Main Pre-Combat sub-phase is always a good idea."*

The data structure survives in the Manalink source:
`char option_PhaseStoppers[2][38]` (`src/manalink.h:120`) — per seat, per
phase, bit 0 = stop here (`src/functions/windows.c:543-557`) — persisted in
the registry as `PhaseStoppers`. Stops are set on your OWN and your
OPPONENT'S phases alike. **New finding: 38 == 0x26 is one past
`PHASE_DAMAGE_PREVENTION` (0x25), the last entry of the original's
`phase_t` (`src/defs.h:685-707`)** — so that array spans the whole phase
enum, combat's sub-phases (`PHASE_DECLARE_ATTACKERS` 0x15 …
`PHASE_NORMAL_COMBAT_DAMAGE` 0x1B) included. That is the file-level
confirmation of `Duel.hlp`'s *"[the Combat Bar] functions in exactly the
same way as the larger bar; you can even use Stops"*, and it is why our
model carries two bars (eight Phase Bar icons, seven Combat Bar ones)
rather than one. Persisted through `Settings` for the same reason the
original persisted it — manual p.117 calls a Stop *"a lasting
instruction"*, p.114 says option settings *"are retained for future
duels"*.

**THE RED DOT WAS ON THE WRONG THING.** It rode beside the CURRENT phase.
Manual p.116: *"First and foremost, the current phase is always
highlighted"* — that is what `Winbk_Phase.pic`'s second column of
white-ground cells is for, and it is the only current-phase cue the manual
names. The only marker any 1997 source describes is the Stop's
(`Duel.hlp`: *"put a **Stop marker** on that phase"*), neither sheet ships
a marker sprite, and the owner's own words for the feature are *"set a stop
point (red dot) there"*. The dot now marks Stops, on both bars, several at
a time.

**RUN TO** (manual p.116) and **Done as a standing instruction** (§6.20a)
share one driver; the manual's two exception lists genuinely differ and
both are implemented as written. Two divergences, both deliberate:

| | Ours | Why |
|---|---|---|
| un-marking | the same `Mark this phase to always stop` entry, as a CHECK item that toggles | the 1997 table ships **no unmark string** — searched `Program/UIStrings.txt`, `Program/Text.res` and `Duel.hlp`. The tick is the only affordance the table leaves room for |
| the two `Help` entries | present and **disabled** | there is no Dueling Help yet (§6.20l). Greying them says the menu is complete and the help is missing; dropping them would say the original's menu had two items |

### 6.2 [1997] The mulligan is the SHANDALAR rule, and you choose play or draw — DONE (2026-08-31; the opening WINDOW 2026-09-01)

`UIStrings.txt:499` `@DIALOG_MULLIGAN`, 12 entries:

```
%s will start first                            %s will also take a mulligan
You will take the first turn                   %s decided not to take a mulligan
%s ante:                                       Take &mulligan
Your ante:                                     &Start the duel
%s has no land and chose to take a mulligan
%s has all land and will take a mulligan
%s has chosen to take a mulligan
%s did not take a mulligan
```

`Duel.hlp`, topic **Mulligan**, states the rule outright: *"If either
player draws no land in this seven cards or draws all land, then that
player has the option to declare a mulligan… If either player declares a
mulligan, that player must shuffle her hand back into her library and draw
seven new cards… The other player has the option to do so as well… Each
player has only one chance to redraw."*

So `docs/ROADMAP.md` was RIGHT — "only 0-land or all-land hands may redraw"
is the 1997 rule, one redraw each, and the opponent may follow. **The
`mulligan to %d` strings are Manalink 3** (top-level
`UIStrings.txt:551-556`); do not copy them, and do not copy s30's London
mulligan (`duel.go:3918-4074`) — that whole shape is **[s30]**.

Note the mulligan dialog also shows **both antes** (`%s ante:` /
`Your ante:`), so the ante is visible before the first card is played.

Before it, `UIStrings.txt:483` `@DIALOG_STARTCOINFLIP` = `Start of Duel`
(the dialog's title; ours says `Tossing for the lead...`,
`duel_screen.gd:306`), and `UIStrings.txt:487` `@DIALOG_PLAYORDRAW`:

```
%s won the toss                    Would you like to:
and will play first.               Play first
and has chosen to draw first.      Draw first
You won the coin toss.             %s will play first.
                                   %s has chosen to draw first.
```

**The toss winner CHOOSES play or draw.** DONE 2026-08-31 (§1.5): the coin
reports only the win (`You won the coin toss.` / `%s won the toss`), the
choice is its own two-button dialog (`Would you like to:` / `Play first` /
`Draw first`), and the result is reported with entries 8-9
(`%s will play first.` / `%s has chosen to draw first.`). The first player
skips their first draw (`Duel.hlp`, **Play or Draw Rule**), which the
engine already did.

The mulligan itself is DONE too — the whole rule, in `Duel.hlp`'s words,
and all twelve `@DIALOG_MULLIGAN` strings, the ante captions included
(2026-09-01, with §6.19). **The last outstanding piece of this item was the
COMPOSITION**, and it is closed: the twelve entries are one window, not
two. We used to pop a 420x220 grey-stone dialog for play-or-draw and a
460x250 one for the mulligan (which listed the hand as comma-separated card
names — our invention, not the table's); the original opens ONE window on
`Winbk_Startduel.pic`, shows both antes as full cards, and asks each
question in that window's own button row. That is now `OpeningWindow`
(`game/duel/opening_window.gd`), and it is why entries 3-4 (`%s ante:` /
`Your ante:`) sit in a mulligan table at all.

Two small corrections that came with it. The announcement is now built
BEFORE the redraw — `%s has no land and chose to take a mulligan` names the
hand that was thrown away, and `take_mulligan` had already replaced it. And
the courtesy offer no longer prints entry 9 as a prompt: `%s will also take
a mulligan` REPORTS the second player's decision, and the head band is
already saying why you are being asked.

#### THE COMPOSITION CLAIM ABOVE IS WRONG, and the two clicks it caused — CORRECTED 2026-09-06

*"The twelve entries are one window, not two"* is right; *"the original
opens ONE window"* is not, and it was never cited. **1997 had TWO windows,
and the evidence is three-deep.**

* **The string tables keep them apart.** `Program/UIStrings.txt:487`
  `@DIALOG_PLAYORDRAW` declares **9** entries and `Play first` / `Draw
  first` are its 6th and 7th (`:494-495`); `:499` `@DIALOG_MULLIGAN`
  declares **12** and `&Start the duel` is its 12th (`:512`). Both counts
  are exact, so `Start the duel` cannot be read into the play-or-draw
  group. (The s30 copy of the table is byte-identical here.)
* **The Windows DIALOG templates keep them apart, and this is decisive.**
  `Program/Magic.exe`'s RT_DIALOG directory holds 34 templates and **no
  single one carries both**. Resource **244** (117x150 DLU) is the
  play-or-draw window and has four controls — the two statics `<You won
  the coin toss.>` / `<Would you like to:>` and the two owner-draw buttons
  `Play first` (id 1221) and `Draw first` (id 1222). **It has no IDOK and
  no third button**: the only way out of it is the order. Resource **227**
  (316x206 DLU) is the mulligan window — the first-turn line (1090), the
  two ante captions (1095/1094), two 73x114 card slots (1097/1096), two
  message areas (1091/1093), `Mulligan` (1092) and `Start the duel` at
  **control id 1, i.e. IDOK**. Each template's default text maps onto its
  string group one for one, which is the cross-check `Provenance.md`
  prescribes, and both pass. The templates are byte-identical in the
  `shandalar-xp` tree.
* **They have different backdrops, both dated 1996** in the owner's
  install: `Winbk_Startduel2.pic` (284x394) and `Winbk_Startduel.pic`
  (659x394). `Magic.exe`'s string literals bind them in two consecutive
  groups keyed by the two dialog names, and Manalink's
  `src/functions/windows.c:1338-1369` has the matching pair of loaders —
  `load_startduel_assets` (the mulligan ground, plus the button's
  **disabled** plate) and `load_startduel_assets2` (the play-or-draw
  ground, normal and depressed only). Only the mulligan window loads a
  greyed button state, which is why it is shown even when you do not
  qualify for a redraw.

**So the second click is 1997's.** Choosing the order dismissed dialog 244;
the duel began on `Start the duel` in dialog 227, a different window on a
different ground, and that window was the first place the player saw the
antes, who leads, and what the opponent had done.

**We do not have two windows, so we do not have the second click.** The
merge into one `OpeningWindow` is this project's own composition — as is
the row `Take mulligan` / `Draw first` / `Play first`, which no 1997
template puts together (`opening_hand.gd` attributes it to the owner's
2026-09-03 correction, and that is what it is). Once both questions are
asked in one window with the antes up the whole time, the original's second
click has nothing left to show, and the playtest of 2026-09-06 said so:
*"if you click either button the duel should start — now you have to click
an additional 'start duel' button, but you already decided in the previous
button."* **Both the merge and the single click are `[QoL]`**, and this is
the row that labels them.

**WHAT THE FIX ACTUALLY WAS — a counter, not a removed button.**
`OpeningHand.run` already had the right rule: the window owes the player
one last `Start the duel` *only when something has happened since they last
pressed*, so the opponent's redraw is always read before the duel starts
(that is `OpeningWindow.status_serial` against `run`'s `pressed_serial`).
`_ask_lead_and_mulligan` simply never wrote to `pressed_serial`, so the
order buttons did not count as a press, the counter stayed at its
never-pressed `-1`, and the window found itself owing a look nobody was
owed — in every duel the player won the toss in. One line records the
press. **The asymmetry the item requires survives unchanged**: `Take
mulligan` never reaches that line (it loops inside
`_ask_lead_and_mulligan` until an order is chosen), so a redraw still deals
a new hand and asks again; losing the toss still ends on `Start the duel`;
and an opponent who redraws *after* your order still buys you the last
look. Pinned by five tests under `tests/ui/test_opening_hand.gd`'s
`one decision, one click` banner.

### 6.3 [1997] The Territory menu — the duel's master control — DONE (2026-09-01; the `Go to:` list 2026-08-31). Two entries stay greyed, both with a reason

`UIStrings.txt:908` `@MENU_TERRITORY`, 25 entries: a right-click menu on
your own territory, and the original's home for nearly everything on our
wishlist.

```
Go to: Upkeep phase              Arrange your cards\tDblClk
Go to: Draw phase                Arrange opponent's cards\tDblClk
Go to: Main phase (precombat)    Duel Options...
Go to: Main phase (combat)       Show ID tags\tCtrl+T
Go to: Attack Fast Effects phase Show invisible effects\tCtrl+I
Go to: Choose Defenders phase    Show all cards' summoning sickness\tCtrl+U
Go to: Block Fast Effects phase  Minimize
Go to: Resolve first strike damage  Save game...\tCtrl+S
Go to: Resolve combat            Help...
Go to: Main phase (postcombat)   Concede
Go to: Discard phase             Yes, I'm sure
Go to: Cleanup phase
Go to: Start of next turn
Go to: next phase
```

**The menu is BUILT (2026-08-31)** — `game/duel/territory_menu.gd` plus
`DuelScreen._open_territory_menu`, opened by a right-click anywhere in
either territory that is not on a card (a card keeps its own right-click
for `@MENU_SMALLCARD`, §6.12). The `Go to:` list and the two `Arrange`
entries are live; the rest are listed and DISABLED, on §6.1's precedent.
Items worth their own lines:
- **`Go to: <phase>` — DONE.** All fourteen entries resolve onto our two
  bars and run through the SAME driver §6.1's **Run to** uses, so the
  menu is the reading route to those stops rather than a rival mechanism.
  `Go to: Main phase (combat)` lands on the Combat Bar's first icon
  (`CombatBar.covers_step` hands every combat step to the smaller bar, so
  the Phase Bar's crescent is never a destination of its own);
  `Go to: Start of next turn` crosses to the other half of the bar.
  **`Go to: next phase`** is new machinery — `Advance.NEXT_PHASE`, a run
  whose destination is "not here" — and it is the one 1997 verb we had no
  equivalent for (p.112 / `Duel.hlp`: *"ends the current phase and moves
  you on to the next one"*), our Done being the finer single pass and Run
  to the aimed one. Pinned by `tests/ui/test_territory_menu.gd`.
- **`Arrange your cards` / `Arrange opponent's cards` — DONE** with §2.3.
  Check items, because the 1997 table ships no "unarrange" string, the
  same call the Stops' `Mark` entry made.
- **`Concede` → `Yes, I'm sure`** is the entire concede flow. We have no
  concede at all — and three cards need it as a game ACTION, not just a
  menu item: `@DEMONIC_ATTORNEY` (`promptsX1.txt:121`), `@BRONZE_TABLET`
  (`prompts.txt:151`) and `@TEMPEST_EFREET` (`prompts.txt:877`) each offer
  `Concede game.` as a choice. `Duel.hlp`, **Territory**: *"Concede
  announces to your opponent that you're giving up… You must confirm this
  decision."*
- **`Save game...\tCtrl+S`** — but NOT in Shandalar. The manual is
  explicit (p.112): Save Game *"appears **only** if you are playing in the
  **Duel** (a separate program described later)"*. The string exists
  because one binary serves both. **Do not build a mid-duel save for the
  adventure.**
- **`Show all cards' summoning sickness\tCtrl+U`** — our spiral is always
  on; the original made it a toggle (and a Duel Option, §6.4).
- **The double-click gesture** the two `Arrange` entries advertise
  (`\tDblClk`) is not wired: the command is, the shortcut is not. Same
  for `Ctrl+T` / `Ctrl+I` / `Ctrl+U`, whose commands do not exist yet.

**THE REST OF THE TABLE WENT LIVE 2026-09-01.** What landed, and what one
of them proved:

- **`Concede` → `Yes, I'm sure` — DONE**, as an ENGINE action
  (`MtgGame.concede`, CR 104.3a: *"A player can concede the game at any
  time. A player who concedes leaves the game immediately."*) rather than
  a screen one, because the three cards this section named —
  `@DEMONIC_ATTORNEY`, `@BRONZE_TABLET`, `@TEMPEST_EFREET` — each print
  `Concede game.` as a CHOICE and will want the same call. It does not use
  the chain, does not wait for priority and cannot be responded to; the
  only thing it refuses is a duel that is already over. The confirmation
  is the table's own entry 25 on an `OriginalDialog`, with `Cancel` beside
  it (`@DIALOGBUTTONS` is the whole 1997 vocabulary for "no").
- **`Minimize` — DONE**, and it is the OS window, not anything on the
  table: *"shrinks the **Magic: The Gathering** window so that you can
  temporarily pursue other Windows functions."*
- **`Show ID tags\tCtrl+T` — DONE.** *"toggles the display of each card's
  unique ID code. This can be useful when you need to determine exactly
  which of several otherwise identical cards is the target of a specific
  spell or effect."* The code it shows is `CardInstance.id`, which is what
  a bug report wants to quote. It draws even on a face-down card, which is
  the case the help file's sentence is really about.
- **`Show all cards' summoning sickness\tCtrl+U` — DONE, AND THIS ITEM
  READ IT BACKWARDS.** The line above says *"our spiral is always on; the
  original made it a toggle"*, i.e. an on/off switch. It is not: the 1997
  executable's own registry key is **`ShowAllCardsSummonSickness`**, and
  the entry is *all cards* — whether the mark appears on permanents that
  are NOT creatures. Sickness reaches every permanent in this engine
  (CR 302.6, and the original played under the pre-Sixth rule where an
  artifact's `{T}` ability was sick too), so the data was always there and
  only the DRAWING was filtered to creatures. Off is therefore the view
  the duel already had, and on is the thing that was missing.
- **`Show invisible effects\tCtrl+I` — LISTED AND GREY**, and it will
  stay that way for a while: *"toggles the appearance of those effect
  cards (the temporary yellow cards that pop up all the time) that are not
  normally displayed."* Our engine has no effect-card objects to show.
- **`Help...` — LISTED AND GREY** (§6.20l).

The three toggles' keys are the 1997 executable's own —
`ShowIDTagsOnCards`, `ShowInvisibleEffectCards`,
`ShowAllCardsSummonSickness` are all in `Program/Magic.exe`'s string table
— so they are persisted beside `@DIALOG_DUELOPTIONS`'s five, in
`DuelOptions.MENU_TOGGLES`. They appear on `@MENU_SMALLCARD` as well,
which is why the table lives with the settings rather than in either menu.

Pinned by `tests/ui/test_territory_menu.gd` and
`tests/ui/test_card_menus.gd`.

#### 6.3a THE DESIGN (2026-09-02) — binding `Ctrl+T` / `Ctrl+I` / `Ctrl+U`, the three accelerators the table carries and we do not honour

**NOT BUILT. This is the spec.** §6.3 above records the state of play in
one line — *"The double-click gesture the two `Arrange` entries advertise
(`\tDblClk`) is not wired: the command is, the shortcut is not. Same for
`Ctrl+T` / `Ctrl+I` / `Ctrl+U`, whose commands do not exist yet."* — and
half of that is now stale: **the commands exist.** All three toggles are
in `DuelOptions.MENU_TOGGLES`, `DuelScreen._flip_display_toggle(key)`
flips one and repaints the table, and two of the three are live. Only the
keystrokes are missing.

##### What the source says, exactly

`@MENU_TERRITORY` (`Program/UIStrings.txt:927-929`), entries 18-20, with
the accelerator written into the string after a tab:

> `Show ID tags\tCtrl+T`
> `Show invisible effects\tCtrl+I`
> `Show all cards' summoning sickness\tCtrl+U`

The same three, same accelerators, appear again on `@MENU_SMALLCARD`
(entries 5-7) — which is the whole reason `DuelOptions.MENU_TOGGLES`
exists rather than a table inside either menu. **They are not on
`@DIALOG_DUELOPTIONS`**: the Duel Options panel's own five switches are a
different five (§6.4), so there is no panel checkbox for these three to
disagree with. The disagreement risk is between **two menus and a
keystroke**, and all three already read and write one place.

##### The spec

**1. No input map.** `project.godot` has no `[input]` section and the duel
screen reads raw keycodes in `DuelScreen._unhandled_key_input` — Space,
Return, Escape, H, M, F12, and 1-9 while the choice overlay is up. Adding
three actions to the project's input map for three fixed 1997
accelerators would put the duel's keyboard contract in two places. **Add
three arms to the existing `match event.keycode`**, guarded on
`event.ctrl_pressed`:

```gdscript
KEY_T when event.ctrl_pressed: _flip_display_toggle("ShowIDTagsOnCards")
KEY_I when event.ctrl_pressed: _flip_display_toggle("ShowInvisibleEffectCards")
KEY_U when event.ctrl_pressed: _flip_display_toggle("ShowAllCardsSummonSickness")
```

GDScript's `match` has no `when` guard, so in practice this is one arm per
key that returns early unless `event.ctrl_pressed` — written out rather
than folded into a table, because the three bare keys `T`, `I` and `U`
must stay free for later and a table invites a fall-through that eats
them. **Ctrl is load-bearing: a bare `T` must do nothing.**

**2. A key that names a dead command does nothing, and says so.** `Ctrl+I`
is `ShowInvisibleEffectCards`, which is `live: false` — we have no effect
cards to reveal (`docs/ROADMAP.md`, "Duel-screen simplifications"). The
menu entry for it is drawn disabled. **The accelerator must obey the same
`DuelOptions.menu_toggle_live()` gate the menu obeys**, or the keyboard
becomes a back door into a setting the UI refuses to offer:

```gdscript
func _accelerate_toggle(key: String) -> void:
    if not DuelOptions.menu_toggle_live(key):
        return
    _flip_display_toggle(key)
```

Silently, not with a refusal string — §6.11's button contract is about
actions the player asked the engine for; this is a display switch, and the
menu's own grey is the message. (If a `_set_prompt` line is wanted later,
it belongs on the menu entry too, not only here.)

**3. What happens when a dialog is open.** Three cases, and they are
already distinguished by code that exists:

- **A modal centre popup** — `DuelScreen._modal_open()` is
  `graveyard_is_open() or _mode_overlay != null or _search_dialog != null
  or _x_dialog != null or _choice_overlay != null`. Its own doc says those
  *"own the keyboard while they are up"*. **The three accelerators must
  return early on `_modal_open()`**, exactly as Return does. A player
  answering an X-cost or a mid-resolution question is not toggling ID
  tags, and the repaint `_flip_display_toggle` triggers under an open
  dialog is a needless risk.
- **The choice overlay specifically** already returns before the `match`
  block (it owns 1-9 and swallows everything else). No change; the guard
  above is belt and braces for the other four.
- **A non-modal `OriginalDialog`** — the Duel Options panel itself, the
  concede confirmation, the between-duels window. These are not in
  `_modal_open()`. **They should be**, for this purpose: the simplest
  correct rule is that the accelerators fire only when the duel screen is
  the thing the player is looking at. Rather than widening `_modal_open()`
  (which would change Return and Escape too, and Return's behaviour under
  a dialog is deliberate — *"the dialog's own OK answers it"*), add a
  narrow `_dialogs_open() -> bool` that reports whether any
  `OriginalDialog` child is alive, and gate **only** the accelerators on
  `_modal_open() or _dialogs_open()`.
- **`MatchScreen`'s between-duels window and the sideboard window** sit at
  `z_index` 400 over a `DuelScreen` that is still in the tree. Since they
  are `OriginalDialog`s parented to the match screen and not to the duel
  screen, `_dialogs_open()` on the duel screen would not see them — so
  `MatchScreen` should stop the duel screen's input while its own window
  is up (`_duel.set_process_unhandled_key_input(false)`), which is one
  line and also fixes Space/Return leaking into a finished duel.

**4. The menu and the keystroke cannot disagree, and this is why.** Both
routes call the same `DuelScreen._flip_display_toggle(key)`, which is
`DuelOptions.set_toggle(key, not DuelOptions.toggle(key))` followed by
`_refresh()`. `DuelOptions.toggle()` reads `Settings`, so the state lives
in exactly one place; the menus build their check marks from
`DuelOptions.toggle()` every time they open
(`CardMenu` `set_item_checked`, `TerritoryMenu.rest_is_live`). **A menu
opened after a keystroke shows the new state because it is not caching
one.** Nothing to reconcile — the invariant to protect is that the
accelerator never writes `Settings` directly.

**5. Show the accelerator in the menu, now that it is real.** §6.3's
standing rule is *"a menu that advertises a shortcut it does not honour is
worse than one that stays quiet"*, and `DuelOptions.MENU_TOGGLES` already
carries the `accel` field (`"Ctrl+T"`, `"Ctrl+I"`, `"Ctrl+U"`) unused.
Once bound, the two menus should render `label\taccel` — Godot's
`PopupMenu` right-aligns after a tab — **for the two that are live only**.
`Ctrl+I` stays label-only while its command stays dark.

**6. Tests.** `tests/ui/test_territory_menu.gd` and
`tests/ui/test_card_menus.gd` are the homes. Four:
`test_ctrl_t_flips_the_id_tag_setting`,
`test_ctrl_i_does_nothing_while_the_command_is_dark`,
`test_a_bare_t_does_not_flip_anything`,
`test_an_accelerator_is_ignored_while_a_dialog_is_open`. All four drive
`DuelScreen._unhandled_key_input` with a constructed `InputEventKey` and
assert on `DuelOptions.toggle(key)`, so none of them needs a window.

**Size: S, UI.** Three arms, one guard helper, one line in `MatchScreen`,
the menu label change, four tests.

**Not in this item:** the `\tDblClk` gesture on the two `Arrange` entries,
which is a different problem (a double-click on a territory already means
something) and stays recorded in §6.3 as unwired.

### 6.4 [1997] The Duel Options panel — DONE (2026-09-01)

`UIStrings.txt:598` `@DIALOG_DUELOPTIONS`, 19 entries — one per line,
verbatim, ampersands and all (**no colons: neither `&Layout` nor `Your
&territory background` carries one.** Checked byte by byte 2026-09-02
after this block had been quoting a colon that is not in the file; the
`Magic.exe` dialog resource's UTF-16 copy has none either. The colons the
panel draws are ours):

```
Duel Options
&Layout
Standard
Advanced
Show coin &flip animations
Show &cue cards
Show &abilities on small cards
Show &power/toughness on small cards
See next &draws at end of duel
Your &territory background
White | Blue | Black | Red | Green | Deck color
Line drawing | Pattern | Mana symbols
```

**THAT IS TWO SETTINGS, NOT A LIST OF NINE**, and three sources agree.
`Duel.hlp`, **Dueling Options**: *"The list on the left simply allows you
to pick the predominant color of your background. The list on the right
includes the different types of background art available for each color.
**Select one option from each.**"* `Magic.exe` stores them as two
registry values, `PlayerTerritoryColor` and `PlayerTerritoryType`. And it
builds the filenames from two tables of its own, which sit adjacent in its
string table: `TERR_BLACK TERR_WHITE TERR_GREEN TERR_BLUE TERR_RED`,
then `pict patt mana`, then the format `%s\%s.pic`.

Persisted under `Software\MicroProse\Magic: The Gathering\DuelOptions`
(the value names are visible in `Program/Magic.exe`): `Layout`,
`DirectiveTracksMouse`, `ShowCoinFlips`, `ShowCueCards`,
`ShowPowerToughnessOnCards`, `ShowIDTagsOnCards`,
`ShowInvisibleEffectCards`, `ShowAllCardsSummonSickness`,
`ShowAbilitiesOnCards`, `ExpandTextBoxOnBigCard`, `SeeNextDrawsAtEndOfDuel`,
**`PhaseStoppers`**, `PlayerTerritoryColor`, `PlayerTerritoryType`.

Every one of these controls something we already draw, and none of them is
switchable. **Checked again 2026-09-01 during the heading audit, because
"don't we have this?" is the obvious reaction to a project that does have
an Options screen:** `game/options_screen.gd` offers sound, music and SFX
volume, hand display, AI pace, and — added 2026-09-01 — the `RulesOptions`
forks with their `?` explanations. That last section is a DIFFERENT list:
the forks are rules divergences (mana burn, damage assignment), not
`@DIALOG_DUELOPTIONS`'s presentation switches. Not one of the nineteen
entries below is settable.

Two of the fourteen registry values do have their BEHAVIOUR built, which
is what makes this an S rather than an M — the panel mostly needs to
expose what already works:
- **`PhaseStoppers`** is built and live (`game/duel/phase_stops.gd`, §6.1)
  — set on the phase bar itself, which is where the original set them too.
- **`PlayerTerritoryColor`** effectively sat on `Deck color`
  (`DuelConfig.apply_deck_colors`), i.e. one of the nine choices was
  implemented and there was no way to pick another. `Deck color` is still
  the default and still that same code; the other five colours and all
  three styles were built around it (2026-09-02), not over it.

- **`Show abilities on small cards`** gates our badges
  (`mini_card.gd:648-725`) — and in Manalink their tooltips too
  (`src/functions/windows.c:353,491`).
- **`Show power/toughness on small cards`** gates our P/T overlay.
- **`Your territory background`** — DONE 2026-09-02, all nine choices,
  `game/duel/territory_ground.gd`. Before that the table simply took each
  seat's deck colour, which is one of the nine (`Deck color`).
- **`Layout: Standard | Advanced`** is not cosmetic: `option_Layout == 2`
  changes the card gesture from right-click to right-DOUBLE-click
  (`src/functions/dialog.c:737-740`), and opens a temporary **Showcase**.
- **`See next draws at end of duel`** pairs with `UIStrings.txt:527`
  `@DIALOG_ENDDUEL` = `%s next draw:` / `Your next draw:` — the end screen
  shows the card you would have drawn.
- **`Show cue cards`** switches the whole `@CUECARD_*` tooltip family on
  and off (§6.1, §6.15).

**BUILT** as `game/duel/duel_options.gd` — the nineteen strings verbatim,
the panel that shows them, and the settings behind them. It opens from
`Duel Options...`, entry 17 of `@MENU_TERRITORY`, which is where the 1997
player found it; that entry is now live.

**THE KEYS ARE THE ORIGINAL'S OWN REGISTRY NAMES** — `ShowCueCards`,
`ShowAbilitiesOnCards`, `ShowPowerToughnessOnCards`, `ShowCoinFlips`,
`SeeNextDrawsAtEndOfDuel`, `Layout`, `PlayerTerritoryColor`,
`PlayerTerritoryType` — spelled as they appear under
`Software\MicroProse\Magic: The Gathering\DuelOptions`. That is §9's rule
applied to a place the player never sees, and it makes a 1997 registry
export readable straight into `user://settings.cfg`. There is no Apply
button: each control writes on the spot, which is what *"These settings
are retained for future duels"* describes.

**WHAT EACH SWITCH NOW GOVERNS**, with the help file's own description as
the specification (`Duel.hlp`, topic **Dueling Options**):
- `Show cue cards` gates the `@CUECARD_SMALLCARD` lines in a MiniCard's
  tooltip — *"the tiny hints that pop up when you position the mouse
  cursor over an active location"* — while the card's own name and rules
  text stay, because those are not cue cards.
- `Show abilities on small cards` gates `MiniCard._rebuild_badges`.
- `Show power/toughness on small cards` gates the P/T overlay, and the
  help explains why the switch belongs there and not on the Showcase:
  *"(The Showcase always shows the original power and toughness.)"*
- `Show coin flip animations` — see **the coin toss** below, which turned
  out to be the most interesting entry in the table. The toss always
  HAPPENS whatever this says: it is the engine's own roll off `game.rng`
  and decides who leads, and play-or-draw and the mulligan still ask their
  questions.
- `See next draws at end of duel` adds `@DIALOG_ENDDUEL`
  (`UIStrings.txt:527`) to the End of Duel window: two strings and no
  more, `Your next draw:` and `%s next draw:`. A seat with an empty
  library gets no line — it drew itself to death and the window has just
  said so.
- `Your territory background` paints the player's own half only:
  *"You cannot do anything to change the background in your opponent's
  territory; it matches the predominant color in her deck."*

#### The coin toss — `Show coin flip animations`, and what it really gated

**THE 1997 COIN TOSS WAS NOT AN ANIMATION. IT WAS A PRE-RENDERED MOVIE**,
and that single fact explains why no coin art exists anywhere in the asset
set to import. Established by the audio pass (§3.8b) from the Tier-2
decompilation — `MCIWndCreateA(...)` on `COINTOSS_Heads.AVI` /
`COINTOSS_Tails.AVI`, a 10ms poll timer and a 15-second timeout, in
`DUEL.EXE`'s dialog proc at entry `004492ad` — and **corroborated from
Tier 1 on 2026-09-02**, which is the stronger evidence of the two:

- `Program/Magic.exe`'s own string table holds the dialog tag and its two
  movies in three consecutive literals:
  `DIALOG_COINFLIP`, `%s\COINTOSS_Tails.AVI`, `%s\COINTOSS_Heads.AVI`.
- **`@DIALOG_COINFLIP` is two strings** (`s30/assets/text/Uistrings.txt:
  593-596`; `Program/UIStrings.txt` reads identically — both are above
  line 1183, so the numbering is shared):

      Coin flip results: Heads
      Coin flip results: Tails

  one caption per movie. The panel had been printing a truncated
  `Coin flip results:` with no face after it; it prints the whole line now.

**AND "OFF" DID NOT MEAN "SHOW NOTHING".** The original's entry point is

    int coin_flip(int player, const char *dialog_title,
                  int show_dialog_if_animation_is_off);
        // Last parameter should always be 1 except during game startup

(`shandalar-src/src/manalink.h:266`). The third parameter is named for
exactly this question and the header's own comment says it is
effectively always on, so **with the switch off the 1997 dialog still
appeared — only the movie was skipped.** Our old "off" showed nothing at
all, which was less faithful than what replaced it.

**THE CODEC — read out of the binary, not guessed.** `magvid.dll`, the
original's video DLL, imports `AVIFileOpenA`, `AVIStreamRead` and
`AVIStreamReadFormat` from `AVIFIL32.dll` and carries the fourcc literals
`iv41` / `IV41` / `iv41j` hard-coded beside `LoadAVI` / `PlayAVI` /
`StopAVI` / `UnloadAVI`. So the 1997 video codec is **Indeo Video 4.1**,
and every one of the 69 AVIs surviving in a Manalink install agrees: all
`IV41`, 24-bit, 15fps. Godot 4 plays Ogg Theora and has no AVI support at
all, and there is no pure-Python Indeo decoder — so the movies cannot be
read at run time by the game OR at build time by us without help.

**THE COIN MOVIES ARE IN NO REFERENCE TREE** (checked 2026-09-02:
`../shandalar-src` holds 69 AVIs and every one is a statistics-window
creature or the ending; `../s30` has none). They ship only with a genuine
1997 install, so mode 1 below is unavailable to most players — including
on the machine this was built on, where it could not be tested against
real footage.

**BUILT (2026-09-02) as `game/duel/coin_toss.gd` — `[QoL]`, three
presentations behind ONE stored value.** `ShowCoinFlips` — the original's
own registry name — now holds `video`, `recreation` or `instant`, and
`DuelOptions.toggle("ShowCoinFlips")` is the 1997 BOOLEAN VIEW of it
(ticked = anything but instant). The Duel Options panel keeps the
original's checkbox, unchanged and still nineteen strings; the `[QoL]`
Options screen offers the full list. A 1997 registry export still reads
straight in: a stored `0`/`1` maps onto instant / the default. One value,
two views, no parallel copy — the same contract this section already
states for the territory background.

- **`video`** — the original's own footage. `tools/import_original.py`
  gained its **first conversion step** for it: it detects `ffmpeg`, or
  `gst-launch-1.0` with `avdec_indeo4`, decodes to raw RGB and tiles the
  frames into a sprite sheet with a `.json` sidecar carrying the grid,
  frame count and frame rate. A sheet is what every other original asset
  here already is, so the game plays the movie with the region walk it
  already knows rather than gaining a video subsystem. With neither
  decoder installed the step is REPORTED and skipped, never fatal.
- **`recreation`** — our own coin, rising and turning end over end onto
  the winner's colour. The default, because it is the only one that works
  without the original, and labelled a reconstruction in the source.
- **`instant`** — the dialog with no motion in it, which is 1997's own
  "switch off" behaviour. Ours is the ICON it carries: the struck coin in
  the winner's deck colour, a drawn chevron aimed at that seat's half of
  the table (the board is not mirrored, §4.2 — the viewer always sits at
  the bottom), and the seat's name, because a mirror match strikes two
  identical coins.

**Which face is which is OURS**, marked as such at the constant: the coin
is called for the seat you are sitting in, so Heads is that seat winning.
The decompilation was not checked out on the machine that built this, so
the mapping could not be read back from `004492ad`.

**THE TWO LISTS ARE THE ORIGINAL'S OWN FILE NAMING**, which is how the
labels map to art: `Program/DuelArt/Terr_<Colour><Type>.bmp`, where the
three types are `Pict` (Line drawing), `Patt` (Pattern) and `Mana` (Mana
symbols) — and `Life_<Colour><Type>` is the same trio at register size,
which is what `tools/import_original.py` already used to settle
`life_panel_*`.

**ONE SIMPLIFIED MARKER LEFT, ledgered in `docs/ROADMAP.md`:**
`Advanced` layout is listed and DISABLED. It *"removes the Showcase
(though it appears when necessary)"* and re-flows the whole table around
the space — a screen-layout milestone, not a switch. The original greys
what it cannot offer rather than shortening its menu (`Duel.hlp`,
**Territory**), which is the call §6.1 already made for the Help entries.

**THE SECOND MARKER IS LIFTED (2026-09-02) — all nine choices now have
their own art, and the claim that stood here was wrong.** It read: *"Only
the `patt` art is imported… the only copies of the other two in
`../shandalar-src` are Manalink `.bmp`s."* Both halves of that were true
and neither mattered. `tools/import_original.py` does not read
`shandalar-src` for art at all — it reads the s30 conversions — and
`s30/assets/art/screens/duel/` was holding **all fifteen**
`Terr_*.pic.png` files, in the same directory as the five `patt` files it
was already importing from. The gap was ten missing MANIFEST rows, not a
missing decoder. This is the third documented claim on this project
written from reading rather than from building, and it is recorded that
way on purpose.

**WHAT THE SURVEY FOUND** (PIL at 3-8x, 2026-09-02; the full write-up is
the territory block at the top of the importer's MANIFEST). The three
files are three *different kinds of thing*, and the earlier reading —
which assumed the `Terr_` trio was the `Life_` trio scaled up — is right
about the naming and wrong about two of the three:
- `Terr_<c>patt.pic` is a **framed panel**, not a bare wallpaper: a
  seamless damask field ringed by a decorative border, measured at 8px on
  white/blue/red/green and ~20px on black (whose border carries a corner
  ornament and a double rule). That border is the *"seam a third of the
  way across"* an earlier pass saw when it tiled the file whole. Trimmed,
  the field tiles perfectly — so it is drawn as a NINE-PATCH: border at
  native size, field tiled inside it.
- `Terr_<c>pict.pic` is **one picture** — carved angels, a winged orb, a
  hooded figure with a lantern on a jetty, a sleeping nymph, a dragon over
  a magenta sea. Drawn COVERED, keeping its own aspect: the board half is
  914x400 and the art 721x381 or 888x381, and a 27% horizontal stretch is
  nothing on a damask and very visible on a dragon (`opening_window.gd`
  states the same rule for `Winbk_Startduel`).
- `Terr_<c>mana.pic` is a true wallpaper with no border, and it is **NOT**
  *"a repeat of that colour's mana symbol"* — that is the `Life_<c>mana`
  arrangement, re-checked and confirmed. At territory size it quilts ALL
  FIVE glyphs together, and it is the grey stone-and-mana-symbol table in
  the owner's own 1997 screenshot.

**WITHOUT THE 1997 ART, all fifteen grounds are PAINTED**
(`game/duel/territory_ground.gd`). `Provenance.md` requires the game to be
complete with no imported asset, and a nine-choice chooser whose choices
all looked alike would be a chooser in name only. The derived set keeps
the three styles apart the way the originals do — a lozenge lattice, a
medallion quilt, one large emblem in outline — and the five colours apart
by palette, drawn in the era's idiom (an ordered dither over a tiny
palette) rather than copied from anything.

**[QoL] THE SAME TWO LISTS ARE ON THE BATTLE-SETUP SCREEN**
(`game/setup_screen.gd`, beside the duelist portraits, with a live
preview at the board half's own aspect). The original had no such control
on its pre-duel screen, so it is labelled `[QoL]` on the screen itself.
It is ONE setting, not two: both controls go through `DuelOptions`'s own
accessors into `PlayerTerritoryColor` / `PlayerTerritoryType`, so they
cannot disagree — pinned by
`test_the_two_controls_are_two_views_of_one_value`.

**PER PLAYER, NOT PER SEAT — and the sources settle it.** `Duel.hlp`,
**Dueling Options**, in full: *"The box in the lower portion of the window
is relevant to the appearance of the background in your territory. (You
cannot do anything to change the background in your opponent's territory;
it matches the predominant color in her deck.) The list on the left simply
allows you to pick the predominant color of your background. The list on
the right includes the different types of background art available for
each color. Select one option from each."* So the COLOUR question is
answered outright, and `Magic.exe` agrees — there is exactly one pair of
values and both are named `Player…`. What no source states is the
opponent's TYPE: the help mentions only her colour, and one stored
`PlayerTerritoryType` cannot say whether the other half followed it or
sat on a constant. **OUR CHOICE, recorded as a choice:** the opponent's
half wears the SAME STYLE at her own deck's colour. It is what a single
stored type most plausibly drove, it keeps the table one design rather
than two, and it is the only reading under which the style list is a
choice about *the table* rather than about half of it. (s30 is Tier 3 and
does neither: `duel.go:999,1004` gives both seats `Terr_%smana` and offers
no setting at all.)

Pinned by `tests/ui/test_duel_options.gd` and
`tests/ui/test_territory_ground.gd` (11 tests), and captured as
`shot_duel_options.png` on the screenshot tour.

### 6.5 [1997] Windows we do not have: the Combat Bar, the Attack window, the Duelist's Face — PARTLY DONE (2026-08-31)

**The Combat Bar and the Combat window are BUILT** — `game/duel/combat_bar.gd`
and `game/duel/combat_window.gd`; see `docs/duel-screen-design.md`
(twenty-ninth pass) for the art survey, the geometry and the captures.
**The Duelist's Face is BUILT** — forty-fifth pass, `game/duel/duelist_face.gd`
plus `DuelScreen._face_shown` / `_open_life_menu`. `Duel.hlp` has a topic of
that name and it turned out to be the complete specification: the register
turns over from its own mini-menu (`@MENU_LIFE`'s `Flip over to face` /
`@MENU_FACE`'s `Flip back to lifepoints`), turns over BY ITSELF whenever a
spell being cast could take a player as a target, and turns back *"when
faces are no longer needed… automatically"*. All three are built; the
automatic flip is recomputed from the pending `TargetSpec` on every refresh
rather than stored, which is what makes the flip back cost nothing.

**Two corrections came out of it.** `Program/DuelArt/Face_*.pic` is NOT the
art — five byte-identical copies of a flat grey gradient, Manalink's
placeholder (the importer's MANIFEST records the whole survey so nobody
repeats it). The real portraits are `Life_<colour>pict.pic`, which this
project was already importing as `life_panel_*` and writing the life total
across — so the panel wore one face twice and had nothing to flip to.
`life_panel_*` now names `Life_<colour>patt`, the wallpaper; the portrait
has its own key. And `_on_game_over` fell through to `game.players[-1]` on a
DRAW and announced it as a win for seat 2; it now says
`@DIALOG_SHANDALARENDDUEL`'s third line.

Still open in this item: the **Lich Register** (`Life_Liched.pic` is
surveyed but not imported — Lich is not in our card pool, so the substitute
register has nothing to substitute for), the Spell Chain's own title bar and
minimise, and `Opp Hand (N)` → `Opponent`.

**CORRECTION, recorded because this file said otherwise.** The Combat Bar
has **SEVEN** icons, not five. The printed manual (p.117) says five and is
the only source that does; the shipped `Duel.hlp`, topic **Combat Bar**,
says *"This bar has seven icons"* and lists them (Declare Attackers · Fast
Effects · Declare Blockers · Fast Effects (2) · Damage Dealing Part 1:
First Strike · Part 2: Normal · Part 3: End of Combat),
`@CUECARD_PHASEBAR` carries exactly seven combat tooltips, and
`Winbk_Phasecombat.pic` draws exactly seven icons. `@MENU_TERRITORY`'s
`Go to:` list names the same seven stops.


`UIStrings.txt:155` `@WINDOWTITLES`, 7 entries:

```
%s Attack      Your attack      Spell Chain
Opponent       Your hand        Save Game      Load Saved Game
```

- **`Your hand`** — ours matches (`stack_hand.gd:110,200`).
- **`Opponent`** — ours said `Opp Hand (5)` (`duel_screen.gd:1326`), which
  is s30's wording, not the original's. **DONE, fortieth pass**: the chip
  is now `Opponent (N)` AND is the hand window's own title bar rather than
  a squashed copy of the whole window (§9.1).
- **`Your attack` / `%s Attack`** — the **COMBAT WINDOW**, now built
  (`CombatWindow.title_for`). `@MENU_ATTACK` (`:843`) = `Minimize` /
  `Help...`; `@MENU_MINIMIZEDATTACK` (`:848`) = `Restore` / `Help...`;
  its minimised state is named `Minimized attack window` in
  `@CUECARD_OTHER` (`:667`), which is the window icon's tooltip. Only
  `Help...` is still missing (there is no Dueling Help at all).
- **`Spell Chain`** — ours has no title bar and no minimise;
  `@MENU_SPELLCHAIN` (`:853`) gives it the same pair (`Minimize` /
  `Help...`), `@MENU_MINIMIZEDSPELLCHAIN` (`:856`) the restored pair
  (`Restore` / `Help...`), and `Minimized spell chain`
  (`@CUECARD_OTHER`, `:667`) its collapsed name — the window icon in the
  Phase Bar's centre band already restores the Combat window and would
  restore this one the same way (`Winbk_Spellmin.pic`, the wand, is the
  twin of the dagger and is surveyed but not imported).
  **This is also where the chain's only remaining SIZE problem goes.**
  Since the forty-second pass every chain object is a full `MiniCard`,
  which puts the strip's pitch at 132px from y=150: **four** objects fit
  above the 800px floor, a **fifth** ends at 810 and clips. Four-deep
  chains are already rare and five-deep essentially unseen, and the 1997
  answer is this window — a framed, titled, MINIMISABLE thing that can
  scroll or fold — not a smaller card. Do not "fix" the overflow by
  scaling a chain object down; that is the defect the forty-second pass
  removed.

**The Combat Bar — DONE.** `Duel.hlp`, topic **Combat Bar**: *"a
miniature Phase Bar that appears during an attack. It functions in exactly
the same way as the larger bar; you can even use Stops. This bar has seven
icons, representing the sub-phases of combat"* — and it **replaces** the
Phase Bar for the duration (`Duel.hlp`, **Phase Bar**: *"During combat,
the Phase Bar is replaced by the Combat Bar"*). The seven map one-for-one
onto the last seven `@CUECARD_PHASEBAR` entries and onto the seven icons
drawn in `Winbk_Phasecombat.pic`. "Begin Combat" is not on the bar — it is
the Main-phase Combat icon itself (p.190: *"when you click on [it], you
are only announcing your intention to attack. The attack doesn't actually
start immediately."*). Built: `game/duel/combat_bar.gd`, with the cue
cards as tooltips and a click on a sub-phase acting as Done (manual
p.126). **Stops and run-to landed 2026-08-31**, on both bars — `Duel.hlp`
says the Combat Bar takes Stops as well, and the original's own
`option_PhaseStoppers[2][38]` is wide enough to prove it (§6.1).

**The Combat window — DONE.** Manual p.126: *"As soon as you add the first
creature to the attack, the **Combat** window opens. Your attackers line up
on your side, and the space on the other side is reserved for (potential)
blockers."* Title bar: `Your attack`. Minimisable from its upper-right
corner, restored from the **window icon** in the Phase Bar's centre band
(p.126) — which is what that blank band in the middle of our own phase
strip is for. Built: `game/duel/combat_window.gd`, on `Winbk_Attack`'s
skull ground with the era's sword and shield as lane markers; the window
icon is `Winbk_Attackmin`, whose 39x70 fits the 41px column and its
~100px centre band exactly. A creature in combat now leaves its territory
for the window, which the Manalink patch
`patch_not_in_combat_window_if_no_longer_attacking.pl` proves was the
original's behaviour.

**Still missing here:** the manual's *"there is no way to change your mind
and remove"* an attacker or blocker — a rules fork we keep revocable by
the owner's earlier call (`RulesOptions.attackers_revocable`); the
**banding prompt** on adding a banding creature (see §6.9); and cards that
FORCE a creature into the window (*"those creatures are highlighted, and
you must add them"*).

**The Duelist's Face and the Lich Register.** `@MENU_LIFE` (`:883`) =
`Target %s` / `Target yourself` / `Flip over to face` / `Help...`, and
`@MENU_FACE` (`:861`) = the same three with `Flip back to lifepoints`. The
life register and the opponent's PORTRAIT are two faces of one panel. The
Lich Register is its own named part; `@CUECARD_LIFE` (`:678`) carries
`%s life points (opponent is Lich'd)` and
`Your life points (you are Lich'd)`. We render neither the portrait nor a
Lich state. (`Target %s` / `Target yourself` confirms the life panel as the
player-target click, which we already do — `duel_screen.gd:515`.)

**The Situation Bar** *"sits between the two territories"* and *"moves so
as to always remain visible"* (`Duel.hlp`); ours is pinned at
`offset_left = 372` (`duel_screen.gd:1697`).

### 6.6 [1997] The spell chain's captions are all wrong — DONE (2026-09-01, forty-second pass)

Ours read `Ability Effect` / `Triggered Ability` / `<name> casts` over the
source's name, on a portrait card SCAN at width 104. It now reads the
original's own words on a full `MiniCard` — see
`docs/duel-screen-design.md`, forty-second pass, for the reference, the
measurements and the reversal of the fortieth pass's audit note.

**One correction to what this item asserted.** `Ability Effect` is NOT
s30's invention. It is 1997 per-card data: `Legacy.csv` column 4,
`Effect Title` — row `0539,"Urza's Avenger","","Ability Effect",…`, which
is exactly the card in the owner's reference — read by
`src/functions/windows.c:1533` as `effect_title_text` for csvid-903
effect cards and painted on the small card's own title bar by
`DrawSmallCardTitle`. Fifteen cards carry that title. We ship no
effect-card table, so we cannot say it for an arbitrary card, which is why
the generic captions below are the ones we use; a future effect-card /
legacy-card layer (§ Legacy Cards) could restore it verbatim.

`UIStrings.txt:1012` `@PROMPT_ACTION` = `CASTING` / `ACTIVATING` /
`PROCESSING`. The chain items themselves — **SHIPPED**, with `%s` filled
by the PLAYER's name, as `src/functions/events.c:563` does when it loads
`PROMPT_PROC1` and formats it with `opponent_name`:

```
@PROMPT_CAST1  :1118   %s casts...        %s casts...\nX is %d.
@PROMPT_TAP1   :1123   %s activates...    %s activates...\nX is %d.
                                          %s activates...\n(with %d mana).
@PROMPT_PROC1  :1134   %s processes...    %s processes...\nX is %d.
```

Note the **X rides on the chain item** — s30's `for N` (§3.9) is the
original's `X is %d`. That is shipped too: `StackItem.x_value > 0` adds
the second line. `%s activates...\n(with %d mana)` is NOT: nothing records
how much mana an activation was paid with. `@CARDTITLES` (`:255`) gives
the titles a non-card chain object wears: `Damage`, `Hunting: %s`,
`Activation`, `Upkeep`, `Draw a card` — still open, with the effect cards
they belong to.

**STILL OPEN in this item.** The original has a state we lack entirely: a
spell is `Trying to cast %s` (`@PROMPT_CHECKFEPHASE[1]`, `:1025`)
*before* it becomes `Cast %s`.
`Duel.hlp`, **Spell Chain**: *"The status of the original spell changes
from Trying to Cast to Casting."* And `prompts.txt:1048` `@PROMPT_FIZZLE` =
`fizzle` — the original said so out loud.

### 6.7 [1997] The message bar's real vocabulary — DONE (2026-09-01); one claim in it was wrong

Our `_status_message()` (`duel_screen.gd:456-493`) *derives* the prompt
from `game.current_step()`. The original does the opposite: the CALLER
passes the caption down — `allow_response(int who, int phase, const char
*caption, int event)` (exe `0x436A20`; the three call sites are
`src/functions/engine.c:371,1565,1769`). That inversion is why its wording
is so specific: it knows what it is asking about.

`UIStrings.txt:1018` `@PROMPT_FASTEFFECTS`, the frame — note the separator
is a bare `...` with **no surrounding spaces**, ours is `?  ...  `:

```
Triggered effects?...%s
Interrupts?...%s
Fast Effects?...%s
```

Which of the three fires is set by the legal-response type mask
(`src/functions/events.c:396-399`): `Interrupts?...` when only
`TYPE_INTERRUPT` may respond (responding to a spell *being cast*),
`Fast Effects?...` when `TYPE_INSTANT` may, `Triggered effects?...` in the
trigger window. Our engine has no interrupt/instant split, so **this
reduces to two for us**: `Triggered effects?...` when the top of the stack
is a trigger, `Fast Effects?...` otherwise.

`UIStrings.txt:1024` `@PROMPT_CHECKFEPHASE` — the `%s` that fills them:

```
Damage prevention   Upkeep Phase      Assign Attackers
Trying to cast %s   Draw Phase        Assign Blockers
Cast %s             Main Phase        Discard Phase
Activate %s                           Use Regeneration Effects
Process %s
```

`UIStrings.txt:1039` `@PROMPT_SPECIALFEPHASE` — the trigger windows:

```
Card into play    Card(s) to Graveyard  Begin Upkeep   Choose Attackers
Card leaving play Draw a card           End Upkeep     Pay for attacker
Damage Dealing    Casting               Draw Phase     Choose Defenders
Graveyard order   Tapping                              End of Combat
                                                       End of Turn
```

So the original says `Fast Effects?...Cast Lightning Bolt`,
`Fast Effects?...Begin Upkeep`, `Fast Effects?...Damage prevention`. We say
`Fast Effects?  ...  ` plus a phase name, and never name what is on the
stack.

`UIStrings.txt:1063` `@PROMPT_MAIN`, 8 entries — and it states whether the
LAND DROP is still available:

```
Main phase (before combat): cast spells
Main phase (before combat): cast spells, play land
Main phase (after combat): cast spells
Main phase (after combat): cast spells, play land
Combat phase: Choose attackers.
Illegal attacker.
Band with other attacker?
Combat phase: Choose blockers.
```

Ours is `Main phase: play a land or cast spells. Done to go to combat.`
(`duel_screen.gd:470`) — s30's wording, and it promises a land drop that
may already be spent.

`UIStrings.txt:1078` `@PROMPT_STOPANYWAY`, nine strings — the original
always says *why* it stopped (seven of them end with a trailing space,
which is in the original):

```
Paused                       Paused: Discard phase
Paused: Upkeep phase         Paused: Cleanup phase
Paused: Untap phase          Paused: First strike damage resolution
Paused: Draw phase           Paused: Combat damage resolution
Paused: Main phase
```

We show a phase name with no indication that anything *stopped* us, so the
player cannot tell a normal priority window from an interruption.
**PARTLY DONE 2026-08-31**: `DuelScreen.paused_message()` maps every step
onto these nine, and a Run to or a Done order that comes to rest flashes
its line over the Situation Bar (§6.1). Still open here: the rest of §6.7,
and the fact that an ordinary priority window still says nothing —
`@PROMPT_STOPANYWAY` should also cover the interruptions the player did
NOT ask for.

The Done button's own label changes with the phase —
`promptsX2.txt:1` `@PROMPT_TURNSEQUENCE`: `Pay for blocker`, `end draw`,
`end main`, `end discard`; plus `promptsX1.txt:1` `@PROMPT_ENDHEALING` =
`end damage prevention`. And `promptsX1.txt:5,9,13`:
`attacker selected`, `blocker selected`, `gain life`.

**THAT PARAGRAPH IS WRONG, and the Manalink source says so (2026-09-01).**
`@PROMPT_TURNSEQUENCE` is not a set of Done labels. Its entries are
CAPTIONS passed into the same response-window frame as everything else:

```c
// src/functions/engine.c:1519  (and ai.c:369)
dispatch_trigger(1-player, TRIGGER_PAY_TO_BLOCK,
                 EXE_STR(0x790248)/*PROMPT_TURNSEQUENCE[0]*/, 1);
```

— the identical shape as `allow_response(..., PROMPT_CHECKFEPHASE[5], ...)`
at `:371`. So `Pay for blocker`, `end draw`, `end main`, `end discard` and
`end damage prevention` are more `%s` fillers for `Fast Effects?...`, from
the priority windows at the END of those phases. **`end damage prevention`
is now built** (§6.8, 2026-09-01): `MtgGame.end_damage_prevention` wears
the verb and the Situation Bar prints `Fast Effects?...Damage prevention`
from the same `@PROMPT_CHECKFEPHASE` table. The other four are still not,
because we do not model an end-of-phase priority window as distinct from
the phase's own — that is engine work of its own.
**Do not put them on the Done button.**

Finally `UIStrings.txt:954` `@PROMPT_STILLTHINKING` = `Still thinking...`
— the original told you when the AI was working. We show nothing during AI
pacing (§2.6).

---

**WHAT LANDED (2026-09-01), and what was already there.** Auditing the
whole section against `_status_message()` found most of it built by
earlier passes: the `Fast Effects?...%s` frame with its bare ellipsis, the
`Cast %s` / `Activate %s` / `Process %s` split, every
`@PROMPT_CHECKFEPHASE` phase name, all four `@PROMPT_MAIN` main-phase
lines with the land clause dropping when the drop is spent,
`Still thinking...`, and `@PROMPT_STOPANYWAY`'s nine `Paused:` lines on a
run that comes to rest.

**The one piece genuinely missing was WHICH OF THE THREE FRAMES.**
`src/functions/events.c:396-399` picks between them off the legal-response
type mask, and the item's own reduction is right: no interrupt/instant
split here means two frames, not three. A TRIGGER on top of the chain is
the trigger window, so the bar now says
`Triggered effects?...Process Howling Mine` where it used to say
`Fast Effects?...Process Howling Mine` — the right verb inside the wrong
question. Pinned in `tests/ui/test_situation_bar.gd`.

**Left unbuilt, deliberately:** `Trying to cast %s`
(`@PROMPT_CHECKFEPHASE` entry 2) is the INTERRUPT window — a response
window while a spell is still being cast — and `@PROMPT_TURNSEQUENCE`'s
end-of-phase captions are the same kind of thing. Both need a priority
window our engine does not have; both are tracked here rather than
pretended at.

### 6.8 [1997] A damage-prevention / regeneration window — DONE (2026-09-01), in four slices plus the marker and the AI — a RulesOptions fork, and MEASURED

**WHAT WAS BUILT.** All four slices of §6.8a's design, in one pass, each
landing green on its own with the whole suite between them and the Deck
Lab's determinism check byte-identical every time (`--matrix decks
--games 6 --seed 4242 --no-elo`, same md5 at every slice).

1. **The packet.** `engine/core/damage_packet.gd` — `source`, `target`,
   `amount`, `prevented`, `is_combat`, `from_redirect`, `id`, plus
   `remaining()`, `prevent()`, and `matches()`/`absorb()` (the Manabarbs
   merge rule). `MtgGame.deal_damage` split into `_plan_damage` (build the
   packet) and `_land_damage` (the eight prevention gates and the
   application); with no window open they run back to back and every
   existing damage test still passes. Every `DAMAGE_DEALT` event now
   carries its packet, so how much was PREVENTED is readable for the first
   time.
2. **The window**, as a hold-open flag pair: `awaiting_damage_prevention`
   and `awaiting_regeneration`, `damage_prevention_request()`,
   `end_damage_prevention(pid)` (the original's own verb,
   `@PROMPT_ENDHEALING`). Packets queue in `MtgGame.damage_pending`
   instead of landing; the window opens in `_open_priority` — the same
   moment CR 704.3 checks state-based actions and the moment `Duel.hlp`
   puts the step; every packet lands AT ONCE when it closes; a redirect
   makes a second window; then the regeneration window opens with
   state-based actions still deferred, so the doomed creature is still
   there to pay for. `EffectBase.is_damage_prevention` /
   `is_regeneration` are the restricted allow.
3. **Damage as a target.** `TargetRef.damage()` / `is_damage` /
   `packet_id`, `TargetSpec.Kind.DAMAGE` with its own `damage_filter`,
   `MtgGame.find_packet`. This closes §6.20b at the engine level.
4. **The cards and the seat.** The Circles of Protection take an OPTIONAL
   damage target and prevent exactly the packet named — their 1997 form.
   `HumanAgent` asks for the window; the duel screen names it in the
   Situation Bar and refuses to run through it.

**WHAT BUILDING PROVED — four things the design got wrong or did not say.**

**1. Slices 2 and 3 had to swap.** §6.8a's slice 2 was "damage as a
target" with slice 3 the window. Built in that order slice 2 is a
provable no-op: nothing can produce a damage ref until a window exists to
hold packets, so no consumer can ever see one, no test can exercise one,
and the audit that is "the work, not the fields" verifies nothing. The
window went first; targeting followed and was testable the moment it
landed.

**2. The design's audit claim was half right, and the wrong half is the
dangerous one.** §6.8a said `is_player` stays false and `instance_id`
stays -1 "so every existing branch falls into the card path and must
early-return on a null `find_instance`". True of the four sites that DO
call `find_instance` — they are all null-guarded already. But three sites
compare identity by hand (`a.instance_id == b.instance_id`) and never
look the instance up at all: TargetPlan's no-duplicate rule
(CR 601.2c), the AI's already-chosen filter, and the duel screen's
selection toggle. Every damage ref carries `instance_id == -1`, so all
three read two DIFFERENT packets as the same target — TargetPlan would
have refused "can't choose the same target twice" for two distinct
Circles. Fixed by giving `TargetRef` a single `same_object()` and routing
all three through it, which is also the only shape that cannot rot when a
fourth arm is added.

**3. The return value is a real problem and needed a real answer.** The
design flagged that `deal_damage` must keep returning the amount actually
dealt; what it did not say is that with a window in the middle the answer
is not merely late, it is UNKNOWABLE at the call. `deal_damage` grew an
optional `after: Callable(dealt)` and the three callers that read it —
Drain Life, Syphon Soul, Mishra's War Machine — now wait for their
packet. `Duel.hlp` agrees this is the right shape: *"You only gain the
life if Spirit Link is in play at the end of the appropriate damage
prevention step."* Packets carrying such a callback do not merge, so an
answer stays its own.

**4. `Duel.hlp` names the regeneration window's contents, and the two
windows need an AUTO-SKIP to be playable.** A window whose only legal
action is a prevention effect, opened for a player who holds none, can
only be passed — so neither window opens unless some seat actually holds
an effect of the right family. That is not a rules shortcut and it is
what keeps the fork from stopping the duel on every point of damage. The
`_open_priority` placement also turned out to be a gift the design did not
claim: it covers combat damage, spell damage, ability damage and cleanup
damage with one call site, because it IS the "a player would receive
priority" moment.

**BOTH REMAINING HALVES BUILT (2026-09-01, the pass after).** The
**damage-marker widget** (§6.20b) — `game/duel/damage_marker.gd` and
`damage_marker_layer.gd`, one yellow card per waiting packet, anchored on
its victim, clicked exactly as a card is — and the **AI's prevention
heuristic** (`AiPlayer._prevention_action` / `_regeneration_action`), which
scales off `AiProfile` alone: the Apprentice's `holds_instants = false`
keeps it out of the window entirely, mistake injection fumbles it, and
`chump_threshold` is the life bar at which damage to the face becomes
worth a card. Both ROADMAP rows are gone. What is still ledgered there is
the greedy prevention POOL — a different animal, because a pool is created
by one spell and spent later by another moment (see the row).

**AND BUILDING THE AI PROVED TWO THINGS WRONG.** Both were invisible while
the only player in the window was a human choosing by hand; an AI looking
for *the cheapest effect that covers this packet* found them at once.

1. **The 1997 Circle did not check its VICTIM.** Every Circle of
   Protection reads *"would deal damage TO YOU"*, and the targeted form
   (slice 4) filtered only on the packet's SOURCE COLOUR — so a Circle of
   Protection: Red was a legal answer to a red packet aimed at a creature,
   which is a card the pool does not contain. Fixed by giving
   `TargetSpec.damage_filter` the SOURCE as a third argument (a predicate
   is built once per `CardData` and shared by every copy, so "you" cannot
   reach it any other way) and checking the victim in
   `PreventDamageShieldEffect._packet_matches`. Ledgered in
   `docs/simplified-cards.md`.
2. **A Fog is legal in the window and cannot answer anything in it.**
   `PreventCombatDamageEffect` raises `MtgGame.combat_damage_prevented`,
   which `_combat_damage_step` reads BEFORE a wave — the packets already
   waiting were planned by a wave that has run. So the window's auto-skip
   opens a step for a player holding nothing but a Fog, and the only right
   move there is to leave it. That is not a bug in the auto-skip: a Fog in
   the FIRST-STRIKE window genuinely stops the normal wave, which is the
   case `Duel.hlp` describes. The file's own header used to claim the
   general case and now says which half is true.

**WHAT THE FORK IS WORTH, MEASURED (2026-09-01).** With the AI able to use
the window, the Deck Lab can answer this for the first time. Two sweeps,
4000 and 2400 AI-vs-AI games each, `--no-elo`, same seed on both sides of
every comparison (so the shuffles are shared and the comparison is
PAIRED — the printed unpaired CI is conservative).

*On the shipped five-deck gauntlet: no measurable difference.* Every
deck's pooled win rate moves by less than its confidence interval
(`--rules fifth` vs the default: Big Green +0.3, Black-Red Raiders −2.2,
Blue Skies +0.2, Mountain Artillery +0.3, White Knights +1.4 percentage
points, on 1600 games each). With only the window fork on, **eight of the
ten matchups come out bit-identical** and the two that move are the two
that involve the one deck holding a regenerator (Black-Red Raiders' two
Drudge Skeletons). The gauntlet holds one Fog and two Skeletons between
five decks: it cannot express this ruleset, and that — not the ruleset —
is what the flat numbers say.

*On four decks built from the cards the window is ABOUT, it is enormous.*
A white Circles-of-Protection/Samite-Healer shell, a black regeneration
swarm, and two of the shipped aggressive decks, 400 games per matchup,
window fork only:

| deck | modern | window on | delta |
|---|---|---|---|
| Circle Wall (4 of each Circle, Healing Salve, Samite Healer) | 35.3% | 49.4% | **+14.1 pp** |
| Mountain Artillery (burn) | 55.9% | 43.5% | **−12.4 pp** |
| Black-Red Raiders | 78.2% | 73.4% | −4.7 pp |
| Regen Swarm (Skeletons, Walls of Bone, Ghouls) | 30.6% | 33.7% | +3.1 pp |

and the single matchups move further still: Circle Wall vs Regen Swarm
56.8% → 78.2%, Mountain Artillery vs Regen Swarm 67.8% → 41.2%. Games get
**12% longer** (22.7 → 25.3 turns pooled), which is the shape of the
change in one number: a step that exists to stop damage makes duels last.

So the answer to *"does the 1997 ruleset play differently at scale?"* is
**yes, exactly where its cards are, and nowhere else.** The Circles stop
being a sideboard tax and become a real answer, and burn stops being able
to close a game the defender has an activation for.

---

#### The original diagnosis (2026-08-31), kept


Four independent strings put a restricted response window inside damage:
`@PROMPT_CHECKFEPHASE[0]` = `Damage prevention` (`UIStrings.txt:1025`),
`@PROMPT_CHECKFEPHASE[11]` = `Use Regeneration Effects` (`:1036`),
`@PROMPT_SPECIALFEPHASE[2]` = `Damage Dealing` (`:1041`), and
`promptsX1.txt:1` `@PROMPT_ENDHEALING` = `end damage prevention`.

`Duel.hlp`, **Combat / Damage Dealing**: *"During damage dealing, players
may use only damage prevention fast effects — those that prevent, heal, or
redirect damage. (If a creature takes lethal damage or is destroyed,
regeneration effects are allowed.) No other kind of fast effects or spells
are permitted."*

Our `MtgGame.deal_damage` applies damage immediately
(`docs/mechanics.md §6`), and `mechanics.md:539` records "no damage on the
stack" as a deliberate simplification. This is the single largest
1997-rules divergence still standing: it is *where* Circle of Protection,
Healing Salve, Death Ward and every regenerator are actually used. The
card prompts assume it — `prompts.txt:185` `@CIRCLE_OF_PROTECTION` =
`Select damage card.`, `prompts.txt:450-452` `@HEALING_SALVE` =
`Select target player.` / `Select damage point to heal (%d of %d).` /
`Illegal target (prevent damage to ONE target).`, `prompts.txt:238-239`
`@DEATH_WARD` = `Select creature.` / `Illegal target (not dying).`,
`prompts.txt:639-640` `@PERSONAL_INCARNATION` = `Select damage to
redirect.` / `How much damage to redirect to you?`

Sized L: it touches the combat damage path and the priority loop — the
same surgery as §1.6's first-strike split, which the original also names
(`Resolve 1st strike damage` / `Resolve normal damage`, `@CUECARD_PHASEBAR`;
`Paused: First strike damage resolution`, `@PROMPT_STOPANYWAY`).

---

#### 6.8a THE DESIGN (2026-08-31) — BUILT 2026-09-01; see the heading above for what building proved

Verified against the engine as it stands and against `Duel.hlp`, which we
hold in the tree (`shandalar-src/Duel.hlp`, 11 Nov 1997) and which turns
out to specify this feature almost completely. **Everything below is now
implemented** (2026-09-01, the widget included); the design is kept
verbatim because the heading above is written against it. Every
`Duel.hlp` quotation in it was re-checked against the file while building
and every one is accurate.

##### The 1997 sources, in the order they answer the questions

1. **What the window is, and what is legal in it** — `Duel.hlp`,
   **Combat**: *"Assign combat damage… During damage dealing, players may
   use only damage prevention fast effects — those that prevent, heal, or
   redirect damage. (If a creature takes lethal damage or is destroyed,
   regeneration effects are allowed.) No other kind of fast effects or
   spells are permitted."*
2. **It is TWO windows, not one.** `Duel.hlp`, **Regeneration**, is
   explicit that regeneration is *not* one of them: *"Nor is regeneration
   one of the damage prevention fast effects that you are allowed to use
   during damage prevention steps. You can use regeneration **only** at
   the time when a creature is about to go to the graveyard."* And
   **Damage Dealing**: *"If combat damage is done to any creature or
   player, there is an opportunity to use damage prevention effects.
   **Afterward**, creatures that still have lethal damage can be
   regenerated; otherwise, they go to the graveyard."*
3. **Damage is a clickable object** — `Duel.hlp`, **Using Land**: *"If the
   effect is a targeted one (damage prevention, for example, **which
   targets damage**), you also need to choose a target. When you're
   prompted, click on any valid target — a card, **a damage marker**, or
   whatever."* That is §6.20b, and it is a prerequisite, not a sequel.
4. **The object is a PACKET, and packets MERGE by source** — the Circle of
   Protection rulings: *"May only be used during damage prevention, as it
   targets **packets** of the appropriate damage. However, you may use the
   Circle on the same damage more than once."* And Manabarbs: *"damage…
   during a damage prevention step is added to an existing Manabarbs
   damage packet (if there is one), so a single use of the CoP would
   target and prevent all of that damage."*
5. **Prevention applies at the END of the window**, not per click —
   *"This effect is applied to damage at the end of the damage prevention
   step, before any effects triggered by the damage take place."*
6. **Redirection RECURSES** — Veteran Bodyguard: *"The damage is
   redirected at the end of damage prevention… if a Bodyguard does
   redirect damage, this causes a **second damage-prevention step that
   follows the current one**."*
7. **A window opens on ANY damage, not only combat damage** — `Duel.hlp`,
   **Cleanup**: *"If any of the automatic effects cause damage or
   destruction, you **do** get the opportunity to use damage prevention,
   redirection, and regeneration fast effects"* — in the one phase where
   `Duel.hlp` says *"neither player can use fast effects (except for the
   aforementioned damage prevention stuff)"*.
8. **What does NOT open one** — **Toughness**: *"There is no damage
   prevention step when toughness is lowered."* §6.20i's list of
   non-actions (mana sources, land drops, sacrifices) says the same for
   its own reasons: *"technically, no damage has been dealt."*
9. **First strike gets its own** — *"After all of the first strike damage
   has been assigned, damage prevention (and regeneration) occurs as
   usual, and then any creatures dealt lethal damage go to the
   graveyard."* §1.6 already split the step, so this is a second call site
   rather than new plumbing.
10. **Some prevention is RETROACTIVE and some is not.** Reverse Polarity
    *"may be played either during the damage-prevention step when the
    damage is dealt or later in the turn"*; Personal Incarnation *"must
    use this ability during the damage prevention step resulting from the
    damage to be redirected **or not at all**"*. Unsummon is the negative
    case: *"cannot be played during damage prevention. Even though it
    happens to let a creature avoid damage, it is not a damage prevention
    effect."*

##### Where our engine stands (verified 2026-08-31)

- **One entry point.** `MtgGame.deal_damage(source, target, amount,
  is_combat)` (`engine/mtg_game.gd:~1297`) is the only place damage lands;
  78 card call sites plus `damage_effect.gd`, `damage_all_effect.gd`,
  `random_effect_table.gd` and combat all funnel through it.
- **Prevention is already modelled — but applied automatically.** Eight
  gates in a fixed order on the player branch and eight on the creature
  branch: `reverse_damage_shields`, `combat_damage_redirect`,
  `artifact_damage_redirect`, `prevention_shields` (colour masks),
  `prevention_shield_filters`, `damage_prevention` (the amount pool),
  `min_life_from_damage`; and protection, `cur_prevent_*`,
  `damage_redirects`, `cur_damage_immunity`, `inst.prevention`. **The
  window does not add prevention. It moves the CHOICE of which prevention
  applies to which packet from the engine to the player.**
- **Combat damage already batches.** `_apply_damage_requests`
  (`:~4068`) sets `_defer_state_based_actions = true`, deals every packet,
  then clears it and sweeps. **That switch is the gap the two windows go
  in**, and it already exists.
- **Regeneration is pre-emptive only.** `RegenerateEffect` adds a shield;
  `destroy()` consumes one; `check_state_based_actions` calls `destroy`.
  The 1997 "about to go to the graveyard" window sits exactly between
  those last two.
- **`TargetRef` is a closed two-case union** (player | card instance) and
  its own doc says *"every consumer branches on this flag first"*.
  `TargetSpec.Kind` has eleven members and no non-card object.
- **`_act_precheck` is a blanket DENY.** Every hold-open flag refuses all
  priority actions. The prevention window is the opposite shape: a
  restricted ALLOW. Nothing in the engine classifies an effect today.

##### The design, in the order it should be built

**Slice 1 — the packet, with no window.** New
`engine/core/damage_packet.gd` (`RefCounted`): `id`, `source_id`,
`target: TargetRef`, `amount`, `prevented`, `is_combat`, `from_redirect`.
`MtgGame.damage_pending: Array[DamagePacket]`, empty except while a
window is open. `deal_damage` splits in two:
`_plan_damage(...) -> DamagePacket` (everything up to the gates) and
`_land_damage(packet)` (the gates and the application). With no window
open the two run back to back and **behaviour is bit-identical** — that
is the point of the slice, and the whole existing damage test suite is
its pin. Packets **merge by `source_id` + target** while a window is open
(source 4).

**Slice 2 — damage as a target.** `TargetRef` gains `packet_id: int = -1`
and `is_damage`; `TargetSpec.Kind.DAMAGE` gains an arm in `legal_targets`
that reads `game.damage_pending`. **The audit is the work, not the
fields**: `is_player` stays false and `instance_id` stays -1, so every
existing branch falls into the card path and must early-return on a null
`find_instance`. Sites to check: both halves of `deal_damage`,
`TargetSpec.is_legal`, `TargetSpec.legal_targets`,
`MtgGame._all_targets_illegal`, `TargetPlan`, `StackItem.targets`,
`DuelScreen._try_take_target` / `_pile_holds_a_target` /
`TargetArrows._collect`. The UI side is a **damage marker** widget: the
1997 `Damage: %d` small-card state (`@CUECARD_SMALLCARD`,
`UIStrings.txt:731`) becomes clickable, which is §6.20b and §2.10's
tenth card state at the same time.

**Slice 3 — the window as a hold-open flag.** Copy
`awaiting_damage_assignment` exactly, because that pattern is proven and
already stops the machine *inside* the damage step:
- `MtgGame.awaiting_damage_prevention: bool` + `damage_prevention_request()
  -> Dictionary` (the packets, whose window it is, which sub-window).
- `end_damage_prevention(pid) -> String` — the original's own verb,
  `@PROMPT_ENDHEALING` = `end damage prevention` (`promptsX1.txt:1`).
- Opt-in through `DecisionAgent.wants_damage_prevention_window()`, so an
  AI-only duel never pauses and 1500 existing tests never see it.
- **The restricted allow.** Add `EffectBase.is_damage_prevention := false`,
  set true in the constructors of `PreventDamageEffect`,
  `PreventDamageShieldEffect` and `PreventCombatDamageEffect`, and
  settable by a card for the handful `Duel.hlp` names explicitly (Reverse
  Damage, Reverse Polarity, Simulacrum, Personal Incarnation). A **data
  flag, not a type switch**, so a card can opt in without the engine
  growing a list. `cast_spell` / `activate_ability` refuse anything whose
  effects do not all carry it while the window is open, with the
  original's sentence: *"No other kind of fast effects or spells are
  permitted."*
- Order inside the step: open prevention → `end_damage_prevention` →
  apply every packet through `_land_damage` (source 5: at the END, not
  per click) → if a redirect produced a fresh packet, open again
  (source 6) → `check_state_based_actions` with
  `_defer_state_based_actions` still set → **the regeneration window**
  over everything now holding lethal damage (source 2), whose only legal
  action is a regeneration ability → clear the defer and sweep.
- Prompts: `@PROMPT_CHECKFEPHASE[0]` `Damage prevention`,
  `[11]` `Use Regeneration Effects`, `@PROMPT_SPECIALFEPHASE[2]`
  `Damage Dealing`. The Situation Bar already has the shape for these
  (`_fe_phase_name`), and the Combat Bar already has the two damage icons.

**Slice 4 — the cards.** Circle of Protection stops being *"any source of
the colour"* (its current, ledgered simplification) and becomes *"this
packet"*; `@CIRCLE_OF_PROTECTION` = `Select damage card.` Healing Salve's
second mode becomes window-only and spreadable across packets
(`Select damage point to heal (%d of %d).`); Death Ward's
`Illegal target (not dying).` becomes expressible for the first time,
because "dying" is only a state the regeneration window can see.

##### Is it a RULES FORK?

**Yes, and a real one** — read `engine/rules_options.gd`'s header test:
two candidates were deleted because our engine already did the 1997
thing, and here it plainly does the MODERN thing. Modern Magic has no
damage-prevention step at all: prevention is a replacement effect applied
automatically in a fixed order, which is exactly our eight gates. 1997
has a real step with a real choice. So `damage_prevention_window`
(`fifth_value: true`, default false, `source: "Duel.hlp topic Damage
Dealing; the prevention step was removed in Sixth Edition"`) belongs in
`FORKS` — but **only when the behaviour exists**, per the class's own
rule: *"implement it behind the flag, then flip `IMPLEMENTED`."*

##### What it must not break

- **Nothing may pause when no human is watching.** The opt-in
  `DecisionAgent` gate is what keeps `tests/cards/` and the simulator
  green; without it every one of the 78 card call sites becomes a
  suspension point.
- **`deal_damage` must keep returning the amount actually dealt** (Drain
  Life reads it). With a window in the middle, the return value is only
  known after `_land_damage`, so any caller that reads it must be checked
  — that is a second audit, and it is why Slice 1 keeps the two halves
  back-to-back until Slice 3.
- **No window for toughness reduction** (source 8), for mana burn (life
  loss, not damage — `tests/unit/test_mana_burn.gd` pins that), or for
  the §6.20i non-actions.
- **`test_a_blocker_assigns_its_damage_in_one_packet`**
  (`tests/unit/test_audit_2026_09.gd`) already pins packet identity for
  Jade Monolith's sake. It is the closest thing to a spec we have and the
  new packet object must not contradict it.

##### Size, honestly

Four slices, of which only the first is small. Slice 2's `TargetRef`
audit and Slice 3's priority-loop surgery are each the size of §1.4, and
Slice 4 is a card-by-card pass. **L was optimistic; this is XL** and it
should be taken one slice per pass, each landing green on its own.

### 6.9 [1997] Manual combat damage assignment — DONE (2026-08-31) — (see §1.4)

`UIStrings.txt:999` `@PROMPT_RESOLVECOMBAT`, 10 entries:

```
%s: Assign damage to blockers, %d points left
%s: Assign trample damage to blockers, %d points left
Assign %d damage
Assign %d trample damage
Illegal target (wrong attack group)
Illegal target (gaseous form)
%s: Assign damage to attackers, %d points left
Assign %d damage
Illegal target (wrong attack group)
Illegal target (gaseous form)
```

A click-to-assign loop with a live "points left" counter, run in **two
passes** — the attacker assigns to blockers, then the blocker assigns to
attackers — with trample as its own pass and two refusal reasons (`wrong
attack group` = banding; `gaseous form`). This confirms §1.4 is 1997
behaviour, not an s30 addition, and gives it its exact wording. The
Manalink source contains no reference to `@PROMPT_RESOLVECOMBAT`, so this
is untouched 1997 code.

**And the loop itself is the evidence for a FORK.** A free click loop with
a running total has no room for a damage assignment ORDER, and it does not
need one: Fifth Edition had none. The order is CR 509.2, introduced in
Sixth Edition in 1999. `RulesOptions.free_damage_assignment` is that fork
— on for the 1997 ruleset, off (the modern order, enforced) by default.
See §1.4 for what was built. The second pass and the two refusal reasons
are both BANDING-shaped and stay as written: our band damage goes through
the same hook, and `Illegal target (wrong attack group)` is the string the
screen uses when a click would break the order.

Related: `@PROMPT_BANDWITHWHOM` (`:987`) = `Band with which attacker?` /
`Illegal band.` / `That isn't an attacker.`; `@PROMPT_DEFENDWHOM` (`:993`)
= `Block which attacker?` / `Illegal block.` / `That isn't an attacker.`;
`@PROMPT_CHOOSEBLOCKERS` (`:1139`) = `Choose blockers`;
`@PROMPT_CHOOSEDEFENDERS` (`:958`) = `Choose defenders`.

**Banding is decorative for us.** `Mtg.Keyword.BANDING` exists and
`mini_card.gd:655` draws its badge, but the choice is never offered.
`Duel.hlp`, **Combat**: *"If you select a banding creature for the attack,
you can choose to have it band with another attacker, rather than attacking
on its own. You're prompted to decide this… Otherwise, click the Done
button. (To skip the option and have the creature not band, you can also
double-click.)"* — **M, both.**

### 6.10 [1997] Illegal-target messages concatenate their reasons — DONE (2026-09-01), AND THEY DO NOT CONCATENATE

`UIStrings.txt:1145` `@PROMPT_ILLEGALTARGET` = `Illegal target.` and
`Illegal target (%s).`; `:1150` `@PROMPT_ILLEGALTARGETWHY` supplies 29
comma-prefixed reasons:

```
,player  ,can't target this  ,where     ,controller  ,owner
,type    ,abilities          ,color     ,name        ,subtype
,power   ,toughness          ,walls     ,spell       ,basic land
,artifact creature  ,target player  ,tapped  ,attacking  ,attacked
,blocked ,blocking  ,attacking/blocking  ,enchanted  ,casted
,cast resolved  ,damaged  ,can untap  ,will untap
```

The Manalink source shows they ACCUMULATE into one buffer with the leading
comma stripped (`src/functions/targets.c:166-181, 685-692`), so the player
reads `Illegal target (type,color,tapped).` — every reason at once. Ours
prints one generic line, `Not a legal choice for '%s'`
(`duel_screen.gd:614`). Cards ship their own bespoke reasons too
(`prompts.txt:452` `Illegal target (prevent damage to ONE target).`,
`promptsX1.txt:167` `Illegal target (not dying).`).

This is the string that teaches the rules, and it needs an engine half:
`TargetSpec.is_legal` returns a bool, so there is nothing to concatenate.

(Manalink-era: the shipped `Text.res` replaces `,name` with `,card type`
and adds `,destroyed`, plus three reasons written into spare exe space.
Port the 29 above.)

**THE CENTRAL CLAIM IS WRONG. THEY DO NOT ACCUMULATE.** Both of
`validate_target_impl`'s failure macros end in `goto epilog`:

```c
#define FAILURE(error_addr)                          \
    do { rval = 0;                                   \
         strcat(&error_str[0], EXE_STR(error_addr)); \
         goto epilog; } while (0)
```

so exactly ONE reason is ever appended, and the epilog's
`strcpy(return_error_str, &error_str[1])` is stripping that one string's
own leading comma rather than a separator between two of them. Sixty-odd
failure sites, every one of them a `goto`, and one of them carries the
comment *"avoid repeating message"*. The buffer SUPPORTS concatenation;
the control flow never produces it. Nobody reads `Illegal target
(type,color,tapped).` in 1997 or in Manalink.

**What the table really is, then, is a DIAGNOSTIC PRIORITY ORDER.** The
player is told the FIRST thing wrong with their choice, and the 29 are
listed in the order the original tests them — compare `targets.c:219-668`
with the table and they run together: `player`, `can't target this`,
`where`, `controller`, `owner`, `type`, `abilities`, `color`, … That
ordering is the only thing in the item that turned out to be load-bearing,
and it is now ours.

**BUILT, engine and UI.** `TargetSpec.WHY` is the 29 verbatim, with the
leading comma dropped (the original strips it before printing), and
`TargetSpec.refusal_reason()` answers with one of them or `""`.
`is_legal()` is now *that function asked for a yes or no* — one set of
checks, so the two can never drift; a sweep test asserts they agree across
every spec × source × ref combination it can build. `TargetPlan` and
`DuelScreen._try_take_target` both print `Illegal target (%s).`.

**The item's quote of our own message was stale**: `Not a legal choice for
'%s'` had already become `Illegal target (%s).` — with the SPEC
DESCRIPTION in the brackets, i.e. the REQUIREMENT. That is the sentence
the player is already reading in the prompt above ("Select target
creature."), so repeating it told them nothing. The original puts what is
WRONG there instead.

**Where our checks have no 1997 name.** The original had a dozen typed
fields (`required_type`, `illegal_color`, `power_requirement`…) where we
have one opaque `filter` Callable per spec, so the word cannot be derived
— it is DECLARED, with `TargetSpec.because()`, and defaults to `type`,
the original's most common answer by far. Three specs name a better one
already (Volcanic Eruption `subtype`, Blaze of Glory and Witch Hunter
`controller`); the rest of the pool is a sweep nobody needs to do at once.

**§3.9 was NOT made cheap by this and stays ledgered.** The two items look
adjacent — both are about a message naming what it refuses — but they
touch different objects: a refusal reason comes from a `TargetSpec` and a
`CardInstance`, while §3.9 needs `StackItem.description` to carry targets
and X, which it still does not. Nothing here forwarded it a single field.

Pinned by `tests/unit/test_illegal_target.gd` (14 tests, plus 3 for
§6.3's concede) and two more in `tests/ui/test_duel_prompts.gd`.

### 6.11 [1997] The button contract, and the missing Cancel — DONE (2026-08-31; heading stamped 2026-09-01)

`UIStrings.txt:172` `@DIALOGBUTTONS` = `OK` / `Cancel` / `Done`;
`:178` `@BUTTONLABELS` = `Cancel` / `Done`.

`Duel.hlp`, **Situation Bar**: *"At the rightmost end of this bar is a
**Done** button, a **Cancel** button, or both, depending on the
situation… Esc is just like Cancel · Return has the same effect as Done ·
Spacebar: if there is only one button, pressing this is the same as
clicking that button."*

The Manalink source gives the same contract as a bit spec: `allow_cancel`
(`src/defs.h:2390`) is two bits — `0` no buttons, `1` Cancel, `2` Done,
`3` both — and "Done" returns `target.card == -2`. **Which buttons appear
is a property of the PROMPT, not a constant.**

**DONE (2026-08-31)** — the bar carries both buttons. `_cancel_button`
sits beside Done in the table's own order and appears only when
`DuelScreen._can_cancel()` says there is something to cancel, which is
the help file's *"depending on the situation"* and the `allow_cancel`
bit spec's whole point. The same predicate drives the Escape key, so
*"Esc is just like Cancel"* is one door rather than two that agree.
Return now reaches Done in every mode (it used to dead-end in targeting,
discard and damage division) and is swallowed while a centre dialog is
up; Spacebar honours *"if there is only one button"* literally — it is
Done until Cancel joins it, and then the key is ambiguous, as the
original says. Pinned by `tests/ui/test_cancel_contract.gd`.

Still open here: the counted-targeting WORDING below. Ours says
`Select %s. (%d so far)` / `(%d so far, max %d)` after §1's pass, which
is `@PROMPT_GRABMANA`'s form; the `@TARGET_COUNT` forms are a different
pair of sentences.

Counted targeting composes from a `@TARGET_COUNT` section that survives
only in the compiled `Text.res` (`src/functions/targets.c:1382-1451`):
`%s (%d of %d)` and `%s (%d of up to %d)`. Ours says `choose %s (%d of %d)`
and `choose %s — %d picked, Done when finished` — same two cases, more
words. Card-level examples: `prompts.txt:384` `@FIREBALL` = `Select target
creature or player (%d of %d).`, `prompts.txt:700-703` `@PYROTECHNICS` =
`Select (1st of 4) target creature or player.` … `(4th of 4)`.

### 6.12 [1997] The right-click menus — DONE (2026-09-01), AND THE ITEM'S TABLE WAS FOUR MENUS SHORT

Right-clicking things opened menus. We had none anywhere in the duel
when this was written; we now have two (the Territory menu, §6.3, and
the life register's, built with the Duelist's Face on 2026-09-01).
The rest of the table below is still unbuilt.

`@MENU_SMALLCARD` (`UIStrings.txt:936`):
```
Original type                 Show ID tags\tCtrl+T
Show full card\tR DblClk      Show invisible effects\tCtrl+I
View in full card             Show all cards' summoning sickness\tCtrl+U
Don't auto tap this card      Help...
```
**`Don't auto tap this card` proves the original HAD auto-tap for mana** —
our "Auto-tap mana" wishlist entry (`docs/duel-screen-design.md §5`) is a
1997 feature, not QoL, and this per-card lock is its prerequisite.
`Show full card\tR DblClk` is the right-double-click examine (§2.15), and
what it opens is the **Showcase**.

`@MENU_GRAVEYARD` (`:901`): `View the graveyard` / `View exiled cards` /
`View both antes` / `Help...` — §1.2 and the ante view, from the original.

`@MENU_LIBRARY` (`:878`): `Count library cards` / `Help...`.

`@MENU_MANAPOOL` (`:890`): `Spend 1 mana: black|blue|green|red|white|
colorless|artifact` / `Help...`. `Duel.hlp`, **Mana Pool**: *"If there is
mana in your pool that you wish to use, click on the area next to the
appropriate color button (or on the button itself) to apply that mana one
at a time. To use all of a particular color, double-click in the area
representing that color."* Our pool is read-only. Note `artifact` as a
seventh slot — the original tracked restricted artifact mana as its own
column, which is exactly our `ManaPool` restricted pool.

`@MENU_FULLCARD` (`:868`): `Expand text box` / `Help for this card...` /
`Help...` — and `ExpandTextBoxOnBigCard` is a persisted setting (§6.4).

`@MENU_HAND` (`:876`): `Help...` only.

---

**BUILT** as `game/duel/card_menu.gd`, which carries every remaining table
verbatim plus the wiring in `DuelScreen`. Each menu is COMPLETE and greys
what we cannot offer — `Duel.hlp`, **Territory**: *"Depending on the
situation, one or more of these options is available."*

**THE ITEM LISTED SIX MENUS AND THERE ARE TEN LEFT.**
`Program/UIStrings.txt:841-947` holds **fourteen** `@MENU_` tables, and the
four this section never mentions are the WINDOW menus:
`@MENU_ATTACK` (`:841`) / `@MENU_MINIMIZEDATTACK` (`:846`) and
`@MENU_SPELLCHAIN` (`:851`) / `@MENU_MINIMIZEDSPELLCHAIN` (`:856`) — each
a `Minimize` or `Restore` plus `Help...`. Manual p.122 describes the pair
for the chain in words: *"you can minimize the Spell Chain window by
clicking in its upper right corner. To restore the minimized window, click
on the window icon in the center area of the Phase Bar."*

What each one does now:

| Table | State |
|---|---|
| `@MENU_SMALLCARD` | LIVE — `Original type` and `Show full card` both dock the card in the Showcase, plus the three display toggles. `View in full card` needs the Advanced Layout (§6.4), `Don't auto tap this card` needs an auto-tap, `Help...` needs §6.20l. |
| `@MENU_LIBRARY` | LIVE — `Count library cards` prints `Your library: N cards` in the Situation Bar, the count `Duel.hlp` says the pile deliberately does not show. |
| `@MENU_HAND` | Listed; it is `Help...` and nothing else, so the whole menu is grey. It answers the gesture rather than swallowing it. |
| `@MENU_MANAPOOL` | Listed, all seven spends grey — see below. |
| `@MENU_FULLCARD` | LIVE — `Expand text box`, persisted as the 1997 key `ExpandTextBoxOnBigCard`; the Showcase's text area grows UPWARD over the art, and only when the card's text needs it — corrected 2026-09-04 against `Duel.hlp` (*"when necessary"*) and the 1997 DLL's own `fullcard_expand_text_box`, which measures the overflow and moves the top up by exactly that much. |
| `@MENU_ATTACK` / `@MENU_MINIMIZEDATTACK` | LIVE — the Combat window already had both actions; the menu flips its one entry with the window's state. |
| `@MENU_SPELLCHAIN` / `@MENU_MINIMIZEDSPELLCHAIN` | Tabled, not live: our chain has no minimised state, and the 1997 restore route is the Phase Bar's window icon, which our icon already spends on the Combat window. |

**Two findings from building it.**

**1. The card menu and the card LIFT share one button, and the original
says so in the same breath.** `Duel.hlp` has *"Right-clicking on a card
also opens a mini-menu"* two sentences after *"You can also right-click
and **hold** to bring a card in your hand to the front for as long as you
hold the mouse button."* Holding is what tells them apart, so a right
press that is let go inside 250 ms is the MENU and a longer one was the
look (§2.15). Both still happen: the press lifts and shows the Showcase,
the short release opens the menu.

**2. `Spend 1 mana: %s` is an ENGINE gap, not a menu one.** In the
original the player pays a cost mana by mana and this entry is how one
goes in. Our engine settles a whole cost inside one `MtgGame.cast_spell`
call — there is no half-paid spell for a mana to be spent INTO — so the
entry has nothing to mean yet. Building it is a held-open payment, the
same shape §1.3 gave the mid-resolution questions, and it is the
prerequisite for the auto-tap that `Don't auto tap this card` proves the
original had. Note the seventh column, `artifact`: that pool is already
modelled (`ManaPool`'s restricted pool); only the command is missing.

Pinned by `tests/ui/test_card_menus.gd` (17 tests).

### 6.13 [1997] Mana burn is 1997 behaviour — DONE (2026-08-31) — a RulesOptions fork

`UIStrings.txt:582` `@DIALOG_MANABURN`:
```
Mana Burn!
%s loses %d life
You lose %d life
```
with its own handler in the 1997 exe (`0x4702A0`). `docs/mechanics.md:539`
records "no mana burn" as a deliberate era choice; that is right for
*modern* rules and wrong for *1997*. **Manalink is what turned the rule
off** (`config.txt` `ManaBurn:0`, re-implemented at
`src/functions/produce_mana.c:1461-1473`).

Restore it as an **option**, not a hard revert — Manalink's own players
voted with that config line. Note the era's extra emptyings, from
`Duel.hlp`: the pool clears at the end of each phase *"and at the beginning
and end of an attack"*.

### 6.14 [1997] The X-spell dialog is a divided-damage dial — SPLIT IN TWO, BOTH DONE (2026-09-01) — because it is TWO widgets

`UIStrings.txt:657` `@DIALOG_FIREBALL`, 7 entries:

```
Generic &mana to put into the spell:      # &Targets:
(max: %d)                                 (max %d)
X cost:                                   Amount of damage to be done each target:
Cost for additional targets:
```

This is precisely the per-target dial the nineteenth pass marked
`SIMPLIFIED` ("a divided amount is spread as evenly as it goes rather than
dialled in per target"). The original dialled X, the target COUNT and the
resulting per-target damage in one dialog, showing the additional-target
cost as it went. It supersedes both our SpinBox
(`"%s — choose X (max %d)"`) and s30's `"X = %d"` button list (§2.5).

---

**THE ITEM MERGED TWO WIDGETS, AND THE 1997 SOURCES SEPARATE THEM
CLEANLY.** `@DIALOG_FIREBALL` is not a divided-damage dial and has no
per-target field in it — read the seven strings again and they are two
INPUTS and three READ-OUTS:

```
Generic mana to put into the spell:  [ 6 ]  (max: 6)
X cost:                                4
Cost for additional targets:           2
# Targets:                           [ 3 ]  (max 4)
Amount of damage to be done each target:  1
```

Six mana in; two of them bought the second and third target at Fireball's
own *"costs {1} more to cast for each target beyond the first"*; the
remaining four are X; and Fireball divides X **evenly, rounded down** among
the targets, so each takes one. `Amount of damage to be done EACH target`
is singular because dividing evenly is Fireball's printed RULE, not a
choice. That is also why `X cost:` is a read-out and not a second field:
there is one pot of generic mana and the dialog shows how it splits.

**The real divided-damage dial is `@PYROTECHNICS`
(`Program/prompts.txt:698`), and it is not a dialog at all** — it is four
prompts:

```
Select (1st of 4) target creature or player.
Select (2nd of 4) target creature or player.
Select (3rd of 4) target creature or player.
Select (4th of 4) target creature or player.
```

One click per point of damage, exactly the shape `@PROMPT_RESOLVECOMBAT`'s
`%d points left` loop already has (§1.4/§6.9). Click the same creature
twice and it takes two. The table hardcodes four because Pyrotechnics
divides exactly four.

So the item is **SPLIT**, and both halves are built:

**§6.14a — `@DIALOG_FIREBALL`, `game/duel/fireball_dialog.gd`.** Entries 1
and 2 are the whole dialog for an ordinary {X} spell (Braingeyser,
Disintegrate, Howl from Beyond) and that is what we already had; the other
five appear only when the spell buys TARGETS with the same mana, which in
this pool is Fireball alone. **It fixes a real bug nobody had reported**:
X was asked BEFORE targets and priced without them, so the dialog offered
the whole pool as X and then the engine refused the cast the moment a
second target was picked — the surcharge had nowhere to come from. Asking
both in one window is what makes the budget add up, which is *why* the
original's dialog has two fields in it. The three read-outs and both
bounds recompute on every keystroke, which is the item's own *"showing the
additional-target cost as it went"*. The mana field also steps by
`cost.x_count`, so `{X}{X}` (Part Water, Voodoo Doll) can no longer be
handed an odd number that buys nothing.

**§6.14b — `@PYROTECHNICS`, the click loop**, in
`DuelScreen._advance_pending` / `_divided_prompt`. This LIFTS the
nineteenth pass's `SIMPLIFIED` marker and its `docs/ROADMAP.md` row. One
consequence is worth stating: §3.1's take-back (click a chosen target
again to deselect) does **not** apply inside a division, because a repeat
click is how you give a target its second point. The original's loops have
no deselect either — the combat division does not — and §3.2's Escape rung
already restarts the picking without losing the cast, so the recovery
route is unchanged. Done is dark for the whole loop: a division submits
itself when the last point lands.

**The third widget the item did NOT mention** is §1.4/§6.9's combat damage
assignment, which is `@PROMPT_RESOLVECOMBAT` and was already built. Three
string families, three widgets, and only two of them are a dial.

While wiring the dialog: `_on_cancel` was leaking a pending cast. It
cleared only in TARGETING mode, and none of the three rungs BEFORE
targeting — the mode menu, the tutor picker, the X question — has entered
it yet, so backing out of any of them left `_pending_card`,
`_pending_pid` and a parked tutor pre-selection behind. Fixed with a note.

Pinned by `tests/ui/test_x_dialog.gd` (11 tests), plus the divided loop's
own in `tests/ui/test_situation_bar.gd` and
`tests/ui/test_stack_hand.gd`.

### 6.15 [1997] Card and panel state vocabulary — the cue cards — PARTLY DONE (2026-08-31)

**The `@CUECARD_SMALLCARD` half is done and shipped with §2.10** — it was
the same item, and the small card now draws and names eight of the ten
states. See §2.10 for what landed and for the two the engine cannot
answer. What is still OPEN here is the rest of the `@CUECARD_*` family:
`@CUECARD_LIFE`'s poison and Lich flags, `@CUECARD_MANAPOOL`'s seven
columns, `@CUECARD_OTHER`'s window names, and the per-card COUNTER names
(we still show counters as bare numbers).

`UIStrings.txt:732` `@CUECARD_SMALLCARD`, the ten states a card on the
table can be in:

```
Damage to player            Is a target
This card will untap        Can't target this
Damage: %d                  Is a target, can't target again
Card is not controlled by owner   Dying
                            Summoning sickness
                            Phased
```

Four used to be invisible — **`This card will untap`** (the inverse of a
Meekstone lock), **`Card is not controlled by owner`** (a Control Magic'd
creature looked identical to your own), **`Dying`**, and **`Is a target,
can't target again`**. All four are drawn now, with `Is a target` and
`Can't target this` beside them; see §2.10.

`@CUECARD_LIFE` (`:678`) shows the life register's readout includes poison
AND a Lich flag (§6.5). `@CUECARD_MANAPOOL` (`:693`) names seven pool
columns including `amount of Artifact`. `@CUECARD_OTHER` (`:667`) names
`Minimized attack window`, `Minimized spell chain`, `%s library`,
`Your library`, `%s graveyard`, `Your graveyard`, `Scrollbar`,
`Scroll thumb`.

The whole `@CUECARD_*` family (`:667-839`) is per-element hover help,
switched by the `Show cue cards` option — including per-card counter names
(`Doom counters: %d`, `Corpse counters: %d`, `Wind counters: %d`,
`Charge counters: %d`, `Clockwork (+1/+0) counters: %d`,
`Shackle (-0/-2) counters: %d`). We show counters as bare numbers.

### 6.16 [1997] Draws exist, and the end-of-duel wording — DONE (2026-09-01)

`UIStrings.txt:514` `@DIALOG_SHANDALARENDDUEL`:
`%s won` / `You won!` / `The duel is a draw`.

We have no draw outcome at all — `_on_game_over` takes a single winner id
(`duel_screen.gd:183-188`) and says `GAME OVER — %s wins!`. A draw is
reachable: `prompts.txt:984` `@WHEELOFFORTUNE` = `Neither player has enough
library to draw new hand, so duel is a tie.`

`@PROMPT_DRAWACARD` (`:1100`) gives the deck-out wording: `Draw Card` /
`No more cards, you lose.` / `No more cards, opponent loses.`

### 6.17 [1997] Discard, upkeep and mana prompts we never show — DONE (2026-09-01)

The engine-side gaps are §1.1 and §1.3; these are the words to use.

`@PROMPT_DISCARDACARD` (`:1106`): `Select card to discard.` /
`at random to discard.` / `to discard.` / `Discard to Library.` /
`Discard to Graveyard.` — and `@PROMPT_DISCARD` (`:1074`) =
`Paused: Discard phase`. **Entry 1 is now the duel's own discard prompt**
(§1.1, DONE 2026-08-31); the other four are for the discard EFFECTS
(Hypnotic Specter's random discard, Bazaar's discard-to-library) and are
still unused.

`@PROMPT_PAYUPKEEP` (`:1129`): `Pay Upkeep costs.` / `Don't pay Upkeep.` —
a two-button choice, which is exactly the "you may pay" that
`DecisionAgent.choose_yes_no` answers for the player across 68 call sites
(measured, §1.3). **DONE 2026-08-31**: the player is asked from the FIRST
ask (§1.3's pre-flight), and the two buttons wear these words whenever the
prompt begins "Pay" and the question is asked in the UPKEEP step —
`PlayerChoice.step`, which is what tells a rent from Urza's Chalice's
`Pay {1} to gain 1 life?`. `DuelScreen.yes_no_labels`.
Related: `Pay for attacker` (`@PROMPT_SPECIALFEPHASE`) and `Pay for
blocker` (`promptsX2.txt:3`) — attack and block costs.

`@PROMPT_GRABMANA` (`:1090`): `Tap %s` / `%s(%d so far)` /
`%s(%d so far, max %d)`; `@PROMPT_GRABMANA_DUALUSE` (`:1096`):
`Which color to use that choice as?` — the dual-land colour question,
which our `_click_permanent` answers through a generic ability menu.

`@PROMPT_UNTAP` (`:1058`): `Untap effects?` / `Paused: Untap phase` — the
original gave a response window in the UNTAP step, which CR 502 does not.
The cards that need it: `prompts.txt:1027` `@WINTERORB` = `PROCESSING
Winter Orb: Select land to untap.`, `prompts.txt:813` `@SMOKE`,
`promptsX1.txt:109` `@DAMPING_FIELD`, each followed by
`Opponent chooses to untap:`.

### 6.18 [1997] The per-card choice prompts we answer for the player — DONE (2026-09-01, all four cost sites closed) — see §1.3

§1.3 is the mechanism — **built 2026-08-31**, so every card below that
asks its question DURING A RESOLUTION now reaches the player through the
generic overlay. What is still owed here is the per-card WORDING: the
overlay speaks the four generic vocabularies (`@PROMPT_PAYUPKEEP`, `Yes`/
`No`, `Select a color.`, `Select target card.`, `Select card to discard.`)
and each card below has its own lines, which are better. These are the
cards, each with the exact 1997 wording:

| Card | Strings | File : line |
|---|---|---|
| Mindbomb | `Lose life or discard...` / `Lose 3 life.` / `Lose 2 life and discard 1 card.` / `Lose 1 life and discard 2 cards.` / `Discard 3 cards.` | `prompts.txt:589-593` |
| Time Vault | `Play this turn.` / `Skip this turn to untap.` | `prompts.txt:909-910` |
| Power Leak | `Take the 2 damage.` / `Pay 1 mana, take 1 damage.` / `Pay 2 mana.` | `prompts.txt:654-656` |
| Hasran Ogress | `Pay 2 mana.` / `Spend 3 life.` | `promptsX1.txt:204-205` |
| Cyclone | `Bury Cyclone?` / `Yes` / `No` | `promptsX1.txt:88-90` |
| Alchor's Tomb | `Select a color.` | `promptsX2.txt:11` |
| Urza's Avenger | `Add which ability?` / `Flying.` / `Banding.` / `First Strike.` / `Trample.` / `Cancel.` | `prompts.txt:944-949` |
| Shapeshifter | `Select Power/Toughness...` + `0/7` … `7/0` | `prompts.txt:780-788` |
| Primal Clay | `Creature type?` / `1/6 Wall.` / `2/2 Creature with flying.` / `3/3 Creature.` | `prompts.txt:672-675` |
| Mana Crypt, Goblin Artisans, Bottle of Suleiman | `Call the coin flip:` / `Heads.` / `Tails.` | `promptsX1.txt:252-254`, `:189-191`, `prompts.txt:134-136` |
| Mana Clash | `Your flip` / `Opponent flip` / `Repeating since a tails came up.` | `prompts.txt:575-577` |
| Natural Selection | `Select card order or DONE to shuffle.` | `promptsX1.txt:277` |

**The SACRIFICE and MANA-COLOUR families are done (2026-09-01, §1.3).** They
are not in the table above because the original states them GENERICALLY and
the engine now does too: `@SACRIFICE_CREATURE` / `@SACRIFICE_ARTIFACT` /
`@SACRIFICE_ENCHANTMENT` / `@SACRIFICE_LAND` (`Text.res:2645-2659`) are all
`Select <what> to sacrifice.` and `@SACRIFICE_LANDS` (`:2661-2667`) spells the
five basics in lower case, which `PlayerChoice.sacrifice_prompt` builds from
the cost's own description — so `@METAMORPHOSIS` (`promptsX1.txt:256`),
`@SACRIFICE` (`:364`), `@ASHNODS_ALTAR` (`:45`), `@ATOG` (`:53`),
`@PRIEST_OF_YAWGMOTH` (`:312`), `@ORCISH_MECHANICS` (`:291`),
`@SAGE_OF_LAT_NAM` (`:368`), `@GATE_TO_PHYREXIA` (`:182`), `@FALLEN_ANGEL`
(`promptsX2.txt:46`) and `@LIFE_CHISEL` (`:81`) all come out right from one
line of code. The same for `@MULTIMANA`'s `%s: What kind of mana?`
(`Text.res:2057-2059`), which is `@FELLWAR_STONE` (`prompts.txt:372-374`)
verbatim once the source's name is in it.

Primal Clay is the one we already do (our modal overlay was modelled on
it); Urza's Avenger and Shapeshifter are close. Everything else is now
ASKED — as of 2026-08-31 the generic overlay puts each of these questions
to the player — but in the generic words, not the card's own. Two things
are still genuinely missing rather than merely generic: several of these
are MODAL (Mindbomb's four outcomes, Power Leak's three, Urza's Avenger's
five) and would need a `PlayerChoice.Kind` richer than a yes/no, and the
coin-flip cards need `@DIALOG_COINFLIP` (`UIStrings.txt:593`) = `Coin flip
results: Heads` / `Coin flip results: Tails`, which we never show.

### 6.19 [1997] Ante is visible throughout the duel — DONE (2026-09-01)

`@DIALOG_VIEWANTES` (`:588`) = `%s ante:` / `Your ante:`;
`@MENU_GRAVEYARD` (`:901`) = `View both antes`; the mulligan dialog shows
both antes (§6.2); and three cards act on it — `promptsX1.txt:23-24`
`@ANTE_A_CARD` = `is added to your ante.` / `top card of library to add to
ante.`, `promptsX1.txt:120-121` `@DEMONIC_ATTORNEY` = `Ante additional
card.` / `Concede game.`, `prompts.txt:148-151` `@BRONZE_TABLET` = `Select
target card.` / `Swap cards.` / `Pay 10 life.` / `Concede game.`,
`prompts.txt:875-878` `@TEMPEST_EFREET` = `Swap cards.` / `Lose 10 life.` /
`Concede game.` / `randomly chooses...`

The engine had the ante zone (`engine/mtg_player.gd:50-55`) and an
untargetable `CARD_IN_ANTE` target kind (§1.2) — but **nothing ever put a
card there**, so the window had nothing to show and Jeweled Bird had
nothing to dump. That is what this item was actually about, and it is now
built.

**WHAT ANTE IS, from the manual.** p.60: *"Before the duel begins, both
players put up one or more cards from their decks as ante. In Shandalar,
whoever wins the duel will get to keep the ante cards, so pay attention to
the ante when you're deciding whether or not to duel a creature."*
Glossary p.165: *"Most duels are played 'for keeps.' That is, both players
chance losing one or more cards to their opponent. The cards that are at
risk in a duel are the ante. The winning player keeps those cards after
the duel is over."* Four more facts the tables and the FAQ pin down:

- **It is a MATCH PARAMETER, not a rule.** `&Ante` is a checkbox on
  `@SHELLPAGE_SINGLEDUEL`, `@SHELLPAGE_GAUNTLET` and
  `@SHELLPAGE_SEALEDDECK` (`Program/UIStrings.txt:48`, `:70`, `:90` —
  citation corrected 2026-09-02 by §6.21: the third 1997 page is the
  GAUNTLET's, `@SHELLPAGE_MULTIDUEL` is Manalink's, and `Text.res` is
  Manalink's table), and the
  manual's Gauntlet options say it plainly (p.138): *"ANTE is a checkbox
  that determines whether you play each duel for an ante card. Playing for
  ante adds 1 to the Difficulty."* **ONE CARD** is the default — the option
  is singular — while the manual's own "one or more" and the Challenge
  screen's *"the card (or one of the cards) you stand to win"* (p.42) keep
  the count open.
- **WHEN: off the deck, before the shuffle.** The manual pins the order in
  passing, describing the minimum-deck padding (p.118): random basic lands
  are added to your library *"(after the ante but before the shuffle)"*.
- **WHICH CARD: random, with one Shandalar exemption.** The player's stake
  never includes a basic land — FAQ 1.9, *"Why don't I ante basic lands?
  Basic lands are too weak a card to ante. In fact, you can actually LOSE
  the game if you only have basic lands in your deck!"* — while the
  creature's may, which is exactly what the owner's screenshot shows
  (`Cromer ante: Mountain` against `Your ante: Animate Dead`). FAQ 1.8 adds
  that the computer never antes Restricted cards, *"[though] according to
  Beth Moursund, the creatures SHOULD ante Restricted cards"* — a bug in
  1997, not a rule, and not copied.
- **A card changes OWNER only through ante** (p.161) — which is why
  `change_owner` and the ante zone are the same story.

**BUILT.** `MtgGame.stake_ante(pid, count, exclude_basic_lands)` lifts
`count` uniformly-random cards out of a library into the ante and sets
`MtgGame.ante_enabled`. Picking at random from the already-shuffled library
is distributionally identical to picking from the unshuffled deck and then
shuffling, and costs the same single `rng` draw. `DuelConfig.ante` (the
`&Ante` checkbox, now on the battle-setup screen and ticked by default)
decides whether the duel screen calls it, between `setup()` and
`deal_opening_hands()`; the player's seat passes `exclude_basic_lands`, the
AI's does not.

**IT IS OPT-IN AND IT IS DETERMINISTIC.** A stake removes a card from a
library and spends one RNG draw, so nothing that does not ask for one may
move: `start()` never stakes, the Deck Lab, the AI benchmarks and every
headless test are untouched. Verified by rerunning the Deck Lab across this
change (200 games, seed 4242, White Knights vs Black-Red Raiders): 124-76
before and after, `matchups.csv` byte-identical.

**THE THREE ANTE CARDS all keep working over a real stake**, and two of
them only became meaningful now: **Jeweled Bird** dumps the opening stake
and leaves the opponent's alone (it had nothing to dump before),
**Demonic Attorney** adds to it rather than creating it, and **Bronze
Tablet** cannot hold a staked card to ransom (the ante is not the
battlefield and `CARD_IN_ANTE` is its own kind) while still settling a
battlefield hostage normally. Darkpact can take the opening stake.
Pinned in `tests/cards/test_pool_wave46.gd`.

**SETTLING the ante when the duel ends — the winner takes it — is NOT
built**, deliberately: it is the adventure layer's economy, and there is no
adventure layer. See §7.

**Not changed:** `GraveyardView`'s ante section still titles itself
`Your ante (N)` / `%s ante (N)`, the [QoL] convention it uses for all three
of `@MENU_GRAVEYARD`'s views. The bare `@DIALOG_VIEWANTES` pair lives in
`OpeningHand.MULLIGAN` (entries 3-4, which are the same two strings) and is
what the opening window prints.

---

### 6.20 [1997] What the MANUAL adds that the string tables could not show

Page numbers are the manual's PRINTED pages (`printed = PDF page − 6` in
the owner's scan). Chapter 8 "The Duel" is pp. 59-106 (the rules), chapter
9 "Dueling in Shandalar" pp. 107-132 (the screen), the Glossary
pp. 159-186, and "Appendix: Sequence of Play" pp. 187-194 — that appendix
is the exact turn machine and should be read before any step-order work.

**a. `Done` is a STANDING INSTRUCTION — DONE (2026-08-31), with one
documented simplification.**
Manual p.112: Done *"does not simply move you on to the next phase or
action. Rather, it tells the 'referee' that you do not intend any action
until (1) you reach a phase that has a **Stop** on it, (2) an action or
decision is required…, or (3) **you are able to use a fast effect**. (Note
that 'able to' means that you have a fast effect handy **and** you have the
mana available to use that effect.)"* That is an autopass **with an
affordability check** — subtler than any modern auto-pass. Return is now
bound to exactly that (`_on_pass_turn` → `_order_done_advance`), per the
manual's key contract (p.116, **Return = Done**), replacing the blind
60-iteration pass loop that burned every priority window on the way.

**SIMPLIFIED — the affordability half.** `MtgGame.can_afford()` prices
against **floating** mana, not against lands you could still tap; the
engine has no potential-mana query (`docs/ROADMAP.md`) and the original
auto-tapped, so its *"mana available"* meant untapped sources. Ours
therefore under-reports and Done runs further than 1997's would. It still
cannot run past a decision, a Stop, or an effect you have actually floated
for, and the active player's declare-attackers step is an unconditional
brake once per turn. **Lifting it needs an engine `potential_mana(pid)` /
`could_afford(pid, cost)` that walks untapped mana sources** — worth
having anyway for the AI's planner and for the castable-highlight hint.

Still open here: `Go To` (p.112) *"ends the current phase and moves you on
to the next one"* has no control of ours. Our Done BUTTON passes priority
exactly once, which is finer than `Go To` and finer than `Done`; keeping it
is a **[QoL]** choice (it is the only way to stop inside a phase you did
not mark), but it means the Situation Bar's Done and the manual's Done are
not the same verb. `Go To` belongs with §6.3's Territory menu.

**b. Damage is an OBJECT you can click — DONE (engine 2026-09-01 §6.8 slice 3; the WIDGET 2026-09-01).**
`TargetSpec.Kind.DAMAGE` and `TargetRef.damage()` make a packet targetable;
`DamageMarker` / `DamageMarkerLayer` (`game/duel/`) put it on the table.
Manual p.119: *"a damage marker — a yellow 'card' on or near the target of
that damage"*, and p.121/125: *"click on any valid target — a card, **a
damage marker**, or whatever"*. Prevention and redirection TARGET THE
DAMAGE ITSELF (p.178: *"Prevention effects target the damage itself"*).
The same idea explains `@CIRCLE_OF_PROTECTION` = `Select damage card.` and
`@PERSONAL_INCARNATION` = `Select damage to redirect.`

**WHAT THE WIDGET IS.** One card-sized yellow marker per waiting
[DamagePacket], carrying the SOURCE on its title bar and the REMAINING
amount over its art — because telling two packets apart *is* the decision
the window exists to put to the player — anchored on whatever the damage
is aimed at (the creature's own widget, or that seat's life register).
Clicking one feeds `TargetRef.damage()`. The lone-packet auto-pick (§3.3's
gesture) is kept; with two or more the screen now opens targeting with the
original's own line, `Select damage card.`, instead of taking none and
letting the Circle fall back to its colour shield. A packet this Circle
cannot answer wears `CantTarget.pic`'s orange circle-slash, which is the
only cue available: the manual gives OPTIONAL and TARGET_LEGAL one yellow
between them (p.115/p.120/p.128), so "legal" has to be drawn as the
ABSENCE of a refusal.

**AND IT ANSWERS ONE OF §2.10's TWO MISSING STATES.** §2.10 wrote
`@CUECARD_SMALLCARD`'s `Damage to player` off as *"the life register's
state (§6.5)"*. That cannot be right: `@CUECARD_LIFE` (`UIStrings.txt:678`)
declares eight entries and none of them is it. It is in the SMALL CARD's
table because the object it describes IS a small card — a damage marker
whose victim is a player, which is the one card-shaped thing on a 1997
table that can be about damage to a player at all. `DamageMarker` carries
both damage cues: `Damage: %d` on a marker aimed at a card, `Damage to
player` on one aimed at a seat. Nine of the ten states are now drawn
somewhere; only `Phased` is still unanswerable, for the reason
`MiniCard.active_states()` gives.

**c. Attackers and blockers are IRREVOCABLE — S, UI (a deliberate divergence).**
Manual p.126: *"Once you have added a creature to the attack lineup, there
is no way to change your mind and remove it."* p.128: *"If you put in a
blocker, but then change your mind about it, there is no way for you to
remove it."* Both we and s30 let you toggle. **Recommendation: keep our
toggle** — it is a genuine QoL improvement and the manual itself warns
*"one bad accident might cost you the duel"* (p.120) — but LABEL it. This
is our clearest **[QoL]** divergence from 1997 in the combat flow, and it
should be a stated choice rather than an accident.

**d. The `potential draw` — S/M, both.**
Manual p.130: *"the single card that you would normally draw is
represented in your hand by a face-down '**potential draw**.' The card
itself is still in your library."* You then *"click on the face-down
representations one at a time"*, and *"each time you draw a card in this
way, it is considered a fast effect"* — so both players may respond
between draws. Effects can add potential draws or let you decline one
(*"Click on the face-down representation you wish to decline, and it
disappears"*). The hand window labels it `Draw a card`. We draw silently
inside the draw step.

**e. Artifacts stop working while tapped — M, engine.**
Manual p.124: *"**When an artifact is tapped, its continuous effects
cease.** This does not apply to artifact creatures."* This is a Fifth
Edition rule with no modern counterpart, and it changes how a large slice
of the 1997 artifact pool plays. Not in `docs/mechanics.md`; not tracked
anywhere. Check it against every implemented artifact before adopting —
it may be the single largest behavioural difference between our engine and
the original.

**f. Life is checked at PHASE boundaries, and negative life is survivable — S/M, engine.**
Manual p.174: *"If a player has less than 1 life at the end of a phase or
the start or end of an attack, that player loses the duel. **You can go
below 0 life and not lose if you manage to gain back enough life to put
you above 0 before the end of the phase.**"* (p.119 words the same rule
as "zero or less at the end of a phase or the end of combat" — the two
passages disagree slightly; p.174 is the Glossary and is the more precise
of the two.) Ours is a state-based action, so 0 life loses immediately.
Also p.177: *"If a player gets 10 poison counters, that player loses
immediately, **even if his or her opponent has negative life**"* — poison
outranks a simultaneous life loss. And p.168: mutual death is **a draw**,
*"you would both take back your own ante"* (§6.16).

**g. The mana pool empties at THREE kinds of boundary — S, engine.**
**PARTLY BUILT; this entry's text was stale and is corrected here
(2026-09-02 ruleset audit).** Manual p.176: *"Your mana pool empties at
the end of each phase **and at the beginning and end of an attack**."*
The modern every-step clear is no longer the only answer:
`RulesOptions.pool_empties_on_attack` clears at PHASE boundaries instead
(`MtgGame._phase_ends_now`), which covers "the end of an attack" — the
combat phase ending — and deliberately drops **the start of an attack**,
per the owner's ruling of 2026-08-31 that combat counts as ONE phase
emptying only when it is over. The same boundary carries p.174's lethal
check (`life_checked_at_phase_end`) and, since the audit, mana burn is
charged BEFORE that check rather than after. What is still owed is only
the start-of-attack boundary: mana floated in the beginning-of-combat step
survives to the damage step here and would have been burned at
declare-attackers in 1997. Ledgered in `docs/ROADMAP.md`. Pairs with
§6.13 (mana burn).

**h. Ending a phase is itself respondable — S/M, engine.**
Manual p.105: *"When the player whose turn it is declares the end of a
phase, the other player can use fast effects in response to this
announcement. **Any such response cancels the end of the phase**, thus
giving the active player additional opportunities to take actions during
that phase."*

**i. Things that are NOT actions, and cannot be responded to — S, engine.**
Manual p.189: *"Putting a land into play (like tapping a land for mana) is
not an action, and thus presents no opportunity for fast effects."*
p.95: *"Drawing mana from a mana source is neither a spell nor an effect.
You cannot respond to or interrupt the use of a mana source."*
p.132: sacrifices *"because they are **costs and not actions**, cannot be
interrupted"*, and *"There is no chance for damage prevention or
regeneration since, technically, no damage has been dealt."*
Cross-check these against our priority loop before building §6.8.
**CROSS-CHECKED (2026-09-01), and all four hold by construction:** a
window opens only where `MtgGame.deal_damage` is called, and none of these
calls it. Toughness reduction changes `cur_toughness`; a mana source runs
through `tap_for_mana`, which skips `_act_precheck` outright (CR 605.3a) and
so stays legal INSIDE a window as p.95 requires; a land drop is
`play_land`, which the window now refuses; a sacrifice is
`sacrifice_permanent`. Mana burn is `adjust_life` and not damage —
`tests/unit/test_mana_burn.gd` pins that, and `Duel.hlp` agrees: *"You
cannot prevent mana burn using damage prevention spells or effects."*

**j. Highlighting IS the affordance system, and it is colour-coded — S, UI.**
Manual p.120: *"the cards you can use at any moment during the duel are
**highlighted**"*; p.115: *"When all the necessary conditions are met, a
card in your hand is useable, and therefore will be highlighted as such"*
— which is exactly our castable hint. But p.128 adds a distinction we lack
entirely: ***"Mandatory effects are highlighted in orange, while optional
effects are in yellow."*** (upkeep effects), and forced attackers/blockers
are *"highlighted, and you must add them to the Combat window"* (p.127-128).
Feeds §2.10.

**k. The Duel Options window, read off the manual's own figure (p.113) — refines §6.4.**
The manual's figure shows the exact control set and default states:
`Layout` = `Standard` (selected) / `Advanced`; check boxes
`Show cue cards` (UNchecked), `Show abilities on small cards` (checked),
`Show power/toughness on small cards` (checked),
`See next draws at end of duel` (checked); group `Your territory
background` = colour column (`White` `Blue` `Black` `Red` `Green`
`Deck color`, selected) × style column (`Line drawing` `Pattern`
`Mana symbols`, selected); `OK` / `Cancel`. Two rules our version must
honour: *"You cannot do anything to change the background in your
opponent's territory; **it matches the predominant color in her deck**"*
(p.114) — so the opponent's background is a READ-OUT, not decoration —
and *"your option settings are **retained for future duels**"*.
Two nuances: `Show power/toughness` shows the **current** P/T, while
*"The Showcase always shows the **original** power and toughness"*
(p.113); and `See next draws` *"has no effect during the duel"* — it only
governs the end screen. Note the manual's figure does NOT list
`Show coin flip animations`, which the string table does
(`UIStrings.txt:598`); the string table is the shipped build, so keep it.

**l. Dueling Help is context-sensitive — M, UI.**
Manual p.14: *"Any time during a duel, you can right-click on any part of
the Dueling Table — a specific Magic card, for example — to open a
mini-menu of options… One of the options is **Help**. If you select this,
**you get information about whatever you clicked on**, plus links to more
details and other topics."* Not a manual dump: keyed to the object under
the cursor, and hyperlinked. Our card files already carry oracle text and
implementation notes in their header comments — that is most of the
content already written (`docs/duel-screen-design.md §5` spotted this).

**m. Who goes first — the manual contradicts itself, and p.110 wins — S, both.**
p.60: *"Who goes first is determined at random — unless one of you has a
first strike advantage."* p.110, flagged *"new to the Fifth Edition
rules"*: *"In every duel, one player plays first and the other draws
first. Who does which is decided by the player who wins a **coin toss**
(unless one player has a preexisting advantage). The player who gets
**First Play** does not draw a card during her first turn."* Implement
p.110 (§6.2); treat p.60 as the simplified summary. The 'Vantage hook —
a first strike advantage overriding the toss — is the one adventure-layer
tie-in the duel must eventually honour.

**n. The 1997 ruleset target, stated — informational.**
Manual p.108: *"This version of Magic: The Gathering enforces the official
**Fifth Edition** rules"* and *"the new rulings… are ruthlessly enforced,
and there is no room for negotiation."* Our engine cites modern CR
throughout. That is a deliberate, defensible divergence (modern CR is
better specified and better known), but it should be stated once rather
than discovered per card — items **e**, **f**, **g**, **h**, **i** above
and §6.8 are all places where Fifth Edition and modern CR genuinely
differ, and each needs a decision rather than a default.

### 6.21 [1997] The match parameters — `MatchState.LENGTHS`, `&Free play`, and a provenance correction (2026-09-02)

**The question this item answers.** `MatchState.LENGTHS` is `[3, 5]`, and
the pass that wrote it justified the pair as *"the only two lengths the
original's strings can narrate"* — while `@DIALOG_GAUNTLETOPTIONS` offers
`Best of &Three` / `Best of &One`. Three readings were possible: 1/3/5 in
different modes; 1 and 3 with the 5 invented by us; or two dialogs that
genuinely differ. **It is the third, and there is a fourth axis nobody had
noticed: the two dialogs are also from different builds.**

**THE 5 IS REAL AND IT IS 1997. We did not invent it.**
`@DIALOG_ENDEXP1DUEL_MATCHPROGRESS` (`Program/UIStrings.txt:553-562`) is
eight entries and two of them are the record sentences:

> `After %1!d! duel(s) in this best of 3 match, your record is %2!d!/%3!d!/%4!d!`
> `After %1!d! duel(s) in this best of 5 match, your record is %2!d!/%3!d!/%4!d!`

Verified in the genuine 1997 copy as well (`s30/assets/text/Uistrings.txt`,
same lines — the two files are aligned to line 1183). `MatchState`'s
reasoning stands: the number is written into the sentence rather than
substituted, so 3 and 5 are the only lengths the original can narrate, and
offering a best of 7 would mean printing a line MicroProse never wrote.

**BUT THREE THINGS AROUND IT ARE WRONG, and one of them is a string we put
on screen.**

**1. `&Free play` is Manalink 3's, not 1997's.** It exists only in
`@SHELLPAGE_MULTIDUEL` (`Program/Text.res:2869`) — a tag that **does not
appear in `Program/UIStrings.txt` at all**. The 1997 solo-duel page is
`@SHELLPAGE_SINGLEDUEL` (`Program/UIStrings.txt:39-56`), sixteen entries:

> `Player:` / `Opponent S&kill` / `Apprentice` / `Magician` / `Sorcerer` /
> `Wizard` / `Match parameters` / `&Ante` / `&Best of:` /
> `Side&board between duels` / `Duel &Options...` / `O&pponent's deck:` /
> `&Your deck:` / `<random deck>` / `Start &match` / `&Load match...`

**No `Free play`.** Manalink's MULTIDUEL page dropped `Opponent S&kill`
and the four skill names, and added `Free Play`, `&Minimum deck size:`,
the five deck-type radios and the network row (`&Send Parameters` /
`&Agree` / `&Disagree`).

**2. The dialog-resource evidence was read out of Manalink's executable.**
`MatchState` cites *"`MULTIDUELPAGE` in `Program/Magic.exe`: `id=1842
'Free Play'` carries `WS_GROUP`, `id=1841 'Best of:'` continues it"*.
`Program/Magic.exe` contains the string `Momir Vig` — it is the Manalink
binary. Its resources include `SingleDuelPage`, `MultiDuelPage` and
`GauntletPage` **side by side**: Manalink left the 1997 page alone and
added a new one beside it. Its `SINGLEDUELPAGE` template
(`strings -el Program/Magic.exe`) matches `@SHELLPAGE_SINGLEDUEL`'s 1997
string block entry for entry, which is what makes it usable as evidence —
`Opponent &Level` and its four skill names are there, and they are exactly
what Manalink's MULTIDUEL page drops:

> `Screen Name` `Joe Schmoe` `&Your Deck` `O&pponent's Deck`
> `Match Options` `&Ante` `Best of:` `msctls_updown32` `Spin1`
> `Side&board between duels` `Opponent &Level`
> `Apprentice` `Magician` `Sorcerer` `Wizard`
> `&Duel Options...` `&Load saved game...` `Start &match`

**`Best of:` is a numeric spinner (`msctls_updown32`), not one half of a
radio pair, and there is no `Free Play` control next to it.** The same
spinner is on `GAUNTLETPAGE` (beside a second one for `Num opponents:`)
and on `SEALEDDECKPAGE`. So the original's match length on every shell
page is **a number you type or click up and down**, and "free play" is a
Manalink-era way of saying "N = 1".

**3. The two Match Sizes are a different screen AND a different build.**
`Best of &Three` / `Best of &One` is `@DIALOG_GAUNTLETOPTIONS`, the
**duel program's own** compact options dialog (`docs/gauntlet-design.md`
§1.2b). The decompilation of the 1997 `DUEL.EXE` shows that dialog's
handler setting wins-needed to exactly **2 or 1** and nothing else
(dialog resource `0xe8`, controls `0x456`/`0x457`), and that binary
carries **no "best of N" sentence at all** — its end-of-duel dialog says
`That was round %d` / `Your record is %d/%d/%d`
(`@DIALOG_GAUNTLETENDDUEL`) instead. `@DIALOG_ENDEXP1DUEL_*` belongs to a
later, expansion-era executable. Manual p.156 describes the pair in prose:
*"Match Size is a choice between two options. You can either play every
match as a two out of three contest or decide each match on the strength
of a single duel."*

**So there are THREE match-length surfaces in the sources, not two:**

| Surface | Where | What it offers |
|---|---|---|
| The shell pages | `@SHELLPAGE_SINGLEDUEL` `:49`, `@SHELLPAGE_GAUNTLET` `:71`, `@SHELLPAGE_SEALEDDECK` `:91` | `&Best of:` — a **spinner**, any N |
| The duel program | `@DIALOG_GAUNTLETOPTIONS` `:624-626` | **Best of Three / Best of One** |
| The record sentence | `@DIALOG_ENDEXP1DUEL_MATCHPROGRESS` `:558-559` | the only two N it can **narrate**: **3 and 5** |

`LENGTHS = [3, 5]` is the intersection of surfaces 1 and 3 and is
defensible. What it is missing is surface 2's **1**.

**IS `Best of One` COVERED BY OUR `FREE_PLAY`? Mechanically yes,
narratively no — and the difference is the whole point of the entry.**

- `MatchState.wins_needed()` is already `best_of / 2 + 1`, which is **1**
  for `best_of == 1`; `is_over()` is already true after one duel;
  `winner()` already works. **`best_of = 1` needs no engine change at all**
  — it is not in `LENGTHS`, so the setup screen never offers it.
- `FREE_PLAY` (0) is different in exactly two places, and both are
  deliberate: `progress_line()` returns `""` and `verdict()` returns `""`.
  That is `&Free play`'s own definition — *one duel, no record kept*.
- **A `Best of One` match keeps a record.** It is a match: it ends with
  `You've won the match!` / `You've lost the match.` /
  `The match ends in a tie.` (`:560-562`, which are length-agnostic), and
  in the original it puts `&Save match` on the between-duels window.
- It cannot print a **progress** line, because there is no
  `best of 1 match` sentence — and `MatchState.progress_line()` already
  returns `""` for any `best_of` not in `PROGRESS`. **The 1997 constraint
  and our code already agree**, by accident.

**RECOMMENDATION — S, UI+doc. BUILT 2026-09-02** (all four points, as
the gauntlet's slice 2; `docs/gauntlet-design.md` §9). `LENGTHS` is
`[1, 3, 5]`, `PROGRESS` is untouched, `&Free play` is labelled `[QoL]` in
`match_state.gd`'s class doc and the citations are corrected. Two knock-on
effects worth naming: the battle-setup screen's `&Best of:` list now opens
on **3** rather than on the first entry (a list that opened on 1 would
make `&Best of:` mean "one duel with a record" by default), and the Deck
Lab's `--best-of` accepts 1 for the same reason `MatchState` does.

1. **Keep `[3, 5]`.** Both are 1997 and the justification in `MatchState`
   is correct.
2. **Add `1`**, as `LENGTHS: Array[int] = [1, 3, 5]`, and add nothing to
   `PROGRESS`. The only behaviour change is that a one-duel match now says
   `You've won the match!` where free play says nothing, which is exactly
   the difference the sources draw. Pin it with a test that a `best_of=1`
   match ends after one duel with a verdict and an empty progress line.
3. **Keep `FREE_PLAY` as the internal default** — every programmatic
   `DuelConfig` (tests, Deck Lab, benchmarks, standalone scene runs) is a
   free-play duel and must stay one — but **mark the setup screen's
   `Free play` label `[QoL]`** in `match_state.gd`'s doc comment. It is a
   Manalink word for a 1997 idea (the spinner at 1) and the label is worth
   keeping precisely because our `FREE_PLAY` really does keep no record.
4. **Correct the citations** in `game/duel/match_state.gd`,
   `game/duel/duel_config.gd:22` and §6.19 above. The 1997 homes are
   `Program/UIStrings.txt`: `&Ante` `:48`/`:70`/`:90`, `&Best of:`
   `:49`/`:71`/`:91`, `Side&board between duels` `:50`/`:72`,
   `Match parameters` `:47`/`:89`. §6.19's third page is
   `@SHELLPAGE_GAUNTLET`, not `@SHELLPAGE_MULTIDUEL`.

**AND THE PROVENANCE BOX AT THE TOP OF §6 IS WRONG.** It says
`Program/Text.res` *"is a SECOND, LARGER copy of the same table… a
superset rather than a different file. Either may be cited."* It is
**Manalink 3's table**: it carries `Momir Basic` (a 2006 format),
`&Challenge Mode` (Manalink's own mode, and it sits where the 1997 gauntlet
page has `&Ante`), `Highlander`, the network row, and
`199 unique / 499 total` where 1997 says `200 / 500`. Its `@SHELLPAGE_*`
blocks in particular are rewritten. **Find a tag in `Text.res` if the
latin-1 grep is inconvenient; quote it from `Program/UIStrings.txt`.**
`docs/gauntlet-design.md` §0 carries the full evidence, including the
seven places where `Program/UIStrings.txt` itself is lightly Manalinked
and `s30/assets/text/Uistrings.txt` is the cleaner 1997 copy.

---

## 7. Out of scope — the adventure layer

Listed once so nothing is silently dropped. All of these are s30 features
that belong to the world map, not the duel:

- Pre-duel ante screen (`duel_ante.go:43-302`) — including the ante-card
  SELECTION rule (a random non-basic land is drawn; the enemy has a 5%
  chance of exposing a Vintage-restricted card).
- Win / lose reward screens (`duel_win.go`, `duel_lose.go`),
  final-boss result (`game_result.go`).
- Dungeon dice notice banner (`duel.go:304-318`) and dice-granted bonus
  permanents put into play at duel start (`duel.go:454-464`).
- Quest constraint evaluation and payout (`quest.go:19-75`).

**What §6.19 built, and what it deliberately did not.** The duel now
STAKES an ante (`MtgGame.stake_ante`) and SHOWS it (the opening window, the
graveyard menu's `View both antes`). **SETTLING it is still owed, and it is
owed HERE**, because settling is an economy and not a rule:

- **The winner takes the ante.** Manual p.165: *"The winning player keeps
  those cards after the duel is over"*; p.167, on conceding: *"If the duel
  is for ante, the winning player collects the ante."* Nothing in the duel
  screen moves a card out of `MtgPlayer.ante` when `game_over` fires, and
  nothing should until there is a collection to move it into.
- **A DRAW gives each player their own stake back** — manual p.168, *"you
  would both take back your own ante"* (§6.16 and §6.20f).
- **Ownership, not the pile, decides who keeps what.** Bronze Tablet,
  Tempest Efreet and Darkpact change `CardInstance.owner_id` permanently
  mid-duel, and that is the value the settlement must read.
- **A dungeon duel has no ante at all** (FAQ 1.21: *"You do NOT get ante
  from creatures in dungeons"*), yet losing one still costs you your stake
  — a per-encounter rule the adventure layer owns. `DuelConfig.ante = 0`
  is already the switch for it.
- Reward alternatives (interrogate instead of taking the cards, p.42),
  the bribe, the riddle, and the pre-duel Challenge screen that shows both
  antes before you accept, are all world-map screens.

`CARD_IN_ANTE` is an untargetable target kind for the same reason as §1.2.

---

## 8. What the 1998 strategy guide adds

The book contains **nothing about the MicroProse game** — verified by
full-text search for `microprose|computer|CD-ROM|software|shandalar` and
by its index. It is a paper-Magic tournament book. Treated purely as
evidence about what expert play needs on screen, it independently
supports items already on this list, which is its whole value:

| The book's reasoning | Our item |
|---|---|
| "in each phase I go from left to right and evaluate each card on the board … remind you of any additional abilities" (p. 106) — the author's centrepiece routine, repeated three times | §2.3 sorting, §2.10 the orange "actionable" border |
| "it is the domain of sleazy players to rush their opponents through phases … they are hoping you are missing something, such as a fast effect" (p. 117) | Never auto-advance a priority window; §3.7 the standing "it's on you" cue |
| "the attack, where in Sealed Deck games almost all mistakes are made … What if the opponent tries to double or triple team one of your creatures?" (pp. 106-107) | §1.4 damage assignment, §2.2 lift, §2.1 arrows |
| "He had one card in his hand however and Red mana open" (p. 108) — the book's fullest worked decision, every input a number a UI shows or hides | Opponent hand count and untapped mana must stay visible (we have both) |
| "many players even put something on their library to help them remember the upkeep cost associated with a Waterspout, Stasis" (p. 106); "simply put a counter on the land to remind them" (p. 116) | A pending-upkeep-cost and will-not-untap indicator on the permanent — **[QoL]**, S, UI. Not currently on any list |
| "I could simply tap mana into my pool and wait for each Demonic Consultation to resolve" — the rules slip that lost a World Championship game (p. 105) | Manual tapping into a visible pool (we have it) and one-object-at-a-time stack resolution with a stop between objects |

Explicitly NOT taken from the book, because it is weakly supported or
because the book values the skill it would remove: an auto-computed
"you'll be at 3 after this attack" preview, a computed turn clock, and
cross-game memory. Our castable highlight already goes further than the
book would endorse; that is a deliberate **[QoL]** divergence.

---

## 9. Naming — adopt the 1997 words

The owner: *"let's have the naming of the items from the manual."* Our
names for things should be the original's, not ones we invented. The full
term-by-term mapping, with sources, is **`docs/glossary-1997.md`**; this
section is the work list, **ordered by how visible the mismatch is to the
player**.

Rules of engagement, in the owner's priority order:
1. **User-facing text first** — prompts, labels, window titles, button
   text, log lines. Cheap, and it is what the owner sees.
2. **New code** uses the manual's word from the start. Anything a later
   pass writes should be named from the glossary, not invented.
3. **Existing identifiers** are proposals with a size, never a sweep. A
   rename reaching into `engine/` is out of scope for duel work entirely.

**Exempt, by the owner's decision: PHASE NAMES.** We keep the modern step
vocabulary and the eight-slot strip. `glossary-1997.md §3` publishes the
mapping instead. Nothing below renames a step.

### Tier 1 — user-facing text (do these first; all S, all UI)

| # | Ours now | Should read | Source | Where |
|---|---|---|---|---|
| 9.1 | ~~`Opp Hand (5)`~~ | **DONE (fortieth pass)** — `Opponent (N)`, and the chip is now the hand window's own title bar (`StackHand.title_plate`), nine-patched like the player's instead of the raw 145x51 sheet squashed into a 150x22 button | `UIStrings.txt:155` `@WINDOWTITLES`; manual p.114 | `duel_screen.gd` `OPPONENT_HAND_TITLE`, `stack_hand.gd` |
| 9.2 | ~~`Tossing for the lead...`~~ **DONE 2026-09-01** | **`Start of Duel`** (the dialog's title) and `%s won the toss` + `and will play first.` — see §6.2 for the full play-or-draw set | `UIStrings.txt:483,487`; manual p.110 | `duel_screen.gd:306,359` |
| 9.3 | ~~`Ability Effect` / `Triggered Ability` / `%s casts` on chain items~~ **DONE 2026-09-01** | **`%s casts...`**, **`%s activates...`**, **`%s processes...`** shipped, with `X is %d` when there is an X (`DuelScreen._chain_caption`). Still open: `Damage` / `Activation` / `Upkeep` / `Draw a card` for effect cards, which need the effect cards themselves | `UIStrings.txt:1118,1123,1134,255`; §6.6 | `duel_screen.gd` `_chain_caption` |
| 9.4 | ~~`GAME OVER — %s wins!`~~ **DONE 2026-09-01** | **`%s won`** / **`You won!`** / **`The duel is a draw`** | `UIStrings.txt:514`; §6.16 | `duel_screen.gd:184,456` |
| 9.5 | ~~`Not a legal choice for '%s'`~~ **DONE 2026-09-01** — with §6.10's premise DISPROVED: the reasons never concatenated (one `goto epilog` per failure), so the 29 are a diagnostic PRIORITY ORDER | **`Illegal target (%s).`** with the 29 reason codes, concatenated | `UIStrings.txt:1145,1150`; §6.10 | `duel_screen.gd:614` |
| 9.6 | ~~`Main phase: play a land or cast spells. Done to go to combat.`~~ **DONE** — `Main phase (before/after combat): cast spells, play land`, dropping `, play land` once the drop is spent (`DuelScreen._status_message`) | the four `@PROMPT_MAIN` variants, which say whether the land drop is still available | `UIStrings.txt:1063`; §6.7 | `duel_screen.gd` `_status_message` |
| 9.7 | ~~`Already chosen — pick a different target`~~ **DONE 2026-09-01** | **`Is a target, can't target again`** (and the rest of the `@CUECARD_SMALLCARD` state words) | `UIStrings.txt:732`; §6.15 | `duel_screen.gd:620` |
| 9.8 | "auto-tap mana" on the wishlist | **`auto-cast`**, with the per-card opt-out **`Don't Auto Tap`** and the term **locked land** | manual p.113, 115; `UIStrings.txt:936` | `docs/duel-screen-design.md §5` |
| 9.9 | ~~"tooltip" in future option text~~ **DONE 2026-09-01** — the Duel Options panel (§6.4) shipped wearing the original's words | **`cue cards`**; and the cards in play are **`small cards`** in option labels | manual p.113 | new Duel Options panel (§6.4) |
| 9.10 | ~~(nothing)~~ **DONE 2026-09-01** — `mini-menu` is in use since §6.12's menus landed | the **`mini-menu`** is the original's name for a right-click context menu; use it in help text and option labels when §6.12 lands | manual p.110 | — |

### Tier 2 — names for things that do not exist yet (free: get them right on arrival)

Every one of these is a to-do elsewhere in this file. Build it under the
original's name and there is nothing to rename later.

| Feature | Build it as | Source | Item |
|---|---|---|---|
| the combat step strip | **Combat Bar** (SEVEN icons — `Duel.hlp`, not the manual's five; it REPLACES the Phase Bar) — BUILT as `CombatBar` | `Duel.hlp` topic *Combat Bar*, manual p.117 | §6.5 |
| the attack lineup window | **Combat window**, titled `Your attack` — BUILT as `CombatWindow` | manual p.126 | §6.5 |
| the per-phase pause marker | **Stop**, set from the Phase Bar mini-menu via **Mark**; skipping forward is **Run to**; ending just this phase is **Go To** — BUILT as `PhaseStops` / `PhaseBar`, except `Go To` (§6.3) | manual p.116-117 | §6.1, §6.3 |
| the settings panel | **Duel Options** (window title) / the **Dueling Options** window (prose) | manual p.113 | §6.4 |
| context help | **Dueling Help** — context-sensitive on the object right-clicked | manual p.14 | §6.20l |
| the opponent's portrait | **Duelist's Face**, reached by **Flip to Face** on the Life Register | manual p.119 | §6.5 |
| the Lich display | **Lich Register** | `Duel.cnt:697` | §6.5 |
| exile | the original's **"out of play" area** in USER TEXT only — keep `Mtg.Zone.EXILE` in code, because "removed from play" reads as "left the battlefield" to a modern player | manual p.118 | — |
| the damage object | **damage marker** — a clickable yellow card, and the thing prevention targets | manual p.119 | §6.20b |
| the pending draw | **potential draw**, labelled `Draw a card` in the hand | manual p.130 | §6.20d |
| hidden continuous effects | **effect cards**, revealed by **Show Invisible Effects** | manual p.112 | §6.3 |
| the instance id display | **ID tags**, toggled by **Show ID Tags** | manual p.112 | §6.3 |
| the Showcase's text toggle | **Expand** | manual p.117 | §6.12 |
| the printed-characteristics view | **Original Type** | manual p.113 | §6.12 |
| the two layouts | **Standard Layout** / **Advanced Layout** | manual p.113 | §6.4 |
| the restore button in the Phase Bar's centre band | **window icon** | manual p.122 | §6.5 |
| the engine, in log lines and refusals | the **referee** — the manual's own word | manual p.112 | — |

### Tier 3 — existing identifiers (proposals; do NOT sweep)

Each is mechanical but touches many call sites, so each wants its own
pass with the suite green either side. None of them touch `engine/`.

| # | Rename | Files | Size |
|---|---|---|---|
| 9.11 | "board half" → **territory**: `_board_half()` → `_territory()`, `_half_rows` → `_territory_rows`, and the comments that say "half" | `duel_screen.gd` (~15 sites) | S |
| 9.12 | `CardPreview` → **`Showcase`**, `_preview_dock` → `_showcase_dock`, `preview` fields on `StackHand`/`CardPile` | `card_preview.gd`, `duel_screen.gd`, `stack_hand.gd`, `card_pile.gd`, `tests/ui/*`, `docs/CODE_MAP.md` | M |
| 9.13 | the message bar → **Situation Bar**: `_prompt_label`/`msg_popup` → `_situation_label`/`_situation_bar` | `duel_screen.gd` (~10 sites) | S |
| 9.14 | `_life_buttons` → **`_life_registers`** | `duel_screen.gd`, `target_arrows.gd` (`player_anchors` doc), `tests/ui/*` | S |
| 9.15 | `_chain_box` → **`_spell_chain`** (the UI's word; `MtgGame.stack` stays `stack`, which is correct CR) | `duel_screen.gd` | S |

**Not proposed, deliberately:** renaming `MtgGame.stack`, `Mtg.Zone.EXILE`,
`Mtg.Step.*`, or the modern type lines. The reasoning is in
`glossary-1997.md §5`.

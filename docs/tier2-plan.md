# Tier 2 — the implementation plan

`docs/duel-todo.md §2` ("Priority two — the duel is hard to READ") lists
fifteen items. This file is the **implementation plan** for them: each one
re-verified against the code as it stands on **2026-08-31**, given a
reference with a citation, a design that names the component doing the
work, a test plan, a place in the order, and its risk.

It does not replace §2. §2 is the *why*; this is the *how*, and where the
two disagree, this file is the later reading — §2 was written on the
twenty-sixth pass and three of its items have moved since (see
[§0.2](#02-corrections-duel-todomd-should-absorb)).

**Labels are unchanged in meaning** (`duel-todo.md` "How to read an item"):

| Tag | Meaning |
|---|---|
| **[1997]** | the original did this; we are reimplementing it |
| **[s30]** | the 30th-anniversary remake added it; the original did not |
| **[QoL]** | ours; neither reference has it |

Citation forms are §2's: `duel.go:NNNN` = `../s30/game/screens/duel/`,
**manual p.N** = printed page of the 1997 MicroProse manual
(`printed = PDF page − 6`), `UIStrings.txt:N` = **`../shandalar-src/Program/`**
(never the top-level Manalink 3 copy), `Duel.hlp` = the shipped help file.

**Our own line numbers are approximate on purpose.** Three agents are
editing `game/duel/` as this is written; `duel_screen.gd` moved ~16 lines
during the survey alone. Every citation below names the **function** as
well, and the function name is the authoritative half.

---

## 0.1 Status — what is already done, part-done, or stale

| # | Item | §2 says | **VERIFIED** | Tag |
|---|---|---|---|---|
| 2.1 | The arrows | DONE | **DONE** — `target_arrows.gd`, 16 tests | [1997] |
| 2.2 | Attacker / blocker LIFT | M, open | **STALE → DROP.** Superseded by the Combat window, which landed today | ~~[s30]~~ |
| 2.3 | Hand and battlefield unsorted | S, open | **DONE (2026-08-31)** — and BOTH tags were wrong: `Arrange Cards` makes the on-demand CONTROL `[1997]`; only the ORDER is s30's. See `docs/duel-todo.md` §2.3 | **[1997]+[s30]** |
| 2.4 | The spell-cast animation | M, open | **OPEN**, but the tag is wrong and the 1997 sources contradict it | [1997]→**[s30]** |
| 2.5 | Ability chooser / X chooser bare | M, open | **PARTLY DONE.** X chooser is an `OriginalDialog`; the ability menu is a themed `PopupMenu` and that is now *correct* | [1997] |
| 2.6 | Pacing is one flat delay | M, open | **OPEN as described** | [s30] |
| 2.7 | Losing life total does not count down | S, open | **OPEN**; no 1997 basis found — re-tier | [s30] |
| 2.8 | No end-of-duel screen | M, open | **DONE** (twenty-eighth pass). One remainder, re-filed to §6.4 | [1997] |
| 2.9 | Creature stats / damage | S, open | **OPEN, but the PREMISE IS WRONG** — the manual settles it in *our* favour, and finds a real defect on the Showcase instead | [1997] |
| 2.10 | Border state machine: 4 states not 9 | M, open | **OPEN**, and there is a better source than s30: the original's own **ten** states, five of which ship as art | [s30]→**[1997]** |
| 2.11 | Missing ability icons | S, open | **OPEN**, minus menace: slot 17 of the 1997 sheet is **blank** | [s30] |
| 2.12 | Land art vs changed basic subtype | S, open | **OPEN as described** | [s30] |
| 2.13 | Rows wrap instead of squeezing | S, open | **OPEN**, half-relieved by the Combat window; and the 1997 answer for the *hand* is the opposite of a squeeze | [s30] |
| 2.14 | Hover-examine: no top-of-stack fallback | S, open | **OPEN**; the 1997 fallback exists and is a different one | [s30] + [1997] |
| 2.15 | No right-click "just look at it" | S, open | **OPEN, and it is [1997]** — manual p.113 | [s30]→**[1997]** |

Net: **two done** (2.1, 2.8), **one part-done** (2.5), **one to drop**
(2.2), **four re-tagged** (2.3, 2.4, 2.10, 2.15), **one premise reversed**
(2.9).

### 0.2 Corrections `docs/duel-todo.md` should absorb

Listed here rather than edited in, because another agent owns that file.

1. **§2.2 — close it as superseded, do not implement.** `combat_window.gd`
   + `DuelScreen._update_combat` / `_combat_lineup` / `_windowed_ids` now
   take every creature in combat *out of its territory* and line it up in
   the 1997 Combat window. Manual **p.126** describes exactly that and
   describes the *only* other attacker cue as highlighting:
   *"Those of your creatures which are able to attack are highlighted."*
   s30 lifts because s30 has no Combat window. The lift would now move
   cards that are not on the board.
2. **§2.3 — the heading says `[1997]`, the summary table (row 5) says
   `[s30]`.** The table is right. No automatic sort exists in the 1997
   game; its equivalent is the on-demand `ARRANGE CARDS`
   (manual p.111, `@MENU_TERRITORY` `Arrange your cards\tDblClk`), which
   *"has no effect on the duel, it just makes things neater."*
3. **§2.4 — re-tag `[1997]` → `[s30]`.** Neither the manual nor `Duel.hlp`
   describes a card flying to the Showcase. `Duel.hlp`, topic **Spell
   Chain**, says the opposite: *"if neither player has the resources to
   interrupt or respond to the spell, the entire process of a spell chain
   may happen so quickly as to be invisible."* The 1997 "signature moment"
   for a cast is the **Spell Chain window** (§6.5/§6.6), not an animation.
4. **§2.5 — half-landed, and the remaining half is smaller than written.**
   The X question is already an `OriginalDialog` on `panel_dark_stone`
   with `@DIALOG_FIREBALL`'s wording; the ability menu is a `PopupMenu`
   *dressed in `OriginalDialog.panel_style`* and opening at the pointer,
   which is right — manual p.113 calls it a **mini-menu** and it opens
   where you right-clicked. What is still missing is the enlarged card
   beside both, digit-key selection, and the engine-side `max_x_value`.
5. **§2.8 — DONE.** `DuelScreen._on_game_over` builds an `OriginalDialog`
   on `panel_end_duel` with `@DIALOG_SHANDALARENDDUEL`'s three lines,
   pinned by `test_the_duels_verdict_is_the_1997_wording`. The remainder
   — `@DIALOG_ENDDUEL` (`UIStrings.txt:527`) `%s next draw:` /
   `Your next draw:`, gated on the Duel Option `See next draws at end of
   duel` (manual p.114) — belongs under §6.4, not §2.
6. **§2.9 — the open question is answered, and the answer is ours.**
   Manual **p.114**: *"The Show Power/Toughness check box determines
   whether or not the **current** power and toughness of each creature is
   displayed on the card in play."* Damage is a **separate** small-card
   state, `Damage: %d` (`@CUECARD_SMALLCARD`, `UIStrings.txt:731`). So the
   original prints live P/T *plus* a damage marker — which is what we do.
   s30's `power/(toughness − damage)` is `[s30]`. The same two pages find
   a *real* defect elsewhere: the Showcase must show **printed** P/T
   (p.114 *"The SHOWCASE always shows the original power and toughness"*;
   p.118 *"changes… are noted on the representation of the card in play,
   not here"*) and `CardPreview` currently shows live P/T.
7. **§2.10 — there is a 1997 source and it beats s30's nine.**
   `@CUECARD_SMALLCARD` (`UIStrings.txt:731`) names **ten** small-card
   states, and manual **p.128** gives the colour code:
   *"Mandatory effects are highlighted in orange, while optional effects
   are in yellow."* Five of the ten ship as **art we have not imported**
   (`Program/CardArt/{Dying,CantTarget,WillUntap,Target,Poison}.pic`).
   §2.10 and §6.15 are the same work and should be merged.
8. **§2.11 — drop menace.** Slot **17** of `Abilities.pic` (22×396, 18
   cells) is a **solid black, empty cell** — verified on both
   `s30/assets/art/card/Abilities.pic.png` and our own
   `assets/original/ability_icons.png`. The 1997 game had no menace icon
   and no menace card. Add **15 regeneration** and **10 protection from
   artifacts** only.
9. **§2.13 — the 1997 answer for the HAND is a revolving scroll, not a
   squeeze.** Manual **p.114**: *"The Hand window has a maximum size. If
   there are too many cards in your hand to display all at once, use the
   scroll arrows at the top to see the rest. This is a 'revolving' scroll…
   the number of cards in your hand is always noted on the top bar."*
   `docs/glossary-1997.md §1` already records this. Our `StackHand`'s ▲/▼
   **collapse and expand** (s30's `handCollapsed`), which is a different
   gesture on the same painted arrows. That is a separate `[1997]` item
   (S, UI) and it also re-frames §3.6.
10. **§2.14 — the 1997 fallback is a different one.** Manual **p.117**:
    *"Whenever the mouse cursor pauses long enough over a card in play, in
    a visible hand, **or even in a graveyard**, that card is displayed
    here. **Cards drawn into your hand are displayed when you draw them.**"*
    Top-of-stack is `[s30]`; draw-into-hand and graveyard-hover are
    `[1997]`.
11. **§2.15 — re-tag `[s30]` → `[1997]`.** Manual **p.113**:
    *"Right-clicking on a card also opens a mini-menu… **Show Full Card**
    displays the card in the Showcase. (When you're using the Advanced
    Layout, this opens a temporary Showcase in which to display the card.
    You can also double-right-click to perform the same function.) You can
    also right-click and hold to bring a card in your hand to the front
    for as long as you hold the mouse button."*
12. **`docs/glossary-1997.md §1` is now stale in three rows** — Combat
    Bar, Combat (window) and the minimised-window icon all say
    *"we have none"*; all three landed today (`combat_bar.gd`,
    `combat_window.gd`, `DuelScreen._window_icon`).

---

## 0.3 The recommended order

Grouped into waves. **A wave is a unit because its items rewrite the same
function** — splitting one means writing that function twice and
re-reviewing the same screenshots twice.

| Wave | Items | Size | Why here |
|---|---|---|---|
| **A** | ~~**2.3** sort~~ → **2.13** squeeze | S | **2.3 LANDED 2026-08-31**, so the wave is down to the squeeze — which now has the stable order it wanted underneath it (`DuelScreen._display_order` / `_hand_order` are the two functions 2.13 rewrites, and both already run before the `PILE_SIZE` slicing). |
| **B** | **2.11** icons → **2.12** land art | S + S | Both are `mini_card.gd` + one `tools/import_original.py` manifest edit. Smallest, safest, and 2.11's manifest work is what Wave C needs. |
| **C** | **2.9** stats + Showcase fix → **2.10** card states | S + M | 2.9 is a two-line correction plus a labelled `[s30]` colour rule; 2.10 is the largest fidelity win in Tier 2 and needs 2.11's import path already extended. Both are `MiniCard.refresh()` / `_apply_style()`. |
| **D** | **2.15** right-click → **2.14** examine fallback | S + S | 2.15 adds the pointer plumbing (`_gui_input` on `MiniCard`, long-press) that 2.14's "nothing under the cursor" path also wants. 2.15 is `[1997]`, so it goes first on the standing rule. |
| **E** | **2.6** pacing | M | Independent, and the only Tier 2 item that changes how a *turn* reads rather than how a *card* reads. Wants Waves A-D landed so the frames it slows down are already the right frames. |
| **F** | **2.5** choosers, remaining half | S (UI) + S (engine) | Wants Wave D, because the missing half is "the enlarged card beside the dialog" and Wave D is where `CardPreview` learns to render somewhere other than its dock. |
| **G** | **2.7** life count-down | S | Pure `[s30]` cosmetic with no 1997 basis. Cheap, pleasant, last. |
| **H** | **2.4** spell-cast animation | M | **Recommend deferring out of Tier 2.** `[s30]`, contradicted by `Duel.hlp`, and the 1997 shape it would compete with (the Spell Chain window's title bar + minimise, §6.5/§6.6) is not built yet. |
| — | **2.2** lift | — | **DROP.** |

**Rationale in one line:** finish the cheap board-readability work first
(A, B), then the fidelity work that the 1997 sources newly unlock (C), then
the input gestures (D), then timing (E-G), and defer the one item the
sources argue against (H).

---

## 2.1 [1997] The arrows — **DONE (2026-08-31)**

`game/duel/target_arrows.gd`, ported from `duel.go:3449-3554`; pinned by
`tests/ui/test_target_arrows.gd` (16 tests) and two staged captures
(`shot_duel_block_arrows`, `shot_duel_stack_arrows`). Recorded in
`docs/duel-screen-design.md`, twenty-sixth pass. Nothing to do.

One follow-on the Combat window created: the red blocker→attacker arrows
now run **between the window's two lanes**, and `_arrows.z_index = 20`
sits above the window's ground (z 10) for exactly that reason. Any wave
that moves cards (A, C) must re-check `shot_duel_block_arrows`.

---

## 2.2 ~~[s30] Attacker / blocker LIFT~~ — **DROP**

### Current state

Nothing lifts, and nothing should. `grep -i lift game/duel/*.gd` returns
only prose. Instead, `DuelScreen._update_combat` (`duel_screen.gd:~1454`)
fills `_windowed_ids` from `_combat_lineup()` and `_rebuild_field`
(`~1607`) skips every id in it — a creature in combat has **left its
territory** for `CombatWindow` (`game/duel/combat_window.gd`), attackers in
the top lane, blockers in the bottom.

### The reference — and why it kills the item

- Manual **p.126**: *"Those of your creatures which are able to attack are
  **highlighted**. Just click on any of your available creatures to add it
  to the lineup… As soon as you add the first creature to the attack, the
  Combat window opens. Your attackers line up on your side, and the space
  on the other side is reserved for (potential) blockers."*
- Manual **p.126-127** for blocking: *"All the attacking creatures are
  shown in the Combat window. To make one of your creatures a blocker,
  click on it."*
- Manalink even has a patch whose whole purpose is to send creatures that
  stopped attacking *back* to the territory
  (`shandalar-src/src/patches/patch_not_in_combat_window_if_no_longer_attacking.pl`)
  — which only makes sense if the window normally removes them.

The 1997 game therefore has **two** attacker cues: a highlight (→ 2.10)
and the window (→ done). It has no lift. s30's lift
(`duel.go:69-72`, `684-776`, hit-test at `1589-1617`) exists because s30
keeps combatants on the board; porting it now would animate a 20px slide
on cards that are no longer there.

### If it is ever revived

The spec is captured for the record, since it was researched: linear (no
easing) 20px over 150ms; `startAttackerLift` re-seeds `from` with the
*current interpolated* value so a mid-flight toggle never jumps
(`duel_attacker_lift_test.go:65-84` pins `from == offsetAtMid` exactly);
yours −20, theirs +20, both toward the centre line; End of Combat freezes
existing lifts; the hit test must add `round(attackerLiftY)` before the
band test (`duel_attacker_lift_test.go:171-188` pins a click in the bottom
2px of the *lifted* rect).

### Risk of dropping

None. Recommend §2.2 is struck through in `duel-todo.md` with a pointer to
the Combat window, exactly as §2.1 is.

---

## 2.3 [s30] Hand and battlefield are unsorted — **DONE (2026-08-31)**

**SUPERSEDED BY THE BUILD, and §0.2 item 2 was half wrong.** The plan
below said the summary table's `[s30]` was right because "no automatic
sort exists in the 1997 game". True, but incomplete: the original's
on-demand `ARRANGE CARDS` (`@MENU_TERRITORY` 15-16, `Duel.hlp` topic
**Territory**) is exactly the control the owner asked for, so the CONTROL
is `[1997]` and only the ORDER is `[s30]`. What shipped is
`game/duel/board_order.gd` + `game/duel/arrange_button.gd` as a per-
territory TOGGLE in `_qol_reserve`, with the design below otherwise
intact — including the sort-before-slicing rule and the live-P/T
correction. See `docs/duel-todo.md` §2.3 and the thirty-seventh pass of
`docs/duel-screen-design.md`.

### Current state (verified)

- Hand: `DuelScreen._rebuild_hand` (`duel_screen.gd:~1696`) —
  `for inst in game.players[pid].hand:` … engine order.
- Battlefield: `DuelScreen._rebuild_field` (`~1625`) —
  `for inst in game.players[pid].battlefield:` … insertion order, then
  chunked into `CardPile`s of `PILE_SIZE = 5`.
- `grep -in sort game/duel/*.gd` → **nothing**. No comparator exists
  anywhere in the presentation layer.

### The reference

**[s30]** — three orders, `duel.go:1438-1544`:

| Order | Keys, in order | Site |
|---|---|---|
| **Hand** | 1. lands before spells · 2. **if both lands, name only, stop** · 3. colour rank asc · 4. mana value asc · 5. name asc | `cardSortKey` / `lessCardSortKey` `:1479-1520`, `handDisplayOrder` `:1524-1539` |
| **Creatures** | power **desc** · toughness **desc** · name asc | `fieldPerms` `:1466-1474` |
| **Lands** | name asc · **untapped before tapped** | `fieldPerms` `:1452-1464` |
| **Other permanents** | *no sort at all* — insertion order | `:1438-1477` |

Colour rank (`manaCostColorRank`, `:1508-1520`, over
`mage-go/pkg/mage/core/color.go:8-16`): **W=1, U=2, B=3, R=4, G=5,
multicolour=6, colourless=7**. Dispatch is on `len(colors)`: 1 → the
colour's own enum value; >1 → 6; 0 → 7. `{X}` contributes 0 to mana value,
so Fireball sorts as a red 1-drop.

Filters that come *before* the sort: skip `AttachedTo != nil` (auras render
on their host) and **creature wins over land** for row assignment
(`permRowFor`, `:1382-1390`), so Mishra's Factory animated is in the
creature row. We already do both (`inst.attached_to != -1`,
`inst.is_creature()`).

**[1997]** — there is no automatic sort. The original's equivalent is a
command: `ARRANGE CARDS` on the territory mini-menu, *"straightens up the
cards in play in the territory where you right-clicked. This has no effect
on the duel, it just makes things neater. (You can also double-click on a
territory to do this.)"* (manual **p.111**; `@MENU_TERRITORY`,
`UIStrings.txt:908`, `Arrange your cards\tDblClk` /
`Arrange opponent's cards\tDblClk`).

The 1998 strategy guide argues for it from the other side: *"in each phase
I go from left to right and evaluate each card on the board"* (guide
p.106) is only a routine if the board has a stable left-to-right order.

### The design

- New file **`game/duel/board_order.gd`** — `class_name BoardOrder`, a
  pure `RefCounted` of static comparators, so it is unit-testable without
  a scene and reusable by the future territory mini-menu:
  - `static func hand(cards: Array) -> Array`
  - `static func creatures(cards: Array) -> Array`
  - `static func lands(cards: Array) -> Array`
  - `static func color_rank(data: CardData) -> int` (W=1…G=5, gold=6,
    colourless=7 — read `data.color_mask()`, not `cur_colors`: this is a
    *hand* order and a card in hand has no live characteristics)
  - Every function **returns a new Array** and must not mutate its input.
    s30 pins that contractually (`duel_card_sort_test.go:106-115`).
- `_rebuild_hand` and `_rebuild_field` call it. **The sorted array is the
  only thing either function iterates** — that is the whole
  index-drift defence, and ours is structurally safer than s30's because
  we do not hit-test by index at all: every `MiniCard` binds its own
  `CardInstance` (`w.pressed.connect(_on_card_clicked.bind(inst))`,
  `_make_widget`). Nothing to keep in sync; just do not add an
  index-keyed path.
- **Lands and other permanents are chunked into `CardPile`s afterwards**,
  so the sort must run *before* the `PILE_SIZE` slicing or the piles will
  re-shuffle their membership as cards tap.
- Read **live** characteristics for the board orders (`cur_power`,
  `cur_toughness`) per CONTRIBUTING.md rule 5 — s30 reads its snapshot's base
  power, which is its own bug, not a spec.
- **Untapped-before-tapped means the pile order changes when you tap.**
  That is s30's stated intent ("so tapping visibly walks the group") and
  it is also what makes the animated tap turn (`TAP_TURN_SECONDS`,
  `_tapped_seen`) re-parent mid-tween. See Risk.

### Test plan

`tests/unit/test_board_order.gd` (new, engine-pure — `BoardOrder` is
`RefCounted`, so it belongs in `unit/`, not `ui/`):

1. `test_hand_puts_lands_first_then_colour_then_cost` — golden order over
   a mixed hand, s30's own fixture:
   `Bayou, Forest, Plains, Healing Salve, Counterspell, Fireball,
   Lightning Bolt, Shock, Vindicate, Sol Ring`
   (`duel_card_sort_test.go:70-104` — substitute pool cards for
   Vindicate).
2. `test_two_lands_sort_by_name_only` — the early-stop branch: a land
   never consults colour rank or mana value.
3. `test_colour_rank_is_wubrg_then_gold_then_colourless` — all seven.
4. `test_sorting_does_not_mutate_the_input`.
5. `test_creatures_sort_by_power_then_toughness_descending` — golden
   including a 0/8 wall last despite the big toughness.
6. `test_creature_order_reads_live_power` — a Crusade'd 2/2 outranks a
   printed 3/3. **This is the one s30 gets wrong; pin it.**
7. `test_lands_sort_by_name_then_untapped_first`.

`tests/ui/test_duel_screen.gd`:

8. `test_the_hand_renders_in_display_order` — build a known hand, read the
   `MiniCard` children's `instance.data.card_name` in tree order.
9. `test_clicking_a_sorted_card_casts_that_card` — the anti-drift pin:
   put two castable spells in hand in reverse display order, click the
   *second widget*, assert the *second displayed* card went on the stack.

### Order and dependencies

**Wave A, first.** Nothing depends on it; 2.13 depends on it landing first
(a squeezed row must squeeze a stable order).

### Risk

- **Pile membership churn.** Lands re-sort on every tap, and `_rebuild_field`
  slices them into `PILE_SIZE` chunks *after* sorting, so tapping a land
  can move a different land into a different pile. Mitigation: sort, then
  chunk, and accept it — it is the reference's behaviour. Verify on
  `shot_duel` with ≥6 lands, half tapped.
- **The tap tween.** `_make_widget` animates a tap once per instance id via
  `_tapped_seen`. Re-ordering rebuilds the widget in a new position while
  the tween runs; the tween is on the widget, which is freed, so the
  animation is simply lost for that frame. Acceptable; note it if it reads
  badly.
- **Immediate-mode hazard.** `CardPile.populate` calls `queue_free()`
  without removing first (`docs/duel-screen-design.md`, twenty-sixth pass
  CAVEAT). Any new code that caches a widget across a refresh must copy
  `TargetArrows._collect`'s `is_queued_for_deletion()` skip and
  `_resolve`'s `is_instance_valid` check **before** the typed assignment.
- **Screenshot check:** `shot_duel`, `shot_hand_mixed`,
  `shot_duel_block_arrows`. The tour must print **zero SCRIPT ERRORs**.

---

## 2.4 [s30] The spell-cast animation — M — UI — **defer out of Tier 2**

*(§2 tags this `[1997]`; that is wrong — see §0.2 item 3)*

### Current state (verified)

No animation of any kind on cast. `DuelScreen._rebuild_stack` draws the
spell chain at the board's left on every `state_changed` — since the
forty-second pass as full `MiniCard`s under the original's own caption;
the card simply appears there and later appears on the battlefield or in
the graveyard.

### The reference

**[s30]** — `duel_spell_animation.go` (291 lines), an exact spec:

- Constants (`:17-22`): move **300ms**, hold **200ms**, magnifier rect
  **245×342** at `(cardPreviewX=0, cardPreviewY=188)`. Minimum total life
  **800ms**.
- Both tweens `ease.OutCubic` (`f(p) = 1 − (1−p)³`); position **and** size
  interpolate independently (`interpolateSpellBounds`, `:102-109`).
- Three phases (`frame`, `:66-91`): fly in → hold on the magnifier → fly
  out. `resolve()` (`:60-64`) clamps `resolvedAt = max(now, startedAt +
  300ms + 200ms)`, so the hold is guaranteed even if the spell resolves
  instantly. `complete` is produced **only** by the exit tween.
- Source rect (`:162-193`): the controller's hand panel origin plus
  `index * handCardOverlap(20)` for that card's index in
  `handDisplayOrder` — i.e. it depends on **2.3**.
- Destination (`:195-248`): the new battlefield slot from the *same*
  `getFieldCardPos` the board uses; an attached aura at `host.Y − 14`;
  else a graveyard rect. Falls back to the controller's graveyard.
- `spellIsAnimating(id)` (`:250-253`) makes `drawBattlefield` skip the
  permanent (`duel.go:3219-3221`) and `drawGraveyard` fall through to the
  card *underneath* (`duel.go:3679-3686`) — so it is never drawn twice.
- Abilities never animate (`syncSpellAnimations`, `:118-147`;
  `duel_spell_animation_test.go:140-150` pins zero animations for
  `IsAbility`).

**[1997]** — the sources describe no such thing, and one of them argues
against it. `Duel.hlp`, topic **Spell Chain**: *"if neither player has the
resources to interrupt or respond to the spell, the entire process of a
spell chain may happen so quickly as to be invisible."* Manual p.121-123
describes the **Spell Chain window** — a titled, minimisable window
(`@WINDOWTITLES` `Spell Chain`, `@MENU_SPELLCHAIN`, `UIStrings.txt:155,853`)
with callouts `Original Spell` / `Spell's Target` / `Interrupt` /
`Interrupt's Target` — as the whole of what a cast looks like.

### Recommendation

**Defer.** Two reasons, both fixable, neither today:

1. It is `[s30]` in a tier the owner is running as a
   complete-*reimplementation* pass. The 1997 shape it competes with —
   the Spell Chain window's own title bar and minimise, and the
   `Trying to cast %s` → `Cast %s` status transition
   (`@PROMPT_CHECKFEPHASE`, `UIStrings.txt:1024`; §6.6) — is not built.
2. It hard-depends on **2.6** (an 800ms animation inside a 350ms flat
   pace is invisible) and on **2.3** (the source rect is a hand index).

If it is built anyway, build it **after** Wave E, as
`game/duel/spell_flight.gd` (a `Control` that owns its own `Tween`s and
draws `MiniCard`-sourced textures), with `DuelScreen._rebuild_stack` and
`_rebuild_field` consulting `is_animating(id)` exactly as s30 does. Its
destination resolution wants `_make_widget`'s output rect, which is only
known after `_refresh` — resolve at draw time as `TargetArrows` does.

### Test plan (if built)

`tests/ui/test_spell_flight.gd`: the four geometry pins from
`duel_spell_animation_test.go` (start = source rect exactly; `+300ms` =
magnifier exactly; ease-out midpoint strictly past the linear midpoint;
`resolve` at `+50ms` yields `resolvedAt == start + 500ms`), plus
`test_an_ability_never_flies` and
`test_the_permanent_is_not_drawn_twice_while_it_flies`.

---

## 2.5 [1997] The ability chooser and the X chooser — **PARTLY DONE** — S — UI + S — engine

### Current state (verified)

| | Then (§2) | Now |
|---|---|---|
| X chooser | `AcceptDialog` + `SpinBox` | **`OriginalDialog`** on `panel_dark_stone`, 392×208, `@DIALOG_FIREBALL`'s own words *"Generic mana to put into the spell:"* + `(max: %d)`, `OriginalDialog.field()` (the bevel run backwards), `OK`/`Cancel` from `@DIALOGBUTTONS` (`_open_x_dialog`, `duel_screen.gd:~1171`). Pinned by `test_the_x_question_opens_as_an_original_dialog`. |
| Ability chooser | `PopupMenu` at the mouse | still a `PopupMenu`, but **dressed**: `OriginalDialog.panel_style("panel_dark_stone", 6.0)`, `OriginalDialog.CHOICE`/`CHOICE_LIT`, `GameSkin.font("font_body")` at 14 (`_build_ui`, `~2084`). It reads the **live** ability lists (`cur_mana_abilities` / `cur_activated_abilities`), fixed by the 2026-09 audit and pinned by `test_the_ability_menu_lists_live_abilities`. |
| X bound | wrong on `{X}{X}` | correct — multiplies by `cost.x_count` (`~1182`), pinned by `test_the_x_bound_charges_x_count_per_point`; and an ability's X is asked for at all, pinned by `test_an_ability_with_x_in_its_cost_asks_for_x`. |

**The `PopupMenu` at the pointer is now the *right* answer, not a
shortcut.** Manual **p.113**: *"Right-clicking on a card also opens a
**mini-menu**"*, and `@MENU_SMALLCARD` (`UIStrings.txt:936`) is that menu.
A mini-menu opens where you clicked; s30's centred full-screen chooser is
`[s30]`. Do **not** move it to the centre.

### What is actually left

1. **[1997] The enlarged card beside the question.** The reference's own
   Primal Clay screen (design doc §3b) shows the card next to the choice
   lines, and `_open_mode_menu` (`~892`) already does exactly that for
   modal spells. The X dialog should do the same; the ability mini-menu
   should instead **feed the Showcase** — hovering a menu row previews
   that ability's source, which is what the original's mini-menu does by
   virtue of the card already being under the cursor. S, UI.
2. **[s30] Digit keys 1-9 / 0-9.** `duel_ability_chooser.go:57-63`
   (`Key1 + i`, `i < 9`) and `duel_xspell.go:61-68` (`Key0 + i`, `i <= 9`,
   so X > 9 stays mouse-only). Cheap, no 1997 evidence either way, label
   it. S, UI.
3. **[QoL] Move the X bound into the engine.** Ours re-derives it in the
   UI by probing `pool.can_pay` in a loop (`~1184`); the bound has already
   been wrong once (twenty-fifth pass). mage-go's answer is
   `Game.MaxXValue(playerID, mc, ctx)`
   (`mage-go/pkg/mage/game.go:4642-4698`): compute an upper bound from
   pool + every untapped source's max output, then **binary search** X
   with the real mana solver. Ours should be
   `MtgGame.max_x_value(pid, cost, surcharge) -> int`, sitting beside
   `can_afford`, folding cost modifiers and restricted mana the same way,
   and returning 0 when `not cost.has_x`. S, engine.
   - Warning from the reference: mage-go **overloads** the same
     `MaxXValue` field for combat-damage assignment
     (`interactive/game_helpers.go:154-161`, `MaxXValue: totalPower`).
     Do not copy that; keep ours a single-purpose helper.

### The design

- `_open_x_dialog` grows a `CardPreview` in an `HBoxContainer` beside the
  question — reuse `_open_mode_menu`'s construction verbatim, which is why
  this waits for **Wave D** (where `CardPreview` learns an undocked mode
  that does not fight the sidebar dock).
- Digit keys: `_x_dialog` and `_ability_menu` both need
  `_unhandled_key_input` routing. `PopupMenu` already handles `1`-`9` if
  the items are given `shortcut`s — prefer that to a custom handler.
- The engine helper is a `MtgGame` public method; the UI replaces its
  `while pool.can_pay(...)` loop with one call. **Both must ship together**
  or the dialog silently keeps the old bound.

### Test plan

- `tests/unit/test_engine_additions.gd`: `test_max_x_value_counts_x_count`
  ({X}{X} with 6 available → 3), `test_max_x_value_folds_cost_modifiers`
  (Gloom's tax lowers it), `test_max_x_value_is_zero_without_x`,
  `test_max_x_value_spends_restricted_mana` (Mishra's Workshop pays a
  Fireball's generic? — assert the engine's actual rule, do not guess).
- `tests/ui/test_duel_screen.gd`:
  `test_the_x_dialog_bound_comes_from_the_engine` (stub the engine value,
  assert the spin's `max_value`), `test_the_x_dialog_shows_the_card`,
  `test_digit_keys_pick_an_ability`.

### Order and dependencies

**Wave F**, after Wave D. The engine half (item 3) has no dependency and
can land any time — it is the one piece an engine-side agent could take.

### Risk

Low. The one trap: `_on_x_confirmed` rebuilds the target slots with the
chosen X (`~1228`) because counts depend on X — any change to the dialog
must keep that call or "Untap X target lands" silently sizes from zero
again (twenty-fifth pass).

---

## 2.6 [s30] Pacing is one flat delay, not per-event dwell — M — UI

### Current state (verified)

`DuelConfig.pace = 0.35` (`duel_config.gd:18`), fed from
`Settings.ai_pace()` (default 0.35) and overridden to 0.8 for the
AI-vs-AI demo. `DuelScreen._maybe_schedule_ai` (`~1115`) starts a
one-shot `SceneTreeTimer` of `config.pace` before every AI action;
`_ai_step` calls `act()` then `_refresh()`. That is the *only* pacing in
the screen — every other `state_changed` renders immediately.

Consequence: an AI turn that draws, plays a land, casts three spells and
attacks renders as five frames 350ms apart regardless of what happened,
and a lethal Fireball reads exactly like a Mox.

### The reference

**[s30]** — a per-message dwell, `duel.go:497-611`:

- Constants (`:55-61`): `phaseDisplayDelay = 100ms`,
  `enemyPhaseDelay = 300ms`, `lifeChangeDelay = 600ms`.
- `phaseDelay(prev, cur)` (`:555-574`): start at 100ms;
  `max(…, 300ms)` when the active player is not you; `max(…, 600ms)` when
  **any** of — either life total changed, any *pre-existing* permanent's
  marked damage changed, or a **new** log line contains both `" deals "`
  and `" damage to "` (spaces included).
- The diff detectors (`:576-611`): `permanentDamageChanged` builds a
  `id → damage` map from *both* of prev's battlefields and only compares
  permanents that already existed — a permanent that just entered never
  triggers. `newDamageLog` scans only `cur[len(prev):]`.
- `drainMessages` (`:497-514`) takes **at most one** message per frame and
  only once `time.Since(lastMsgTime) >= nextMsgDelay`. The dwell is
  computed from the message *just shown*, i.e. it is how long that message
  will stay up (`applyGameMsg`, `:516-536`).
- `drainQueuedMessages` (`:538-556`) drains with **no** dwell, used when a
  modal choice must show the live step (pinned by
  `duel_pacing_test.go:92-131`).

**[1997]** — no direct evidence for a dwell, and one line against a
*universal* one: `Duel.hlp`, **Spell Chain**, *"the entire process of a
spell chain may happen so quickly as to be invisible"*. What the original
*does* have is `@PROMPT_STILLTHINKING` (`UIStrings.txt:954`)
`Still thinking...` — already wired in `_status_message` — i.e. it tells
you it is busy rather than slowing down. Treat the dwell as `[s30]`.

### The design

Our architecture is different in one load-bearing way: **s30 consumes a
message queue; we render synchronously off `state_changed`.** Do not build
a queue. Instead:

- New file **`game/duel/duel_pacing.gd`** — `class_name DuelPacing`,
  `RefCounted`, pure: it holds the previous snapshot (life totals, an
  `id → damage` dictionary, `log_lines.size()`) and answers
  `next_delay(game) -> float`. Everything s30 puts in `phaseDelay` and the
  two diff detectors goes here, and **it is unit-testable without a
  scene**, which is the whole point.
- `DuelScreen` calls `_pacing.next_delay(game)` in `_maybe_schedule_ai`
  instead of reading `config.pace`, and calls `_pacing.observe(game)` at
  the end of `_refresh`.
- **`config.pace` becomes the multiplier, not the value.** Keep the
  Options slider meaningful: `delay = base_delay * (config.pace / 0.35)`,
  or more simply scale the three constants by `config.pace / 0.35`. The
  AI-vs-AI demo's 0.8 then still slows everything proportionally.
- Log matching must use **our** log's wording, not s30's. Check
  `MtgGame.deal_damage`'s log line before hard-coding `" deals "` /
  `" damage to "` — if ours differs, prefer the structural detectors
  (life change, marked-damage change) and drop the string match, which is
  the fragile third of s30's rule anyway.
- Keep the "modal choice sees the live state" escape: any path that opens
  an `OriginalDialog` must bypass the dwell (we have no queue, so this is
  free — just do not gate `_refresh` itself, only the AI scheduler).

### Test plan

`tests/unit/test_duel_pacing.gd` — s30's own seven cases
(`duel_pacing_test.go:22-90`), against our `MtgGame`:

1. player's turn, nothing changed → base.
2. opponent is the active player → the enemy delay.
3. your life dropped → the life delay, even on the opponent's turn.
4. opponent's life dropped on your turn → the life delay.
5. a permanent's marked damage went 0 → 1 → the life delay.
6. a permanent that *just entered* with damage → base (the
   already-existed rule).
7. first call with no previous snapshot → base.

`tests/ui/test_duel_screen.gd`:
8. `test_the_ai_timer_uses_the_paced_delay` — assert the scheduled
   timer's `time_left` bucket, not a wall-clock sleep.

### Order and dependencies

**Wave E.** Depends on nothing mechanically, but wants A-D landed so it is
slowing down frames that already look right. **2.4 depends on it.**

### Risk

- **The biggest functional risk in Tier 2 after 2.10.** `_maybe_schedule_ai`
  is guarded by `_ai_pending` and `_toss_active` and is re-entered from
  `_refresh`, which `_ai_step` calls. A longer, variable delay widens
  every window in that loop. Pin `test_full_fast_forwarded_turns_do_not_crash`
  and `test_pass_and_fast_forward_advance_the_game` before and after.
- **Headless.** The UI suite and the Deck Lab must not get slower. Gate on
  `DisplayServer.get_name() == "headless"` exactly as `_on_game_over` and
  `_run_coin_toss` already do, or the ~12s suite grows minutes.
- **`_on_pass_turn`'s 60-iteration fast-forward** runs the engine in a
  tight loop with no frames between; it must not start consulting the
  pacer or it will stall.

---

## 2.7 [s30] The losing life total does not count down — S — UI

### Current state (verified)

`DuelScreen._on_game_over` (`duel_screen.gd:~217`) sets the verdict, mutes
the music, plays win/lose, and opens the end-of-duel `OriginalDialog`
immediately. Life numerals are written straight from `players[pid].life`
in `_refresh` (`~1320`). Nothing interpolates.

*(§2's `duel_screen.gd:183-188` is stale — the function moved when the
end-of-duel window landed.)*

### The reference

**[s30]** — `duel.go:613-682`, `1218-1234`:

- `lossLifeAnimationDuration = 900ms`, `lossLifeHoldDuration = 500ms`
  (`:63-66`); complete at **1400ms** total (`:677-682`).
- `startLossAnimationFromMessage` (`:613-629`) fires only on `GameOver`,
  and only for a side whose life is `<= 0`; it prefers the **previous**
  message's life as the `from` value. On a win only the opponent's counter
  runs (`duel_loss_animation_test.go:84-113`).
- `start` is **idempotent** (`:631-639`): `if a.started { return }` — a
  second call keeps the original `from`/`to`/`startedAt`.
- Interpolation is **linear** (`:657-671`), rounded to an int.
- The gate (`:1218-1234`): quest payout runs immediately, but the *screen
  transition* returns `DuelScr` until `lossAnimationComplete(now)`.
  `autoPlay` skips the wait entirely.

**[1997]** — none. Manual **p.119**: the Life Registers *"simply note how
much life each duelist has at the moment. Whenever one (or both) of these
is zero or less at the end of a phase or the end of combat, the duel is
over."* That end-of-phase check is already a shipped rules fork
(`RulesOptions` `life_checked_at_phase_end`, in `IMPLEMENTED`).

### The design

- `DuelScreen` grows two `Tween`s driving the two `_life_buttons[pid].text`
  values, started from `_on_game_over` before the dialog is built:
  `tween_method(func(v: float) -> void: _life_buttons[pid].text = str(roundi(v)), from, to, 0.9)`.
- The end-of-duel `OriginalDialog` is deferred by `0.9 + 0.5 = 1.4s`
  (`get_tree().create_timer(1.4)`), which is our equivalent of s30's
  "refuses to leave the duel". Do **not** defer `_pass_button.disabled` or
  the sfx — those are the immediate half.
- Idempotency: a `_loss_tween_started` flag, or simply check
  `_over_dialog == null` (the function already guards on it).
- **Skip in headless** — `_on_game_over` already returns early there.
- `from` is "life before the killing blow". We do not keep a previous
  snapshot… except that **2.6's `DuelPacing` does**. Build 2.7 after 2.6
  and read `_pacing.previous_life(pid)`; before 2.6, cache the last
  non-negative life in `_refresh`.

### Test plan

`tests/ui/test_duel_screen.gd`:
1. `test_the_dying_life_total_counts_down_from_its_previous_value` —
   drive `adjust_life` to a lethal value, assert the numeral still reads
   the old value on the frame the game ends and the final value after the
   tween.
2. `test_the_countdown_never_restarts` — call `_on_game_over` twice,
   assert one tween.
3. `test_only_the_dying_seat_counts_down`.
4. `test_headless_skips_the_countdown` — the existing headless guard.

### Order and dependencies

**Wave G**, after 2.6 (for the previous-life snapshot). Nothing depends on
it.

### Risk

Low, with one real trap: **the deferred dialog must not race the screen
being freed.** If the duel is exited (or the scene reloaded) inside the
1.4s window the timer fires on a dead node. Use
`get_tree().create_timer(1.4).timeout.connect(cb, CONNECT_ONE_SHOT)` and
have `cb` check `is_inside_tree()`.

Given it has **no 1997 basis at all**, this is a reasonable candidate to
re-tier to the QoL wishlist if Tier 2 needs shortening.

---

## 2.8 [1997] The end-of-duel screen — **DONE (2026-08-31)**

`DuelScreen._on_game_over` / `_on_game_over_dismissed`
(`duel_screen.gd:~217-243`): an `OriginalDialog` on **`panel_end_duel`**
(`Winbk_Endduel`, the only **inset** bevel in the 1997 set — the verdict
is carved in, not raised), 272×300, carrying
`@DIALOG_SHANDALARENDDUEL`'s exact three lines (`UIStrings.txt:514`) —
`You won!` / `%s won` / `The duel is a draw` — both seats' final life, and
`OK` from `@DIALOGBUTTONS`. Pinned by
`test_the_duels_verdict_is_the_1997_wording` and
`test_every_centre_popup_wears_the_shared_chrome`; captured as
`shot_dialog_end_duel`.

**Two remainders, neither a §2 item:**

1. **`@DIALOG_ENDDUEL` (`UIStrings.txt:527`)** = `%s next draw:` /
   `Your next draw:` — the end screen shows the card each player *would*
   have drawn, gated on the Duel Option `See next draws at end of duel`
   (checked by default; manual **p.114**, *"Some players like to know."*).
   S, UI. Belongs under **§6.4** (the Duel Options panel) because it is
   meaningless without the switch.
2. **Draws.** `MtgGame` has `draw_game` / `is_draw` (CR 104.4) but
   `game_ended(winner_id)` carries a single id, so `The duel is a draw`
   can never be shown. S, both. Already filed as **§6.16**.

---

## 2.9 [1997] Creature stats and damage — S — UI — **premise reversed**

### Current state (verified)

- `MiniCard.refresh` (`mini_card.gd:337`):
  `_pt_label.text = "%d/%d" % [instance.cur_power, instance.cur_toughness]`
  — live P/T, no colour, white with a shadow.
- Damage: the original's **`Damage.pic` dagger** plus the number
  (`mini_card.gd:~354-358`, `damage_marker_texture()` →
  `masked_sprite("damage_marker")`), shown only on the battlefield and
  only while `instance.damage > 0`. Landed in the twenty-first pass.
- `CardPreview._pt_text` (`card_preview.gd:305`):
  `"%d/%d" % [inst.cur_power, inst.cur_toughness]` for battlefield cards,
  printed for hand cards.

### The reference — the manual settles the open question, against s30

- Manual **p.114**, on the Duel Options check boxes: *"The **Show
  Power/Toughness** check box determines whether or not the **current**
  power and toughness of each creature is displayed on the card in play.
  (The SHOWCASE always shows the **original** power and toughness.)"*
- `@CUECARD_SMALLCARD` (`UIStrings.txt:731`) lists **`Damage: %d`** as its
  own small-card state, separate from P/T.
- Manual **p.118**: *"Note that the Showcase always displays the original
  card text. Any changes made to a card after it was put into play —
  modifications to the power, toughness, color, or what have you — are
  noted on the representation of the card **in play, not here**."*
- Manual **p.119** confirms `Damage.pic` is *not* the whole story: a
  **Damage Marker** is *"a yellow 'card' on or near the target of that
  damage… These markers are necessary during damage-prevention steps,
  because you often must choose which damage to target for prevention (or
  redirection). To select damage in this way, simply click on the
  appropriate damage marker."* That object is §6.8/§1.9 work, not this
  item; the dagger is the `Damage: %d` state.

So: **the original prints live P/T *and* a separate damage marker.** That
is exactly what we do. s30's `power/(toughness − damage)` — floored at
zero, `displayedCreatureStats`, `duel.go:3430-3432`, pinned by
`duel_stats_test.go:10-26` (`3/4` with 2 damage → `"3/2"`; `1/1` with 3
damage → `"1/0"`, never `-2`) — is **`[s30]`** and should not be adopted:
it would double-count against the dagger we already draw.

What *is* worth taking from s30 is the **colour**, `duel.go:3402-3416`
and `3780-3786`, compared against the **printed** card:

| condition | RGBA |
|---|---|
| `power > printed.power or toughness > printed.toughness` | `(100,255,100)` green |
| `power < printed.power or toughness < printed.toughness` | `(255,100,100)` red |
| else | white |

Note it is an **OR across both stats and pumped is tested first**, so a
+2/−2 reads as pumped/green. Colour is *not* pinned by s30's tests.

### The design

Three changes, all small:

1. **[1997] FIX — the Showcase shows PRINTED P/T.** `card_preview.gd:305`
   currently returns live values for a battlefield card. Per p.114/p.118
   it must return `inst.data.power`/`toughness` always, keeping the
   existing `*/*` quirk for a printed 0/0 with statics (fifteenth pass).
   **This is a fidelity defect, not a feature** — it is the reason 2.9 is
   worth doing at all.
2. **[s30] ADD — pump colouring on the small card.** In
   `MiniCard.refresh`, after setting `_pt_label.text`, set
   `font_color` from the three-way rule above, comparing
   `instance.cur_power/cur_toughness` against `instance.data.power/toughness`.
   Guard on `instance.zone == Mtg.Zone.BATTLEFIELD` — a hand card has no
   live values to differ.
3. **[1997] KEEP — the dagger.** No change. Add a `Damage: %d` tooltip on
   the marker (`@CUECARD_SMALLCARD`), which is free and is §6.15's
   vocabulary.

Also settle the alignment while the file is open: s30 right-aligns the
stats at `card.right − ceil(textWidth) − 3`, bottom at
`card.bottom − 22` (`creatureStatsTextPosition`, `duel.go:3418-3423`);
ours is anchor-driven. Leave ours — the twelfth pass measured it against
the owner's screenshot and that measurement wins over s30's constants.

### Test plan

`tests/ui/test_stack_hand.gd` (where the other `MiniCard` pins live) or a
new `tests/ui/test_mini_card.gd`:

1. `test_the_showcase_shows_printed_power_and_toughness` — a Crusade'd 2/2
   Savannah Lions: the `MiniCard` reads `3/2`, the `CardPreview` reads
   `2/1`. **The 1997 pin.**
2. `test_a_pumped_creature_letters_its_stats_green`.
3. `test_a_weakened_creature_letters_its_stats_red` (Weakness).
4. `test_an_unmodified_creature_letters_its_stats_white`.
5. `test_a_plus_two_minus_two_reads_as_pumped` — the OR-and-pumped-first
   rule, made explicit so nobody "fixes" it later.
6. `test_damage_does_not_change_the_printed_toughness` — 3/4 with 2
   damage still reads `3/4` **plus** a visible dagger and `2`. **The
   anti-s30 pin: this is the one that stops someone porting
   `displayedCreatureStats` by mistake.**

### Order and dependencies

**Wave C, first.** Independent of everything; do it before 2.10 because
both touch `MiniCard.refresh`/`_apply_style` and 2.10 is much larger.

### Risk

Very low. One caveat: comparing against `data.power` for a **token** or a
copy (`become_copy` repoints `CardInstance.data`, CR 707) is correct by
construction — `data` *is* the printed card after a copy. Do not cache
the printed values.

---

## 2.10 [1997] The small-card state machine — M — UI

*(§2 tags this `[s30]` and frames it as "four states, not nine". There is a
1997 source, it names **ten**, and five of them ship as art — see §0.2
item 7. §2.10 and **§6.15** are the same work; merge them.)*

### Current state (verified)

`MiniCard` has **four** states —
`enum Highlight { NONE, CASTABLE, TARGET, SELECTED }` (`mini_card.gd:22`)
— painted as a border colour and width in `_apply_style`
(`~504`: `border_color = HIGHLIGHT_COLORS[_highlight]`, width 3 when not
`NONE`, else 1) plus a lightened frame modulate (`~492`). Colours
(`~90-95`): castable `(0.35,0.85,0.35)` green, target `(0.95,0.80,0.25)`
amber, selected `(0.95,0.45,0.15)` orange.

`DuelScreen._highlight_for` (`~1765`) maps mode → state: in TARGETING,
already-chosen → SELECTED, legal → TARGET; in ATTACKERS, chosen →
SELECTED, legal attacker → CASTABLE; in BLOCKERS, assigned/selected →
SELECTED, an attacker → TARGET; in NORMAL, an affordable hand card →
CASTABLE (via `game.can_afford`, plus the land-drop conditions).

Separately, `MiniCard` already draws two **overlays**: the summoning-
sickness spiral (`Summon.pic`, `masked_sprite`) and the damage dagger
(`Damage.pic`).

### The reference

**[1997], and it is the better source.** `@CUECARD_SMALLCARD`
(`UIStrings.txt:731`), verbatim, ten entries:

```
Damage to player                    Is a target
This card will untap                Can't target this
Damage: %d                          Is a target, can't target again
Card is not controlled by owner     Dying
                                    Summoning sickness
                                    Phased
```

These are the **cue-card tooltips of the overlays a small card can wear**,
and **five of them ship as art in `../shandalar-src/Program/CardArt/`**,
all in the same image+mask format `MiniCard.masked_sprite()` already
decodes (verified: right-half alpha 0-255 on every one but `Poison`):

| file | size | image | state |
|---|---|---|---|
| `Summon.pic` | 194×97 | 97×97 | `Summoning sickness` — **imported** |
| `Damage.pic` | 84×26 raw | | `Damage: %d` — **imported** |
| `Dying.pic` | 194×97 | 97×97 | **`Dying`** — not imported |
| `CantTarget.pic` | 130×65 | 65×65 | **`Can't target this`** — not imported |
| `WillUntap.pic` | 110×59 | 55×59 | **`This card will untap`** — not imported |
| `Target.pic` | 122×61 | 61×61 | **`Is a target`** — imported, but as the *cursor* only |
| `Poison.pic` | 42×26 | 21×26 | `Damage to player` — not imported (right half fully opaque; needs the other decode branch) |

`Target.pic` is currently used as `target_cursor`
(`DuelScreen._set_target_cursor`, `~789`, "first 61×61 frame"). It is
**also** the small-card "Is a target" stamp; the same 61×61 image serves
both. That is not a conflict — import it once, use it twice.

And the **colour code** is the manual's, not s30's — manual **p.128**:
> *"Mandatory effects are highlighted in **orange**, while optional
> effects are in **yellow**."*

with manual **p.120** (*"the cards you can use at any moment during the
duel are **highlighted**"*), **p.115** (*"When all the necessary
conditions are met, a card in your hand is useable, and therefore will be
highlighted as such"*) and **p.126-128** (attack-eligible creatures are
highlighted; forced attackers/blockers are *"highlighted, and you must add
them to the Combat window"*). `duel-todo.md §6.20j` already records this
and points here.

**[s30]** — nine border states, `duel.go:3302-3377`, in five blocks of
which only the first returns early (blocks 2-5 can overpaint):

| # | guard | colour | width |
|---|---|---|---|
| 1 | damage-assignment blocker | `(0,255,0)` | 2 — **and returns** |
| 2a | your attack-eligible creature | `(255,255,0)`, **`(0,255,0)` once pending** | 2 |
| 2b | any *other* actionable permanent | **`(255,140,0)` orange** | 2 |
| 3 | your selected / assigned / eligible blocker | green / green / yellow | 2 |
| 4 | an attackable enemy attacker | yellow → **orange with Menace** → green when the selected blocker may block it (last wins) | 2 |
| 5 | targeting: legal → `(255,255,0)` w2; selected → `(0,255,0)` **w3** | | 2 / **3** |

Blocks 2 and 3 carry `targetingCardID == uuid.Nil`, so they are mutually
exclusive with block 5. The same orange w2 marks playable **hand** cards
(`duel.go:3616-3617`).

### Where the two references disagree, and the recommendation

s30's orange means "this permanent has *something* you can do"; the
manual's orange means "**mandatory**". Both are useful and they collide.

**Recommendation:** take the manual's meaning for colour and s30's
*coverage* for which cards get one.

- **Yellow** = you *may* act (optional): a castable hand card, an
  attack-eligible creature, an eligible blocker, a legal target, an
  activatable permanent. This absorbs s30's 2a-yellow, 2b-orange, 3-yellow
  and 5-yellow into one meaning, and it matches p.115/p.120/p.126, which
  use one word — *highlighted* — for all of them.
- **Orange** = you *must* act: a must-attack creature
  (`cur_must_be_blocked` / `no_attacks_this_turn`'s counterparts,
  `CombatState`), a mandatory upkeep payment, a forced block. `[1997]`,
  p.128.
- **Green** = committed: a pending attacker, an assigned blocker, a chosen
  target. `[s30]` for the exact hue; the original has no evidence either
  way, and green-means-locked-in is already our `SELECTED`.
- **Width 3** for a chosen target, 2 otherwise — s30's one width
  distinction, keep it.
- **Everything in `@CUECARD_SMALLCARD` that is a *fact about the card*,
  not an affordance, becomes an OVERLAY, not a border.** That is the
  structural insight the 1997 source gives us and s30 does not have:
  `Dying`, `Can't target this`, `Is a target`,
  `Is a target, can't target again`, `This card will untap`,
  `Card is not controlled by owner`, `Phased`, `Summoning sickness`,
  `Damage: %d`, `Damage to player`.

### The design

Two independent halves. **Ship them as two commits.**

**Half 1 — the overlays (S).**
- `tools/import_original.py`: five new manifest keys —
  `state_dying` (`Dying.pic`), `state_cant_target` (`CantTarget.pic`),
  `state_will_untap` (`WillUntap.pic`), `state_is_target` (`Target.pic` —
  the same file `target_cursor` already names, so add the key, do not
  duplicate the file), `state_poison` (`Poison.pic`).
- `MiniCard`: a small `STATE_OVERLAYS` table `state → skin key`, one
  `TextureRect` per active overlay stacked over the art, each with its
  `@CUECARD_SMALLCARD` string as `tooltip_text`. Reuse
  `masked_sprite()` — it already handles both the silhouette-mask and the
  alpha variants (twenty-first pass).
- The state predicates, all readable from `CardInstance`:
  | state | predicate |
  |---|---|
  | `Summoning sickness` | already implemented (`_sick_spiral`) |
  | `Damage: %d` | already implemented (the dagger) |
  | `Dying` | marked damage ≥ `cur_toughness`, or lethal already assigned — i.e. "this will die at the next SBA check" |
  | `This card will untap` | `not inst.skip_untaps` **and** it is tapped **and** the untap step is its controller's next — the inverse of a Meekstone lock |
  | `Card is not controlled by owner` | `inst.controller_id != inst.owner_id` (we have `controlled_via`) |
  | `Phased` | `inst.zone == Mtg.Zone.PHASED_OUT` — we already have phasing |
  | `Is a target` | the instance appears in a `TargetRef` of any live `StackItem` |
  | `Is a target, can't target again` | it is in the *current* slot's chosen group — the state §3.1's duplicate refusal is groping for |
  | `Can't target this` | in TARGETING, a card the current spec refuses (shroud, protection, `cur_target_bans`) |
  | `Damage to player` | `Poison.pic`; not a card state — park it |

  Do **not** implement all ten in one pass. `Dying`,
  `Card is not controlled by owner` and `Is a target` are the three §6.15
  singles out as invisible today; ship those three plus the two we have.

**Half 2 — the borders (M).**
- Widen `MiniCard.Highlight` to
  `{ NONE, OPTIONAL, MANDATORY, COMMITTED, TARGET_LEGAL, TARGET_CHOSEN }`
  with `HIGHLIGHT_COLORS` = none / yellow `(0.95,0.80,0.25)` / orange
  `(0.95,0.55,0.10)` / green `(0.35,0.85,0.35)` / yellow / green, and a
  parallel `HIGHLIGHT_WIDTH` = 1/2/2/2/2/**3**.
  Keep `CASTABLE`/`SELECTED` as deprecated aliases for one pass so the
  other agents' in-flight edits do not break.
- `DuelScreen._highlight_for` grows the NORMAL-mode branch s30 has and we
  lack entirely: **an actionable permanent on the battlefield** — any
  instance with a non-empty `cur_mana_abilities`/`cur_activated_abilities`
  whose cost the player can pay right now. That is the "this has something
  you can do" cue, and it is what the 1998 guide's *"go from left to right
  and evaluate each card on the board"* routine (guide p.106) needs.
  Ask the engine (`game.can_afford_cost`), never re-derive.
- The mandatory branch needs an engine question we may not have. Check
  before designing further: is there a "this creature must attack" query?
  If not, ship OPTIONAL/COMMITTED/TARGET_* now and file MANDATORY as an
  engine follow-up rather than guessing.

### Test plan

`tests/ui/test_mini_card.gd` (new):
1. `test_a_dying_creature_wears_the_dying_overlay`.
2. `test_a_stolen_creature_says_it_is_not_controlled_by_its_owner`.
3. `test_a_targeted_permanent_wears_the_target_overlay`.
4. `test_every_overlay_carries_its_1997_cue_card_string` — assert the
   `tooltip_text` of each is the exact `@CUECARD_SMALLCARD` line. **This
   is the wording pin; it is what stops the vocabulary drifting back to
   ours.**
5. `test_the_overlay_art_decodes_from_the_1997_mask` — the skin-present
   branch, mirroring `test_skin.gd`'s style.

`tests/ui/test_duel_screen.gd`:
6. `test_an_activatable_permanent_is_highlighted` — the new NORMAL cue.
7. `test_a_permanent_you_cannot_pay_for_is_not_highlighted`.
8. `test_a_chosen_target_draws_a_thicker_border` (width 3).
9. `test_a_pending_attacker_is_committed_not_optional`.

### Order and dependencies

**Wave C, second** — after 2.9 (same functions) and after **2.11** (the
same `import_original.py` manifest edit and the same `masked_sprite`
path). Nothing depends on it, but it is the largest fidelity win in the
tier.

### Risk

- **The manifest is shared.** `tools/import_original.py` is edited by 2.11
  and by both halves of 2.10. Do them in one wave or expect conflicts —
  and note the twenty-first pass found a **duplicate manifest key silently
  overriding an entry**. Grep for duplicates after editing.
- **Overlay stacking.** A creature can legitimately be sick *and* damaged
  *and* targeted. Decide the z-order and the placement before writing
  code, or the dagger will be under the spiral. The spiral is full-strength
  over the art (twenty-second pass) and will hide anything behind it.
- **`Target.pic` serves two masters.** Changing how it is decoded for the
  overlay must not change the cursor (`_set_target_cursor` takes the
  "first 61×61 frame" — i.e. the image half, not the mask).
- **Screenshot check:** `shot_duel`, `shot_duel_sick`, `shot_card_detail`,
  and a new staged capture with a damaged + targeted + sick creature.

---

## 2.11 [s30] Missing ability icons — S — UI — **minus menace**

### Current state (verified)

`mini_card.gd:735-747`:
```
BADGE_SLOT      = { FLYING:11, TRAMPLE:12, BANDING:13, FIRST_STRIKE:14, REACH:16 }
PROTECTION_SLOT = { G:5, R:6, U:7, B:8, W:9 }
```
Drawn by `_rebuild_badges` (`~773`) along the card's bottom edge, IN PLAY
only, deduped by slot, with the activation-cost mana symbol first.

**The doc comment on line 734 already claims `15 regeneration`** — the
dict does not have it. A live doc/code mismatch; fixing the dict fixes the
comment too.

### The reference

**[s30]** `duel.go:1047-1121`, the full sheet map (1 column × 18 rows,
`imageutil.LoadSpriteSheet(1, 18, …)`):

| idx | meaning | | idx | meaning |
|---|---|---|---|---|
| 0-4 | mana symbols (unused as badges) | | 11 | Flying |
| **5** | protection from **green** | | 12 | Trample |
| **6** | protection from **red** | | 13 | Banding |
| **7** | protection from **blue** | | 14 | First Strike |
| **8** | protection from **black** | | **15** | **Regeneration** |
| **9** | protection from **white** | | 16 | Reach |
| **10** | **protection from artifacts** | | **17** | *(s30 maps Menace)* |

`0` is s30's "no icon" sentinel, so slot 0 is unusable there. Protection
matching is case-insensitive on the colour's name **including the literal
string `"artifacts"`** — it comes through the same `FromColors` list.
Placement: bottom-left, 22px pitch, `break` on overflow (no wrap), which
on a 100px card caps at **4 icons**; icons are drawn regardless of tapped
state and are not rotated (`duel_ability_icons_test.go:11-34`).

### The correction: slot 17 is BLANK

Verified directly, on both copies of the sheet:

```
$ python3 -c "…Counter(cell17.getdata()).most_common(3)"
15 [((0,0,0,255), 92), ((28,28,28,255), 73), …]   ← green trident, regeneration
16 [((0,0,0,255), 92), ((249,239,176,255), 65), …] ← pale star, reach
17 [((0,0,0,255), 484)]                            ← SOLID BLACK, 484/484 px
```
(`s30/assets/art/card/Abilities.pic.png` and our own
`assets/original/ability_icons.png`, both 22×396 = 18 cells of 484px.)

The 1997 game had no menace keyword and no menace icon; s30's `17: Menace`
would blit a black square. `duel-todo.md §3.4` already says no 1997 card
needs menace. **Add 15 and 10 only.**

Visual confirmation of the tail, rendered at 8×: slot 10 is a brown/white
shield (artifacts), 11 a wing, 12 a red foot, 13 a blue cross, 14 a
sword-and-shield, 15 a **green trident** (regeneration), 16 a pale star
(reach), 17 nothing.

### The design

- `BADGE_SLOT[Mtg.Keyword.REGENERATION] = 15` — **if** we model
  regeneration as a keyword. Check first: `RegenerateEffect` is a *shield
  builder* (`engine/effects/regenerate_effect.gd`) and regeneration in
  this pool is usually an activated ability (`{B}: Regenerate`), not a
  keyword. If there is no `Mtg.Keyword.REGENERATION`, the badge predicate
  is instead *"this permanent has an activated ability whose effects
  include a `RegenerateEffect` targeting itself"* — a small helper on
  `MiniCard`, and the honest one. **Resolve this before writing code; it
  is the whole risk in this item.**
- `PROTECTION_SLOT` gains artifacts. `CardInstance.cur_protection` is a
  colour bitmask; protection from artifacts lives in
  `CardData.protection_from` as a non-colour entry. Read the field, do not
  extend the colour mask.
- The pitch: ours is `BADGE = 17` on a 132px card (7 fit) vs s30's 22 on
  100 (4 fit). Keep ours — the twelfth/fifteenth passes measured it.

### The defect this pass should also fix

**The imported sheet's cells carry an opaque near-black backdrop.** Cell
11 (flying) on `assets/original/ability_icons.png` has
`(0,0,0,255)` as its modal colour (92 of 484 px), and `badge_from_slot`
builds a bare `AtlasTexture` with no keying — so every badge draws a dark
22px square behind its disc. The set-symbol pass (eleventh) hit the same
class of bug and solved it by keying **every achromatic pixel**; that will
not work here (the protection-white shield and the reach star *are*
achromatic). **Clip to a circle instead** — the icons are discs inscribed
in their cell — or flood transparency inward from the four corners.
Confirm on a flier in the screenshot tour before and after.

### Test plan

`tests/ui/test_stack_hand.gd` (where the badge pins live) or the new
`tests/ui/test_mini_card.gd`:
1. `test_a_regenerating_permanent_badges_slot_15`.
2. `test_protection_from_artifacts_badges_slot_10` (Artifact Ward /
   a `protection_from` artifact card in the pool).
3. `test_menace_is_not_badged` — assert nothing is drawn, **with a comment
   citing the blank cell**, so nobody "completes" the map later.
4. `test_badges_are_deduped_by_slot` — s30's own case, flying twice +
   trample + first strike → exactly three
   (`duel_ability_icons_test.go:35-52`).
5. `test_a_badge_has_no_opaque_backdrop` — sample the cell's corner alpha
   after decoding. The keying pin.
6. `test_badges_only_show_in_play` — the existing rule, re-pinned.

### Order and dependencies

**Wave B, first.** Smallest item in the tier and it opens the
`import_original.py` + `masked_sprite` path that **2.10** then reuses.

### Risk

- **Does `Mtg.Keyword.REGENERATION` exist?** If not, the predicate is an
  ability scan and the item grows from S to S/M. Check before starting.
- The keying fix touches every existing badge. `shot_duel` with a flier
  before/after is mandatory.

---

## 2.12 [s30] Land art does not follow a changed basic subtype — S — both

### Current state (verified)

`MiniCard.refresh` (`mini_card.gd:332`):
`var art := GameSkin.card_art(d.card_name)` — always the **printed** name.
`CardPreview` does the same (`card_preview.gd:226`). A City of Brass
turned into a Forest by Evil Presence keeps City of Brass's art; a Blood
Moon'd dual keeps its dual art.

Our engine models the change correctly — the 2026-09 audit added CR 305.7
land retyping and `battlefield_with_type_statics()` — so this is a pure
presentation gap.

### The reference

**[s30]** `permanentArtName`, `duel.go:337-371`, pinned by
`duel_land_art_test.go` in full:

```
if not is_land or printed_card == null: return printed name
current  = the live basic subtypes, de-duped, IN FIRST-SEEN ORDER
if current is empty: return printed name
printed  = the printed basic subtypes
for subtype in [Plains, Island, Swamp, Mountain, Forest]:   # canonical order
    if current.has(subtype) != printed.has(subtype):        # ANY difference
        for s in current_order:                             # first NEWLY GAINED wins
            if not printed.has(s): return s
        return current_order[0]                             # only-removals fallback
return printed name
```

The test table, which is the spec:

| case | printed | live subtypes | result |
|---|---|---|---|
| changed | City of Brass (no subtypes) | `Forest` | `Forest` |
| unchanged | Forest `[Forest]` | `Forest` | `Forest` (printed path) |
| **added** | Forest `[Forest]` | `Forest Mountain` | **`Mountain`** — the *newly gained* one, not the first listed |
| reverted | City of Brass | *(empty)* | `City of Brass` |
| non-land | Forest Bear (creature) | `Bear Forest` | `Forest Bear` — the `is_land` guard |

s30 also back-fills the five basic-land arts unconditionally into its
image map (`buildCardImageMap`, `duel.go:320-333`) so a Forest's art is
resolvable even when neither deck runs one.

**[1997]** — no direct statement, but the manual's own framing supports
it: p.118, *"Any changes made to a card after it was put into play —
modifications to the power, toughness, **color**, or what have you — are
noted on the representation of the card in play"*. Art follows the card in
play. Label it `[s30]` anyway; the manual does not say *art*.

### The design

- `MiniCard.art_name(inst: CardInstance) -> String` — **static**, so
  `CardPreview` uses the identical function and the two can never
  disagree. Reads `inst.cur_subtypes` vs `inst.data.subtypes`; falls back
  to `inst.data.card_name`.
  - Verify the field name first: `CardInstance` has `last_subtypes` (CR
    608.2h) — confirm the *live* list is `cur_subtypes` before writing.
- Both call sites change to `GameSkin.card_art(MiniCard.art_name(instance))`.
- `tools/fetch_card_art.py` already fetched all 896 pool cards, so the
  five basics are present; no importer change needed. Add a fallback:
  if the swapped name has no art, fall back to the printed name rather
  than rendering the identity-colour placeholder.
- **Only the ART changes.** The name on the title bar, the frame texture
  and the mana stripes stay printed — s30 swaps only the image, and the
  card's *name* is not what changed.
  - Open question worth one line in the code: should the **frame** follow?
    A Blood Moon'd Volcanic Island is a Mountain; our frame is keyed off
    `frame_skin_key(instance.data)`, i.e. printed. s30 does not swap it.
    Leave it printed and note it.

### Test plan

`tests/ui/test_mini_card.gd` — port s30's five cases 1:1:
1. `test_a_retyped_land_draws_the_new_basic_art` (Evil Presence on City
   of Brass → Swamp).
2. `test_an_unchanged_basic_land_draws_its_own_art`.
3. `test_an_added_subtype_wins_over_the_printed_one` — the Forest →
   `Forest Mountain` → `Mountain` case; the subtle one.
4. `test_the_art_reverts_when_the_effect_ends`.
5. `test_a_nonland_with_a_land_word_in_its_name_is_untouched`.
6. `test_the_showcase_and_the_small_card_agree` — both call the same
   static.

### Order and dependencies

**Wave B, second.** Independent; grouped with 2.11 only because both are
`mini_card.gd` and both are S.

### Risk

Low. One trap: `MiniCard.refresh()` runs on **every** board rebuild, and
`art_name` would then do string work per card per frame. At duel scale
(tens of cards) that is fine, but early-out on `not inst.is_land()`
**first**, exactly as s30 does — that is one boolean for ~90% of cards.

---

## 2.13 [s30] Rows wrap instead of squeezing — S — UI

### Current state (verified)

Every board row is an `HFlowContainer`
(`DuelScreen._build_ui`, `~1897-1946`), so an overflowing row wraps to a
second line, pushing the row below it and breaking the board's reading
order. `_apply_hand_reservation` (`~2214`) narrows each half's row VBox by
`offset_right` so the piles wrap *before* they reach the hand window —
i.e. the current design **relies** on wrapping.

> **Superseded 2026-09-04.** `_apply_hand_reservation`, `_hand_reserve`
> and `HAND_GAP` are GONE. The hand window is free to sit anywhere and
> the board never rearranges itself for it — the owner's ruling (*"the
> hand stack can be present anywhere; only cast mini-cards are bound to
> the playfield"*), which also fixed the defect where dragging the
> window shoved every placed card and every land row. Any plan below
> that leans on the reservation needs re-reading with that in mind.

**Half-relieved since §2 was written.** `_windowed_ids` now removes every
creature in combat from its territory into the Combat window, so the
creature row — the one that overflowed worst, and the one whose reading
order matters most — is at its emptiest exactly when combat is being read.
The land/other rows still overflow, but they are `CardPile`s of 5, so a
wrap there costs less.

### The reference

**[s30]** `getFieldCardPos`, `duel.go:1426-1435` — one row, always, cards
overlapping once they must:

```go
maxSpacing := 35;  if row == permRowCreature { maxSpacing = 120 }
availableW := duelBoardW - 30 - fieldCardW          // 721 - 30 - 100 = 591
spacing := maxSpacing
if total > 1 && (total-1)*spacing > availableW {
    spacing = availableW / (total - 1)              // INTEGER division
}
pos := image.Pt(duelBoardX + 30 + idx*spacing, baseY)
```

Thresholds that fall out of it: the creature row (120px pitch, 100px card)
starts squeezing at **6** cards — 6→118, 7→98, 8→84, 10→65, 12→53. The
land/other rows (35px pitch) start at **18**. The left edge is fixed and
the last card's right edge never passes `duelBoardX + duelBoardW − 7`.

Draw and hit-test call `fieldPerms` + `getFieldCardPos` as a **pair** with
the same `i` and `len(perms)` (`duel.go:3213-3216` and `1595-1599`), which
is how the two agree; the hit-test walks a row **backwards** so the
topmost overlapping card wins.

**[1997]** — nothing about the territory. But for the **hand** the manual
says the opposite of a squeeze — manual **p.114**: *"The Hand window has a
maximum size. If there are too many cards in your hand to display all at
once, use the scroll arrows at the top to see the rest. This is a
'revolving' scroll, which means that the top cards cycle to the bottom;
the number of cards in your hand is always noted on the top bar."* Our
`StackHand`'s ▲/▼ collapse and expand instead
(`stack_hand.gd:~210-240`, s30's `handCollapsed`). Do **not** apply the
squeeze to the hand; file the revolving scroll separately (see §0.2 item 9).

### The design

- Replace the three `HFlowContainer`s per half with a small
  **`game/duel/squeeze_row.gd`** — `class_name SqueezeRow extends Control`:
  - `var max_pitch: float` and `var card_size: Vector2`
  - `_notification(NOTIFICATION_SORT_CHILDREN)` places every child at
    `x = i * pitch` where
    `pitch = min(max_pitch, (size.x - card_size.x) / max(1, n - 1))`,
    clamped below at some floor (a quarter of the card width — s30 has no
    floor and will happily reduce the pitch to 0).
  - `custom_minimum_size.y = card_size.y`.
  - Alignment: our rows are `ALIGNMENT_END` (right-hugging piles) /
    left-reading creatures. Preserve that — the reference measurement
    (sixth and thirteenth passes) puts lands/piles at the **right** of
    each half and creatures reading from the left.
  - **z-order matters once cards overlap.** Later children must paint on
    top (s30 draws in row order and hit-tests backwards). Godot paints in
    child order, so "later = on top" is free; just make sure the hit test
    matches, which with real `Button` children it does automatically —
    the topmost `Control` takes the pointer.
- Pitches, scaled from s30's constants to our `MiniCard.SIZE = 132×106`
  (s30's card is 100×83): creature row `120/100 × 132 ≈ 158`, land/other
  `35/100 × 132 ≈ 46`. But our lands are `CardPile`s, not single cards, so
  the land/other pitch should be `CardPile.WIDTH`-derived, not 46.
  **Measure on the owner's screenshot before hard-coding.**
- **`_apply_hand_reservation` keeps working for free**, because it sets
  `offset_right` on the row VBox and `SqueezeRow` reads its own `size.x`.
  That is the single biggest reason to do it this way rather than with
  absolute positions.

### Test plan

`tests/ui/test_squeeze_row.gd` (new — a bare `Control`, no game needed):
1. `test_a_row_that_fits_uses_the_full_pitch`.
2. `test_an_overflowing_row_shrinks_the_pitch` — s30's thresholds,
   rescaled: 5 creatures at full pitch, 6 squeezed.
3. `test_the_last_card_never_leaves_the_row` — the invariant that matters.
4. `test_the_pitch_never_goes_below_the_floor`.
5. `test_a_single_card_is_placed_at_the_origin` (the `n-1` divide-by-zero
   guard).

`tests/ui/test_duel_screen.gd`:
6. `test_the_creature_row_never_wraps` — twelve creatures, assert every
   child's `position.y` is equal.
7. `test_the_board_still_stops_before_the_hand_window` — re-run the
   twenty-seventh pass's three reservation tests against the new row.
8. `test_clicking_an_overlapped_card_hits_the_top_one`.

### Order and dependencies

**Wave A, second — after 2.3.** A squeezed row of unsorted cards is worse
than a wrapped row of unsorted cards, because overlap hides the very names
you are scanning.

### Risk

- **This is the highest-risk item in Wave A.** It replaces a stock
  container with a custom layout, and *four* consumers resolve pixel
  positions from those children: `TargetArrows` (draw-time
  `_collect`/`_resolve`), `CombatWindow.fit`, `_apply_hand_reservation`,
  and the tap-rotation holder in `_make_widget` (which sizes itself to the
  **rotated** bounding box, `SIZE.y + 8 × SIZE.x + 8` — a squeezed row
  must use each child's own `size`, not a constant).
- **The immediate-mode hazard again.** See 2.3's Risk; the same
  `queue_free`-without-remove and freed-typed-local traps apply, and the
  screenshot tour is the only check that catches them.
- **Screenshot check, mandatory:** `shot_duel` with ≥8 creatures a side,
  `shot_duel_block_arrows`, `shot_combat_window`, `shot_hand_mixed`.
  Zero SCRIPT ERRORs.

---

## 2.14 [s30]+[1997] Hover-examine has no fallback — S — UI

### Current state (verified)

`DuelScreen._make_widget` (`~1702-1712`) wires each `MiniCard`:
`mouse_entered` → `_card_preview.show_card(inst)` (unless `face_down`);
`mouse_exited` → hide, but **only when not docked** — and the preview
*is* docked in the sidebar, so in practice the last hovered card sticks.
Nothing else ever feeds the Showcase.

Gaps: nothing shows while the pointer is over empty board; ~~nothing shows
for a card on the **stack** (the spell chain items carry a
`tooltip_text` only, `_rebuild_stack`)~~ **— CLOSED 2026-09-01,
forty-second pass: every chain object is a `MiniCard` built by
`_make_card`, so hovering one docks it in the Showcase like any other
card**; nothing shows for a card in a **graveyard** (the pile is a
`TextureRect` with a tooltip — §1.2's hole); and a drawn card is not
shown.

### The reference

**[1997]** — manual **p.117**:
> *"To the left of the Phase Bar, in the center, is a big card. As in some
> other screens, this is the Showcase. Whenever the mouse cursor **pauses
> long enough** over a card in play, in a visible hand, **or even in a
> graveyard**, that card is displayed here. **Cards drawn into your hand
> are displayed when you draw them.**"*

and manual **p.118**: in Standard Layout the Showcase is permanent and
never leaves the screen — which our docked preview already matches.
Note also *"pauses long enough"*: the original has a **hover delay**; ours
fires on `mouse_entered`.

**[s30]** — `updateHoverPreview`, `duel.go:1930-1954`, a four-stage chain,
each returning on hit:
1. own hand card (`handDisplayOrder` + `handCardIdxAtPoint`) → preview
   **by name** (perm `nil` ⇒ printed stats);
2. own battlefield permanent (`fieldPermAtPoint`, aura strip probed before
   the card body) → preview **with the permanent**;
3. opponent battlefield permanent → same;
4. **unconditional** — `if len(StackItems) > 0 { preview(StackItems[len-1]) }`.

Stage 4 fires whenever the pointer is over empty space, so the resolving
card is always in the magnifier. Hover runs **only when not targeting**
(`duel.go:1199-1216`).

### The design

Three additions, cleanly separable:

1. **[1997] Draw-into-hand.** `DuelScreen._on_game_event` already receives
   every `GameEvent`; on a draw whose player is the human seat, call
   `_card_preview.show_card(drawn)`. One `match` arm. **The most faithful
   and the cheapest of the three.**
2. **[s30] Top-of-stack fallback.** A `_hovered_count` (incremented on
   `mouse_entered`, decremented on `mouse_exited`) or simply: at the end
   of `_refresh`, if nothing is hovered and `not game.stack.is_empty()`,
   show `game.stack[-1]`'s source card. Guard it so it does not fight the
   docked persistence — the rule is *"empty space + a non-empty stack"*,
   not *"empty space"*.
3. **[1997] Graveyard hover.** Blocked on **§1.2** (graveyards are not
   interactive at all). Note the dependency and skip it here; when §1.2
   lands, its cards are `MiniCard`s and get the hover for free.

Do **not** port s30's hover-delay-free behaviour without noting it:
p.117's *"pauses long enough"* means the original had a dwell. A
`Timer`-gated hover is `[1997]` and a genuine improvement over a preview
that strobes as the pointer crosses a row — but it is a behaviour change,
so ship it separately with the owner's sign-off.

### Test plan

`tests/ui/test_duel_screen.gd`:
1. `test_a_drawn_card_appears_in_the_showcase` — the 1997 pin.
2. `test_the_showcase_falls_back_to_the_top_of_the_stack`.
3. `test_the_fallback_does_not_fire_with_an_empty_stack` — the last
   hovered card must stay, not blank.
4. `test_hovering_a_card_beats_the_stack_fallback`.
5. `test_the_opponents_hidden_hand_is_never_previewed` — the
   hidden-information pin (`face_down` guard); a regression here leaks
   the opponent's hand, which is the worst failure mode in this item.

### Order and dependencies

**Wave D, second — after 2.15.** 2.15 introduces the "which card is under
this point" resolution; 2.14's fallback is the *else* branch of the same
question. Item 3 waits on §1.2 (Tier 1, another agent).

### Risk

- **Hidden information.** Any new preview path must respect
  `hidden_hands` / `MiniCard.face_down`. The existing wiring checks
  `not w.face_down`; a stack-item path must check the controller and the
  zone. Test 5 above is not optional.
- Low otherwise. `CardPreview.show_card` is idempotent and already
  handles the docked/undocked split.

---

## 2.15 [1997] Right-click / long-press "just look at it" — S — UI

*(§2 tags this `[s30]`; it is `[1997]` — see §0.2 item 11)*

### Current state (verified)

`grep -rn "MOUSE_BUTTON_RIGHT" game/` → **two hits, neither in the duel's
card path**: `stack_hand.gd:211` handles `MOUSE_BUTTON_LEFT` only, and
`combat_bar.gd:136` is a slot click. `MiniCard` extends `Button` and emits
`pressed` — a left-click only. **There is no right-click anywhere on a
card, and no long-press at all.**

### The reference

**[1997], manual p.113**, quoted in full because it is the spec:

> *"Every card in play or in your hand has one or more uses… In most
> instances, you can simply click on the card to activate that primary
> function. If a card has more than one possible function, you're prompted
> to choose the one you want to use. **Right-clicking on a card also opens
> a mini-menu.** Other than the options listed above, a card's mini-menu
> might also contain:*
> - *Don't Auto Tap marks a land to be ignored…*
> - *ORIGINAL Type shows you what this card was when it was cast, before
>   any spells and effects changed it.*
> - ***Show Full Card** displays the card in the Showcase. (When you're
>   using the Advanced Layout, this opens a temporary Showcase in which to
>   display the card. **You can also double-right-click to perform the same
>   function.**)"*
>
> *"You can also **right-click and hold** to bring a card in your hand to
> the front for as long as you hold the mouse button."*

and the menu itself, `@MENU_SMALLCARD` (`UIStrings.txt:936`, quoted at
`duel-todo.md §6.12`):
```
Original type                 Show ID tags\tCtrl+T
Show full card\tR DblClk      Show invisible effects\tCtrl+I
View in full card             Show all cards' summoning sickness\tCtrl+U
Don't auto tap this card      Help...
```

**[s30]** — `handleRightClick`, `duel.go:1909-1928`: three probes (own
hand → own battlefield → opponent battlefield), each loading the preview
and returning; **no action performed**. Wired to both
`IsMouseButtonJustPressed(MouseButtonRight)` and `ui.LongPress` — and
`LongPress` (`s30/game/ui/pointer.go:70-72,106-108,149-150`) requires the
press origin **and** the current position inside the bounds, is cleared by
dragging, and its threshold is `UpdatesPerSecond / 2` = **0.5 seconds**.
Right-click runs *outside* the targeting branch, so examine works
mid-targeting.

### The design

Ship the **minimum faithful gesture** now and leave the full mini-menu to
§6.12:

- `MiniCard` gains a `right_pressed` signal, emitted from `_gui_input` on
  `InputEventMouseButton` with `button_index == MOUSE_BUTTON_RIGHT and
  pressed`. `MiniCard` extends `Button`, so `_gui_input` runs before the
  button's own handling — accept the event so it does not fall through.
- `DuelScreen._make_widget` connects it to
  `_card_preview.show_card(inst)` — **`Show full card`, verbatim from
  `@MENU_SMALLCARD`.** It performs no action: no cast, no tap, no
  attacker toggle. That is the whole point of the item.
- **It must work while TARGETING.** s30 deliberately runs right-click
  outside the targeting branch; our `_on_card_clicked` routes by mode, so
  keep `right_pressed` on a separate path that never touches `mode`.
- **Long-press** for the Steam Deck / Pi targets (design doc §1): a
  `Timer` (0.5s) started on `button_down`, cancelled on `button_up` or on
  a mouse-motion drag beyond a few pixels, firing the same handler. Copy
  s30's two guards — origin-and-current both inside, cancelled by drag —
  or a scroll-drag over the hand will fire previews.
- **`right-click and hold` on a hand card raises it to the front**
  (p.113). Our `CardPile` clips covered cards to their title bar; raising
  one means temporarily un-clipping it. Worth doing in the same pass —
  it is the same gesture, and it is the one that makes a stacked hand
  readable. `[1997]`, S.
- Everything else in `@MENU_SMALLCARD` — `Original type`,
  `Don't auto tap this card`, `Show ID tags`, `Help...` — is **§6.12**.
  Leave a `# §6.12` comment at the emit site so the next pass knows where
  the menu hangs.

### Test plan

`tests/ui/test_duel_screen.gd` — drive `MiniCard._gui_input` with a
synthetic `InputEventMouseButton`, do not simulate the OS:
1. `test_right_clicking_a_card_shows_it_in_the_showcase`.
2. `test_right_clicking_performs_no_action` — right-click a castable hand
   card, assert `game.stack.is_empty()` and `mode == Mode.NORMAL`. **The
   defining pin.**
3. `test_right_click_examines_while_targeting` — enter TARGETING,
   right-click an illegal target, assert the preview changed and the
   targeting state did not.
4. `test_a_long_press_examines_like_a_right_click`.
5. `test_a_drag_cancels_the_long_press`.
6. `test_right_click_and_hold_raises_a_hand_card` (if the raise ships in
   the same pass).

### Order and dependencies

**Wave D, first.** Independent of everything; **2.14** wants its pointer
resolution, and **§6.12** (the full mini-menu) hangs off its emit site.

### Risk

- **`MiniCard` extends `Button`.** Godot's `Button` consumes mouse events;
  `_gui_input` runs first, but any handler must `accept_event()` or the
  right-click can still reach a parent. Verify against the `CardPile`
  holder buttons, which already take the pointer for pile rows
  (twenty-seventh pass: *"a row's MiniCard is mouse-transparent — the
  holder Button takes the pointer"*). **The pile path needs its own wiring
  and is the easiest thing to miss in this item.**
- Long-press and drag collide on the hand window, which is draggable by
  its title bar (`StackHand._on_title_input`). The gesture must be
  card-scoped, not screen-scoped as s30's is.

---

## 3. Cross-cutting

### 3.1 Test conventions for this tier

- **Test-first**, per `CONTRIBUTING.md` and `docs/ARCHITECTURE.md`. Every item
  above names the pins before the design is written; write those first.
- **Pure logic goes in `tests/unit/`, not `tests/ui/`.** `BoardOrder`
  (2.3), `DuelPacing` (2.6) and `SqueezeRow` (2.13) are all designed as
  `RefCounted`/bare-`Control` helpers precisely so they can be. A UI test
  that boots a whole duel to assert a comparator is a slow test that will
  be deleted later.
- Three new files are proposed. Each needs a **row in
  `docs/CODE_MAP.md`** (`CONTRIBUTING.md` hard rule 6):
  `game/duel/board_order.gd`, `game/duel/duel_pacing.gd`,
  `game/duel/squeeze_row.gd` (+ `game/duel/spell_flight.gd` if 2.4 is
  ever built).
- **Wording pins are the point.** Where an item shows 1997 text
  (2.10's cue cards, 2.15's `Show full card`), assert the *exact string*
  from the `Program/` table. Two passes have already drifted back to s30's
  paraphrase; a string assertion is what stops it a third time.

### 3.2 The screenshot loop

```
SHANDALAR_SHOT_DIR=/tmp/…/shots xvfb-run -a -s "-screen 0 1280x800x24" \
  ../tools/godot --path . res://tools/screenshot_tour.tscn
```
then `Read` the PNGs. The tour must print **zero SCRIPT ERRORs** — the
twenty-sixth pass found ~40 errors per run that the entire test suite
missed, because UI tests never refresh between caching an anchor and
drawing it.

Per wave, the shots that matter:

| Wave | Shots |
|---|---|
| A (2.3, 2.13) | `shot_duel`, `shot_hand_mixed`, `shot_duel_block_arrows`, `shot_combat_window` |
| B (2.11, 2.12) | `shot_duel` with a flier and a retyped land, `shot_card_detail` |
| C (2.9, 2.10) | `shot_duel_sick`, `shot_card_detail`, a new staged damaged+targeted creature |
| D (2.15, 2.14) | `shot_duel_stack_hover`, `shot_hand_mixed` |
| E-G | `shot_duel`, `shot_dialog_end_duel` |

New staged captures should follow `tools/screenshot_tour.gd`'s existing
pattern (stage the exact board, capture, tear down).

### 3.3 The three biggest risks, ranked

1. **The board is immediate-mode and four subsystems resolve pixels from
   the widgets it rebuilds** — `TargetArrows`, `CombatWindow`,
   `_apply_hand_reservation`, and the tap-rotation holder. Waves A and C
   all change what `_rebuild_field` produces. The failure mode is a freed
   object handed to `_draw` a frame later, it does **not** show up in the
   test suite, and it has already happened twice (twenty-sixth pass
   CAVEAT). Every wave ends with the screenshot tour, not with a green
   suite.
2. **`tools/import_original.py`'s manifest is shared by 2.10 and 2.11**,
   and the twenty-first pass found a **duplicate key silently overriding
   an entry**. Do those two items in one wave and grep for duplicate keys
   after editing.
3. **Pacing (2.6) widens every window in the AI scheduling loop.**
   `_maybe_schedule_ai` is re-entered from `_refresh`, which `_ai_step`
   calls; `_on_pass_turn` runs 60 engine iterations with no frames
   between. A variable delay in that loop is the one change in this tier
   that can hang a duel rather than mis-draw one. Keep the headless
   early-out.

### 3.4 Items to re-tier or drop

| Item | Recommendation | Why |
|---|---|---|
| **2.2** lift | **Drop** | Superseded by the Combat window; the manual (p.126) describes the window and highlighting, never a lift |
| **2.4** spell-cast animation | **Defer out of Tier 2** | `[s30]`; `Duel.hlp` says an uncontested cast may be *"so quickly as to be invisible"*; competes with the unbuilt Spell Chain window (§6.5/§6.6) |
| **2.7** life count-down | **Keep, but last** | `[s30]` with no 1997 basis; cheap and pleasant, but the first thing to cut if the tier needs shortening |
| **2.8** end-of-duel | **Close as done**; move the "next draw" remainder to §6.4 | Landed on the twenty-eighth pass |
| **2.10** ⟷ **§6.15** | **Merge** | Both are `@CUECARD_SMALLCARD`; §6.15 lists four missing states, 2.10 lists the borders — one component, one pass |
| **2.14** graveyard hover | **Blocked on §1.2** | Graveyards are not interactive; the hover comes free once they are |
| — | **New item: the hand's revolving scroll** `[1997]`, S, UI | Manual p.114; our ▲/▼ collapse instead of scrolling. Re-frames §3.6 |
| — | **New item: the Showcase must show printed P/T** `[1997]`, S, UI | Manual p.114/p.118; folded into 2.9 above, but it is a fidelity *defect*, not a feature |

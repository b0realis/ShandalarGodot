# Duel Screen — Design Document (M2)

The project's stated goal, in the owner's words: **fully faithful to
MicroProse's Magic: The Gathering + Duels of the Planeswalkers, with modern
computer, Raspberry Pi and console support, quality-of-life features, and
graphics faithful to the original.** This document records the decisions
that follow from that goal, and the wishlist that guides later milestones.

## 1. Platform targets & the renderer decision

| Platform | Status | Notes |
|---|---|---|
| Linux / Windows / macOS | Primary | Godot 4.7 export presets, keyboard+mouse first |
| Raspberry Pi (4/5) | Primary | The reason we ship the **Compatibility (OpenGL) renderer** — set in project.godot. A 2D card game needs nothing Vulkan offers, and GL runs on every Pi, old laptop, and thin client |
| Steam Deck / handhelds | Free ride | Linux build + full gamepad support (below) |
| Consoles | Aspirational | Godot has no built-in console export; ports go through W4 Games / Lone Wolf-style porting partners. Our obligations TODAY: full gamepad navigation, no OS-specific code outside `game/`, 16:9-and-16:10-safe layout, no mouse-only interactions |
| Web (WASM) | Later | Godot 4 web export works with Compatibility renderer; s30 proves the genre fits the browser |

A note on a quirk that was NOT engine-side. Until 2026-09-01 every run
that had touched `CardRegistry` — headless and windowed alike — aborted
at exit (134, "double free or corruption") and it was written up here as
a harmless GL-dummy teardown. It was our own static card table being
destroyed after the card scripts its Callables point into; see
`game/lifecycle.gd`. A non-zero exit is a bug again — and it caught a
second cache of the same shape the next day (`DeckFilter._facts`, keyed
by card objects, which kept the Deck Builder's every visit ending in an
abort on Exit).

Other platform-driven rules: base design resolution **1280×800** (16:10,
covers Steam Deck exactly, letterboxes cleanly to 16:9 TVs), stretch mode
`canvas_items` so the UI scales crisply at any size; every interaction
reachable by D-pad focus navigation (Godot's built-in Control focus system)
as well as pointer.

## 2. Faithful graphics — strategy

The original's art (duel table, card frames, mana symbols, wizard portraits,
tap animations) is **still copyrighted**; we never ship it in the repo (same
policy as card art — see cards/data). Faithfulness is achieved in layers:

1. **Faithful LAYOUT now** (this milestone): the screen composition mirrors
   the 1997 duel screen — opponent's battlefield across the upper half,
   yours across the lower, your hand fanned along the bottom, and a left
   sidebar carrying both wizards' life, the phase indicator and the game
   log, where the original put its portraits and phase bar. Proportions and
   reading order match the original even while widgets are placeholder.
2. **Clean skin as default**: a restrained dark-stone-and-gold look evoking
   the original's palette, drawn with plain Godot theming. This is what CI
   builds and new players get.
3. **Original-assets import path** (SHIPPED — `tools/import_original.py`
   + `game/skin.gd`): owners of the original game run the importer against
   their own copy (PNG conversions from an s30 checkout and/or a Manalink
   install; a native .PIC decoder is on the roadmap). Assets land in
   `res://assets/original/` (gitignored, dev) or `user://original_skin/`
   (players/exports); `GameSkin` loads them at runtime, bypassing the
   import pipeline, and every UI surface falls back to the clean skin when
   a key is missing. Currently skinned: title screen + MagicMedieval
   title font, **all fifteen `Terr_<colour><type>` territory backgrounds**
   (five colours x three styles — see the forty-eighth pass below), all
   12 original card frames (5 colors +
   gold + artifact + 5 land frames) on every card widget, and MPlantin on
   the duel's reading surfaces. Imported-and-waiting for future UI work:
   card back, mana-symbol and ability-icon sheets, damage marker, the
   original targeting cursor. **One key is CONVERTED rather than copied:**
   `coin_toss_heads` / `coin_toss_tails` are sprite sheets transcoded from
   the two `COINTOSS_*.AVI` movies (Indeo Video 4.1, which nothing in
   Godot or Python decodes) by whichever of `ffmpeg` /
   `gst-launch-1.0` the player has — detected, reported and skipped when
   absent. Each sheet carries a `.json` sidecar with its grid, frame count
   and frame rate; see the fiftieth pass.
4. **Card art**: Scryfall border crops fetched at build/run time exactly as
   s30 does (`utils/download_card_images.py` is the reference); cached to
   `user://card_art/`. Never committed.

## 3. Screen anatomy (v1, implemented)

```
┌─────────────┬──────────────────────────────────────────────┐
│  SIDEBAR    │  Opponent hand: N cards          [portrait]  │
│  turn/phase │  ── opponent lands ──────────────────────────│
│  opp life ❤ │  ── opponent other permanents ───────────────│
│  my life  ❤ │  ── opponent creatures ──────────────────────│
│  priority ▶ │ ═════════ THE STACK (strip, top→right) ══════│
│  prompt     │  ── my creatures ────────────────────────────│
│  [Pass]     │  ── my other permanents ─────────────────────│
│  [Confirm]  │  ── my lands ────────────────────────────────│
│  [Cancel]   │  ─────────────────────────────────────────── │
│  game log   │  My hand: fanned card row                    │
└─────────────┴──────────────────────────────────────────────┘
```

- Creatures row sits nearest the battle line, lands furthest — the
  original's convention, and what makes combat readable.
- The stack renders as a horizontal strip between the battlefields; the
  RIGHTMOST item resolves next. Every stack item shows its name and target.
- Life totals are buttons — they ARE the click-targets for "any target"
  spells, like the original's wizard portraits.

### 3b. Reference: how the ORIGINAL duel screen composes (owner's screenshots)

The project owner supplied gameplay screenshots of the 1997 duel screen
(2026-08-30); they are the fidelity target for future passes. What they
show, feature by feature:

- **Left panel** (fixed column): huge yellow life numerals top (opponent)
  and bottom (you); each player's LIBRARY as a physical stack of card
  backs; each player's MANA POOL as a vertical column of the six symbols
  (B U G R W X) with a count beside each; and the ENLARGED CARD dockable
  area — hovering/examining any card renders its full card (art, text)
  in this panel, not floating over the board.
- **Hand window**: draggable, titled "Your hand (N)" with ▲▼ arrows; one
  strip per card showing the name COLOR-CODED by identity (red spells in
  red, green in green, lands in yellow, artifacts bone, gold multicolor);
  the currently selected/last card renders as a FULL CARD inside the
  window under the strips. → Implemented now as StackHand (Options →
  "Hand display: stacked"): strips + colors + drag + hover preview; the
  in-window full card and the ▲▼ arrows are wishlist.
- **Battlefield**: every permanent is a full mini-card WITH ART and a P/T
  overlay; multiple non-creature permanents and lands group into the same
  strip-stack windows the hand uses ("Black Vise / Library of Leng /
  Howling Mine / Ivory Tower" as strips with the last shown full).
- **Opponent hand**: the hand window's TITLE BAR ONLY, counting the cards
  ("Opponent (5)") — no card backs row. Manual p.114: *"Only the title bar
  of your opponent's hand is visible; this is to keep you aware of how many
  cards are in that hand."* → `StackHand.title_plate`, the fortieth pass.
- **Prompt bar**: "Done | Fast Effects?...Discard Phase" — the phase
  question mark style; our prompt label should adopt this wording.
- **Stack objects** render as small framed cards with an "Ability
  Effect / <name>" caption (spiral art placeholder for abilities).
- **Modal choices** (Primal Clay screenshot): a dark dialog listing the
  modes as clickable lines with the ENLARGED CARD rendered beside it —
  our mode PopupMenu should grow into this (enlarged card + line list).

Status after the s30-port pass (2026-08-30, per the owner's "lean on the
30th anniversary codebase" rule — port, don't reinvent): IMPLEMENTED —
life numerals + Winbk_Manapool columns + deck/grave counts, the docked
enlarged card (persists, fed by hovering any card anywhere), the stacked
hand window with the Hand_* bar as DEFAULT (fan remains an Option),
"Opp Hand (N)" counter bar, phase strip between sidebar and board, the
mid-screen Done+message bar (Statbutt DONE states), card art via
tools/fetch_card_art.py (s30's Scryfall approach, pre-downloaded).
Second pass (same day): the hand window is now the reference's PILE of
full card faces (CardPile: each offset OVERLAP, last card fully visible),
battlefield cards are full mini-cards with ART (CardWidget: name strip /
art window / status / P/T), and card art itself is in via
tools/fetch_card_art.py (all 896 fetched).

Third pass (same day) — the reference wishlist is IMPLEMENTED:
- Library as physical card-back stacks with counts, beside the Grave_*
  panels (sidebar player blocks).
- Lands/other permanents group into CardPiles of PILE_SIZE (the
  "Black Vise / Library of Leng / Howling Mine" stacks). **A CARD IN A
  PILE TURNS WHEN IT TAPS** (2026-09-04). Every row is a WHOLE MiniCard
  occluded by the card in front of it — 1997's own mechanism
  (`update_hand_window`, `windows.c:1108-1178`, `MoveWindow` + z-order),
  not the clipped 17px strip we drew until then — and the stack steps
  along each card's own TITLE EDGE: 17px DOWN from a flat card, whose bar
  is across its top, and 17px LEFT from a turned one, whose bar is down
  its right. So a tapped row rotates 90° where it stands through
  `MiniCard`'s own tween, every row keeps a full 17px of its own name
  band whichever way it faces, and a pile with everything tapped is
  exactly the flat pile turned 90° clockwise (132x174 becomes 174x132).
  The cost is bounded: over all 32 arrangements of five cards the worst
  footprint is 200x132 or 132x200, never both, against 102px of measured
  vertical slack and 400px of horizontal.
  It wears **all three cues at once** — the turn, the 55% wash over its
  mana slashes, and `(T)` in front of the name — on the owner's
  instruction: *"Cards should tap even in the stack — and show tapped
  symbol along with being darker."* They read at different distances (the
  turn across the table, the wash down a column of bars, the letters when
  a card is half covered) and all three rotate with the card. This
  replaced the 2026-09-03 pass, in which the letters were a SUBSTITUTE
  for a turn the clipped row could not perform and the two were mutually
  exclusive; the owner rejected the substitution — *"they do not rotate
  90 deg... they must look tapped!"* Sources, alternatives and reasoning:
  the `[QoL]` section "THE TAPPED CARD IN A PILE" in `docs/ROADMAP.md`.
- Attached cards render as WHOLE MINI CARDS BEHIND their host, stepped
  +6px right and -18px up per attachment so each one's title band shows
  above it and its right edge down the side (the reference's Urza's
  Avenger; s30's `attachedPerms`, forty-first pass).
- The hand bar's ▲ end collapses the pile to bands, ▼ expands
  (s30's handCollapsed "[+]" marker).
- "Fast Effects?" message-bar vocabulary (ported from s30's
  statusMessage) with flashed refusals (warningMsg, 2.5s).
- The spell chain: stack items float at the board's left as MINI CARDS
  under a one-line 1997 caption — `%s casts...` / `%s activates...` /
  `%s processes...` (forty-second pass; Winbk_Spellchain backdrop).
- Modal choices open the reference's Primal Clay dialog: enlarged card
  beside glowing choice lines on the Winbk_Bigcard dark panel.
- CardPreview text alignment fixed: name band along the very top edge
  (title font), art below it, type on its own band, rules inset on the
  textbox.

Fifty-fourth pass (2026-09-04) — **THE HAND WINDOW STOPS MOVING THE
BOARD**, from the owner's playtest: *"When I move my hand stack, also
other cards move on the table. They shouldn't."*

**What it was.** The playfield boundary added the day before
(`_placement_bounds`) subtracted the floating hand window's band from the
placeable area, on the reasoning that the stack hand is opaque, taller
than a card and draggable — the one piece of chrome that can swallow a
mini-card whole. The rows gave up the same band through the same
`_hand_reserve`, so the two could not disagree. And the window drove both
by its `item_rect_changed` signal.

`item_rect_changed` is emitted when a `Control` MOVES, not only when it
resizes. So every drag of the hand window redrew the boundary and
`_reclamp_placements` shoved every placement that now fell outside it,
while the rows re-flowed underneath. **Measured** with a real
press-move-release on the window's grip under `xvfb-run` (`Input.warp_mouse`
plus pushed events — headless has no GUI picking at all): ONE 480px drag
fired `_reclamp_placements` twelve times, moved two of three placed cards
and collapsed both onto the same x, and slid all four of the row's lands
385px sideways. The second suspect — the pile-drag arming
(`_arm_pile_drag`) also walking the hand window's own `CardPile` — was
refuted in the same probe: zero drag handlers are armed on it, because
`_arm_pile_drag` is called only from `_rebuild_field`, on battlefield
piles.

**The ruling.** The owner: *"Yes, the hand stack can be present anywhere —
only cast mini-cards are bound to the playfield."* So the reserve is gone
entirely: `_hand_reserve`, `_apply_hand_reservation` and `HAND_GAP` are
deleted, each half keeps its full inset width wherever the window sits,
and nothing on the board listens to the window. The re-clamp survives and
is wired to **each half's own `resized` and nothing else** — a card parked
at the right edge of a 1920-wide window is still off-screen at 1280, and
that rescue is about the card leaving the screen, not about chrome.

**What happens to a card the window covers.** Nothing, and that is the
point. It keeps its place under the window; the player drags either object
off the other to see it again, and both are theirs to move. The general
rule this pass buys, worth more than the diff: **a placement is a
statement of intent.** A re-clamp is a rescue for a card that would
otherwise be unreachable — never a tidy-up, and never something a piece of
chrome the player is free to move gets to trigger. The maths was right the
whole time; the trigger was wrong.

Pinned by `test_moving_the_hand_window_leaves_every_placement_alone`,
`test_the_hand_window_is_not_subtracted_from_the_playfield` and
`test_the_board_rows_do_not_reflow_when_the_window_moves`
(tests/ui/test_card_placement.gd), and by the three that replaced the
reservation's own in tests/ui/test_duel_screen.gd — including
`test_the_window_is_not_wired_into_the_board_at_all`, which asserts that
nothing on the duel screen is connected to `item_rect_changed`.

Fifty-third pass (2026-09-03) — **THE P/T, AT THE SIZE THE CORNER WAS
ALWAYS MEANT TO CARRY**, from the owner's note: *"The power and defense
numbers on mini cards should be a bit more prominent (mini card builder) —
like original"*, beside a photograph of the 1997 table where a TAPPED
Avenging Ghoul's **6/4** reads across the room from the card's
bottom-right corner. Ours was 14px on a 106px card.

- **Ported as a RATIO, because a ratio is what the original has.** The
  1997 small card has no fixed size at all: `set_smallcard_size` is
  `mainwindow_width / 8` (`shandalar-src/src/functions/windows.c:1088`,
  replacing a literal `sar eax, 3` at `Magic.exe:494d3c`), so the card is
  an eighth of the window however big the window is, and any pixel count
  read off one screenshot would be a number for that screenshot only.
  **[s30]** is the only source that states a type size for the pair:
  its battlefield card is 100x83 and it letters the stats at **20**
  (`duel.go:1360-1364`, `battlefieldCreatureStatsSize`), right-padded 3
  and standing 2 clear of the bottom edge. That is **0.241 of the card's
  height**. On `MiniCard.SIZE` (132x106) the same share is **25**, and the
  padding and clearance scale to 4 and 2 — `MiniCard.PT_FONT_SIZE`,
  `PT_BOX`, `PT_INSET`, all derived in one place with the arithmetic
  written down beside them.
- **OUTLINED, not shadowed**, and this is the same finding the zone column
  reached hours earlier on the pile counts: the numbers sit on whatever
  art the card happens to carry, and a 1px shadow disappears on a pale one
  (Savannah Lions' sand, Serra Angel's sky). `PT_OUTLINE_SIZE` is 4, the
  same as `DuelScreen.PILE_COUNT_OUTLINE_SIZE`, in hard black. The 1997
  renderer backs its card text in the same spirit —
  `draw_text_with_shadow` paints a dark copy of the glyphs before the
  light ones (`drawcardlib.c:1280-1332`) — and an outline is that idea
  made symmetric, which is what a number standing on four different card
  arts needs. The old 1px shadow is gone with it: an outline already backs
  the glyph on all four sides and the two together only muddy it.
- **THE CORNER IS NOW SHARED BY THREE THINGS AND THE ORDER IS DECIDED.**
  The pair owns the bottom-right; the DAMAGE dagger and its count ride
  directly above it (their offsets are now derived from `PT_BOX` rather
  than being loose numbers, so growing the pair pushed them up instead of
  letting it grow through them); the KEYWORD BADGES keep the bottom-LEFT
  and the row is now `PRESET_BOTTOM_WIDE` with its right edge at the
  pair's left edge and `clip_contents = true`, so a card wearing four or
  more badges clips the row rather than running it under the numbers. That
  precedence is stated rather than hoped for: a clipped fifth badge is a
  cost, an unreadable 6/4 is the defect. And the pair keeps its
  `z_index = 1`, so the same day's DYING cracks pass UNDER it.

Shots: `shot_pt_board.png` (a row reading 3/2 green on a Crusaded
Savannah Lions, 6/4 white on Craw Wurm, 5/5 green on a Serra Angel that
also carries the damage dagger and a red 2 directly above it, 3/3 on a
White Knight wearing two badges, a Plains with no numbers at all, and a
TAPPED Hill Giant whose 3/3 turns with the card — the owner's photograph's
own case), `shot_pt_and_death.png` (both of the day's changes in one
corner: the big 2/2 standing over the dying cracks).

Fifty-second pass (2026-09-03) — **THE DYING MARK**, from the owner's
playtest note: *"Killed creatures should have blood state graphic over
them!"* The graphic was already here and had never been seen.

- **What the 1997 `Dying` state IS**, and this is the finding of the pass.
  `@CUECARD_SMALLCARD` (`UIStrings.txt:741`) entry 8 is the word, and the
  small card's own tooltip handler gives the predicate
  (`shandalar-src/src/functions/windows.c:724`, quoting the exe's string
  at `0x786f08`): `else if (instance->kill_code == KILL_DESTROY)`.
  `KILL_DESTROY` (`defs.h:428`) is DESTRUCTION — marked to go to the
  graveyard and not reaped yet. It is the same predicate a regeneration
  effect targets (`defs.h:2481`, `TARGET_SPECIAL_REGENERATION`, refused
  with `Illegal target (not dying).` — Death Ward, Elephant Graveyard,
  Pyramids), and `Duel.hlp`'s **Regeneration** topic says it in words:
  *"You can use regeneration ONLY at the time when a creature is about to
  go to the graveyard."* So `Dying` is NOT "lethal damage marked": Terror
  and Wrath put a creature in the state with no damage at all, and the
  same handler's hit-rect (`5%..95%` of width by `15%..95%` of height —
  the ART window, the rect the summoning-sickness cue shares) says where
  it is drawn.
- **The art is one frame, and it is silver, not red.** `Dying.pic` is
  194x97 — a 97x97 IMAGE beside a 97x97 MASK whose only two indices are 0
  (ink) and 255 (clear), so there is no second drawing in it and nothing
  animates. Its palette is 18 entries and every one of them is a NEUTRAL
  GREY (`[0,0,0]` through `[247,247,246]`): the mark is a field of silver
  CRACKS spreading over the card, not blood. Drawn exactly as
  `Summon.pic`'s spiral is — same 97x97 shape, same art region, same
  `masked_sprite` decode.
- **It is raised off the DEATH, not off the damage** (`DeathMark`, raised
  by `MiniCard._on_game_event` from `Mtg.EventType.DIES`). This engine's
  `MtgGame.destroy` decides and moves in one call, so 1997's window has no
  duration under the modern ruleset — the one place it is held open is
  `awaiting_regeneration`, behind `RulesOptions.damage_prevention_window`,
  off by default and auto-skipped when no seat holds a regeneration
  effect. Hanging the mark on the damage instead would put it on creatures
  that go on to REGENERATE, which is a lie about the board; hanging it on
  the death makes it appear one step late and true. `HOLD`+`FADE` (0.45s +
  0.55s) are **[QoL]** and stand in for a step whose 1997 length was
  however long the player took to pass it (`docs/ROADMAP.md`).
- **A whole card, not bare cracks, and that is also a correctness call.**
  The board re-flows the instant a creature leaves it, so the vacated
  square belongs to a LIVE neighbour within a frame or two; cracks alone
  would be sitting on that neighbour saying IT was the one dying. The dead
  card's own face under them cannot be misread.

Shots: `shot_death_before.png` (Grizzly Bears, Serra Angel, Craw Wurm
clean), `shot_death_mark.png` (Bears destroyed — the cracks over its art
where it stood, and a Drudge Skeletons that was destroyed WITH a shield up
standing tapped and unmarked beside it), `shot_death_mark_fading.png`,
`shot_death_after.png` (the row closed, nothing left), and
`shot_death_lethal_marked.png` (the LIVE overlay: Craw Wurm with four
marked and the sweep deferred — the engine's own regeneration moment).

Fifty-first pass (2026-09-03) — **THE ZONE COLUMN**, from the owner's
photograph of it: *"What is this small number right of the exile stack?
Move this number to the bottom right of the relevant stack and colour it
some contrasting colour so it can be read. There is space right of the
exile stack! Put there the player's chosen portrait, and his name above
it. Same for the opponent — name BELOW the portrait, to be symmetric."*

**The answer to the question: it was the GRAVEYARD's count.**
`_grave_labels` had been built as a bare `Label` appended to the piles row
AFTER the exile plate — a leftover from when one label read "Deck N /
Grave N" for both piles — so it floated in the black gap in the default
theme's WHITE while the library's and the exile's counts sat on their own
art in yellow. It belonged to nothing on screen, which is exactly how it
read.

- **Every count rides the pile it counts** (`_pile_count_label`), in that
  pile's own bottom-right corner, in `PILE_COUNT_INK` — the yellow the
  life numeral, the library and the exile already used — over a 4px black
  outline. The OUTLINE is the fix rather than the hue: the library's count
  had none and stood on a busy card back. One yellow with a hard floor is
  legible over a card scan, a card back, all five painted plates and the
  black column behind them. The graveyard's card list moved to the
  PLATE's tooltip, where it can actually be reached — a `Label` is
  `MOUSE_FILTER_IGNORE`, so the tooltip it used to carry was unreachable.
- **Four columns, three even gaps, spending the row exactly.** The sidebar
  is fixed at `CardPreview.SIZE.x` = 300 so the examined card fills it
  1:1; the mana panel takes 128*0.85 = 109 and the panel row's separation
  6, leaving **185** — now spent as `50 + 5 + 40 + 5 + 40 + 5 + 40`. The
  plates and the portrait are the 1997 grave plate's own 40x60.
- **The deck is 50x61 because it is a STACK, and its thickness is 1997's
  own readout.** `Duel.hlp`, **Library**: *"The number of cards left in
  your library is represented — inexactly, as in real life. If you must
  know, you can right-click on a library to find out the exact number."*
  So `LIBRARY_STEPS = [1, 4, 10, 20, 32, 45]` draws one card back per
  threshold reached, nought to six, redrawn as the library empties
  (`_dress_deck_stack`); the TOP card back never moves — the stack grows
  and shrinks behind it, up and to the left — so the count riding the
  box's corner is right at every depth. A 60-card library opens at six
  sheets, a 40-card one at five, an empty one draws nothing at all.
- **The seat's chosen portrait fills the gap the stray count vacated**
  (`_seat_portrait_block`), through `DuelIntro.portrait_for` so the duel
  and the pre-duel splash cannot disagree about whose face a seat wears —
  and so a seat that chose nothing falls back to its duelist face exactly
  as the splash does. Nothing in a duel read `DuelConfig.portraits`
  before this pass. The name is above the face for the player and below it
  for the opponent, so both hug their own edge of the screen, and it is
  trimmed to the portrait's width with `OVERRUN_TRIM_ELLIPSIS_FORCE` —
  **not** the plain `OVERRUN_TRIM_ELLIPSIS`, which was measured under Xvfb
  at this size trimming "Wolfgang Amadeus Mozart" to "Wolfgan" and
  DROPPING the dots, so a cut name read as a short one. The full name
  stays in the tooltip.
- Divergence, stated: 1997 printed no counts and put no portrait beside
  the piles. Both are `[QoL]`; `docs/ROADMAP.md` carries the row, and
  neither hides a 1997 affordance — `Count library cards`, the
  flip-to-face and the pile viewers are all still there.
- Pinned by `tests/ui/test_zone_column.gd` (23 tests).

Fiftieth pass (2026-09-02) — **THE COIN TOSS, AND WHAT THE 1997 ONE
ACTUALLY WAS.** `game/duel/coin_toss.gd`, `[QoL]` three ways of presenting
the opening toss, and a finding that reframes the feature.

**The 1997 coin toss was not an animation. It was a pre-rendered movie.**
The audio pass of the same day read it out of the decompilation —
`MCIWndCreateA(...)` on `COINTOSS_Heads.AVI` / `COINTOSS_Tails.AVI`, a
10ms poll timer and a 15-second timeout, in `DUEL.EXE`'s dialog proc at
entry `004492ad`. This pass corroborated it from **Tier 1**, twice, and
the corroboration is stronger than the original claim:

- `Program/Magic.exe`'s own string table holds the dialog tag and the two
  movies in three consecutive literals — `DIALOG_COINFLIP`,
  `%s\COINTOSS_Tails.AVI`, `%s\COINTOSS_Heads.AVI`.
- `@DIALOG_COINFLIP` (`s30/assets/text/Uistrings.txt:593-596`, and
  `Program/UIStrings.txt` reads identically) is exactly **two strings** —
  `Coin flip results: Heads` and `Coin flip results: Tails` — one caption
  per movie. The panel used to print a truncated `Coin flip results:` with
  no face after it; it now prints the whole line.

That is why no coin art exists anywhere to import, and it means
`Show coin flip animations` gated PLAYING A MOVIE. Ours is a
reconstruction, and the file says so.

**A second finding changed what "off" means.** The original's entry point
is `coin_flip(int player, const char *dialog_title, int
show_dialog_if_animation_is_off)` (`shandalar-src/src/manalink.h:266`) —
the third parameter is named for exactly this question, and the header's
own comment says it *"should always be 1 except during game startup"*.
**With the switch off the 1997 dialog still appeared; only the movie was
skipped.** Our old `off` showed nothing at all, so the new instant mode is
closer to 1997 than what it replaced.

**THE CODEC, and why the importer now transcodes.** `magvid.dll` — the
original's video DLL — imports `AVIFileOpenA` / `AVIStreamRead` /
`AVIStreamReadFormat` from `AVIFIL32.dll` and carries the fourcc literals
`iv41` / `IV41` / `iv41j` hard-coded beside `LoadAVI` / `PlayAVI`. So the
1997 video codec is **Indeo Video 4.1**, read out of the binary rather
than guessed, and all 69 AVIs surviving in a Manalink install agree (all
`IV41`, 24-bit, 15fps). Godot 4 plays Ogg Theora and has never heard of
AVI; there is no pure-Python Indeo decoder and writing one is not a
reasonable amount of work. `tools/import_original.py` therefore gained its
**first conversion step**: it detects `ffmpeg`, or `gst-launch-1.0` with
`avdec_indeo4`, decodes to raw RGB, and tiles the frames into a sprite
sheet with a `.json` sidecar for the grid — a sheet being what every other
original asset here already is. With neither installed the step is
reported and skipped, never fatal. The pipeline was verified end to end
against genuine 1997 `IV41` footage (the statistics-window animations,
same codec and encoder); **the coin movies themselves are in no reference
tree and could not be tested.**

**THE THREE MODES, one stored value.** `ShowCoinFlips` — the original's
own registry name — now holds `video` / `recreation` / `instant`, and
`DuelOptions.toggle("ShowCoinFlips")` is the 1997 boolean VIEW of it
(ticked = not instant). The Duel Options panel keeps the original's
checkbox, unchanged and still nineteen strings; the `[QoL]` Options screen
offers the whole list. A 1997 registry export still reads: a stored `0`/`1`
maps onto instant / the default. The video entry is shown and DISABLED
when the footage is absent, with the reason on the screen rather than in a
tooltip.

**The instant badge relays the seat, three ways at once** — the struck
coin in the winner's deck colour, a chevron aimed at that seat's half of
the table (the board is not mirrored and the viewer sits at the bottom),
and the seat's name, because a mirror match strikes two identical coins.

**TWO DEFECTS THE SCREENSHOTS CAUGHT AND NO TEST COULD HAVE.**

1. The toss opened **in the top-left corner, half off screen**. Moving the
   panel under a new `CoinToss` node meant its centre anchor now resolved
   against that node, and `set_anchors_preset` alone leaves a freshly
   `new()`ed Control at size (0,0) until its parent happens to re-lay-out
   — which the duel screen, already sized when `_new_game` runs, does not.
   Fixed by setting the offsets and the size in the same frame.
2. The badge's pointer **drew nothing**. It was a `Label` carrying `▼`,
   and `OriginalDialog.ink_label` dresses text in the 1997 body face
   (MPlantin), **which has no triangle glyphs**. It is drawn geometry now
   — pale outline, then ink, so it belongs to the dialog. Worth
   remembering for the graveyard shelf's `◀ ▶`, which only get away with
   it because they fall back to the default font.

Forty-ninth pass (2026-09-02) — **THE SET BADGES**: the title screen now
says what pool it is made of, in a row across its top-left corner
(`game/set_badges.gd`, one badge per `CardRegistry.SET_ORDER` entry).

- **The sheet was measured before anything was built, and it is not what a
  column profile suggests.** `s30/assets/art/card/Cardsets.pic.png` — the
  original's own sheet of the symbols it stamps on a card — is 330x15 and
  holds FIVE 66-wide slots, each of which is a 33x15 IMAGE half and a
  33x15 MASK half, the same image+mask pairing as `Summon.pic` and
  `Dying.pic`. The mask half is the exact complement of the image half's
  ink (palette index 0 where there is ink, index 255 — the file's declared
  transparent index — everywhere else), verified pixel for pixel across
  all five. **There is no sixth slot**: 330 = 5 x 66 exactly, the columns
  that look empty are the mask halves, and a 55-wide grid (the other way
  330 divides) cuts slot 3's ink across a cell boundary. Every glyph is
  right-aligned in its cell, where a printed card carries its expansion
  symbol; the left padding varies 0-18px, so the badges crop to the ink.
- **Which symbol is which set** was settled against the original's own
  file names rather than against a reading of a 15px picture: the five
  slots were rendered at 10x beside the six NAMED `Program/DBArt` glyphs
  (`Dark`, `Legends`, `ArabNite`, `Antiquit`, `Astral`, `Fourth`) at 8x
  and matched by eye. Left to right the strip is **The Dark (crescent),
  Legends (pillar), Arabian nights (scimitar), Antiquities (anvil),
  Astral (comet)** — `drk leg arn atq past`.
- **Fourth Edition is not on that strip, and that is the finding.**
  `DBArt/Fourth.pic` exists (a gold Roman `IV`) and is already imported as
  `set_icon_4ed`, so it is tempting to call 4ed a set with a symbol. It is
  a DECK BUILDER FILTER medallion — `deckdll.cpp`'s
  `draw_filter_button_pic(hdc, r, 5, 20, ... FS_4TH_EDITION)` — and the
  sheet the game stamps on CARDS has no slot for it, exactly as a printed
  Fourth Edition card has no expansion symbol. So 4ed letters itself,
  which is also the form the owner asked for by name.
- **The letters are the product, not the fallback.** No original art is in
  this repository (`Provenance.md`), so a player who has not run the
  importer must see the whole row: `2nd ARN ATQ LEG DRK 4th Astral PR`,
  eight badges, no gaps. The short forms are `GameSkin.set_label`'s — the
  same ones the enlarged card and the Deck Builder's Set filters already
  use — and the full 1997 names (`DeckFilter.SET_LABELS`, the cue cards'
  own wording) are the tooltips. **Astral is named** rather than coded,
  the owner's instruction and the obvious call: its Scryfall code is
  `past`, so the general rule would letter the one set nobody has ever
  seen in print `PAST`.
- **`4th`'s ordinal is drawn, not laid out.** A `RichTextLabel` can change
  size mid-line but not baseline (BBCode has no superscript tag), and two
  `Label`s in a box can only align the small one to the row's top or
  bottom, neither of which is the cap line. `SetBadges.Lettered` asks the
  FONT for its own ascent and puts the suffix a measured 0.28 of it above
  the baseline at 0.62 of its size, and takes its minimum size from the
  same two strings — so it rides the cap line in any face and cannot clip.
- **The glyphs wear the letters' shadow, and it is load-bearing.** The two
  sources hand over art of opposite value — the 1997 strip's glyphs are
  near-black (drawn for a card's pale type line), DBArt's are gold — and
  both land on the same pale sandstone plaque. Screenshotted without a
  shadow the gold set nearly vanished into the stone. Both sources are
  also cropped to their ink: a DBArt medallion is a 35x36 tile with the
  symbol floating in it, so fitting the tiles to a common height fitted
  the PADDING and the first render had a scimitar a third the size of the
  pillar beside it.
- **Still owed**: `tools/import_original.py`'s ART manifest has no row for
  the strip yet (it was being edited by another pass). The badges take
  `set_icon_<code>` — Manalink's DBArt restyle — until it lands:
  `"card_set_symbols": ["Cardsets.pic.png"]`.

Forty-seventh pass (2026-09-01) — **THE M SWEEP**: the four M items in
`docs/duel-todo.md` (§2.4, §2.6, §6.10, §6.14) plus the unbuilt
remainders of §6.3 and §6.12. **Four of the six had something wrong with
them**, and twice it was the item's central claim.

- **§2.4 the spell flies — and the item's [1997] tag does not survive
  contact with the sources** (`game/duel/spell_flight.gd`). The 1997 duel
  is a Win32 application of registered window CLASSES
  (`MAGICGAME_SpellChainClass`, `MAGICGAME_BigCardCardClass`); its ONE
  animation switch is `Show coin flip animations`, and `coin_flip` is the
  only 1997 entry point that takes an "animation is off" argument; and
  `Duel.hlp` closes the Showcase question with *"a display only; it has
  no other function."* So the flight is **[s30]** — kept because it is
  good, labelled because it is a divergence. **What IS 1997 is the
  DESTINATION**: s30 flies the card to its magnifier because s30 has no
  Spell Chain window, and the original has one, so ours flies to the
  chain and then on to the battlefield slot or the graveyard plate. Size
  is not interpolated, which is a fidelity gain: the original has ONE
  card size (`set_smallcard_size`, the forty-second pass), so a
  `MiniCard` at `MiniCard.SIZE` is both ends of the flight.
- **§2.6 per-event dwell.** We have no message queue, so the thing that
  waits is the AI's own pacing timer. `DuelConfig.pace` keeps meaning
  exactly what it meant and maps onto s30's MIDDLE tier, because an AI
  action IS the opponent acting; the other two tiers are its multiples in
  s30's own ratios. Your own turn gets faster (an AI passing priority in
  it is s30's 100ms case) and a blow lingers (600ms). The damage record
  is per PERMANENT, not a total, because a sum would cancel a heal
  against a wound.
- **§6.10 THE REASONS DO NOT CONCATENATE.** The item read Manalink's
  accumulate-into-one-buffer shape and concluded the player reads
  `Illegal target (type,color,tapped).` Every one of
  `validate_target_impl`'s sixty failure sites ends in `goto epilog`, so
  ONE reason is ever appended and the epilog is stripping that one
  string's own leading comma. What the 29 really are is a diagnostic
  PRIORITY ORDER — the table's order and the code's check order run
  together — and that is the half worth having. `TargetSpec.is_legal` is
  now `refusal_reason` asked for a yes or no, so the two cannot drift.
- **§6.14 TWO WIDGETS, MERGED BY THE ITEM.** `@DIALOG_FIREBALL` is X plus
  the target COUNT with the arithmetic between them shown live
  (`game/duel/fireball_dialog.gd`); the divided-damage dial is
  `@PYROTECHNICS` (`prompts.txt:698`) and it is a CLICK LOOP —
  `Select (1st of 4) target creature or player.` — one click per point,
  the same gesture as the combat division. Split, both built, and the
  nineteenth pass's SIMPLIFIED marker lifted. The dialog also fixes a bug
  nobody had reported: **Fireball could not be cast for more than one
  target at a payable X**, because X was priced before the targets and
  the per-target surcharge had nowhere to come from.
- **§6.3 `Show all cards' summoning sickness` is not an on/off switch.**
  The 1997 executable's key is `ShowAllCardsSummonSickness` — *all
  cards*, i.e. whether NON-CREATURE permanents wear the spiral. Our
  engine marks every permanent sick already (CR 302.6, and the original
  played under the pre-Sixth artifact rule), so only the drawing was
  filtered. Concede, Minimize and the ID tags landed with it.
- **§6.12 the item's table was four menus short.**
  `Program/UIStrings.txt:841-947` holds fourteen `@MENU_` tables; the four
  it never mentions are the window menus (`@MENU_ATTACK`,
  `@MENU_SPELLCHAIN` and their minimized twins). All ten remaining tables
  are now in `game/duel/card_menu.gd`, complete and greyed where we
  cannot offer them. The card menu and the card LIFT share one button and
  the original says so in the same breath — holding is what tells them
  apart.

One more defect surfaced while wiring the X dialog: `_on_cancel` LEAKED a
pending cast. It cleared only in TARGETING mode, and none of the three
rungs before targeting — the mode menu, the tutor picker, the X question
— has entered it yet, so backing out of any of them left `_pending_card`,
`_pending_pid` and a parked tutor pre-selection behind.

Forty-sixth pass (2026-09-01) — **THE S SWEEP**: every S item in
`docs/duel-todo.md` worked to completion in one go. Twelve landed, three
were settled by an evidence search rather than by code, and the reason to
write the pass down is that **five of them proved their own to-do item
wrong**. In section order:

- **§2.7 the dying life total falls.** s30's 900ms count + 500ms hold, and
  the End of Duel window awaits it. The number it counts DOWN FROM is
  `_last_life`, which is one repaint behind the engine by construction —
  `MtgGame` deals the lethal damage, emits `game_ended`, and only then
  emits `state_changed`, so at game-over time the array still holds the
  pre-damage life. That invariant has its own test, because it is what
  would break silently if the engine ever emitted in the other order.
- **§2.12 a retuned land wears the new land's art** (`MiniCard.art_name`).
  Filed [s30]; it is [1997]. `Duel.hlp`'s **Original Type** mini-menu
  entry — *"shows you what this card was when it was cast, before any
  spells and effects changed it"* — only earns its place on a table where
  the card in play already shows what it BECAME.
- **§2.13 rows squeeze instead of wrapping** (`game/duel/squeeze_row.gd`).
  s30's pitch arithmetic, generalised to mixed-width children because our
  non-creature rows hold strip-stack piles rather than single cards.
- **§2.14 the Showcase fills itself on a DRAW.** The item asked for s30's
  top-of-chain fallback; `Duel.hlp`'s **Showcase** topic has a rule s30
  does not — *"Cards drawn into your hand are displayed when you draw
  them"* — and we had neither. Both are built; the draw rule needed
  `CARD_DRAWN` to start carrying its `instance`.
- **§2.15 look without touching.** Filed [s30]; the 1997 game has both
  gestures and prints one of them as an accelerator inside the string
  table — `@MENU_SMALLCARD` entry 2 is `Show full card\tR DblClk` — while
  `Duel.hlp` states the other twice: *"You can also right-click and hold
  to bring a card in your hand to the front for as long as you hold the
  mouse button."*
- **§3.3 the lone counter-target**, with s30's three guards intact. Not
  generalised to "any slot with one legal target": there is no undo after
  a cast.
- **§3.6 the hand folds on `H` and on a header click** — and the header
  click had to be reconciled with a 1997 gesture s30 does not have, the
  title bar being the DRAG handle. Movement tells them apart. While
  reading for it, the ▲/▼ turned out to be the original's SCROLL arrows,
  not a fold (`Duel.hlp`, **Hands**, "a **revolving** scroll"); that is
  now a ledgered simplification.
- **§3.7 Done lights whenever Done applies.** Filed [QoL]; `allow_cancel`
  (`shandalar-src/src/defs.h:2390`) is a two-bit spec — 0 none, 1 Cancel,
  2 Done, 3 both — so it is a 1997 question with a 1997 answer.
  `_done_applies()` is written as the deliberate companion of
  `_can_cancel()`: the two predicates ARE the two bits.
- **§3.8 THE SOUND MAP WAS WRONG.** `defs.h:2179` is the 1997 sound enum
  and it groups `White/Blue/Black/Red/Green.wav` under a literal
  `// Land sounds.` comment — we were playing them on every SPELL CAST.
  A spell sounds like its card TYPE (`engine.c:1784-1802`); a land sounds
  like the colours it MAKES (`functions.c:14387-14453`), and a five-colour
  land is silent. Sixteen 1997 files imported. Two of s30's three named
  cues turn out to have no 1997 basis at all: `WAV_COUNTER` is annotated
  in the enum itself as *"a counter has been added to a card", not "a
  spell has been countered"*, and `ManaBall.wav` is not in the duel enum.
- **§3.10 the bar's warning is RED and now expires.** Both "missing"
  targeting states were already there in the original's own wording;
  what was missing was that a refusal looked exactly like a status line,
  and that the flash never ended if nothing else in the duel moved.
- **§6.4 the Duel Options panel** (`game/duel/duel_options.gd`) —
  `@DIALOG_DUELOPTIONS`'s nineteen strings, the original's own registry
  key names, and five switches that really switch something.
- **§6.7 which of the three question frames.** `Triggered effects?...` for
  a trigger on the chain. And `@PROMPT_TURNSEQUENCE` is NOT a set of Done
  labels, whatever the item said: `engine.c:1519` passes its entries as
  response-window captions, the same shape as `@PROMPT_CHECKFEPHASE`.

Settled without code: **§3.4** (no card in the 1997 pool has menace, so
building the pre-flight would mean inventing the restriction it
pre-flights), **§3.9** (worse than written — the engine's own
`StackItem.description` carries neither targets nor X, and s30's
message-bar prefix has no 1997 counterpart), and **§4.2** (the row-order
dispute: `Duel.hlp`, the Manalink source and the string tables are all
silent, so the owner's measured screenshot stands — but the code's own
`Row` comment claimed the opposite and is fixed).

Forty-fifth pass (2026-09-01) — **THE PRE-DUEL EXPERIENCE**: the whole of
`@SHELLPAGE_MULTIDUEL` (`Program/Text.res:2852`, 22 entries), which is the
original's OWN pre-duel parameter screen and the screen ours was always a
partial copy of. Six items, in order.

**1. `<random deck>`** (`Text.res:2866`). The list's first row, above the
decks, verbatim. Resolved off an RNG seeded from the duel's own seed, so a
seed replays which decks were dealt as well as how they were shuffled.
`SetupScreen.random_deck_path` is static and RNG-injected precisely so that
claim is a test rather than a hope.

**2. THE DUELIST'S FACE** (`duel-todo.md` §6.5, `DuelistFace`). `Duel.hlp`
has a topic of that name and it is the whole specification: the life
register turns over from its own mini-menu (`@MENU_LIFE`'s `Flip over to
face` / `@MENU_FACE`'s `Flip back to lifepoints` — two tables differing in
one entry, which is the string tables saying these are two faces of one
panel), turns over BY ITSELF while a spell could take a player as a target,
and turns back *"automatically"* when it could not. All three are built; the
automatic flip is derived from the pending `TargetSpec` every refresh rather
than stored, which is what makes the flip back free.

**THE ART, AND A TRAP.** `Program/DuelArt/Face_*.pic` — the obvious files,
never imported before — are **five byte-identical copies of one flat grey
gradient** (md5 `88f7c83f…`, a 468x312 RGBA PNG wearing a `.pic` extension):
Manalink's placeholder, the same restyle-not-original trap the dialog
grounds were already documented for. The real faces are `Life_<colour>pict.pic`
— one PICTURE filling the 120x88 register, a different duelist per colour —
which this project was ALREADY importing, as `life_panel_*`, and drawing the
life total across. So the panel had one face used twice and nothing to flip
to. Corrected: `life_panel_*` now names `Life_<colour>patt`, the seamless
wallpaper a numeral belongs on, and `duelist_face_*` names the portrait. The
`Terr_<colour>` trio settles the naming — `patt` is the pattern, `pict`
the picture — though the forty-eighth pass found the two trios are the
same NAMES rather than the same art, and that at territory size `patt`
carries a decorative border and `mana` quilts all five glyphs. (The genuine `Face_*.pic` does survive, 240x170 with a sixth MULTI
variant, inside a 7z in `shandalar-src`'s git object store; it is a
different, larger asset — the pre-duel Versus portrait — four of its six
entries were colour-reduced by the mod author, and the importer's MANIFEST
comment records where it is so nobody searches again.)

**3. DECK GROUPS** (`DeckGroups`). Provenance, answered two ways: the
player's decks are known by their PATH (`user://decks`), because a file
must not be able to claim it is a 1997 original; everything else declares
itself with a `# group:` line, which rides as a comment `DeckList.parse`
already skips — the same trick `# note:` uses, and the reason every deck
file written before this still loads. The owner named three groups; a
fourth, `Starter decks`, exists because this project's own five decks are
neither 1997's nor the expansion's and filing them under either would be a
false claim.

**4. BEST-OF-N AND THE SIDEBOARD** (`MatchState`, `MatchScreen`) — the
structural one, and the reason the original's screen exists: it sets up a
MATCH, not a duel. `&Free play` or `&Best of:` 3 or 5 — three and five
because `@DIALOG_ENDEXP1DUEL_MATCHPROGRESS` (`UIStrings.txt:553`) ships
exactly two record lines and writes the number into the sentence, so a best
of seven would mean printing a line the original never wrote. `MatchScreen`
owns the sequence and the duel screen learns one new thing, a
`duel_finished` signal; the between-duels window is the original's own,
entry for entry (`Side&board...`, `&Edit deck...` greyed, `&Continue match`,
`&Quit match`). Each duel draws its seed from the match's, so duel 3 is
reproducible as duel 3 of that match.

**5. THE FIVE FORMATS** (`DeckFormat`). Not from the manual and not from
`Duel.hlp` — neither documents them at all; the manual's "Restricted" is a
different thing entirely (a Deck Builder card filter, p.147/p.180). The
rules come from the game's own `check_deck_type()`
(`shandalar-src/src/deck/deckdll.cpp:2908-2954`), whose five branches are
reproduced one for one, corroborated by MicroProse's own ManaLink 1.3
readme. **No 1997 banned/restricted list survives anywhere**; the list used
started as the game's modern one, on the reasoning that the 1997 card pool
would do the historical filtering for us. **That reasoning was wrong and was
corrected on 2026-09-01** — it filters cards ADDED to the list since 1997
but cannot restore the eleven REMOVED from it, all of which are in our pool
and were going unflagged. The list is now the union of the modern table and
the DCI's own Classic (Type 1) list as printed in *The Duelist* #22
(1 January 1998); see `engine/deck_format.gd`'s header and
`docs/ROADMAP.md`. Two Help pages say all of that on the page, because a
help screen that fills a gap with a plausible invention is worse than one
that admits the gap.

**6. THE SEED FIELD** — marked `[QoL]`, because the original had nothing
like it. Every duel already ran on a seed and already logged it; the only
missing piece was a box to type the number back into.

**AND THE CLI.** Everything above, plus `--lives`, `--ante`, `--names` and
the six rules forks, is now reachable from the Deck Lab. A setting only the
GUI can set is a setting only a human clicking can exercise.

Forty-fourth pass (2026-09-01) — **THE LAST FOUR QUESTIONS, AND THEY DO NOT
NEED A SNAPSHOT** (`duel-todo.md` §1.3, closing it).

The thirty-ninth pass gave the player 103 of the engine's 109 mid-resolution
questions by PRE-FLIGHTING each stack resolution over a `GameSnapshot`. Four
were left, and they were left because they are not resolutions at all: a mana
ability's *"Sacrifice a creature"* and Fellwar Stone's colour (a mana ability
never uses the stack, CR 605.3a), and the *"as an additional cost, sacrifice
a creature"* of a cast and of an activation (paid before the object reaches
the stack, CR 601.2h). Nothing on the stack, nothing to probe.

**They need much less than a probe.** All four are asked at a point the
2026-09-01 refusal-order fix created: after the whole cost has been checked
(so no refusal is left) and before any of it is paid (so nothing has been
mutated). At that point the hold does not have to be able to UNDO anything —
it only has to be able to DO the same thing again. So `_hold_cost_choice`
parks a record of the call in `MtgGame._pending_action` —
`{"kind", "pid", "inst", "targets", "x", "mode"/"index"}` — sets
`awaiting_choice` and returns `""`, and `answer_choice` parks the answer on
the seat's agent and re-issues the action, which now serves it from the
mailbox. Two counters (`_cost_answers` / `_cost_asked`) let a replay serve
the answers it already has and stop on the next question, so an action with
two of them stops twice instead of looping.

**The screen needed almost nothing, which is the point.** The overlay is
raised from `_refresh` on `game.awaiting_choice`, so it comes up for a cost
question exactly as it does for a resolution's, and `_on_choice_option` →
`answer_choice` already carries the answer back. Three edits:

- `_choice_source_card` also looks in the asking seat's HAND. A cast's
  additional cost is paid while the spell is still in hand, so that is where
  its face is — Metamorphosis now shows its own card beside its own question.
- `choice_question` uses the source's own line for a COST colour question
  instead of the generic `Select a color.` The original has both:
  `@ALCHORS_TOMB` (`promptsX2.txt:11`) titles a colour chosen mid-resolution,
  and `@MULTIMANA` (`Text.res:2057-2059`) titles one chosen as a source is
  TAPPED — `%s: What kind of mana?`, which `@FELLWAR_STONE`
  (`prompts.txt:372-374`) spells out as `Fellwar Stone: What kind of mana?`
  `PlayerChoice.is_cost` is what tells the two apart.
- `choice_colors` narrows the colour lines to what the source actually
  offers. Fellwar Stone lends only the colours the opponent's lands could
  make; listing five and substituting away the two the player cannot have
  would be a lie in the dialog.

The sacrifice wording is the original's generic one, because the original's
is generic too: `@SACRIFICE_CREATURE` / `@SACRIFICE_ARTIFACT` /
`@SACRIFICE_ENCHANTMENT` / `@SACRIFICE_LAND` (`Text.res:2645-2659`) are all
`Select <what> to sacrifice.`, `@SACRIFICE_LANDS` (`:2661-2667`) spells the
five basics in lower case, and every per-card tag from `@METAMORPHOSIS` to
`@LIFE_CHISEL` repeats the same sentence. `PlayerChoice.sacrifice_prompt`
builds it from the cost's own description. There is no `Cancel.` line: a
cost's sacrifice is not optional (CR 601.2h), and the overlay only offers one
where declining is legal.

**What the verification found, and it was not what the entry predicted.**
Three of the four sites really were clean at the moment they asked.
Fellwar Stone was not: its colour was asked from inside the card's
`ManaAbility.dynamic_color`, which `tap_for_mana` calls *after* the source is
tapped and the cost paid — a replay would have been refused with "already
tapped" — and it was asked TWICE per activation, once for the mana trigger's
colour and once inside `produce_into_for`, so a parked answer would have been
served to the first ask and the heuristic to the second. Both are fixed by
moving the ASK out of the card: `ManaAbility.color_options` returns the
CENSUS, `tap_for_mana` asks once before anything is paid, and
`produce_into_for(..., forced_color)` is told the answer instead of asking
again.

Shot: `shot_choice_sacrifice.png` — Metamorphosis cast with a Grizzly Bears,
a Hill Giant and a Serra Angel on the table, the spell's own face on the left
of the Winbk_Bigcard panel and three numbered bodies on the right.

Forty-third pass (2026-09-01) — **THE OPENING IS ONE WINDOW, AND IT HAS A
STAKE IN IT** (`duel-todo.md` §6.2, §6.19).

Two faults, one composition. **First: nothing ever staked an ante.** The
engine had the zone, `move_to_ante`, `ante_top_of_library`, a `CARD_IN_ANTE`
target kind and a graveyard viewer that already listed an ante pile — and no
duel ever put a card in it, so all of that was furniture around an empty
room. `MtgGame.stake_ante` fills it (see §6.19 for what the manual says ante
actually is). **Second: we opened the duel with two grey-stone popups** —
a 420x220 `panel_dark_stone` for play-or-draw and a 460x250 one for the
mulligan, the latter listing the hand as comma-separated card names, which
is nowhere in the 1997 table. `@DIALOG_MULLIGAN` is TWELVE entries and they
describe ONE window: who takes the first turn, `%s ante:` / `Your ante:`,
four lines naming the kind of hand the opponent threw away, two more for the
courtesy offer, and `Take &mulligan` / `&Start the duel`. A dialog that
shows the antes is a dialog that stays up while the antes matter.

**`OpeningWindow` (`game/duel/opening_window.gd`)** is that window, composed
region for region off the owner's 1997 screenshot: the first-turn line at
top left, the opponent's mulligan status at top right, `Your ante:` and
`%s ante:` over two full cards side by side, and the two buttons under them.
It opens after the coin toss, asks play-or-draw in its own button row, then
the mulligan, and closes on `Start the duel` — the player always presses
last, so an AI decision that lands after their press holds the window for
one more look rather than flashing past.

**THE GROUND is `Winbk_Startduel.pic`** (`versus_background`, 659x394 —
measured: 3px of dithered highlight along top+left, 3px of shadow along
bottom+right, hence a patch margin of 4, and it STRETCHES because it is a
picture). It was imported months ago and used only by the battle-setup
screen; the start-of-duel window is the thing it is named after.

**THE ONE-CARD-SIZE RULE DECIDED THE GEOMETRY, and the measurement is the
point.** Two `CardPreview`s at their own 300x428 may not shrink, so the
window is sized around them and not the other way round:

| | px |
|---|---|
| column margin, top + bottom | 32 |
| head band (two lines of 16px type) | 44 |
| body separation | 8 |
| `Your ante:` caption + its gap | 24 |
| **the card — not negotiable** | **428** |
| body-to-buttons separation | 10 |
| button row (`Winbk_Startduelbutton` is 131x36) | 38 |
| **height** | **584** |

Width then follows the ground's own aspect (584 x 659/394 = **977**), which
is a uniform 1.48x scale of the picture rather than a stretch into a
different shape — and 977 is comfortably more than the 660 the two cards and
their margins need, so the classical figures show around the cards exactly
as the screenshot has them. **977x584 fits both supported window sizes**:
1280x800 leaves 151px each side and 108 above and below, and 1280x720 leaves
the same 151 and 68. Nothing is scaled at either. Pinned by
`tests/ui/test_opening_hand.gd`.

One thing the pass changed in shared chrome: the window's buttons take
`Winbk_Startduelbutton*.pic`'s OWN 131x36. `OriginalDialog.button` defaults
to 96x26, at which `Take mulligan` crowds its own double rule — visible at
3x in the first capture of this pass.

Captured by `tools/screenshot_tour.gd` as `shot_opening_window.png` (live —
those are the two cards the duel really staked, and the tour now WAITS for
the window instead of sleeping towards it, having first photographed the
coin dialog fading) and `shot_opening_mulligan.png` (staged: a qualifying
hand is rare, so the composition the screenshot froze would otherwise never
reach the review set).

Forty-second pass (2026-09-01) — **A CHAIN OBJECT IS A CARD**: the spell
chain was the last place on the board where a card was not a `MiniCard`.

`_rebuild_stack` drew each waiting spell as the Scryfall SCAN, **portrait,
at width 104**, with a `CardPreview` scaled to `104/300` as the fallback
when no scan existed, under a two-line tan caption reading
`Ability Effect` / `Triggered Ability` / `<player> casts` over the source's
name. Everything about that is now replaced.

**THIS REVERSES A JUDGEMENT MADE IN THE FORTIETH PASS'S AUDIT.** That
audit looked at this exact `face.scale` and cleared it: *"Legitimate — it
is an icon in a strip, not a card on the table"*, reasoning that the
chain's primary rendering was the scan and the scaled Showcase was only
its fallback. The reasoning was sound against the evidence it had, which
was s30's chain. **The owner then produced the 1997 reference, and the
reference overrules it.** The entry in that audit's "THE SCALES THAT STAY"
list is struck through below; the other two survive unchanged.

*The reference*: the Urza's Avenger screenshot — a **gold `Ability Effect`
band**, a name under it, and then a **landscape small card**: art window,
`3/3` in the corner. Not a portrait photograph of a card. The same
screenshot the forty-first pass read for attachments, and it says the same
thing here.

*What the original actually does*, which settles it beyond the picture:

- `windows.c:1088` `set_smallcard_size(mainwindow_width)` writes **one
  global** `smallcard_width`/`smallcard_height` (default `width / 8`) that
  every card in the duel is drawn at. There is no second card size in the
  executable to give the chain.
- Every chain object goes through `DrawSmallCard` + `DrawSmallCardTitle`
  (`windows.c:1446`, `:1499`) — the same pair the battlefield uses. The
  *title bar of the small card* is where its name goes, which is why our
  caption no longer repeats the name: the card titles itself.
- The reference's `Ability Effect` is **not** a UI string and not s30's
  invention (as `duel-todo.md` §6.6 assumed). It is per-card data:
  `Legacy.csv` column 4, `Effect Title`, row
  `0539,"Urza's Avenger","","Ability Effect",…`, read by
  `windows.c:1533` for csvid-903 effect cards. We ship no effect-card
  table, so we cannot say it truthfully for an arbitrary card.

*The caption is therefore the original's generic chain wording*, from the
tags that caption chain objects, with the **X on the object** where the
original puts it:

```
@PROMPT_CAST1  Program/UIStrings.txt:1118   %s casts...     / …\nX is %d.
@PROMPT_TAP1                         :1123   %s activates... / …\nX is %d.
@PROMPT_PROC1                        :1134   %s processes... / …\nX is %d.
```

The `%s` is the PLAYER, not the card: `src/functions/events.c:563` loads
`PROMPT_PROC1` and fills it with `opponent_name`. (`Duel.hlp`'s **Spell
Chain** topic names two more states we do not model — a spell is
*"Trying to Cast"* before it is *"Casting"* — logged in `duel-todo.md`
§6.6.)

**The strip measures**, off `shot_duel_spell_chain.png` at 1280x800:
each object is one card wide, **132px, x 362..494**, inside a board that
starts at x=366 and runs to 1280 — the extra 28px over the old 104 costs
nothing. Vertically the pitch went **DOWN**: 18px caption + 106px card +
6px separation = **132 per object**, against 180 for the old portrait
scan. Measured bands at 150..169, 282..301, 415..450 (that one two-line,
carrying `X is 3.`), last card ending at 556. So the strip holds **four**
full-size chain objects between y=150 and the 800px floor where it held
three, and 1280x720 is the same 800 logical rows (`canvas_items` +
`expand` scales 0.9 and widens to 1422). A **fifth** object would end at
810 and clip; that is logged rather than papered over, because the 1997
answer to a chain that long is the Spell Chain WINDOW with its own title
bar and minimise (`duel-todo.md` §6.5), not a smaller card. The Situation
Bar crosses the strip at y≈386 and is drawn — and picked — ON TOP of it
(later sibling, `z_index` 90 vs 80), which is what a floating window over
a board does.

**Behaviour gained, none lost.** The chain object goes through
`_make_card` like every other card, so it is now hover-docked in the
Showcase and CLICKABLE — which is how a counterspell takes a chain object
as its target (`_on_card_clicked` → `_try_take_target`), and the Spell
Chain window is where `Duel.hlp` says that happens. `item.description`
(the targets line) is prepended to the card's own tooltip, because a
`Button` stops Godot's tooltip walk at itself and the entry's copy would
never be reached. A knock-on: `TargetArrows._cast_origin` finds a widget
for a spell on the chain now, so amber arrows spring from the chain object
instead of falling back to the caster's hand panel — `Duel.hlp`: *"The
spell in progress, any other spells in the batch, and all their targets
are displayed."* (`test_target_arrows.gd`'s no-widget case had staged its
ghost as both source and target; it now uses a separate stack-zone card,
or it would have been measuring nothing.)

Pinned by `tests/ui/test_card_dimensions.gd`
(`test_the_spell_chain_is_made_of_whole_cards`,
`test_a_triggered_ability_on_the_chain_says_processes`): three objects
deep, every one 132x106 at scale 1, every entry exactly one card wide,
the three captions verbatim, and the name absent from the band.

Forty-first pass (2026-09-01) — **AN ATTACHED CARD IS A CARD**, drawn
behind its host and peeking out over its top-right shoulder.

The report came with two pictures. Ours: Savannah Lions under a flat grey
strip lettered *Artifact Ward*, with `◆1 aura` written across the lion.
His 1997 reference: Urza's Avenger with a second, YELLOW card behind it —
the title bar of *Ability Effect* showing above the host's own title bar,
and the yellow frame's right edge running down the host's right side. The
ask: *"mimicking a mini card beneath and seen on the right and top of mini
card."*

**WHAT WE HAD WAS S30'S FALLBACK PATH, SHIPPED AS THE DESIGN.** The code
comment claimed the reference it was diverging from — *"s30 draws each aura
offset -14px behind its host"* — while building a 16px `Button` in a
`StyleBoxFlat` of the aura's darkened frame colour and gluing it on top.
s30's real branch (`game/screens/duel/duel.go:3223-3242`) is:

```go
auras := s.attachedPerms(perm.ID)
for j, aura := range slices.Backward(auras) {        // furthest drawn first
    auraY := pos.Y - (j+1)*14
    auraImg := s.getCardArtImg(aura.Name, fieldCardW)   // a WHOLE CARD
    if auraImg != nil {
        auraOpts.GeoM.Translate(float64(pos.X), float64(auraY))
        screen.DrawImage(auraImg, auraOpts)
    } else {
        vector.FillRect(..., fieldCardW, 14, ...)       // ONLY if art missing
        elements.NewText(10, aura.Name, pos.X+4, auraY+2).Draw(...)
    }
}
```

The full card is the design; the 14px name strip is what it falls back to
when the art will not load. The host is blitted *after*, so it overlaps.

**THE STEP, `DuelScreen.AURA_PEEK` = (6, 18).**

| | value | where it comes from |
|---|---|---|
| up | **18px** | s30's `-14` on an 83px-tall field card, carried onto ours: 14 × 106/83 = 17.9. It lands on 18 a second, independent way — a `MiniCard`'s title bar runs y=2..18 (`MiniCard._build_face`), so an 18px reveal is EXACTLY one whole name band and none of the art below it. Two derivations agreeing is why it is right. |
| right | **6px** | s30 has no horizontal step — it stacks dead vertically — but the original does, which is the half of the ask s30 could not answer. Measured off the reference: the yellow card is revealed 43px to the right of a 948px-wide host = 4.5% of the card's width = 5.9px on our 132px card. |

Per-attachment, both axes, so several auras FAN rather than pile: three on
a Shivan Dragon give three legible title bars stepping up and to the right
and three distinct frame-coloured slivers down the side (verified at 3x on
`shot_duel_card_badges.png`). A 6px sliver is 18px at the 3x the board is
read at, and carries enough frame texture to be seen against both the host
and the board.

Ordering is s30's: `attachments[0]` sits ONE step out and is added LAST of
the fan, so it draws over its neighbours and a newly resolved aura lands on
the OUTSIDE — nothing already on the card moves.

**THE FAN RESERVES WIDTH BUT NOT HEIGHT, and that asymmetry is the whole
reason the row still reads.** The first cut reserved both, and the capture
showed the defect the fortieth pass exists to prevent, in its other form:
the line grows by the fan's height, `SHRINK_CENTER` re-centres everything
in it, and the enchanted host drops half the fan below its neighbours — 9px
with one aura, **27px with three** — with the whole row jolting upward the
moment an aura resolves. So the wrap reserves a PLAIN CARD'S HEIGHT and the
fan overflows upward instead, which is what s30 does anyway (its field
cards sit on the fixed grid of `getFieldCardPos` and the aura is drawn at
`pos.Y - 14` over whatever is up there). The host then keeps exactly the
footprint it would have with no aura at all: same row centre line, no jump
when one attaches, and a tap still pivots in place. The overflow is safe
because both creature rows are the LAST row of their board half, under an
expanding spacer, so it lands in empty board and inside that half's own
`clip_contents`. Width IS reserved, because the card to the right sits at
the same height and would otherwise be overlapped.

**Behaviour kept, in one place instead of two.** The band had been
hand-wired with its own `pressed` and hover connections to keep it
clickable and to drive the Showcase. `_make_widget`'s card-building half
is now `DuelScreen._make_card`, and an attachment goes through it like any
other card — so it arrives already clickable, already hovering the enlarged
view, already carrying its highlight and its `@CUECARD_SMALLCARD` state,
and is a `MiniCard` at `MiniCard.SIZE` like everything else on the table.
Mostly hidden, never shrunk.

**The `◆N aura` chip is GONE** (`MiniCard.refresh`). It was written across
the host's ART, where the reference leaves the picture clear, and it only
ever existed because the attachments themselves were drawn as something
unrecognisable. The peeking cards now say it better and say WHICH — and
they can be hovered and clicked, which a chip never could. The one place
that loses a marker is an enchanted permanent buried in a five-card
`CardPile`, where the chip was already clipped away on every card but the
front one.

Pinned by three tests in `tests/ui/test_card_dimensions.gd`:

* `test_an_attachment_is_a_whole_card_behind_its_host` — host 132x106,
  every attachment 132x106, one `AURA_PEEK` step out each, drawn before the
  host, wrap height equal to a plain card's, and no `aura` text left on the
  host's status line;
* `test_an_attachment_follows_a_tapped_host_to_its_turned_corner` — the fan
  anchors to the TURNED card's visible corner (4,4 inside its holder), not
  the holder's, and the wrap reserves the attachment's own 132 rather than
  the 106 a turned host shows;
* `test_the_peeking_strip_of_an_attachment_still_answers_the_mouse` — a
  real `InputEventMouseMotion` at the exposed strip, asserting both that
  Godot's picker reaches it (it is drawn OUTSIDE its wrap's rectangle and
  inside a `clip_contents` board half — either could have swallowed it;
  `Viewport::_gui_find_control_at_pos` only stops descending at a control
  that clips) and that the Showcase docks the ATTACHMENT's card, not the
  host's.

Fortieth pass (2026-09-01) — **ONE CARD SIZE, EVERYWHERE**, the owner's
standing rule, audited end to end and then pinned by measurement.

The report was four observations in one sentence: *"In the hand stack I see
one dimension of mini cards, on the bottom the other, tapped minicards look
again a bit different, and the Crusade card on the table again looks
different height! Didn't we say we keep only ONE dimension of mini cards
(the same, just rotated smoothly for tapping)?"*

**THE CAUSE OF THE ONE NOBODY COULD FIND — AND NO CONSTANT ANYWHERE SAID
IT.** `FlowContainer` and `BoxContainer` STRETCH a child carrying the
default `SIZE_FILL` to the height of its line (`flow_container.cpp`: *"if
(child->get_v_size_flags() & SIZE_FILL) child_size.height = line_height"*).
The battlefield rows are `HFlowContainer`s that also hold things TALLER
than a card:

| what | how tall |
|---|---|
| a card | `MiniCard.SIZE.y` = **106** |
| a TAPPED card's holder (the rotated footprint) | `SIZE.x + 8` = **140** |
| a five-card `CardPile` | `4 * 17 + 106` = **174** |
| a card wearing auras | `106 + 16 per aura` |

So every plain card standing beside one of those was drawn 140 or 174
pixels tall. Nothing was rescaled and no number was wrong; the widget was
simply handed the wrong rectangle, and the name band, the mana stripes, the
badges, the damage marker and the P/T — all anchored as FRACTIONS of the
face — went with it. That is exactly why a lone Crusade beside a land pile
"looks a different height", and why an untapped creature beside a tapped
one did too. `tests/ui/test_card_dimensions.gd` measured it at **140 vs
106** before the fix and pins it at 106 after.

The fix is structural rather than per-call-site: `MiniCard._init` now sets
`SIZE_SHRINK_CENTER` on both axes, so **no caller anywhere can forget**
(`graveyard_view.gd` had been setting it card by card since the
thirty-third pass — that is now the default and its two lines are gone).
`CardPile`, the tap holder and the aura wrap shrink too, which also gives a
row ONE CENTRE LINE: a card pivots in place when it taps instead of sliding
as its holder changes shape.

**THE FAN WAS THE SECOND CARD SIZE.** `fan_hand.gd` carried
`const CARD_SIZE := Vector2(96, 120)` — TALLER than wide, where a mini card
is 132x106, WIDER than tall — and forced it onto every card it dealt. It is
the same defect `graveyard_view.gd` had with its own `Vector2(96, 134)`,
and the fan is a live Options setting ("Hand display: Fan of cards"), so it
is what the owner sees whenever that is chosen. `CARD_SIZE` is now an ALIAS
of `MiniCard.SIZE`, and every number the fan derived from it is derived
again rather than measured: `MAX_SPACING` is three quarters of a card (it
was a bare `72.0`, which WAS three quarters of 96 and then went stale) and
`ONE_ROW_HEIGHT` is `8 + ARC_DROP + SIZE.y + 12` (it was a bare `150.0`).
`MIN_SPACING` stays 56 and the reason is written down: it is an exposure in
PIXELS of name, and the name font is one fixed size and starts 6px inside
the card whatever the card's width. Per the owner's graveyard ruling, when
a row no longer fits the COUNT gives, never the size — the fan already had
a second row for that.

**TWO DEAD CONSTANTS DELETED.** `CardPile.FACE_SCALE` / `FACE_HEIGHT`
derived a 188px face by scaling `CardPreview.SIZE` down to a pile's width.
No code read them; only one test did, as a loose upper bound. They dated
from a pile whose last card was a shrunken ENLARGED card, which has not
existed since the twelfth pass made every card in the game a `MiniCard`,
and left in place they implied a second card size.

**THE TAP TURN IS NOW RESUMED, NOT SNAPPED.** The rotation was already
correct — exactly 90°, no rescale, the holder reserving the swapped
footprint — but the board is immediate-mode and tapping a land for mana
fires several `_refresh`es inside the 0.22s the turn takes. Each one freed
the widget mid-tween, and `_tapped_seen` stored a bare `true`, so the
replacement took the "already turned" branch and jumped the rest of the
way. It now stores WHEN the turn began, and the new widget picks the
animation up at the angle the old one had reached
(`Tween.interpolate_value`). The ease went from `TRANS_BACK` to `TRANS_QUAD`
for the same reason: an overshoot restarted from a resumed angle wobbles,
where a monotone curve carries on. The dictionary also forgot a card only
while it was still on the battlefield, so a creature bounced tapped and
recast arrived at 90° with no turn at all.

**Since 2026-09-03 the whole of that lives in `MiniCard`** —
`tap_turn()`, `turn_angle()`, `turn_holder()` and the static `_turn_book`
— because the card is the thing that knows whether it is tapped. The
holder is still the parent's job (a `Container` zeroes a child's rotation
on every sort), and a parent opts a card in by giving it a CENTRE PIVOT.
Two things the move added: the turn is KILLED rather than joined when a
second one starts, and a headless run — which draws no frames — lands the
final angle at once instead of leaving it wherever the first frame's delta
fell. See the `[QoL]` section in `docs/ROADMAP.md`.

**THE SCALES THAT STAY, AND WHY.** Three `.scale` assignments survive the
audit, and all three are on `CardPreview` — the ENLARGED card — not on a
mini card. The rule is about the mini card's ONE dimension; the big card
has always been a different object.

- `duel_screen.gd` `_open_mode_menu` and `_build_choice_overlay`, **0.9**:
  the 300x428 Showcase inside the 552x402 `Winbk_Bigcard` panel, whose size
  is the 1997 dialog's own. 0.9 makes it 270x385 and it fits with 5px to
  spare. Growing the dialog instead would falsify a measured 1997 window to
  avoid scaling a card that is not a table card. **Legitimate.**
- ~~`_rebuild_stack`, **104/300**: a spell-chain thumbnail. The chain's
  PRIMARY rendering is the real card SCAN at width 104 (a photograph of a
  card, portrait); the scaled Showcase is only the fallback for a card we
  have no scan of, and it matches that branch's aspect. A MiniCard here
  would make the fallback look nothing like the thing it stands in for.
  **Legitimate — it is an icon in a strip, not a card on the table.**~~
  **REVERSED BY THE FORTY-SECOND PASS.** The premise — that the chain's
  primary rendering is a portrait scan — was s30's, and it is wrong: the
  owner's 1997 reference shows a landscape small card, and
  `windows.c` draws every chain object with the same `DrawSmallCard` off
  the same single global `smallcard_width` as the battlefield. There is no
  icon-in-a-strip in the original, so there is no exception to grant. Both
  branches are gone; a chain object is a `MiniCard` at 132x106, unscaled.
- `deck_builder/card_area.gd`, `_card_scale`: the inventory grid's own zoom
  control. A different device on a different screen; not this pass's, and
  not a table card. **Legitimate.**

**AND THE OPPONENT'S HAND, which was the same bug wearing different
clothes** (`duel-todo.md` §9.1). *"The opponent hand stack is cropped at
left end."* It was a disabled `Button` wearing the raw 145x51
`hand_panel_<colour>` sheet as an UNPATCHED `StyleBoxTexture` at 150x22 — so
the whole window, border and speckled bar and the ▲ painted into its left
edge at x 1..9, was scaled into a strip less than half its height. And the
chip then wrote `↑ Opponent (5) ↓` on top of the arrow pair the sheet
already paints, so each arrow appeared twice.

Manual p.114 settles what it should be: *"Only the title bar of your
opponent's hand is visible; this is to keep you aware of how many cards are
in that hand."* So it is not a chip at all — it is THIS WINDOW with no list
under it, and `StackHand.title_plate` now builds it: the same made-whole
nine-patch, the same 11/36/11/7 patch margins, the same tiled vertical
axis, the same label placement past the painted ▲. **The arrows are the
texture's and the text has none** — s30 does exactly this
(`drawHandPanel`'s label is `Opp Hand (%d)`, no arrows, over an untouched
`handBg`). The word is the original's: `@WINDOWTITLES` (`UIStrings.txt:155`)
gives this window `Opponent`; the `(N)` is [QoL] in the form our own
`Your hand (N)` already uses, and it is the reason the manual gives for
showing the bar at all.

**THE ILLUSTRATOR CREDIT** (`Illus. <name>`, bottom-left of the Showcase).
`Duel.hlp`'s "Parts of the Card" topic numbers twelve labelled parts and
part **6 is `Artist`**; we drew eleven of the twelve. The help screen's own
card-anatomy page already described it (*"The ARTIST's name is beside them,
and means nothing to the duel"*) — it was documenting something the
Showcase did not draw.

The data did not exist: `tools/fetch_cards.py` trims the Scryfall response
to an explicit field list and `artist` was not in it. It is now, and
`cards/data/` was refreshed — 1300 records gained exactly one key each and
**nothing else changed** (diffed field by field against the previous
snapshot; every record has an artist). It reaches `CardData.artist` the way
`set_code` does, filled in by the `CardRegistry` loader from that snapshot,
so no card file and no generator is touched: a credit is metadata about a
printing, not behaviour. Scryfall rather than the original's own
`Master.csv` because the ART we display comes from Scryfall for the same
set and collector number, so this is the credit for the picture on screen.
It sits at 0.075-0.56 of the bottom border, where the P/T box starts at
0.58, so a long name and a `10/10` cannot collide; an empty artist draws
NOTHING, never a bare `Illus. `.

**THE MANA SYMBOLS IN THE RULES TEXT** (2026-09-04, the owner: *"The text
has special symbols `{R}`, `{B}` etc. for mana and `{T}` for tap. Can we
replace these in the text with actual mana and tapping symbols?"*).

**Yes, and the original did.** The evidence is its own shipped card
database. `../shandalar-xp/MagicTG/Master.csv` (**Tier 1**, dated
1997-08-14 in the owner's install) is
`ID,Card Name,Type Description,Artist Name,Rule Text,Quote`, and the Rule
Text column carries the symbols INSIDE the sentence, pipe-escaped:

    0230,Sol Ring,Artifact,Mark Tedin,|T: to add |2 to pool - Interrupt,
    0057,Dark Ritual,...,Add |B|B|B to your mana pool.

338 of its 1 251 rows carry a tag, and the commonest by a wide margin is
**`|T` — 204 rows**. That is decisive on its own: **tap is never part of a
mana cost**, so those 204 symbols can only ever have been drawn in the
rules-text body. The vocabulary is `|X`, `|0`..`|9`, `|W|U|B|R|G` and `|T`
— exactly the nineteen cells of `Cardart/Manasymbols.pic` (342x18,
1996-10-29) and nothing more. `Info.csv` beside it stores the CASTING COST
as a packed numeric field instead (`000001` = Sol Ring), which is why the
original's renderer has two separate paths for the two.

Three more Tier-1 witnesses agree. `Magic.exe` and `Shandalar.exe` import
**`DrawManaText`** and **`CalcDrawManaText`** from `DrawCardLib.dll` by
name — the 1997 DLL had no "draw plain rules text" entry point at all.
`Magis___.ttf` (1996-07-30) is *"MagicSymbols … © 1994 by Wizards of the
Coast"*, mapping `W U B R G`, `T`, `X` and `0`-`9`. And `Duel.hlp`
(1997-11-11) does it in its own prose, in the **Activation Cost** topic:
*"For example, Strip Mine has the effect "⟦T⟧, Sacrifice Strip Mine:
Destroy target land.""* — single characters switched into the MagicSymbols
face, which the help file's font table declares, in the middle of a
sentence of quoted card text. So the help screen's own claim that these
symbols are met *"on the enlarged card in the Showcase"*
(`game/help/help_pages.gd`) is **verified**; the braces are ours, an
artefact of the Scryfall snapshot in `cards/data/`, and this is fidelity
rather than decoration.

**The geometry is the 1997 DLL's**, ported from Manalink's drop-in
replacement (`shandalar-src/src/drawcardlib/drawmanatext.c:296-298`,
Tier 3): `sym_hgt = tmHeight * 75/100` in an advance cell of
`sym_ext_wid = w * 85/100`, i.e. **a square three quarters of the LINE BOX
in a cell 85% of it**, centred both ways
(`((font_line_hgt - sym_hgt) >> 1) + posy`, `:445-449`). The symbol is a
share of the TYPE, so it steps down with the ladder and a 10 px line can
never carry an 18 px symbol. And **a run of adjacent symbols is atomic**:
the original collects the whole run and moves all of it to the next line
rather than splitting it (`:412-434`), so `{B}{B}{B}` is one indivisible
mark. `ManaText` reproduces all four numbers and that rule.

**The mechanism is a `TextParagraph`, not a `RichTextLabel`**, and the
reason is the fitting arithmetic. The card picks its rules type size
SYNCHRONOUSLY inside `show_card`, by measuring the wrapped text against
the box it has to stand in; a `RichTextLabel` only knows its height after a
layout pass, so a ladder built on it would choose this hover's size from
the last hover's measurement. `TextParagraph` is the object both a `Label`
and a `RichTextLabel` are built on and takes `add_object` for an inline box
the shaper wraps around, so **measurement and render are the same object**
— strictly stronger than the `Label` it replaces, whose height had to be
reconstructed from `get_multiline_string_size`. 1997 had the same problem
and solved it the same way: `CalcDrawManaText` is `DrawManaText` with the
pen switched off.

**THE POOL SWEEP, BEFORE AND AFTER** — 897 cards, measured on the real
widget after a real layout pass:

| | braces (Label) | symbols (ManaText) |
|---|---|---|
| full ported size, unexpanded | 685 | **688** |
| clipped, unexpanded | 7 | **7** (the same seven) |
| full ported size, `Expand` on | 810 | **812** |
| **losing a line with `Expand` on** | **0** | **0** |

Nothing regressed: a symbol is narrower than the three characters it
replaces, so three more cards read at full size than did before.

**Unskinned it is still the braces.** With no imported skin there is no
mana sheet, and the fallback is PER TOKEN, not per card — the run goes back
in as literal text, accumulated into one span so the paragraph shapes
character for character as the plain string the box used to hold. The one
code this pool uses that the nineteen cells cannot draw is `{C}` (90
occurrences; Scryfall's modern colorless pip, which the 1997 texts wrote
out in words), and it reads as `{C}` while the `{T}` beside it still draws.

**Where else this could go, and why it does not need to.** The Deck
Builder's Showcase IS a `CardPreview`, so it already has this. The small
card draws no rules text at all — only its activation-cost badge, which has
gone through `ManaIcons.cost_row` since it was written. The remaining
oracle text on screen is `MiniCard`'s and the Deck Builder card list's
`tooltip_text`, and a Godot tooltip is a string: it cannot carry an image
without a custom tooltip Control, which is a different piece of work.

**OPTIMISATION, measured before and after** (`MiniCard` is on the hot path:
the board is immediate-mode and `_rebuild_field` for a 30-permanent board
costs ~11.8ms, of which ~5.6ms is building the cards):

| | before | after |
|---|---|---|
| build one MiniCard | 254.3 µs | **206.6 µs** (-19%) |
| `refresh()` one MiniCard | 49.3 µs | **31.4 µs** (-36%) |
| `_apply_style()` | 14.6 µs | **2.0 µs** (-86%) |

Three changes, in order of what they bought. (1) **The game goes in through
the constructor.** The duel screen assigned `w.game` one line after
`MiniCard.new(inst)`, which tripped the setter's `refresh()` and re-derived
the whole face a second time, for every card of every rebuild. (2) **The
frame StyleBoxes are shared and the re-apply is skipped.** `_apply_style`
allocated two to four resources per call and pushed four theme overrides;
there are only `frames x highlights` distinct looks, none of them mutated,
so they are built once and handed out by reference, and a `_style_key`
makes a no-op re-apply free. `_init` also calls it BEFORE `_build_face`,
while the card is still childless — `add_theme_stylebox_override` raises
`NOTIFICATION_THEME_CHANGED` and Godot propagates it to every descendant.
(3) **The five rare state overlays are built on demand.** The DYING cracks,
the WILL UNTAP arrow and the three CENTRE stamps are invisible on nearly
every card nearly all the time, and were being made and thrown away by the
thousand. Z-order is still decided explicitly rather than by creation
order: the stripes and the P/T carry `z_index = 1` so a lazily added
overlay cannot land on top of them.

**TWO MORE DEFECTS IN THE FAN**, both only visible with a hand big enough
to fan. `mouse_entered` can fire more than once without an intervening
`mouse_exited` — `relayout` moves cards under the pointer and every move
re-enters the one it lands on — and each fire subtracted another
`HOVER_RAISE`, so the hovered card CREPT upward. And the lift set
`z_index = 100`, which is exactly `FRONT_Z`, the z of the LEFTMOST front
card, so hovering any other card moved it UNDER its right-hand neighbours
instead of over them.

Shots: `shot_duel_card_states.png` (a tapped Serra Angel in a row of
untapped creatures, all one size, one centre line), `shot_arrange_off.png`
(a two-card pile beside a five-card pile), `shot_hand_mixed.png` (the
opponent's plate and the player's window in one frame), `shot_card_detail.png`
(the credit).

Thirty-ninth pass (2026-08-31) — **THE CHOICE OVERLAY, and the engine
change that made it possible** (`docs/duel-todo.md` §1.3, the last Tier 1
item). The duel asks the player 81 questions in the middle of a resolution
— "Pay {B}{B} to keep Junún Efreet?", "Select a color.", "Select target
card." — and until now a heuristic answered every one of them on the
player's behalf. From the 2026-08-31 morning pass it at least did so *out
loud*; this pass stops it doing so at all for the questions a resolution
asks.

**THE DECISION THE ITEM DEMANDED: PRE-FLIGHT, NOT AWAIT.** The item put it
as a fork — *"either the choice points become awaitable, or every one of
them grows a pre-flight the UI can fill"*. Awaitable is not available to
us. A GDScript function containing `await` hands its caller a coroutine
rather than a value the moment it actually suspends, and every one of these
81 asks happens inside a `Callable` several frames deep in a card's effect
(`_resolve_top` → `trigger.on_resolve.call()` → `game.agents[pid]
.choose_yes_no()`). Making the ask awaitable makes the whole engine a
coroutine: `_run_effects`, `dispatch_event`, `check_state_based_actions`,
`pass_priority`, and 1800 synchronous tests with them. s30 gets away with
blocking because Go has goroutines and channels — `s.human
.ChoiceResponses() <- resp` (`duel.go:2676`) is a real blocking read on a
real second thread. GDScript's equivalent would be a `Thread` mutating game
state off the main thread, which is a worse trade than anything this item
is worth.

So: the pre-flight. **But it is COMPUTED, not written out 81 times.** The
engine resolves the stack's top object TWICE. The first run is a PROBE over
a `GameSnapshot` rewind point: it answers every question with the heuristic
(so it always terminates and always follows a real branch), records what
was asked, and is then undone — no log lines, no events, no state signals,
no ledger entries, and the rng put back where it was (`MtgGame.is_probing()`
is what the rest of the engine reads to hold still). What survives the
rewind is the QUESTION. It goes on `MtgGame.awaiting_choice` and HOLDS the
resolution exactly as `awaiting_attackers`, `awaiting_discard` and
`awaiting_damage_assignment` already hold the turn; `answer_choice(value)`
parks the answer on the seat's own agent and lets the item resolve for
real. Branching questions fall out for free: the answer changes what the
next probe finds, so "don't pay" and "pay" can lead to different second
questions without any card knowing the mechanism exists.

`GameSnapshot` is reflective — `get_property_list()` over every mutable
state object reachable from the game — and restores IN PLACE, writing the
saved values back onto the same objects, so every reference anyone else
holds (the screen's selected card, a preview, an agent's cached permanent)
survives a rewind. Card DEFINITIONS are not walked: `CardData`, the
abilities and the effects are shared and never written to (CONTRIBUTING.md rule
5). The `DecisionAgent`s ARE, which is what makes a probe invisible to the
seat being probed — the human's parked answers are consumed by the probe
exactly as the real run will consume them, then handed back untouched.

The guard on the whole design is one test: **a probed duel is the same
duel.** Eight turns of a rent-heavy board played twice from one seed, once
with the pre-flight and once without, compared line for line in the game
log. Any state the rewind misses, any rng draw it fails to restore and any
log line that escapes the probe shows up there.

**THE OVERLAY.** One window for all four question kinds, which is s30's
design (`duel.go:2596-2762` — `handleChoiceRequest` / `initChoiceUI` /
`respondToChoice` / `drawChoiceUI`): dim the board to `RGBA{0,0,0,160}`,
put the REASON at the top, show the reason's CARD, and list the options as
`"%d. %s"` lines answerable by the number keys 1-9. Ours takes s30's dim,
its numbering and its keys, but wears the 1997 window that already asks
this kind of question — the Primal Clay modal screen, enlarged card left
and choice lines right (`prompts.txt:670`) — because the original had no
generic chooser and that is the nearest thing it had. The options scroll,
because a library search offers thirty names where an upkeep cost offers
two and the window is one size.

It is raised from `_refresh()`, not from any one call site, which is the
other half of the fix: the old foreseen-question dialog only opened when
the player clicked Done (`_on_pass`), so a question reached during a Run To,
a Done order or the AI's own turn was still answered by the referee. The
engine holds now, whatever drove the resolution, and every driver stops.

It is also the ONE popup with no way out. `@PROMPT_PAYUPKEEP` has two
entries and neither of them is Cancel — the original's answer to "don't
want to pay" is `Don't pay Upkeep.`, not an escape — so Escape does nothing
while it is up and the Situation Bar shows no Cancel button.

**THE WORDS, all the original's.** `@PROMPT_PAYUPKEEP` (`UIStrings.txt:1129`)
is `Pay Upkeep costs.` / `Don't pay Upkeep.`, and it now covers every "Pay…"
question asked in the upkeep STEP rather than only those whose prompt
happens to contain the word — `PlayerChoice.step` is what tells Junún
Efreet's rent from Urza's Chalice's `Pay {1} to gain 1 life?`, which keeps
`Yes` / `No` (`@CYCLONE`, `promptsX1.txt:88-90`). A colour question is
titled `Select a color.` (`@ALCHORS_TOMB`, `promptsX2.txt:11`) over `White` /
`Blue` / `Black` / `Red` / `Green` (`UIStrings.txt:610-614`). A card
question keeps the tutor's `Select target card.` and offers `Cancel.`
(`prompts.txt:949`) only where declining is legal — a search may fail to
find (CR 701.19b), a cost's sacrifice pick may not. A discard question is
`Select card to discard.` (`@PROMPT_DISCARDACARD` entry 1,
`UIStrings.txt:1106`), one click per card.

Screenshots: `shot_choice_upkeep.png` (the upkeep cost, put to the player
the FIRST time the card asks), `shot_choice_card.png` (the same overlay
carrying a tutor's candidate list). Pinned by
`tests/unit/test_choice_preflight.gd` (12) and the §1.3 half of
`tests/ui/test_duel_prompts.gd` (8).

Thirty-eighth pass (2026-08-31) — **THE SMALL CARD'S STATE MACHINE**
(`docs/duel-todo.md` §2.9, §2.10, §2.11, §6.15 — four items that are one
component and were shipped as one job). The small card is the single
generator for every card on the table, in the piles, in the deck builder
and on the help screen, so everything below lands everywhere at once.

**THE SOURCE IS THE ORIGINAL'S OWN, AND IT NAMES TEN STATES.**
`@CUECARD_SMALLCARD` (`UIStrings.txt:732`, latin-1 — GNU grep prints
nothing without `-a`) is the cue-card table for a card on the table, and it
is a better source than s30's nine border colours because it is a list of
*facts about the card*, not of affordances:

```
Damage to player                    Is a target
This card will untap                Can't target this
Damage: %d                          Is a target, can't target again
Card is not controlled by owner     Dying
                                    Summoning sickness
                                    Phased
```

**FIVE OF THEM SHIP AS ART, AND IT WAS NEVER IMPORTED.** Every candidate
was opened with PIL before a line was written:

| file | 1997 size | image half | what it actually is |
|---|---|---|---|
| `Summon.pic` | 194×97 | 97×97 | grey spiral — *already imported* |
| `Damage.pic` | 84×26 | 42×26 | red dagger — *already imported* |
| `Dying.pic` | 194×97 | 97×97 | **silver CRACKS spreading over the card** |
| `CantTarget.pic` | 130×65 | 65×65 | **an ORANGE CIRCLE-SLASH** |
| `WillUntap.pic` | 110×59 | **55×59** | **a BLUE CURVED ARROW** (halves are not square) |
| `Target.pic` | 122×61 | 61×61 | a red CROSSHAIR — imported, but as the cursor only |
| `Poison.pic` | 42×26 | 21×26 | *not imported — see below* |

**A FOURTH PROVENANCE RULE, and it nearly took this pass in.** The
planning note said the five live in `Program/CardArt/`. They do — but
`Program/CardArt/` is the same trap as `Program/DBArt/`: **every `*.pic`
in a Manalink install's CardArt is a PNG wearing a `.pic` extension**, and
it is Manalink's own RESCALE. Summon and Dying are 254×127 there against
the 1997 194×97; CantTarget and Target are 206×103 against 130×65 and
122×61; WillUntap is 152×76 against 110×59. Same drawings, upscaled, with
two-tone silhouette masks instead of real alpha. The s30 `.pic.png`
conversions are the 1997 files and go first in every candidate list.
A fifth wrinkle on the same shelf: `Dying.pic` ALSO exists at a Manalink
install's root as a genuine raw 1997 **X0 container** (magic `X0`, u16
length, u16 w=194, u16 h=97) which nothing we have can decode.

**`Poison.pic` IS DELIBERATELY NOT IMPORTED**, and for two reasons rather
than one. It is the tenth state, `Damage to player`, which is the LIFE
REGISTER's state and not a card's (`@CUECARD_LIFE`, §6.5) — and s30's
conversion is *broken*: its right half is 546/546 px of solid black, a
dead mask that decodes to a fully transparent sprite. Only Manalink's
60×30 rescale has a working mask. Whoever builds the poison counter takes
that one.

**`Target.pic` SERVES TWO MASTERS AND IS IMPORTED ONCE.** The duel
screen's targeting cursor takes its raw image half
(`_set_target_cursor`); the small card's "Is a target" stamp takes the
decoded sprite through `masked_sprite`. One key, `target_cursor`, two
uses — a second manifest key would be a second copy of the same bytes.

**WHAT THE WIDGET NOW DRAWS — eight of the ten.** `MiniCard.State`,
`STATE_CUE` (the verbatim strings) and `STATE_SPRITE` (the skin key), with
one `TextureRect` per state, each carrying its own cue card as
`tooltip_text` AND folded into the card's tooltip. The overlays stay
`MOUSE_FILTER_IGNORE` — the card is a Button and the sidebar preview rides
on its `mouse_entered`, so a mouse-catching child would have cost more
than it bought. Z-order is decided rather than accidental: spiral, then
the cracks over the whole art, then the corner arrow, then the centre
stamp, which is the transient targeting news and belongs on top. The three
centre stamps are mutually exclusive and a refusal beats a re-pick beats a
plain target, because the original stamps ONE mark over a card's art.

**THE TWO IT CANNOT DRAW, and why, so nobody hunts for them again:**

- **`Damage to player`** is the life register's, not a card's.
- **`Phased`** cannot reach a widget. `MtgGame.phase_out` moves the
  instance OUT of `players[pid].battlefield` into `phased_out` while
  leaving `zone == BATTLEFIELD`, and **there is no `Mtg.Zone.PHASED_OUT`**
  — so the board never builds a card for a phased permanent in the first
  place. `test_phased_and_damage_to_player_are_recorded_as_unanswerable`
  fails the day that changes.

**§2.9's PREMISE WAS BACKWARDS, AND THE DEFECT WAS ON THE OTHER SIDE.**
The to-do asked whether we should adopt s30's `power/(toughness − damage)`.
Manual **p.114** settles it against s30: *"The Show Power/Toughness check
box determines whether or not the **current** power and toughness of each
creature is displayed on the card in play. (The SHOWCASE always shows the
**original** power and toughness.)"* — and `Damage: %d` is its own cue
card. So the original prints LIVE P/T *and* a separate damage marker,
which is exactly what we already did; porting `displayedCreatureStats`
would double-count against the dagger. The real defect was the other half
of that sentence: **`CardPreview` was showing LIVE P/T for a battlefield
card**, when p.118 says *"the Showcase always displays the original card
text. Any changes made to a card after it was put into play … are noted on
the representation of the card **in play, not here**."* It now returns the
printed values always, keeping the `*/*` quirk. A Crusade'd Savannah Lions
reads **3/2 on the table and 2/1 in the Showcase**, and two tests pin both
halves — including the anti-s30 one, so nobody ports the subtraction later.

**[s30] taken anyway: the P/T COLOUR** (`duel.go:3402-3416`). Live stats
compared against PRINTED: green when pumped, red when weakened, white
otherwise. Note it is an OR across both stats with **pumped tested first**,
so a +2/−2 reads as pumped; that is s30's rule and there is a test whose
whole job is to stop someone "fixing" it.

**THE BORDERS: the manual's colour code, s30's coverage.** s30's orange
means "there is something you can do here"; the manual's **p.128** means
*"Mandatory effects are highlighted in **orange**, while optional effects
are in **yellow**"*. They collide, and the manual wins on meaning while
s30 wins on which cards get a border at all. `MiniCard.Highlight` is now
`NONE / OPTIONAL / MANDATORY / COMMITTED / TARGET_LEGAL / TARGET_CHOSEN`
(the old `CASTABLE`/`TARGET`/`SELECTED` kept as aliases so in-flight
callers keep compiling), with s30's one width distinction: **3px for a
chosen target, 2 for everything else**. p.115/p.120/p.126 use ONE word —
*highlighted* — for a castable hand card, an attack-eligible creature, an
eligible blocker and a legal target, which is why they all collapse into
OPTIONAL instead of s30's four separate yellows and oranges.

MANDATORY turned out to be answerable after all, which the plan doubted:
`CardInstance.must_attack_this_turn` and `Mtg.Keyword.MUST_ATTACK`
(Juggernaut) give the forced attacker, and `cur_must_be_blocked` (Lure)
gives the defender's side of it.

**THE NORMAL-MODE CUE WE LACKED ENTIRELY** is s30's block 2b: an
ACTIONABLE PERMANENT. `DuelScreen._can_act_on` asks the engine
(`can_afford_cost`, a pure check) whether any of the permanent's live
activated abilities is payable right now, skipping `{T}` costs on a tapped
or sick permanent. It is deliberately NARROWER than s30's: **mana
abilities are excluded**, because every untapped land has one and lighting
the mana base up turns the cue into wallpaper. This is what the 1998
guide's *"go from left to right and evaluate each card on the board"*
(p.106) needs.

**§2.11: TWO ICONS, NOT THREE — and the map's own blank cell.** Rendered
at 4×, `Abilities.pic`'s tail is 10 a brown shield, 11 a wing, 12 a red
foot, 13 a blue cross, 14 sword-and-shield, 15 a **green trident**, 16 a
pale star — and **17 is 484/484 px of solid black, one unique colour**.
s30 maps Menace there (`duel.go:1047-1121`); the 1997 game had neither the
keyword nor the icon, so that mapping blits a black square. Added: **15
regeneration** and **10 protection from artifacts**. Not added: menace,
with a test and a comment saying why.

**Both new badges needed a PREDICATE, because the engine has no flag for
either**, and this is the part the plan got wrong in our favour:

- **There is no `Mtg.Keyword.REGENERATION`.** Regeneration in this pool is
  an activated ability whose effect is a `RegenerateEffect` shield builder.
  `MiniCard.regenerates_itself()` scans `cur_activated_abilities` (not
  `data.`, so Zombie Master's gift is seen and Titania's Song's silence is
  respected) for a `RegenerateEffect` with **no target spec** — a spec
  means it regenerates something ELSE (Ragnar, Elephant Graveyard), which
  is not a statement about this card.
- **`CardData.protection_from` is a colour bitmask with no non-colour
  entry** — the plan said otherwise and it is not so. The one card that
  grants protection from artifacts, **Artifact Ward**, expresses it as the
  three clauses protection is made of, on the live lists that already
  existed for them. `warded_from_artifacts()` asks for the two that define
  it: artifact damage prevented AND artifact sources barred from targeting.
  Matching the engine's own human-readable `desc` is the coupling that
  costs; the day `cur_protection` grows a non-colour entry it becomes one
  lookup in `PROTECTION_SLOT`.

**THE BADGE BACKDROP, MEASURED RATHER THAN GUESSED.** Every cell of the
1997 sheet is a disc on an opaque near-black square, and `badge_from_slot`
built a bare `AtlasTexture`, so **every badge on every card has been
drawing a dark 22px block behind its disc**. The set-symbol fix (eleventh
pass) keyed every achromatic pixel; that is unavailable here because the
protection-white shield and the reach star ARE achromatic. So the cells
were measured: across all eighteen, the furthest non-black pixel sits at
**r = 11.068** and the nearest black one at **r = 11.34** in a 22px cell —
the backdrop is exactly the four corners outside the inscribed disc and
nothing else. A cut at `cell * 0.51` (11.22) separates them with no
judgement call, and black pixels INSIDE the disc (the skull, every icon's
outline) survive untouched. Same one-pixel rim feather `ManaIcons.symbol`
uses. Verified on a flier before and after.

**A DEFECT FOUND WHILE VERIFYING, AND FIXED: `⟳` WAS A TOFU BOX.** The
staged capture showed the "not controlled by owner" mark rendering as an
empty rectangle, so every symbol this widget might want was put to
`Font.get_glyph_index` in all three fonts it can end up with. **U+27F3 ⟳ —
the tapped mark, on every tapped card since it landed — is glyph 0
(missing) in ALL THREE**, `ThemeDB.fallback_font` included. So are ⇄, ↔, ●
and ▲; and `font_title` (MagicMedieval) carries letters and almost nothing
else — even `«` and `*` come back as glyph 0. The intersection that
renders everywhere is plain ASCII, so the two lettered marks are now
`(T)` and `stolen`, with the exact 1997 sentence one hover away, where the
vocabulary belongs.

**A SECOND, QUIETER BUG, found by a test.** `_rebuild_badges` and
`_rebuild_stripes` called `queue_free()` without `remove_child()`, and a
freed-but-not-yet-collected child stays in `get_children()` for the rest of
the frame — so two refreshes in one frame (which is what happens now that
the duel screen hands the widget its `game`) left every badge on the card
TWICE.

**VERIFIED VISUALLY**, three staged captures added to
`tools/screenshot_tour.gd` (`shot_duel_card_states`,
`shot_duel_card_badges`, `shot_duel_targeting_states`) and read back with
PIL at 2-5×. Two things the first staging taught: emptying
`players[pid].battlefield` is NOT enough to clear a table, because statics
are gathered from instances that still say they are on the battlefield (an
AI-played Crusade kept pumping from nowhere); and damage must be marked
AFTER the last call that runs state-based actions, or the `Dying` creature
is destroyed before the shutter opens. Each board is kept to one row —
eight creatures put the second row off the bottom edge.

Thirty-seventh pass (2026-08-31) — **ARRANGE CARDS, THE CANCEL LADDER,
AND THE TERRITORY MENU** (`docs/duel-todo.md` §2.3, §3.1, §3.2, §6.11,
§6.3). Five items that turn out to be two ideas: *the table can be put in
order on request*, and *every prompt has a way back out of it*.

**ARRANGE CARDS — the owner's toggle, and the source that vindicates it.**
The owner asked for *"its own new icon under the large card on the right —
clicked would sort the table, unclick would return to previous state it
was before sorting."* The to-do tagged the item `[s30]` because s30
auto-sorts. It is better than that: **the 1997 game has no automatic sort
of anything, and its equivalent is exactly an on-demand command.**
`@MENU_TERRITORY` (`UIStrings.txt:908`) entries 15-16 are `Arrange your
cards\tDblClk` / `Arrange opponent's cards\tDblClk`, and `Duel.hlp`, topic
**Territory**, spells it out: *"**Arrange Cards** straightens up the cards
in play in the territory where you right-clicked. This has no effect on
the duel, it just makes things neater. (You can also double-click on a
territory to do this.)"* The hand has no arrange at all — `Duel.hlp`,
topic **Hands**, gives that window only a *"revolving"* scroll. So the
item re-tags: **the CONTROL is `[1997]`**, **the ORDER is `[s30]`** (no
1997 source records what "straightened" looked like), **the hand half is
`[s30]`**, and **the toggle-back is `[QoL]`**.

- `game/duel/board_order.gd` — static, non-mutating comparators, ported
  from `duel.go:1438-1544` and pinned against s30's own fixtures. Hand:
  lands first by name and *stop there*, then WUBRG / mana value / name.
  Creatures: power desc, toughness desc, name. Lands: name, then
  **untapped before tapped**. Other permanents keep play order — the
  reference leaves that row alone and it is the row where the player's
  own grouping means something.
- Two corrections to the reference, both pinned: the creature order reads
  **live** P/T (`cur_power`, CONTRIBUTING.md rule 5) where s30 reads its
  snapshot's printed numbers, so a Crusade'd 2/2 overtakes a 2/3; and
  every key ends on the instance id, because `Array.sort_custom` is not
  stable and this runs on every refresh — two identical untapped Forests
  would otherwise trade places sixty times a second.
- **THE RESTORE IS FREE, AND THAT IS THE WHOLE DESIGN.** Nothing is
  snapshotted. The engine's own zone arrays *are* the unarranged order and
  are never touched; an arrange is a VIEW, so untoggling restores the
  order exactly, with no snapshot to go stale. It also answers the item's
  one hard question — a card that arrives while the table is arranged
  takes its arranged place at once, and when the toggle goes off it
  appears where the ENGINE put it. A snapshot design would have had to
  invent an answer; this one inherits the right one.
- The arrange can never desynchronise a click from its card, because every
  `MiniCard` binds its own `CardInstance`. s30 has to draw and hit-test in
  the same order for exactly this reason; we have no index to keep in step,
  and `test_clicking_an_arranged_card_operates_that_card` keeps it that way.
- `game/duel/arrange_button.gd` is the control, and it is the **first
  tenant of `_qol_reserve`** — the black strip built and named for it
  ("the black space under the large preview card will be used by new QoL
  buttons and features when they land"), right-aligned against the
  column's inner edge and hard up under the Showcase. Its icon is DRAWN,
  not imported: `Program/DuelArt/` has no arrange icon because in 1997 the
  command lived in a text menu. Three cards askew when off, three squared
  up when on, in the era's own ink and highlight over the Situation Bar's
  stone. Tooltip is the table's own `Arrange your cards`.
- Per TERRITORY underneath, because the 1997 command is: the sidebar
  toggle works the whole table (the owner's control), and
  `@MENU_TERRITORY`'s two entries work one half each. The toggle shows
  pressed only while both halves are arranged.

**THE CANCEL LADDER — §3.1, §3.2 and §6.11 are one contract.** `Duel.hlp`,
topic **Situation Bar**: *"At the rightmost end of this bar is a **Done**
button, a **Cancel** button, or both, depending on the situation… Esc is
just like Cancel · Return has the same effect as Done · Spacebar: if there
is only one button, pressing this is the same as clicking that button."*
The Manalink source states the same thing as a bit spec — `allow_cancel`
(`src/defs.h:2390`) is two bits — so **which buttons appear is a property
of the prompt**.

- **The Cancel button exists at last.** It sits beside Done on the
  Situation Bar in the table's own order and appears only when there is
  something to cancel (`DuelScreen._can_cancel`). Until now the targeting
  prompt said *"(Cancel to abort)"* and offered no control to click.
- **Esc and the button are one door.** `_can_cancel` drives both, so
  *"Esc is just like Cancel"* cannot drift into two behaviours that merely
  agree today.
- **Escape peels ONE layer** (s30 `handleEscape`, `duel.go:1329-1350`):
  graveyard view → modal-choice overlay → library picker → the X question
  → **the picked targets only** → the pending action. The ability menu
  needs no rung; it is a real `PopupMenu` and Godot closes it first. With
  nothing open, Escape does nothing — it never leaves the duel.
- Two of those rungs were **dead** before this pass. The X question and
  the library picker are `OriginalDialog`s, not Popups, and the mode is
  still NORMAL while they are up, so Escape sailed straight past them into
  a `_on_cancel` that had nothing to do: **the dialog simply would not
  close.** Return was worse — it reached `_on_pass_turn` and fast-forwarded
  several priority windows with the question still on screen.
- **Re-clicking a chosen target now takes it back** (§3.1). The refusal it
  replaces used the right SENTENCE — `@CUECARD_SMALLCARD` entry 7, *"Is a
  target, can't target again"*, is the cue card the original prints under
  a card that is already a target — but the wrong ACTION: a misclick cost
  the whole cast. s30's other branch, "replace when the maximum is one",
  needs no counterpart: `_advance_pending` closes a slot the instant its
  maximum is met, so a one-target slot is never still open to re-click.
- **Return now reaches Done in every mode.** It used to dead-end in
  targeting, discard and damage division, so the one keystroke the manual
  names could not answer the three prompts that most need answering. In
  NORMAL it is still the standing instruction (manual p.112), which is the
  §6.1 reading.
- **Spacebar honours the "only one button" rule literally.** Done is
  always on the bar, so Space is Done until Cancel joins it — at which
  point the bar has two buttons and the key is ambiguous, exactly as the
  help file describes. Return and Esc still name one button each.

**THE TERRITORY MENU (§6.3) — the `Go to:` list.** `game/duel/territory_-
menu.gd` carries `@MENU_TERRITORY` and `DuelScreen` opens it on a
right-click anywhere in either territory that is not on a card (a card
keeps its own right-click for `@MENU_SMALLCARD`, §6.12).

- The fourteen `Go to:` entries are LIVE and resolve onto the two bars, so
  they run through the SAME driver **Run to** uses rather than a second
  mechanism — the menu is the reading route to those stops, not a rival to
  them. `Go to: Main phase (combat)` lands on the Combat Bar's first icon,
  because `CombatBar.covers_step` hands every combat step to the smaller
  bar and the Phase Bar's crescent is therefore never a destination of its
  own. `Go to: Start of next turn` crosses to the other half of the bar.
- **`Go to: next phase` is new machinery**: `Advance.NEXT_PHASE`, a run
  whose destination is "not here". `Duel.hlp` defines it separately —
  *"ends the current phase and moves you on to the next one"* — and it is
  the one 1997 verb we had no equivalent for, our Done being the finer
  single pass and Run to the aimed one.
- The rest of the table is present and DISABLED, on §6.1's own precedent:
  showing them greyed says the menu is complete and the features are
  missing. **`Save game...\tCtrl+S` is deliberately absent** — manual
  p.112: it *"appears **only** if you are playing in the **Duel** (a
  separate program)"*. There is no mid-duel save in the adventure and we
  must not invent one.
- Captures: `shot_arrange_off` / `shot_arrange_on` over the same staged
  board, `shot_menu_territory`, `shot_bar_cancel`.

Thirty-sixth pass (2026-08-31) — **THE EXILE PILE**, the owner's ask:
*"In our duel gui there is stack icon, graveyard icon and there is space
to the right of the graveyard. Lets put there the space for exiled cards
(support for the future). Make also a suitable exile icon square similar
to graveyard square."*

- Each seat's piles row is now `[deck] [graveyard] [exile]`. The exile
  plate is the graveyard's twin — same 40x60 slot, same
  `STRETCH_KEEP_ASPECT`, same click, same viewer — and it is read the
  same way: **its top card when it holds one, its own plate when it does
  not**. Its count rides ON the plate (bottom-right, in the deck count's
  yellow) because the row has no width to spare beside the mana column,
  and it is blank while the pile is empty, which is most duels.
- Clicking it opens `GraveyardView`, not a second overlay: that view has
  laid out all three of `@MENU_GRAVEYARD`'s zones — graveyard, exile,
  ante — since the thirty-third pass. One plate, one viewer, three
  sections.
- A card exiled FACE DOWN (Knowledge Vault) leaves the plate showing:
  nobody may look at it. The hover text is the zone's 1997 name — the
  manual's *"out of play"* (p.118) — and lists what is in it, face-down
  cards as `(face down)`.
- **THE PLATE IS DERIVED ART, and this pass is a DELIBERATE DIVERGENCE.**
  The 1997 table had no exile pile at all. `Duel.hlp` (the shipped help
  file, 11 Nov 1997) says how the zone was reached: *"You can also
  right-click on either graveyard to see a reminder of what cards you and
  your opponent have put up as ante or to view cards removed from the
  game."* — which is `@MENU_GRAVEYARD`'s own four-line menu
  (`UIStrings.txt:901`). Neither `Program/DuelArt/`, the Manalink source
  tree, nor the s30 re-release holds any exile art; `Grave_<Colour>` is
  the only pile plate that was ever drawn. So there was nothing to
  import and `game/duel/exile_plate.gd` paints one.
- What it paints, and out of what: the plate is built at the grave
  plate's own size and geometry (61x91, a 1px white border around 59x89
  of art) and **every colour is sampled from that seat's own grave
  plate** — the five originals are tiny-palette woodcuts (Green has four
  art colours, Red nine), so the pair reads as two halves of one asset.
  The scene is a card standing in the void with its right-hand side
  already eaten away, drawn as the duel's own mini cards are read (art
  box over three text lines) so the silhouette is a CARD even at 40x60,
  and the motes it sheds drift off into a speckled ground. Ordered 4x4
  dither for the fade, hash-jittered so the edge crumbles instead of
  running in a ruled diagonal; nothing in it is random — the same plate
  comes out on every machine, every run.
- No skin, no plate: `ExilePlate.plate()` returns null when the seat has
  no `grave_panel_*` to borrow from, and the pile is built inside the
  same branch as the graveyard's — the two piles appear and disappear
  together rather than leaving a painted exile square beside a bare
  graveyard.

Thirty-fifth pass (2026-08-31) — **THE HELP SCREEN**, and the one shared
change it needed (`game/help/`, `game/skin.gd`). The owner asked for a
Help button above Exit opening *"scrollable pages with left and right
button with many pages where basic mana types and basic MTG rules are
explained, along with all icons player can meet in the duel gui and deck
builder."*

The screen itself invents no chrome — it is `UiChrome.stone_panel` /
`panel_around` / `menu_button` / `body_label`, on `Menubak.pic`, the
shell's own backdrop, which the importer had carried since the first skin
pass and nothing had used. Two things there are worth recording because
they are general:

- **The reading width is capped** (`HelpScreen.MAX_TEXT_WIDTH`, 980px, the
  body centred in the panel by a gutter recomputed on resize). The panel
  fills the window so the page furniture does not jump between pages, but
  the first screenshot pass set prose across the full 1164px and it was
  unreadable — the eye loses the return sweep. Any future full-width
  reading surface wants the same treatment.
- **No page scrolls.** The throwaway capture tool printed content height
  against viewport height for all 24 pages; six overflowed, and they were
  SPLIT into whole pages rather than left to scroll. A reference page you
  can read entire is worth more than a shorter page list.

**The shared change: `GameSkin.region(key, Rect2i)`** — a generic, cached
sheet cutter. Most sheets already have a decoder that knows their grid
(`ManaIcons.symbol`, `MiniCard.badge_from_slot`, `FilterBar.sheet_cell`);
the ones that do not are read through a published `Rect2` instead
(`PhaseBar.active_region`, `CombatBar.active_region`) or are frame strips
(`Target.pic`). The help screen needs those, and the rule it must not
break is that one screen never reaches into another's private art code —
so the cutter lives in the one place that owns skin art.

The help screen's own guarantee, and the reason it has a test rather than
a review: **every icon resolves through the same accessor the screen it
documents draws with**, so a cell map that moves breaks the help test at
the same moment it breaks that screen. It did, immediately: this pass and
the thirty-fourth ran concurrently, the deck builder's colour PLAQUES
became medallions and Enchantment/Sorcery moved cells, and the help
suite failed on five null textures before a human looked at anything.

Thirty-fourth pass (2026-08-31) — **THE DECK BUILDER, RESTYLED TO THE
OWNER'S 1997 SCREENSHOT** (`game/deck_builder/`). The owner supplied a
genuine 1024x768 capture of the in-Shandalar Deck screen and the brief was
*"explore and find a proper art for Deck builder and style it as in the
reference screenshot"*, then *"keep our QoL… just style it as legacy"* —
so the screenshot governs how the screen LOOKS and nothing functional was
dropped to match it.

**What the screenshot settled, and what it cost the earlier passes.**

| region | before | after |
|---|---|---|
| screen ground | olive `Dektile1` (s30's choice) | navy `Dektile4`, the screenshot's own weave |
| Deck area | a plain navy field | a QUILT — every slot carries a carved 1997 mana watermark |
| command bar | eight buttons across the TOP of the screen | the screenshot's five along the BOTTOM of the deck area |
| Filters | four labelled columns | ONE unlabelled row of medallions |
| Inventory | two rows of 0.85-scale miniatures | ONE row of cards at 1:1 |

Four art readings were **corrected by the screenshot**, each of which had
been inferred by shape-matching before:

1. **`Bldr_sheet` is not the colour filter buttons.** Two passes called
   its ten carved plaques "the Colour Filter plaques" and put them on the
   Colour Filters. They are **the deck area's empty-slot watermarks**: the
   screenshot's deck grid is these cells laid edge to edge, cycling
   `(row * columns + col) % 5`, and a crop of the grid beside the sheet's
   bottom row is a pixel match. The two rows pair with the two deck tiles
   — blue slate on navy `Dektile4`, warm gold on olive `Dektile1`. The
   skin key is renamed `deck_slot_plaques`.
2. **The Colour Filters are `sprite_sheet` medallions** like every other
   filter — W (2,8), U (0,7), B (1,6), R (2,4), G (1,5), each a coloured
   glyph on a black disc, which is what makes them identifiable.
3. **ENCHANTMENTS is (1,3) and SORCERIES is (2,6).** The audit pass had
   moved Sorcery to (0,5) and Enchantment to (2,6) by silhouette. The
   screenshot shows the type run in the manual's own order (Land,
   Artifacts, Creatures, Enchantments, Instants, Interrupts, Sorceries);
   each medallion was cut out and correlated against all 27 cells, and the
   discriminator turned out to be **the gold ring** — every SET medallion
   wears one and no type button does. (1,2) is a crescent with the ring
   (The Dark); (1,3) is the same crescent without it, and that is
   Enchantments. The audit was right that (2,5)'s ringed exclamation mark
   is a set (`@RESTRICTED`) and wrong that Enchantment was near it.
4. **ON is the plain medallion, OFF is the dark one.** Every filter in the
   screenshot is depressed and every medallion reads 122-128 mean
   luminance — the NORMAL sheet's 120-127, not `_pressed`'s 62-66. The
   warm/cool `ON_TINT`/`OFF_TINT` pair a previous pass invented to
   separate the states is retired: the sheets are already 2:1 in
   luminance, which is the original's own answer.

**Where the reference and our feature set disagreed**, resolved in the
era's language rather than by deleting anything:

- the bar is five buttons wide and the screen has thirteen commands, so
  the bar keeps `Stats (N cards) | Deck1 | Deck2 | Deck3 | Done` and gains
  a `Deck` button opening `@DECKSURFACE_STANDALONE`'s own right-click
  mini-menu — where the original kept those commands anyway.
- the four Filter GROUPS survive as structure (`FilterBar.group_names`),
  told apart on the strip by a wider gap, which is the original's only
  grouping cue. Their names live in the cue cards.
- the type-ahead and the sort moved onto the tail of the filter strip,
  which is what freed the height for full-size Inventory cards. The sort
  is a bevelled button with a mini-menu, not a dropdown.
- **the trade this makes, stated rather than hidden**: one row of nine
  cards where two rows showed twenty. The filters, the sort and the
  type-ahead are what the 1997 screen expected you to reach for, and the
  count line now says which slice of the list is on screen.

**[QoL] added in the same pass** (all marked `[QoL]` at their sites and in
the mini-menu itself): three in-memory DECK SLOTS behind the screenshot's
own `Deck1/2/3` buttons; one-step UNDO over the deck's contents; ADD BASIC
LAND; DECK NOTES saved as `# note:` lines that older readers skip; two
EXPORT formats (`.dec` for other programs, `.dck` for the 1997 game); the
Inventory's already-in-deck badge; a rules-text switch for the type-ahead;
and Ctrl-key shortcuts. Deferred proposals are in `docs/ROADMAP.md`.

**Measured, because the pass touched the paging path**: one notch of the
Inventory costs **1.46 ms** (9 cells rebound) against **3.81 ms** for the
old two-row geometry (20 cells), the page widgets are still REBOUND rather
than rebuilt, and `filter_passes` is still 1 after twenty card additions —
the `DeckFilter.revision` gate is intact. The Inventory's new badge reads
the deck per VISIBLE CELL, never per pool card, for exactly that reason.

Thirty-third pass (2026-08-31) — **THE GRAVEYARD IS MADE OF OUR OWN
CARDS** (`graveyard_view.gd`, `duel-todo.md §1.2`). A **[QoL] divergence,
chosen by the owner in these words**: *"graveyards should be composed of
our mini cards, 5 in a row, with arrow on the left and arrow on the right
to scroll through graveyards if they are extensive. And a number which
card of all in the graveyard it is, in the center card of the 5. Now the
graveyard has its own format — no! Only big preview and mini cards with
names, art, icons, power/defense etc. Let's be consistent. This is a
divergence from the original but this is what we want — enhanced game with
old feel and good QoL."* The 1997 game gives the graveyard a presentation
of its own; we give it the presentation every other zone already has.

**THE DEFECT WAS AN ASPECT RATIO.** The view did use `MiniCard`, but it
forced `CARD_SIZE = Vector2(96, 134)` onto every one — TALLER than wide,
where `MiniCard.SIZE` is `132 x 106`, WIDER than tall. Every part of a
mini card is anchored as a FRACTION of that 132x106 face (name band, mana
stripes, badge row, damage marker, P/T), so squashing the widget put all
of them somewhere they were never laid out for. The pile was the one place
in the duel where a card did not look like a card.

What the pass built:

- **A SHELF, not a grid.** Five plain `MiniCard`s at their own size, laid
  out by the container. Nothing about a card is re-drawn in
  `graveyard_view.gd` any more — `mini_card.gd` stays the single generator
  it says it is.
- **A CARD IS NEVER SCALED.** The owner, when a uniform scale was
  proposed: *"do not make them smaller — if they are too big then let's
  display only 3 at once and have arrows to scroll through graveyard!"*
  So `cards_across()` costs a row out in real pixels — `n * 132` plus the
  8px gaps plus both 34px arrows with their own 12px gaps: **784 for
  five, 504 for three** — against the width the shelves actually have, and
  answers 5 or 3. The COUNT gives; the card does not.
- **Measured, not guessed.** The shelves lay out inside the DuelScreen's
  own `_board_area()`, not the whole screen: the docked `CardPreview` they
  fill lives in the sidebar and a pile on top of it would hide the very
  thing hovering is for. That leaves 890px on the 1280x800 canvas (1280 - 300 sidebar - 50 phase bar - the HBox separations, less a 12px inset each side), so
  **five** is what shows — confirmed on captures at 1280x800 *and*
  1280x720 (the `canvas_items`/`expand` stretch only ever makes the canvas
  wider, never narrower than 1280).
- **◀ ▶, the era's own scroll device turned horizontal.** Manual p.114
  gives an overflowing pile *"scroll arrows at the top"*; `StackHand` wears
  that ▲/▼ pair on its bar. These are `OriginalDialog.button` — the 1997
  three-state button art every dialog in the duel already wears — one
  whole page per press, disabled at the ends, and absent altogether on a
  pile that fits (p.114 gives arrows to a list with *"too many cards to
  display all at once"*). The Situation Bar's stone (`bar_button`) was
  tried first and tiles into a pink barber pole at 34x106; the capture is
  why it is not what shipped.
- **The position on the CENTRE card**: a small plaque reading `13 / 35` at
  the card's bottom-centre, clear of the P/T corner and the badge row. The
  centre of the shelf is a fixed reading position, which is why the arrows
  move by a whole page and why the window CLAMPS instead of revolving
  (p.114's scroll revolves — that half of the 1997 behaviour is the part
  we gave up for a counter that means something).
- **Hover fills the duel's own big card**, exactly as `CardPile` does.
- **Opening while TARGETING lands on the page holding the first legal
  card**, centred — otherwise Raise Dead's answer can be page five of
  seven and the player has to hunt for it.
- **A second, deeper dim over the board region only.** s30's single 0.63
  black left a busy battlefield legible straight through the pile (the
  first capture of this pass had the ante shelf sitting on three summoning
  spirals). The sidebar keeps the plain s30 dim so the big card reads.
- Kept: all three of `@MENU_GRAVEYARD`'s zones in its order, both seats'
  piles, the yellow target ring on a pile holding a legal target, close on
  the same pile / outside / Escape, and `Illegal target (%s).` for a card
  that cannot be taken.

Shots: `shot_graveyard_view.png` (35-card pile, both graveyards, exile and
both antes) and `shot_graveyard_paged.png` (two presses of ▶ — the shelf
walks to cards 11-15 and the counter reads `13 / 35`). Verified by
cropping the SAME card, Savannah Lions, out of the pile and off the
battlefield in one capture: both are exactly 132x106 with the name band,
art window and `2/1` on identical pixels.

Thirty-second pass (2026-08-31) — **STOPS, RUN TO, and the Phase Bar's
mini-menu** (`duel-todo.md §6.1`, `§6.3`, `§6.20a`). The owner asked for it
in these words: *"can user right click on the individual phase and set a
stop point (red dot) there or make it stop and decide on the moves. If the
red dot is removed it moves automatic if possible as in legacy game!"*

**THE RED DOT WAS ON THE WRONG THING, AND THE MANUAL SAYS SO.** Ours rode
beside the CURRENT phase (the fourth pass put it there). Manual p.116:
*"First and foremost, the current phase is always highlighted."* The
highlight is the current-phase cue — it is why `Winbk_Phase.pic` ships two
columns, the icons on black grounds and a white-ground variant beside each
— and the only marker any 1997 source describes is the Stop's:
`Duel.hlp`, topic **Stop**, *"select **Mark** from the mini-menu to put a
**Stop marker** on that phase."* Neither sheet carries a marker sprite, so
the original drew it in code. A dot that always sits beside the highlight
carries no information; a dot on a phase you have marked carries all of it.
**The red dot is now the Stop marker, on both bars, several at a time.**
Verified in the captures: `shot_phase_stops.png` shows the white-ground
highlight on the phase the duel is in and red dots on two *other* icons,
one per half.

- **THE STOPS MODEL** — `game/duel/phase_stops.gd`. Two halves (manual
  p.116: *"The top half of the bar represents the phases in your
  opponent's turn, while the lower half represents your turn"*) times two
  bars, eight Phase Bar icons and seven Combat Bar ones. That shape is the
  original's own: `char option_PhaseStoppers[2][38]`
  (`shandalar-src/src/manalink.h:120`), written as
  `option_PhaseStoppers[current_turn][current_phase]` with bit 0 the flag
  (`src/functions/windows.c:543-557`). **38 == 0x26 is one past
  `PHASE_DAMAGE_PREVENTION` (0x25)**, the last entry of the original's
  `phase_t` (`src/defs.h:685-707`) — so that array spans the whole phase
  enum, combat's sub-phases (0x15…0x1B) included. That is the file-level
  confirmation of `Duel.hlp`'s *"you can even use Stops"* about the Combat
  Bar, and it is why our model has two bars rather than one.
  **AND THE ORIGINAL SHIPPED THREE OF THEM SET** — established
  2026-09-03 by disassembling that array's loader, which zeroes it and
  then writes `[HUMAN][PHASE_MAIN1]`, `[HUMAN][PHASE_MAIN2]` and
  `[AI][PHASE_DISCARD]`, and forces the first back on even when a stored
  value is read. Ours are the owner's three (your Main pre-combat, combat
  and Main post-combat) and the divergence is `[QoL]`: see
  `docs/ROADMAP.md`, "THE THREE DEFAULT STOPS", and
  `PhaseStops.ORIGINAL_1997_YOURS`, which keeps the original's set beside
  ours.
  **PERSISTED** through `Settings`, because the manual calls a Stop *"a
  lasting instruction"* (p.117) and `PhaseStoppers` is one of the values
  under the original's `DuelOptions` registry key, of which p.114 says
  *"your option settings are retained for future duels."*
- **THE PHASE BAR IS A CLASS NOW** — `game/duel/phase_bar.gd`, built like
  `CombatBar` instead of three loose nodes inside `duel_screen.gd`.
  Sixteen live hit zones, each carrying its `@CUECARD_PHASEBAR` cue card
  (`Program/UIStrings.txt:706`, entries 1-16 — the half of §6.1 that was
  still missing), the highlight overlay, and sixteen Stop dots.
- **RUN TO**, manual p.116: *"You can move forward ('run') to any phase by
  clicking on the icon for that phase… The duel blithely skips through all
  the intervening phases, then stops."* Three exceptions, and the code
  implements exactly those three: a required action or decision, anything
  new from the opponent that *"requires or permits a response"*, and a
  Stop. Then *"your original 'destination' phase is forgotten"* — so an
  interrupted run is cancelled, never resumed. It crosses turns: *"you can
  click on any phase on either side of the bar."*
- **A STOP YOU ARE STANDING ON DOES NOT TRAP YOU.** *"that phase does not
  end until you tell it to manually"* — giving the order IS telling it
  manually, so a Stop only bites on phases the run ENTERS. One flag
  (`_advance_moved`) is the whole of that rule.
- **DONE IS A STANDING INSTRUCTION** (§6.20a, manual p.112): *"you do not
  intend any action until (1) you reach a phase that has a Stop on it, (2)
  an action or decision is required…, or (3) you are able to use a fast
  effect."* Return is bound to it, per p.116's key table — replacing the
  blind 60-pass fast-forward that burned every priority window on the way.
  Note the two lists genuinely DIFFER and both are honoured as written:
  Done weighs affordability and ignores the opponent's actions, Run to
  does the reverse.
  **SIMPLIFIED**: *"able to"* means *"you have a fast effect handy **and**
  you have the mana available"*, and `MtgGame.can_afford()` prices against
  FLOATING mana, not against lands you could still tap — the engine has no
  potential-mana query and the original auto-tapped. Ours therefore
  under-reports and Done runs further than 1997's would. It still cannot
  run past a decision, a Stop, or an effect you have actually floated for,
  and the active player's declare-attackers step is an unconditional brake
  once per turn.
- **THE MINI-MENU** — `@MENU_PHASEBAR` (`Program/UIStrings.txt:947`), all
  four entries verbatim, in the dialogs' own stone. Two stated
  divergences: `Mark this phase to always stop` is a CHECK item that
  toggles, because the 1997 table ships **no unmark string** and the tick
  is the only un-mark affordance it leaves room for; and both `Help`
  entries are shown **disabled**, because there is no Dueling Help yet
  (§6.20l) — greying them says the menu is complete and the help is
  missing, where dropping them would say the original's menu had two
  items.
- **THE COMBAT BAR, per the owner's follow-up**: *"make it blue when im
  attacking and gold when an enemy is attacking. Use the same strip but
  icons use black behind (recolor white to black and when individual phase
  is active use the white behind icon). In classic microprose manner."*
  All three parts landed, and the third explains the first two: the larger
  bar's own art already does exactly this — `Winbk_Phase.pic` draws its
  normal cells on BLACK and its highlighted cells on WHITE, gold in the
  opponent's half and blue in yours. `Winbk_Phasecombat.pic` ships both
  variants on white, so `keyed_texture()` grew a `Fill` choice: the ground
  column is keyed white→BLACK and the lit cell is drawn straight off the
  sheet, white box and all. The white box IS the highlight, which beats
  the ~12% brightness difference between the sheet's two variants — and it
  frees the red dot for the Stops. `column_region()`/`active_region()`
  take their seat argument back (thirty-first pass had pinned them to
  blue). Verified at 3x on both seats: `shot_combat_your_attack.png` blue
  on black with a white Declare-Attackers cell,
  `shot_combat_window.png` gold on black with a white Declare-Blockers
  cell.

Shots: `shot_phase_stops.png`, `shot_menu_phasebar.png`, and the two
combat captures above.

Thirty-first pass (2026-08-31), the owner's two notes:
- **THE COMBAT BAR WEARS BLUE AND YELLOW, ALWAYS.** *(SUPERSEDED by the
  thirty-second pass: the owner settled the seat split — blue when you
  attack, gold when the opponent does.)* The owner supplied a
  1997 screenshot of "Your attack": the strip's icons are BLUE with
  YELLOW lightning, and only the CURRENT sub-phase is set apart. Our bar
  was drawing GOLD, because `Winbk_Phasecombat.pic` carries FOUR columns
  (gold normal | gold lit | blue normal | blue lit) and the twenty-ninth
  pass inferred gold = the opponent's seat. No source we hold shows the
  bar during the opponent's attack, so that was a guess; the screenshot
  is evidence. `column_region()` now returns the blue half for either
  seat, and the gold half stays imported and documented but undrawn.
  (An intermediate attempt dimmed the whole strip so the colour would
  only show on the active icon — reverted: the art already distinguishes
  them, and dimming was solving the wrong problem.)
- **WHITE IS THE SHEET'S TRANSPARENCY KEY.** *(The keying stands; the
  FILL was superseded by the thirty-second pass — black, not stone, with
  the lit cell keeping its white.)* In the owner's screenshot the glyphs
  sit straight on the strip; our conversion fills every icon cell with
  pure (255,255,255), so the bar read as seven white boxes.
  `CombatBar.keyed_texture()` replaces near-white, cached per sheet
  rectangle because the keying walks every pixel. The stone fill it
  originally used is sampled from the bare row-6 gap at y 248-288 in the
  same column so the grain lines up, and survives as `Fill.STONE`.
- `@PROMPT_PAYUPKEEP` (Program/UIStrings.txt:1129) replaces `Yes`/`No` on
  the one question the player meets every turn: `Pay Upkeep costs.` /
  `Don't pay Upkeep.` Keyed off a prompt that begins "Pay" AND mentions
  upkeep, so `Pay for attacker` / `Pay for blocker` — which have their
  own strings — are not swallowed by it.
- Fixed in the review loop itself: the play-or-draw dialog is modal and
  the screenshot tour never answered it, so every capture taken after the
  opening was composed UNDERNEATH it (the graveyard and damage-division
  shots both went out that way). The tour now clicks through
  OpeningHand's questions before staging anything.

Thirtieth pass (2026-08-31) — **THE FOUR MOMENTS THE DUEL STOPS FOR YOU**:
`duel-todo.md` tier 1, all six items. Three of them are new places the
screen holds still and asks; one is a whole zone that was never clickable.

**The graveyard is a screen now** (`graveyard_view.gd`, §1.2). It was a
`TextureRect` with a tooltip, which meant the engine's four graveyard
target kinds had NOTHING to point at and Raise Dead, Animate Dead,
Resurrection, Adun Oakenshield and Ashes to Ashes were uncastable through
our UI — the worst defect on the list. The overlay is s30's shape (a
`RGBA{0,0,0,160}` dim, titled sections, a card grid) with the ORIGINAL's
scope: `@MENU_GRAVEYARD` offers `View the graveyard` / `View exiled cards`
/ `View both antes`, so all three zones are in the one overlay, in that
order, and only the non-empty ones are drawn. Section titles are
`@CUECARD_OTHER`'s own second person — `Your graveyard (6)`,
`AI Wizard graveyard (1)`.
Interaction is s30's exactly: a pile opens on click, the SAME pile closes
it, a click outside closes it, and Escape peels the view BEFORE the
pending cast. Two additions of our own, both cues rather than mechanics:
the pile wears a 2px yellow ring while it holds a legal target (otherwise
nothing says the answer is off the battlefield), and a card in the grid
that is a legal target is outlined the way a board target is.

**The Discard Phase** (§1.1). `Mode.DISCARD`, entered when the engine
holds the cleanup step open. The Situation Bar reads
`Select card to discard. (1 of 2)` — `@PROMPT_DISCARDACARD` entry 1, and
the count in the bracket form the targeting line already uses. Clicking
picks and clicking again un-picks; picking past the count replaces the
oldest, because this is the one screen with no Cancel and a misclick must
not dead-end it. Done submits.

**The damage division** (§1.4), and it is a CLICK LOOP, not a dialog.
`@PROMPT_RESOLVECOMBAT` is `%s: Assign damage to blockers, %d points left`
(and `Assign trample damage` once trample is in play), so that is the
Situation Bar line, verbatim, counting down one point per click and
submitting itself when the last point is spent. Trample's spill is a click
on the opponent's life register — `@MENU_LIFE`'s own `Target %s`. The
screen only offers the clicks the engine will accept: under modern rules
the next point belongs to the first blocker in the assignment order still
short of lethal, and under `RulesOptions.free_damage_assignment` (the 1997
ruleset, which had no order at all) every blocker is open at once. An
illegal click gets `Illegal target (wrong attack group)` rather than a
refusal after the fact. The Combat window is up throughout, so the
blockers being divided among are lined up opposite the attacker.

**The opening hand** (`opening_hand.gd`, §1.5). The coin toss now reports
only the WIN — `You won the coin toss.` — because the winner CHOOSES:
`Would you like to:` / `Play first` / `Draw first`, then the Shandalar
mulligan, then turn 1. Both dialogs are `OriginalDialog` on the sandstone,
and every line in them is `@DIALOG_PLAYORDRAW` or `@DIALOG_MULLIGAN`
quoted exactly, announcements included (`%s has all land and will take a
mulligan`, `%s will also take a mulligan`, …). Seats that are not human
answer through their DecisionAgent and no dialog is drawn, which is also
what makes the whole sequence testable headless.

**And one question the screen can now see coming** (§1.3). The engine is
synchronous, so no dialog can open mid-resolution — but `choice_history`
remembers what each card asked the last time it resolved, and almost every
question in this pool is an upkeep trigger asking the same thing every
turn. `DuelScreen.foreseen_choice()` reads the top chain item, and passing
priority puts the question up as a Yes/No before letting it resolve. From
a card's second ask onward the player decides; on the first, the heuristic
still does — and now says so in the log.

Two follow-ons this pass leaves behind, both for whoever owns the hand
window: the DISCARD highlight is hard to read on a `StackHand` row,
because a covered card is clipped to its title bar; and `@PROMPT_PAYUPKEEP`
(`Pay Upkeep costs.` / `Don't pay Upkeep.`) would be better button text
than `Yes` / `No` for a question whose prompt begins "Pay".

*SUPERSEDED the same day by the thirty-ninth pass: the second-ask dialog
and `foreseen_choice()` are gone, replaced by the engine's pre-flight and
one generic overlay that catches the FIRST ask too, from any driver — and
`@PROMPT_PAYUPKEEP` is now the button text.*

Shots: `shot_graveyard_view.png`, `shot_discard_phase.png`,
`shot_damage_division.png`.

Twenty-ninth pass (2026-08-31) — **COMBAT**: the Combat Bar and the
Combat window, the two windows `duel-todo.md §6.5` said we did not have.

**THE MANUAL IS WRONG ABOUT THE COMBAT BAR, AND THREE OTHER SOURCES SAY
SO.** Manual p.117: *"This bar has only five icons, representing the
sub-phases of combat."* The shipped `Duel.hlp`, topic **Combat Bar**,
says otherwise and then enumerates them:

> *"The Combat Bar is a miniature Phase Bar that appears during an attack.
> It functions in exactly the same way as the larger bar; you can even use
> Stops. **This bar has seven icons**, representing the sub-phases of
> combat:"* — Declare Attackers · Fast Effects · Declare Blockers ·
> Fast Effects (2) · Damage Dealing, Part 1: First Strike Damage Dealing ·
> Damage Dealing, Part 2: Normal Damage Dealing · Damage Dealing, Part 3:
> End of Combat

Seven, and the other two sources agree: `@CUECARD_PHASEBAR`
(`shandalar-src/Program/UIStrings.txt:706`) carries exactly **seven**
combat tooltips after its sixteen Phase Bar ones, and
`Winbk_Phasecombat.pic` **draws exactly seven icons**. The printed manual
is the only source that says five and it is outnumbered — it reads like
prose written against an earlier build. `@MENU_TERRITORY`'s `Go to:` list
(`:908`) independently names the same seven stops. The whole chain now
lines up one-for-one:

| icon | what it draws | `@CUECARD_PHASEBAR` | `@MENU_TERRITORY` | our step |
|---|---|---|---|---|
| 0 | a sword, hilt up | `Choose attackers phase` | `Main phase (combat)` | `DECLARE_ATTACKERS`, awaiting |
| 1 | the sword with red rays | `Attacker fast effects phase` | `Attack Fast Effects phase` | `DECLARE_ATTACKERS`, declared |
| 2 | a shield | `Assign defenders phase` | `Choose Defenders phase` | `DECLARE_BLOCKERS`, awaiting |
| 3 | the shield with red rays | `Blocker fast effects phase` | `Block Fast Effects phase` | `DECLARE_BLOCKERS`, declared |
| 4 | the shield split, red through the break | `Resolve 1st strike damage` | `Resolve first strike damage` | `FIRST_STRIKE_DAMAGE` |
| 5 | a red sword through the shield | `Resolve normal damage` | `Resolve combat` | `COMBAT_DAMAGE` |
| 6 | the Phase Bar's own **mirrored crescent** | `Main phase (postcombat)` | `Main phase (postcombat)` | `COMBAT_END` |

`docs/duel-todo.md §6.5` and `docs/glossary-1997.md §3` are corrected
accordingly; both previously repeated the manual's five.

**THE ART, opened with PIL before anything was written** (the standing
rule after two passes were burned by guessing). Every finding is in
`tools/import_original.py`'s MANIFEST comments:

| file | what it turned out to be |
|---|---|
| `Winbk_Phasecombat.pic` 164x760 | the Combat Bar. It is `Winbk_Phase`'s own 82px **[normal \| highlighted] pair laid down TWICE**, side by side — x 0..81 in the opponent's GOLD, x 82..163 in the player's BLUE — each column a full **760** tall, the Phase Bar's own height, so the file drops straight into that rectangle and nothing else has to move. Cells are the Phase Bar's 35x40 at x 3 / 44 (+82 for the player) and y `2 + 41*row`; icons at rows 0-5 and **7**, row 6 left as bare stone — the gap the original puts between the six in-combat icons and the exit. Where the Phase Bar picks its seat by HALF, this picks it by COLUMN |
| `Winbk_Attack.pic` 888x316 | the Combat window's ground, a field of skulls — and, like `Winbk_Telluser`, it carries **no bevel of its own**: every edge row is plain texture. So the window is RULED in code, by the same `OriginalDialog` routine that frames the Situation Bar, and wears that bar's stone as its title bar. Its 316 IS the layout: a title bar over two lanes of **140**, and 140 is exactly the box a TAPPED mini-card turns inside (`MiniCard.SIZE.x + 8`) — which is what an attacker becomes |
| `Winbk_Attacksword.pic` 56x132 | image+mask → a 28x132 steel sword: the ATTACKERS' lane marker |
| `Winbk_Attackshield.pic` 44x128 | image+mask → a 22x128 green kite shield: the BLOCKERS' lane marker |
| `Winbk_Attackbones.pic` 777x70 | image over mask (a VERTICAL split, the only one in the set) → a 777x35 strip of bones: the window's floor |
| `Winbk_Attackmin.pic` 39x70 | a dagger on dark green in a blue rule. **39 wide against a 41px Phase Bar column and 70 tall against its ~100px centre band**: this is the *"window icon in the center area of the Phase Bar"* (manual p.126) that restores the minimised window, drawn at 1:1. `Winbk_Spellmin.pic` is its twin (a wand) for the Spell Chain, and is surveyed but not imported — our chain has no minimise yet |
| `Winbk_Attackrats.pic` 142x210 | SIX 71x35 image+mask frames of a rat scurrying — the window's live decoration. Surveyed, not built |

One genuine difference worth recording: the Phase Bar's icons sit on
**black** cards and the Combat Bar's on **white** ones (checked in the
palette, not the eye — `phase_bar.png` carries a tRNS and pure black
grounds, `combat_bar.png` pure white). The Combat Bar is *meant* to read
brighter than the strip it replaces.

**MASK POLARITY IS NOT CONSTANT, and that is now handled.**
`MiniCard.masked_sprite` assumed a black-on-white silhouette
(`alpha = 1 - mask.r`), which is right for `Damage.pic` and inverted for
all three Combat window sprites. The mask's own **top-left pixel is by
construction background**, so the decoder reads the polarity off it
instead of carrying a per-file table, and grew a `vertical` flag for the
bone strip's top/bottom split. The alpha-carrying variant (`Summon.pic`)
is untouched.

**THE COMBAT BAR** (`game/duel/combat_bar.gd`) lives in the Phase Bar's
own column and only one of the two is ever visible — *"the Combat Bar
takes the place of the Phase Bar"* (manual p.125), *"During combat, the
Phase Bar is replaced by the Combat Bar"* (`Duel.hlp`, **Phase Bar**). It
is up from `COMBAT_BEGIN` to `COMBAT_END`, wears the attacking seat's
colour, lights one icon per step (the two DECLARE steps each carry both a
declaration and the fast-effects round that follows, which is exactly the
split the original drew as two icons — `awaiting_attackers` /
`awaiting_blockers` picks between the pair), and marks Stops with the same
red dot the Phase Bar does. Each icon carries its 1997 cue card as a
tooltip, and clicking one is the manual's third way to end a declaration:
*"Use the Done option on the mini-menu, the Done button on the Situation
Bar, or click a sub-phase on the Combat Bar."* Run-to and **Stops** landed
in the thirty-second pass, on both bars — `Duel.hlp`: *"you can even use
Stops."*

**THE COMBAT WINDOW** (`game/duel/combat_window.gd`) opens *"as soon as
you add the first creature to the attack"* and closes when combat ends.
Title `Your attack` / `%s Attack` (`@WINDOWTITLES`:155). Two lanes: the
attacking player's lineup on **their own side** of the window (yours
below, the opponent's above) and the blockers facing it, each lane marked
by the era's sword or shield. Minimise is the button at the upper-right
of the title bar (`@MENU_ATTACK` = `Minimize`), and it restores from the
window icon in the strip's centre band (`@MENU_MINIMIZEDATTACK` =
`Restore`; `@CUECARD_OTHER`:667 names the state `Minimized attack
window`).

**A CREATURE IN COMBAT LEAVES ITS TERRITORY.** The proof is a Manalink 3
patch: `src/patches/patch_not_in_combat_window_if_no_longer_attacking.pl`
exists to make *"creatures that attacked this turn, but are not currently
attacking, appear in territory instead of the combat window"* — only
worth writing if the window normally takes them out. (The same file names
the original's window class, `wndproc_AttackClass`.) `_rebuild_field`
skips whatever the window is holding, which also keeps the arrows honest:
exactly one widget per card, so the red blocker→attacker arrow runs
between the window's two lanes instead of forking between duplicates.
**[QoL] divergence:** minimising sends the lineup back to the board.
The original leaves it hidden inside the icon; a lineup nobody can see is
not a lineup, and minimising exists precisely to look at the board.

**WHAT THIS ANSWERS, AND WHAT IT DOES NOT.**
- **§2.2, the attacker/blocker LIFT, is superseded.** Its own note said
  *"check the manual first: if the original marked attackers some other
  way, that wins."* It did: the original moves them into the Combat
  window. s30's 20px slide is its substitute for a window it does not
  have (s30 fights in place). Nothing lifts because nothing is left on
  the board to lift.
- **§3.5 landed** on the way: a declaration the engine has stopped waiting
  for is now dropped the moment the declare step ends (s30
  `duel.go:1629-1656`), because a stale lineup would put phantom
  creatures in the window as well as phantom arrows on the board. Two
  existing tests had been relying on a mode that cannot occur in a real
  duel, and now set their step.
- **§1.4 (manual damage assignment) is untouched**, as instructed — it is
  sized L and the owner's to schedule.
- **§3.4 (menace pre-flight)** still needs engine §5.10 first.
- The **Phase Bar still has no per-slot tooltips** (`§6.1`) while the
  Combat Bar now does. The hover-zone mechanism is built and reusable;
  it is a ten-line follow-up, deliberately not taken here.
- One thing the manual specifies that we deliberately do NOT do:
  *"Once you have added a creature to the attack lineup, there is no way
  to change your mind and remove it"* (and the same for blockers). That
  fork already exists as `RulesOptions.attackers_revocable`, revocable by
  default by the owner's earlier call; the window does not change it.

**"DUELS OF THE PLANESWALKERS" — nothing distinguishes it for combat,
stated plainly rather than invented.** The project's goal (§ top of this
file) names MicroProse's own 1998 follow-up, not the 2009 Stainless
title. Searched: the word "planeswalker" occurs 14 times in the 1997
manual and **every one is lore** (Arzakon, Lim-Dûl, the Shandalar
backstory) — never a product name. `Duel.hlp` does not contain it at all,
and nothing in `Duel.cnt`, `UIStrings.txt` or the Manalink patch set
names a second product or a second combat screen. The 1998 Advanced
Strategy Guide in the repo's parent is a *play* guide with no UI in it.
So: **no combat distinction between the two exists in any source we
hold.** Everything above is the 1997 game's, and no 2009-era idea was
imported.

**VERIFIED VISUALLY**, three staged captures added to
`tools/screenshot_tour.gd` beside `shot_duel_block_arrows`:
`shot_combat_window` (the opponent's attack — gold bar, their lineup in
the upper lane, our blocker below, the red arrow between them),
`shot_combat_minimized` (the window folded into the dagger icon, the
lineup back on the board) and `shot_combat_your_attack` (blue bar, `Your
attack`, our attacker in the lower lane, the upper lane reserved). Each
was read back and the bar column, the title bar, the minimise button and
the window icon cropped and upscaled with PIL. The tour finishes with
zero script errors. One defect it caught and fixed: a `MiniCard`'s name
label carries `z_index = 2` (`mini_card.gd:158`), so a window at the
default zero had the territory's card names painted straight through its
title bar — the window sits at 10 and the arrow layer at 20, keeping
s30's order (arrows over the board, under the hand window).

Pinned by `tests/ui/test_combat_bar.gd` (12) and
`tests/ui/test_combat_window.gd` (14).

Twenty-eighth pass (2026-08-31) — EVERY POPUP, DIALOG AND BUTTON, on
the original's own chrome. The owner: *"Original has different style of
button, border, text… Try to find this art and reimplement as in my
reference photo."* His photo is of the **Situation Bar** (the 1997 name —
manual p.118, `docs/glossary-1997.md §1`): mottled red-brown stone with
a thin lighter rule inset inside it, a bevelled button at the left with
a dark outline and a pale label, and the message in large bold pale type
with a hard dark drop shadow, reading `Fast Effects?...Discard Phase`.

**THE ART SURVEY.** Every un-imported `DuelArt/WinBk_*` was opened with
PIL and looked at, because two earlier passes were burned by guessing:

| file | what it actually is | now |
|---|---|---|
| `Winbk_Telluser.pic` 600x35 | the Situation Bar's stone. Measured: mottled red-brown, and **no frame of its own** — every edge row and column is plain texture | already `message_panel`; the rule is now drawn |
| `WinBk_TellUser.bmp` 900x53 | **Manalink 3's flat grey gradient replacement.** Same name, different game | rejected |
| `Winbk_Questmana.pic` 289x274 | the mana-question window's DARK GREY STONE, 3px raised bevel | `panel_dark_stone` |
| `Winbk_Changetext.pic` 481x323 | the "change word / to" dialog's BLUE CELTIC KNOT (`@DIALOG_CHANGETEXT`), 3px bevel — the original's ground for a dialog that asks you to pick from a list | `panel_knot` |
| `Winbk_Endduel.pic` 272x422 | the end-of-duel window: blue and gold rings, and the ONLY **inset** bevel in the set (dark top/left, light bottom/right) — the duel's verdict is carved in, not raised | `panel_end_duel` |
| `Winbk_Startduelbutton{Normal,Depressed,Disabled}.pic` 131x36 | **THE 1997 BUTTON**, three states — the only generic button art in DuelArt | `button_normal/pressed/disabled` |
| `WinBk_EndDuel.bmp`, `WinBk_StartDuelButton*.bmp` | Manalink 3 again: flat grey, flat olive | rejected |
| `Winbk_Fireball.pic` 545x410 | the X-spell dialog's red spiral — a picture the size of a whole window, where our X dialog is a two-line question | surveyed, not imported |
| `Winbk_Manaburn.pic` 260x170 | an illustration (the mana-burn flash), not chrome; we have no mana burn | not imported |
| `Winbk_Attack.pic` 888x316 + `Attackbones/rats/shield/sword` | the attack animation's backdrop (a field of skulls) and its actors | not imported |
| `Winbk_Attackmin` / `Winbk_Spellmin` 39x70 | the MINIMISED attack and spell-chain windows (a sword, a wand) — `@MENU_MINIMIZEDATTACK` | not imported: nothing to minimise yet |
| `Winbk_Questmanaselection.pic` 36x57 | one beveled grey CELL of the mana-question grid | not imported |
| `Winbk_Phasecombat.pic` 164x760 | the **Combat Bar** — a real to-do (`duel-todo.md §6.5`), not popup chrome | not imported |

Two rules fell out of it and are written into `tools/import_original.py`:
a `.bmp` in a Manalink install is Manalink's own restyle and never the
1997 file, and **`Statbutt.spr` is the ADVENTURE's button strip** — its
sixteen 48px cells are the five mana symbols, then three states each of
"WIZ STATS", "JOURNAL" and "DONE". s30 blits its DONE onto the duel seam
(`duel.go:1019`) and so did we; it is a flat 48x22 grey tile that had to
be stretched to 64x24 and cannot carry a bevel at that size, which is
exactly the "different style of button" the owner is pointing at. Its
one lasting contribution is evidence: its DONE letters are **dark on a
light face**, which is how the original letters a button.

**THE COMPONENT — `game/duel/original_dialog.gd`.** One place for the
whole look, so it cannot drift popup by popup:

- `PANELS` — the measured bevel width per ground (Options 2px, Questmana
  3px, Changetext 3px, Endduel 3px, Bigcard 3px) as a 9-patch margin.
  The middle **stretches**, deliberately: these grounds are smaller than
  some of our windows and a second tile shows its join. Only the
  Situation Bar tiles, because a bar is never as wide as its own 600px
  stone, so exactly one tile is laid and clipped — the stone stays 1:1.
- `bar_texture()/bar_style()` — Telluser has no frame, so the bar is
  ruled: the era's ink `(28,24,26)` at the very edge and the highlight
  two pixels in, which is the owner's "thin lighter inset border line".
  A test asserts the middle of the tile is left untouched.
- `button()` — the 1997 three-state art 9-patched at margin 8. The frame
  is a **DOUBLE rule**, measured on `Winbk_Startduelbuttonnormal`:
  2px `(207,209,209)` highlight on top+left, 2px `(82,111,140)` slate
  shadow on bottom+right, 3px of speckled face, then that pair AGAIN at
  5-6px in. Depressed inverts both rules; Disabled inverts only the
  inner one. Godot wants five states and the era ships three: hover is
  `normal` brightened (a mouse cue the 1997 game had no concept of),
  focus follows hover.
- `label()` / `ink_label()` — the era's two voices, both read off the
  art: **pale `(207,209,209)` with a hard 1px `(28,24,26)` shadow** on
  dark grounds (the Situation Bar) and **dark ink with a pale outline**
  on the light sandstone (the toss dialog).
- `choice_line()` — a dialog answers a question with clickable LINES,
  tan `(205,176,143)` idle and pale `(247,240,208)` under the pointer.
- `field()` — a numeric field is the bevel run BACKWARDS (shadow on top
  and left), so the box reads as cut into the stone.
- `create()/body()/add_button()/dismiss()` — the modal itself.

Colours are `shandalar-src/Duel.plogpal`, the duel's own 256-entry
Windows LOGPALETTE; it was decoded to confirm the `.pic.png`
conversions are faithful (`Damage.pic.png`'s palette matches it entry
for entry from index 1), which is also what proves the greys in
Questmana and Statbutt are **real palette content**, not a bad
conversion.

**WHAT WEARS IT NOW.** The Situation Bar and its Done button, the
modal-choice dialog, the X question, the library picker, the ability
mini-menu, the end-of-duel window and the opening coin toss. Two of
those were OS windows (`AcceptDialog`, `ConfirmationDialog`) drawn in
the desktop's chrome, outside the dueling table entirely; a test now
forbids either class in `duel_screen.gd`. The coin toss was reviewed as
instructed and had a real defect: its 9-patch margin was **12** against
a bevel that is **2**, so the frame ate ten pixels of stone at every
corner and stretched the speckle — and with `tile` on, a 452px window
laid a second 400px tile and showed the seam. Both fixed; it also gained
its 1997 title.

**THE WORDS.** The bar's vocabulary was s30's paraphrase, which is how
we came to ask "Attackers?" — the `?...` form belongs to
`@PROMPT_FASTEFFECTS` and nothing else. Every string below is now quoted
from `shandalar-src/Program/UIStrings.txt` or `prompts.txt` (the
`Program/` copies — the top-level ones are Manalink 3):

| was | is | source |
|---|---|---|
| `Attackers?...Declare Attackers` | `Combat phase: Choose attackers.` | `@PROMPT_MAIN`:1063 |
| `Blockers?...Declare Blockers` | `Combat phase: Choose blockers.` | `@PROMPT_MAIN`:1063 |
| `Main phase: play a land or cast spells. Done to go to combat.` | `Main phase (before combat): cast spells, play land` — and the land clause drops once the drop is spent | `@PROMPT_MAIN`:1063 |
| `Fast Effects?  ...  <name>'s Main Phase` | `Fast Effects?...Main Phase`, and `Fast Effects?...Cast <card>` / `Activate` / `Process` while something waits on the chain | `@PROMPT_FASTEFFECTS`:1018 + `@PROMPT_CHECKFEPHASE`:1024 |
| `GAME OVER — X wins!` | `You won!` / `%s won` / `The duel is a draw` | `@DIALOG_SHANDALARENDDUEL`:514 |
| `<card>: choose <spec>  (Cancel to abort)` | `Select target creature.`, counted `(2 so far)` / `(2 so far, max 3)` | `prompts.txt` passim + `@PROMPT_GRABMANA`:1090 |
| `Not a legal choice for 'X'` | `Illegal target (X).` | `@PROMPT_ILLEGALTARGET`:1145 |
| `Already chosen — pick a different target` | `Is a target, can't target again` | `@CUECARD_SMALLCARD`:732 |
| `X can't attack: why` | `Illegal attacker. why` | `@PROMPT_MAIN`:1063 |
| `X can't block Y: why` | `Illegal block. why` | `@PROMPT_DEFENDWHOM`:993 |
| `<card> — choose X (max N)` | `Generic mana to put into the spell:` + `(max: N)` | `@DIALOG_FIREBALL`:657 |
| `<card> — pick <desc>` | `Select target card.` | `@DEMONIC_TUTOR` / `@REGROWTH`, prompts.txt:246,742 |
| `<card>...\nChoose one:` | `You select:` / `%s selects:` | `@PROMPT_NEWFULLCARD`:1114 |
| `Tossing for the lead...` / `X wins the toss and plays first!` | `Start of Duel` (title), `You won the coin toss.` / `%s won the toss` + `and will play first.` | `@DIALOG_STARTCOINFLIP`:483, `@DIALOG_PLAYORDRAW`:487, `@DIALOG_MULLIGAN`:499 |
| `OK` / `Cancel` / `Done` | unchanged — `@DIALOGBUTTONS`:172 names exactly these three, and no popup may invent a fourth | |

**THE ONE PLACE THE ART DISAGREES WITH THE PHOTO**, recorded so the
owner can arbitrate: he reads the Done button's face as **tan/salmon**
with a **light blue-grey** label. The 1997 files say otherwise — the
generic button face is a light blue-grey speckle
`(146,171,176)/(174,176,175)/(164,164,164)` with pinkish `(204,179,173)`
specks, and every button label evidence we have (Statbutt) is dark
letters on a light face. The standing rule is to port the art, so that
is what shipped; a photographed CRT warming a light speckle toward tan
is the likeliest explanation. Everything else in the description —
bevelled, light top-left, dark bottom-right, dark outline, pale bold
message with a hard drop shadow, the inset rule around the stone — is
now literally the original's.

Captured for review by `tools/screenshot_tour.gd`:
`shot_dialog_modes`, `shot_dialog_x`, `shot_dialog_search`,
`shot_dialog_end_duel`, `shot_menu_abilities`, plus the existing
`shot_coin_toss_result` and `shot_duel`. Pinned by
`tests/ui/test_original_dialog.gd` (20 tests, including the measured
bevel pixels of the button art) and seven more in
`tests/ui/test_duel_screen.gd`.

Twenty-seventh pass (2026-08-31) — THE HAND WINDOW, rebuilt from the
1997 asset, and the board it was covering.

**It was painted over the play area.** The stacked hand floats as a child
of the SCREEN at `Settings.hand_stack_pos()` (default 1062,412) while the
player's field rows flowed to the far edge of their half, so the lands
pile was sliced vertically and the pile beside it chopped mid-name. The
original never overlaps the two. `DuelScreen._apply_hand_reservation()`
now measures the window's LIVE rect against each half's rect and takes
the band it covers (plus `HAND_GAP`) off that half's right edge; a half
the window has been dragged clear of keeps its full width, and the
opponent's half pays instead if the window is dragged up there. It is
recomputed on every `_refresh`, on the window's `item_rect_changed` (so
it follows a DRAG and a hand that grows or collapses) and on each half's
`resized` (boot, window resize, stretch). The old fixed
`margin_right = StackHand.WIDTH + 24` on the two pile rows is gone — it
assumed a window position that the drag handle can change, and was 42px
short of the default position anyway. Pinned by three tests in
tests/ui/test_duel_screen.gd. **REVERSED on 2026-09-04** — a board that
yields to a DRAGGABLE window re-lays itself out on every drag. See the
fifty-fourth pass.

**The chrome is now ONE continuous piece.** It used to be a title strip
spanning the window with a separate thin-bordered box under it, stepping
at the corners, and the border was a FLAT sampled colour instead of the
original's pattern. Measured on `assets/original/hand_panel_red.png`
(the 1997 `Hand_Red.pic`, 145x51 — the same file s30 loads as `handBg`,
duel.go:1000; all five colours share the layout exactly):

| rows | what |
|---|---|
| 0-6 | patterned border |
| 7-28 | grey speckled title bar (▲ at x 1-9, ▼ at x 125-132) |
| 29-35 | patterned band under the bar |
| 36-43 | ONE tan list row — the stretchable middle |
| 44-50 | patterned foot |

and horizontally cols 134-140 are the patterned right border with 4px of
outer stone at 141-144. The file carries **no left border** — it starts
flush against the title bar — so `StackHand.window_texture()` mirrors
those 11 right-hand columns onto the left, giving a symmetric 156x51
window. That is drawn as a NinePatchRect over the WHOLE window (margins
11 / 36 / 11 / 7, vertical axis TILED so the tan list row and the side
pattern repeat at their own scale instead of smearing), with the speckled
bar sitting inside it at the top and the pile inset by the border. The
flat deck-coloured frame survives only as the no-skin fallback.

- The title reads LIGHT GREY, not yellow (yellow is the CASTABLE-card
  colour; both wearing it made the title look like a card row), and sits
  LEFT-aligned just past the ▲ exactly as s30 places it
  (`elements.NewText(16, label, dp.handX+15, dp.handY+13)`, duel.go:3571).
- The HOVERED ROW lightens and its name turns YELLOW (the owner's zoomed
  screenshot: "Disenchant" reads lighter and gold). The pile pushes the
  state into `MiniCard.hovered`, because a row's MiniCard is
  mouse-transparent — the holder Button takes the pointer.
- A CARD'S ART IS INSET INSIDE ITS FRAME. It ran to 0.03/0.965, i.e.
  straight over the frame's own borders, so a table card read as a
  picture with a hairline round it. It now uses the frame art's measured
  window (0.075/0.925 across, 0.917 at the foot — the same inset
  CardPreview uses) with the art window's gold/tan bevel redrawn at
  mini-card size, where the stretched frame loses it.
- Verified against a MIXED hand, because the white starter deck tints
  every row cream and hides tinting bugs: `tools/screenshot_tour.gd`
  stages the owner's reference hand card for card — Disintegrate / Fork /
  Regrowth / Disenchant / Volcanic Island / Taiga in a RED-deck window —
  as `shot_hand_mixed.png` plus `shot_hand_collapsed.png`. The rows come
  out red-brown, red-brown, green, cream, and neutral stone for both
  duals, with blue+red and green+red mana slashes at their right ends:
  the reference's own row colours. (Land frames ARE neutral in the 1997
  art — the five Cardbk_*land.pic top strips average within (116-134,
  95-105, 87-96) of each other — with only a thin colour-keyed rim, so a
  dual needs no special case.)
- Measured on the capture: outer stone 0-5, border 6-10, list 11-142,
  border 143-149, stone 150-153 — symmetric, and unbroken from the bar to
  the foot.
- NOT changed, and worth naming: the row NAME font stays
  `MiniCard.NAME_FONT_SIZE` (11). The owner's zoom reads "BIG BOLD", but
  one font size for every card name on screen is a standing decision
  (eleventh pass) and our 17px rows already give the name more of the row
  than the reference's ~13px ones do.

Twenty-sixth pass (2026-08-31) — THE ARROWS. s30 has them and we had
none; `game/duel/target_arrows.gd` is a straight port of
`s30/game/screens/duel/duel.go:3449-3554`, a Control that draws over the
board and under the hand window (exactly where s30's `Draw()` puts them:
after `drawBattlefield`, before `drawHandPanel`).
- `drawArrowLine`: a 2px shaft plus a 10px two-stroke head at the
  DESTINATION end, the barbs half a spread either side of the shaft.
- **RED (255,0,0)** from each blocker's TOP-CENTRE to its attacker's
  BOTTOM-CENTRE — the player's pending assignments always, and the
  blocks the engine already holds while the declare-blockers or combat-
  damage step runs (s30 gates on its declare-blockers and first-strike
  steps; our damage is one step and covers both).
- **AMBER (255,200,0)** from the casting player's hand window to every
  target of every spell on the stack — s30's own reason: "so the user
  can see what is being cast (especially by the opponent) and what it
  targets". A targeted PLAYER terminates on their life panel, s30's
  `targetPosition` (it uses (30, Y+32), and `drawLife` paints the 64px
  numeral at (15, Y), so that point is the numeral's own centre).
- OUR ONE DIVERGENCE, deliberate: the same amber also draws the targets
  picked SO FAR while a spell is still being aimed, so a half-declared
  Fireball shows what it has caught. Same vocabulary, one moment earlier.
  Attacker→defender arrows are NOT drawn — s30 has none, and the
  original lifts attackers instead.
The layer owns no state: `_refresh()` hands it the live game, the pending
block map and the picked refs, and it resolves screen positions at DRAW
time from the MiniCards that same refresh just rebuilt (asking a
freshly-added card where it is would read a stale rect). Pinned by
tests/ui/test_target_arrows.gd and by two staged captures in
tools/screenshot_tour.gd (shot_duel_block_arrows, shot_duel_stack_arrows).

CAVEAT FOR ANYONE ELSE CACHING WIDGETS — the board is IMMEDIATE MODE, and
that bit twice here:
- `CardPile.populate` calls `queue_free()` on its old cards WITHOUT
  removing them first, so for the rest of the frame the tree holds both
  the doomed card and its replacement. A scan that takes the first match
  caches the doomed one and hands `_draw` a freed object a frame later.
  `_collect` now skips any `is_queued_for_deletion()` subtree.
- Assigning a freed object to a TYPED local ("Trying to assign invalid
  previously freed instance") raises at the assignment, so a null check
  afterwards never runs. `_resolve` tests `is_instance_valid` BEFORE the
  `Control` assignment and drops the dead entry.
Neither showed up in the test suite — the UI tests never refreshed
between caching an anchor and drawing it, and only the screenshot tour
surfaced the 40-odd errors per run. Both are pinned now
(`test_anchors_survive_a_refresh_that_rebuilds_the_board`), and the tour
is the check that matters: it must print zero SCRIPT ERRORs.

Two documents came out of the same pass and are the standing reference
for what the duel still owes: **docs/duel-todo.md** (the prioritized work
list, every item traceable to the 1997 manual / Duel.hlp / string tables,
to s30's Go, or to mage-go, and each labelled [1997] / [s30] / [QoL] so
divergence is never silent) and **docs/glossary-1997.md** (the original's
own word for every duel thing, and the 1997↔modern phase mapping).

Twenty-fifth pass (2026-08-31) — the UI defects handed back by the
2026-09 engine/card audit (docs/audit-2026-09.md), each verified against
the code before being fixed, each pinned by a test in
tests/ui/test_duel_screen.gd:
- **An ability's X was never asked for.** Casting routed through
  _continue_cast_chain → _open_x_dialog, but activating went straight to
  _advance_pending and submitted the default x_value = 0. Voodoo Doll's
  "{X}{X}, {T}:" fired for free and the Candelabra's "Untap X target
  lands" untapped nothing. Abilities now open the same dialog, and
  _advance_pending passes _pending_x to activate_ability.
- **The X bound offered double on {X}{X} costs.** The engine charges
  x_count mana per point of X (mtg_game.gd:620, 762); the dialog's
  payable bound counted one, so Part Water and Voodoo Doll offered twice
  the X the pool could cover. It now multiplies by x_count, and reads the
  ABILITY's cost when an ability is what's pending.
- **Target counts were computed before X was known.** _build_target_slots
  ran at X=0 and _build_ability_slots hardcoded 0, so X-based counts and
  divided damage were sized from nothing. _on_x_confirmed now rebuilds
  the slots with the chosen X.
- **The ability menu listed PRINTED abilities while the engine indexes
  LIVE ones** (cur_mana_abilities / cur_activated_abilities). A Strip
  Mine under Blood Moon was offered its lost sacrifice ability and the
  wrong {T} mana line — and the indices could shift out from under the
  engine. The menu reads the live lists now, so the indices match by
  construction.
- **The castable hint lied under cost modifiers.** It ran can_pay on the
  PRINTED cost, ignoring Gloom's tax and the Mana Matrix's discount, plus
  restricted mana and colour substitutions. Rather than re-deriving the
  rule in the UI (where it would drift), the engine grew
  `MtgGame.can_afford(pid, data)` — the same folding cast_spell does,
  under the CR 601.2f discount floor — and the hint asks it. The yellow
  card name rides on the same answer.
- **The mana readout hid restricted mana.** It used `amount_of`, which
  counts only UNRESTRICTED mana, so tapping Mishra's Workshop floated
  three colourless and the panel still read all zeroes. `ManaPool` grew
  `total_of(color)` — the honest per-colour total — and the readout uses
  it.
- **Poison had no display at all** (CR 704.5c: ten counters lose the
  game), so a duel lost to Marsh Viper simply ended. A venom-green "N/10"
  now sits in the life panel's bottom corner, hidden while the count is
  zero.
- **A duel could not be reproduced from a bug report**: game.setup got no
  seed. DuelConfig grew `rng_seed`; the duel screen rolls a real one when
  it is 0 and LOGS it as the first line, so any duel replays by setting
  that field.

Twenty-fourth pass (2026-08-31), the owner's sidebar notes:
- The examined-card slot is NEVER an empty black hole. Before anything
  has been examined it holds a face-down MAGIC CARD BACK (the imported
  Cardback.pic, 228x323 — the same aspect the 1997 frame gives the
  CardPreview control, so it fills the slot exactly);
  `CardPreview.show_back()` toggles one full-rect Panel that is added
  LAST, so it covers the whole face, and `show_card()` clears it. No
  skin imported → a plain dark card shape in the back's brown.
- The player's LIFE numeral now finishes flush with the screen's bottom
  edge, and the deck/graveyard pair moved down with it. The block is as
  tall as the mana column beside it, which is taller than life+piles;
  that slack used to pool at the BOTTOM of the block. It is now parked
  on the block's middle side (an expanding spacer above the piles for
  the player, below them for the opponent), so both numerals hug their
  own corner of the screen.
- The big card rides as HIGH as the column allows — the 40px of air an
  earlier pass measured against the reference's y 0.258 is gone, on the
  owner's instruction. ALL of the column's slack now collects BELOW the
  card in `_qol_reserve`, the black strip that will hold the QoL
  controls (fast-forward, cancel, log, settings) when they land.
- Measured at 1280x800: opponent life 0-75, their piles 80-139, the card
  164-590, the reserve 591-657 (67px), the player's piles 658-717, their
  life 724-799. The canvas_items stretch carries it to 1280x720 intact
  (every band scaled by 0.9, the numeral still flush at 719).

Twenty-third pass (2026-08-31) — THE OPENING COIN TOSS, and what the
original actually does at duel start:
- The 1997 game DOES flip a coin. The proof is in the Manalink header,
  `shandalar-src/src/manalink.h`:
      int coin_flip(int player, const char *dialog_title,
                    int show_dialog_if_animation_is_off);
          // Last parameter should always be 1 except during game startup
  — i.e. the same routine cards use (Krark's Thumb and friends) runs at
  GAME STARTUP, with `Toss.wav` (WAV_TOSS = 59, defs.h). An earlier read
  of this screen guessed a CARD CUT off WinBk_StartDuel.bmp; that guess
  was wrong twice over — that panel is Manalink 3's own splash (it is
  branded "Manalink 3"), and the 1997 WinBk_StartDuel.pic is the
  PRE-duel Start Duel screen's backdrop (it comes with
  WinBk_StartDuelButton{Normal,Depressed,Disabled}), which is why
  `versus_background` already used it for the setup screen.
- The coin's own ART is a resource inside the 1997 executable, so it is
  not in DuelArt/ and cannot be imported (the whole folder was searched:
  no coin, no toss, no flip sprite). The coin is therefore struck from
  an original asset that IS a disc — each face is a seat's deck-colour
  MANA SYMBOL off Manasymbols.pic, ringed and shadowed. It reads
  instantly: the colour the coin lands on is the colour that leads.
- The toss is a DIALOG, so it wears the original's dialog chrome —
  Winbk_Options' beveled sandstone, drawn as a NinePatchRect (margin 12)
  so the bevel stays one pixel wide at any size, with dark ink and a
  pale outline on the verdict instead of a text box. The redundant
  `start_duel_panel` manifest key is gone (81 keys).
- Motion: the coin rises and falls on an eased arc while turning end over
  end nine half-turns (squash `scale:y` to a sliver, swap the face, open
  out), then settles with a BACK ease at 1.14x. `toss_start_face()` picks
  the starting face so the coin LANDS on the seat the engine chose — the
  animation reports the result, it never decides it (pinned by a test).
- Determinism bug fixed on the way: the leader was rolled with the global
  `randi()`, so a seeded duel would not replay its own opening. It now
  rolls on `game.rng`, part of the game's stream (pinned by a test).

Twenty-second pass (2026-08-31), the owner's four notes:
- MANA STRIPES read boldly now, and correctly. Two things were wrong:
  the band is a 2px diagonal in a 54x21 cell, so squeezing that cell into
  a 14px stripe dissolved it into a smudge — the original draws these at
  NATIVE size onto rows about as tall as ours, so the stripe is a 1:1
  window drawn unscaled, in the SHEET'S OWN orientation (the band leans
  bottom-left to top-right; mirroring it turned the slash the wrong
  way). The window is
  sized from the band's traced path — it runs (21,0) to (1,20) in the
  sheet, about 1:1 — so a 17x16 crop has the band's CUT EDGES meeting
  the top and bottom of the card's title bar, instead of the band
  petering out inside the stripe as a 14x15 crop did. And the sheet's black
  backdrop must be KEYED OUT, not kept: the reference draws a bare
  diagonal slash straight onto the card's own top-border texture with no
  block behind it (see the owner's Swamp/Badlands rows). The key
  threshold sits below the BLACK-mana band's own grey (0.18) so that
  band survives while the true-black backdrop goes.
- EDITION LABELS render as they are WRITTEN: the stem on the baseline
  with the ordinal RAISED beside it (2 with a small "nd", 4 with "th"),
  drawn as two labels rather than flat text.
- MANA STRIPES: every colour owns a FIXED SLOT along the title bar
  (W U B R G C, left to right, STRIPE_PITCH apart, the last flush with
  the bar's end). A card that makes several colours therefore shows
  several slashes AT ONCE, each in its own place — Black Lotus and Birds
  of Paradise wear all five, Badlands wears black and red — and a given
  colour lands at the same x on every card. The card's name simply stops
  short of the leftmost slot in use, so single-colour cards keep their
  room.
- TAPPED CARDS keep their exact dimensions and simply turn 90°, and the
  turn is now TWEENED instead of snapping. It animates once per tap, not
  on every board rebuild, and the id is forgotten on untap so the next tap
  animates again. (0.22s ease-out/BACK as first shipped; monotone
  `TRANS_QUAD` since the fortieth pass, because a resumed overshoot
  wobbles, and owned by `MiniCard` since 2026-09-03.)
- THE EFFECT OVERLAY (the summoning spiral) draws at FULL strength over
  the art rather than at 75% — it reads at a glance, as in the
  reference's Onulet and Urza's Avenger.

Twenty-first pass (2026-08-31) — the two gaps named at the end of the
twentieth are closed:
- DAMAGE MARKER decoded. The original ships TWO Damage.pic files and the
  importer was taking the wrong one: the converted 94x20 copy is neither
  a plain sprite nor a clean pair, while the RAW 84x26 file is a proper
  image+mask (white background, black silhouette). The manifest now
  prefers the raw .pic (a duplicate manifest key was also silently
  overriding the entry), and the spiral's decoder was generalised into
  MiniCard.masked_sprite(), which handles both the silhouette-mask and
  the alpha-carrying variants. A wounded creature now wears the dagger
  plus its damage number instead of the words "N dmg".
- ASPECT verified rather than assumed: the duel was captured at 1280x720
  (the shape of the owner's screenshots 2 and 3) and the whole
  composition scales proportionally — sidebar, phase strip, half-split
  board, seam popup, piles right, creatures at the far edge, hand window.
  Nothing reflows or clips beyond the board's own margins.

Twentieth pass (2026-08-31) — the final measured comparison. Every
landmark was measured on a fresh capture and checked against the same
landmark in the owner's screenshot, as a fraction of the screen:

| landmark | reference | ours | delta |
|---|---|---|---|
| sidebar right edge | 0.240 | 0.234 | 0.6% |
| phase strip left | 0.247 | 0.241 | 0.6% |
| board left | 0.287 | 0.287 | 0.0% |
| seam / message bar | 0.489 | 0.485 | 0.4% |
| Done button left | 0.310 | 0.291 | 1.9% |
| big card top | 0.258 | 0.256 | 0.2% |
| big card bottom | 0.782 | 0.792 | 1.0% |

Two fixes came out of it: the Done button sat ON the phase strip (the
reference puts it inside the board, just right of the strip), and the
big card rode 5% high because our opponent block is shorter than the
reference's — a measured 40px of air above the card puts both its top
and bottom on the reference's marks.

Nineteenth pass (2026-08-31) — MULTI-TARGET CASTING. The engine grew
variable and divided targeting (wave 43); the screen still mirrored the
old "one TargetRef per effect" model and simply could not cast those
cards. Targeting now walks one SLOT per targeting effect, each carrying
its own (min, max) from EffectBase.target_range plus its divided total,
so "Tap X target creatures", "one or more target creatures" and
"N damage divided among any number of targets" all drive the same loop:
a fixed slot closes itself, a variable slot closes on Done once its
minimum is met, duplicate picks are refused, and already-chosen targets
highlight as SELECTED.
SIMPLIFIED: a divided amount is spread as evenly as it goes (remainder
to the first target) rather than dialled in per target — picking a
single target still sends the whole amount, which is the common case. A
per-target dial is the natural next step.
*LIFTED by the forty-seventh pass: the original's per-target dial is
`@PYROTECHNICS` (`Program/prompts.txt:698`), a CLICK LOOP of `Select
(1st of 4) target creature or player.` prompts — one click per point of
damage, the same gesture as the combat division. The marker and its
`docs/ROADMAP.md` row are both gone.*

Eighteenth pass (2026-08-31): the GRAVEYARD shows its TOP CARD when it
holds one and the original's empty-grave plate otherwise (the reference
shows a card face in a full graveyard); the DONE button is sized to the
reference's proportion (~37px of a 750-wide screen = 64 at our 1280,
down from 88).

Seventeenth pass (2026-08-31): the two UI defects found by the code
review (docs/code-review-2026-08.md) are fixed here —
- the hand's castable hint now requires PRIORITY, and a land lights only
  when the land drop is genuinely open (mirroring MtgGame.play_land's
  CR 305.1 conditions); it used to promise actions the engine refuses;
- the summoning-sickness spiral also respects cur_attacks_as_if_hasty,
  so an Instill Energy'd creature that can legally swing is no longer
  drawn as sick (Instill Energy lifts the attack gate without granting
  real HASTE).
Both pinned in tests/ui/test_stack_hand.gd.

Sixteenth pass (2026-08-31): mini cards also badge their ACTIVATION
COST — the reference puts a small mana symbol at a permanent's
bottom-left for the ability you can use (Urza's Avenger wears the "0" of
its "{0}:" ability; a Circle of Protection wears its "1"). Vanilla
creatures badge nothing. Pinned by tests/ui/test_stack_hand.gd.

Fifteenth pass (2026-08-31), the owner's strips/borders/icons round:
- HAND STRIPS now read as the original's thin list: a covered card shows
  a 17px band (the reference's rows are ~13px on a 1280-wide screen; ours
  keeps the 11px name legible), and the MiniCard's title bar was tightened
  to match (y 2..18).
- DECK BORDER corrected. The earlier colours came from the middle of each
  Hand_<colour>.pic, which is shared tan chrome — that is why a white deck
  framed itself in gold. Sampling each bar's OUTER EDGE gives the real
  frame colours: white 110,110,112 · blue 20,47,109 · black 67,67,67 ·
  red 155,36,28 · green 28,28,28.
- EVERY card names its set: the original's DBArt symbol where one exists,
  and a short LABEL where it never did (Unlimited "2nd", the promos "PR").
- MINI-CARD ABILITY ICONS extended per s30: keyword badges (11 flying,
  12 trample, 13 banding, 14 first strike, 16 reach) PLUS the protection
  shields (5 green, 6 red, 7 blue, 8 black, 9 white), deduped, drawn in a
  row along the card's bottom edge and only while the card is IN PLAY.
- The LARGE CARD BUILDER learned card quirks: a creature whose printed
  P/T is 0/0 with statics that set it prints "*/*" (Nightmare, Keldon
  Warlord — as the original does); rules text steps its font down
  (12/11/10) instead of overflowing its box; battlefield cards show live
  P/T, hand cards printed.
- Deferred: the original's Damage.pic marker. Its 94x20 file decodes as
  neither a plain sprite nor an image+mask pair (the whole thing is
  opaque and the right half is not a silhouette), so wounded creatures
  keep the legible text indicator until the format is understood.

Fourteenth pass (2026-08-31), closing the two gaps named at the end of
the thirteenth:
- BOARD BACKGROUND: Terr_*.pic is a whole board background (721x381),
  not a small tile. Tiling it left a seam a third of the way across each
  half; each half now fills with one scaled image, as the original does.
- KEYWORD BADGES: ported from s30's getKeywordIcons — the ability sheet's
  cells (11 flying, 12 trample, 13 banding, 14 first strike, 16 reach)
  drawn in a row along a permanent's bottom edge, exactly where s30 puts
  them (pos.Y + cardH - iconSize). Badged only IN PLAY; the status text
  moved under the title bar so the two never collide.

Thirteenth pass (2026-08-31) — a region-by-region measurement against the
owner's screenshot fixed two layout errors that had survived every
earlier pass:
- The board is NOT mirrored. Measured on the reference: the player's
  artifact/land piles sit just BELOW the seam (y 290-350 of 563) with
  their creatures LOWER (y 450-520). Both halves therefore read the same
  top-down order — piles first (right-hugging), creatures after.
- Creatures hug the FAR EDGE of their own half: the opponent's just
  above the seam (y 175-245 of a 0-265 half), the player's near the
  screen bottom. An expanding spacer above each creature row pins them
  there instead of letting them float under the piles.
- The mana pool is sized to what is left beside the 428px big card
  ((800-428)/2 per block); at 1.05 scale the player's pool ran off the
  bottom of the screen.

Twelfth pass (2026-08-31) — THE MINI CARD. CardWidget is renamed
MiniCard and is now the single generator for every card on the table, so
a played card, a pile card and a hand card are the same component at the
same size; CardPreview is its large counterpart. A MiniCard draws: a
border of the card's own frame texture with its TOP BORDER as the title
bar · the art · the name on that bar, YELLOW when castable now and WHITE
otherwise (MiniCard.castable) · one diagonal mana stripe per colour the
card can produce · the SUMMONING-SICKNESS SPIRAL over the art of a
creature that can't act yet (the original's Summon.pic — note the two
source variants: the raw 1997 file carries a black-on-white MASK, the
converted one carries ALPHA in that half, and the loader detects which)
· P/T at the art's corner. A CardPile is a stack of MiniCards, each
covered one CLIPPED to its title bar, under the hand window's
deck-coloured border and "Your hand (N)" title. The big card also gained
true card proportions (SIZE 300x428 = the frame art's own 228:325, within
2% of a real 63x88mm card) and a smaller set symbol.

Eleventh pass (2026-08-31), four measured corrections:
- Set symbols keep ONLY the symbol. Their DBArt backdrop is a grey BEVEL
  (light at the top corners, dark at the bottom), so keying one flat
  colour left a black square; every ACHROMATIC pixel is keyed instead,
  which the strongly-coloured symbols survive untouched.
- Rules text is inset inside the frame's white box (measured at
  x 8.3%-91.7%; the text now runs 11.8%-88.2%) instead of sitting flush
  against its left edge.
- Mana stripes read correctly: the coloured band occupies the LEFT part
  of each Manastripes cell (x 1..25 of 54), so cropping the middle — as
  the first attempt did — caught mostly empty backdrop.
- ONE font size for every card name (CardWidget.NAME_FONT_SIZE, used by
  table cards and hand rows alike); names too long to fit are TRIMMED
  WITH AN ELLIPSIS rather than scaled down.

Tenth pass (2026-08-31): deck-border colours are now SAMPLED from the
original Hand_<colour>.pic art (white 207,173,113 · blue 20,47,109 ·
black 67,67,67 · red 155,36,28 · green 37,84,41) instead of being
approximated; the big card's art is inset to sit INSIDE the frame's
bevel rather than riding over it; and a card's SET SYMBOL is drawn at
the right-hand end of the middle border, just under the art — using the
ORIGINAL's own DBArt icons (imported as set_icon_<code>, backdrop keyed
out). Unlimited and the promos show none, exactly as the printed cards
have none. tools/screenshot_tour.gd gained shot_card_detail.png so the
symbol slot is exercised in review shots.

Ninth pass (owner's hand-stack specification, 2026-08-31) — the hand
window is now built from the original's own rules:
- The window wears the DECK's dominant colour (Hand_<colour> title bar +
  matching border), and is PAD wider than its cards so that border is
  never covered by the rows.
- Each covered card is represented by its OWN TOP BORDER: that strip of
  the card's frame texture (CardWidget.frame_strip, the top 5.5% of
  Cardbk_*.pic) as the row background, carrying the card's NAME and NO
  mana cost.
- Name colour is a STATE, not an identity: YELLOW when the card can be
  cast right now, WHITE when it can't (so the castable-green glow was
  dropped from piles; glows remain for targeting/selection only).
- Cards that produce mana carry one diagonal Manastripes band per
  colour they can make, at the row's right end. The sheet's black
  backdrop is KEPT — that dark block is what makes a white or black
  band readable on a light marble row.
- The front card extends the same border into a full table card
  (border, name, mini art) at exactly CardWidget.SIZE.

Eighth pass (owner's table-card reference, 2026-08-31): a table card is
a TITLE BAR IN THE CARD'S OWN COLOUR (blue for King Suleiman, red for
Dwarven Warriors, tan for Savannah Lions — never black) with the name
reading dark on light bars and gold on dark ones, art filling the rest,
and P/T overlaid white-on-art at the bottom-right corner. On the big
card the mana cost now fills and centres in the top-border band instead
of anchoring to its midpoint, which had let the symbols hang below the
border onto the art.

Seventh pass (owner's card-anatomy directive, 2026-08-31):
- The big card is drawn ON the frame's own regions, measured from
  Cardbk_White.pic (228x325): top border 0-5.5% carries NAME + MANA
  COST, art window 5.8-55.5%, the strip at 55.5-60% carries the TYPE
  LINE, the white box 60-91.7% carries the RULES TEXT, and the bottom
  border 91.7-100% carries P/T. No band, box, or square is drawn behind
  any of it — "only card back and text". The flat no-skin fallback
  paints an equivalent frame (and only then a parchment rules box),
  with the ink colour flipping to suit.
- ONE card size on the table: CardWidget.SIZE is the single constant;
  CardPile.WIDTH and its visible last card derive from it, so a played
  card is exactly as big as a card in the hand window. Detail comes from
  hovering, which fills the big card in the sidebar.
- Covered pile cards are NAME ROWS (identity-coloured name + mana cost
  on a dark strip) — the reference's hand list, and legible at any card
  size, replacing the scaled card faces used before.

Sixth pass (measured against the owner's screenshots, 2026-08-31):
- No black bands on cards. Field-card names draw DIRECTLY on the art in
  gold with a dark outline; the fully-visible bottom card of every pile
  is the REAL CARD SCAN (Scryfall border_crop via
  tools/fetch_card_art.py, all 896 fetched — the tool now pulls art_crop
  AND <name>_card.jpg, with rate-limit backoff). Covered pile rows keep
  their black name rows — that IS the reference's strip look.
- Battlefield cards show no mana cost (hand cards do).
- Proportions measured off the screenshots: the left column is 23.4% of
  the screen = CardPreview.SIZE.x, so the docked big card renders 1:1
  and lands on the reference's 52% height.
- Lands/other permanents hug the RIGHT of each half and size to content;
  creatures take the leftover height and read from the left — the
  reference's arrangement. The player's piles keep clear of the hand
  window; board halves are inset so nothing clips at the edges.
- The opponent's hand window — its TITLE BAR only — at the bottom-right of
  the opponent's half (level with their creature row). *Superseded by the
  fortieth pass: it was a squashed copy of the whole window with the ▲ ▼
  written into its text as well as painted into its texture; it is now
  `StackHand.title_plate` and says `Opponent (N)`.*
- Spell-chain items are a TAN caption box ("Ability Effect" / source
  name) over the real card scan, floating on the board — no panel.
  *Superseded by the forty-second pass: the caption keeps its tan box but
  is one line in the original's own words, and the scan is a `MiniCard` —
  the chain was the last card on the board that was not one.*
- Message box: WHITE text on the dark Telluser box, terse original
  wording ("Attackers?...Declare Attackers").

Fifth pass (owner's complete-reimplementation directive — divergence and
QoL return LATER): pure BLACK ground with floating panes (no parchment
sidebar panel); the enlarged card is a LARGE CENTERED popup shown while
hovering (scale 1.3, hides on leave — nothing docked); NO message row in
the board (the halves meet directly; Done + the Winbk_Telluser box float
as a popup over the seam); the Fast-forward/Confirm/Cancel buttons, the
turn label and the on-screen log are REMOVED — Done doubles as the
declaration Confirm (lit when confirmable), keyboard shortcuts remain,
the log accumulates in game.log_lines for a future QoL viewer.

Fourth pass (owner's exact-layout screenshot): playfield split EXACTLY
in half (_board_half: equal-stretch halves, per-seat tiled Terr_*
patterns, message seam between); life numerals at the extreme sidebar
corners with mirrored deck/grave blocks; the phase strips' RED DOT
marker (8 icon slots per half, dot rides the active player's strip —
**superseded by the thirty-second pass: the dot marks STOPS, and the
current phase is marked by the highlight the manual gives it**);
piles framed in the tan window border with COMPACT last faces (name +
art + type, no rules box — rules live in the enlarged view); field
cards resized to the reference's proportions (CardWidget.SIZE 132x106,
art-dominant, gold names, white P/T with shadow over the art corner);
the message popup is compact and left-aligned at the seam (Done button
+ Winbk_Telluser tan box, dark-red text); artifact pile names GOLD
(Black Lotus / Mox / Black Vise).

Thirty-fifth pass (2026-08-31) — **THE DECK BUILDER, AUDITED AGAIN**
(`game/deck_builder/`). The restyle moved every region, so the screen was
driven end to end a second time: every filter combination, the 200/500
limits, save and load round trips, deck notes on files written before the
field existed, paging boundaries, rapid clicks, drags both ways, the
mini-menus and the keyboard, at 1280x800 and 1280x720. Six defects, two
recovered 1997 commands, six [QoL] additions and a measured optimisation
pass; the full record with numbers is in `docs/ROADMAP.md`.

**The thrice-corrected medallion cell map survived independent
verification and was NOT moved a fourth time.** The check was rebuilt from
the pixels rather than from the earlier reasoning: the strip in the
owner's screenshot was located by its own bevel (eighteen buttons on a
39px pitch, 40px tall, drawn 1:1), one global (dx, dy) alignment was
fitted across all eighteen at once, and each was correlated against all 27
cells of all three sheets. Every button has a unique top match;
Enchantments (1,3) scores 0.635 against a runner-up of 0.437 and Sorceries
(2,6) 0.651 against 0.529. The on/off polarity holds on luminance too
(capture 85.6-138.9, `sprite_sheet` 68.3-128.0, `sprite_sheet_pressed`
38.0-71.8), and `Bldr_sheet` is confirmed as the deck grid's watermarks:
the capture's quilt is a 126x103 tiling of those 117x100 carvings cycling
`(row * columns + col) % 5`.

Two corrections to the thirty-fourth pass's record, both from the same
check. **The gold ring is not a rule** — (0,1) is `Gold`, a COLOUR filter,
and it wears one; it happens to separate the type run from the sets, which
is all that pass needed of it. And **the screenshot's strip has no Set
group at all**: its eighteen medallions are six colours, the seven types
and five Other Filters, and no button matches the anvil, the scimitar, the
ringed crescent, the IV, the column or the comet. That capture is the
IN-SHANDALAR Deck screen; the Set Filters the manual names as one of its
four groups belong to the STANDALONE builder, which is what we draw, so
our strip is twenty-three medallions wide and not eighteen.

The pass also read the whole deck-builder run of `s30/assets/text/
Menus.txt` rather than the one tag the screen quoted, and found two 1997
commands the builder never had: `@EXTRACARDSDIALOG`'s **Extra Cards** —
which is a dialog with an ACTION, *"Remove Extra Cards"*, for the
duplicate advice the screen could previously only print — and
`@DECKSURFACE_ADVENTURE`'s **Move by color out of deck** with
`@GROUPMOVE`'s own colour picker. `@LONGLIST`'s *"Select All / Clear All"*
supplied the era's words for the one thing a strip of twenty-three toggles
badly needed: a way back from them.

**THE FORTY-EIGHTH PASS (2026-09-02) — `YOUR TERRITORY BACKGROUND`: THE
CHOOSER, AND THE TEN FILES NOBODY HAD ASKED FOR.**

`@DIALOG_DUELOPTIONS` ends with `Your &territory background` and nine
choices, and `Duel.hlp`, **Dueling Options**, says what they are: *"The
list on the left simply allows you to pick the predominant color of your
background. The list on the right includes the different types of
background art available for each color. Select one option from each."*
Two lists, not a list of nine — which is what `Magic.exe`'s two registry
values, `PlayerTerritoryColor` and `PlayerTerritoryType`, already said.

**The art was there the whole time.** §6.4's ledger row claimed the `pict`
and `mana` styles could not be imported because *"the only copies in
`../shandalar-src` are Manalink `.bmp`s"*. True, and irrelevant: the
importer reads the s30 conversions, and
`s30/assets/art/screens/duel/` holds all fifteen `Terr_*.pic.png`
files in the same directory as the five `patt` files it was already
taking. Ten MANIFEST rows, and the shortfall was gone.

**The three styles are three different kinds of file, opened at 3-8x
before anything was wired:**

| file | what it is | how it is drawn |
|---|---|---|
| `Terr_<c>patt.pic` | a seamless damask ringed by a DECORATIVE BORDER — 8px on white/blue/red/green, ~20px on black (a corner ornament plus a double rule) | `NinePatchRect`, `AXIS_STRETCH_MODE_TILE`: border at native size, field tiled inside it |
| `Terr_<c>mana.pic` | a borderless wallpaper quilting ALL FIVE mana glyphs on speckled stone, tinted to the colour — the owner's own screenshot | tiled at native scale |
| `Terr_<c>pict.pic` | ONE picture: carved angels, a winged orb, a hooded figure with a lantern on a jetty, a sleeping nymph, a dragon over a magenta sea | `STRETCH_KEEP_ASPECT_COVERED` — a board half is 914x400 and the art 721x381 or 888x381, and a 27% horizontal stretch is nothing on a damask and very visible on a dragon |

That border is also the answer to a note the previous pass left in
`_board_half`: *"tiling it left a seam a third of the way across."* The
seam was the frame repeating. Measured by trimming t pixels off the file,
tiling the rest to 914x400 and looking — below the border it bars, at the
border it is seamless.

**Two claims corrected, both written from reading rather than building.**
`Terr_<c>mana` is not *"a repeat of that colour's mana symbol"* — that is
`Life_<c>mana`, re-checked and confirmed (black skulls, blue drops, green
trees, red dragons, white suns, one glyph per file). And `Your &territory
background` has **no colon**: `UIStrings.txt:609` runs straight from `d`
to the newline and `Magic.exe`'s UTF-16 dialog resource holds the same 26
characters. The colon the panel draws is ours.

**Without the 1997 art, all fifteen grounds are painted**
(`game/duel/territory_ground.gd`): a lozenge lattice, a medallion quilt
and one outlined emblem, over a Bayer-dithered stone in the seat's colour,
every tone arithmetic on that colour's own card-frame tint. Provenance.md
requires the game to be complete without an imported asset, and a
nine-choice chooser whose choices all looked alike would not be one.

**[QoL] the same two lists sit on the battle-setup screen**, beside the
duelist portraits, with a live preview at the board half's own aspect —
a place the original never put them, so labelled `[QoL]` on the screen.
One value, two views: both write `DuelOptions`'s accessors.

**Per player, not per seat.** The help settles the colour outright (*"You
cannot do anything to change the background in your opponent's territory;
it matches the predominant color in her deck"*) and says nothing about the
opponent's *style*; one stored `PlayerTerritoryType` cannot say whether
the other half followed it. Our choice, recorded as a choice: the
opponent's half wears the same style at her own deck's colour.

**THE FORTY-NINTH PASS (2026-09-02) — THE GAUNTLET: THE MODE THAT NEEDED
NO NEW SCREEN, ONLY AN OUTER LOOP AND TWO WINDOWS.**

The fourth 1997 duel mode, `2&Gauntlet:Defeat as many opponents in a row
as possible.` (`@SHELLSCREEN_DUEL`), built from `docs/gauntlet-design.md`
without re-deriving it. Nothing on the duel screen changed and nothing in
`engine/` did: a gauntlet is a sequence of MATCHES the way a match is a
sequence of duels, so `GauntletScreen` owns `MatchScreen`s exactly as
`MatchScreen` owns `DuelScreen`s, and the layer below never learns the
mode exists.

**One change to `MatchScreen`, and it is a flag rather than a count.** A
finished match now emits `match_finished(winner_id)` always, and
`reports_to_owner` — set by the gauntlet — decides whether the match keeps
its own last window and its own exit. The first cut asked
`match_finished.get_connections().is_empty()` instead, which is neat and
wrong: a GUT test that merely WATCHES a signal is a connection, so the
test that pinned the standalone path was the thing that broke it. The flag
is what a screenshot could not have caught and a test did.

**Two windows, and both were screenshotted.** *Gauntlet Options*
(`@DIALOG_GAUNTLETOPTIONS` entry for entry, plus the shell page's
`&Num opponents:` and `Side&board between duels`) on the pre-duel
`Winbk_Startduel` ground; and the round window
(`@DIALOG_GAUNTLETENDDUEL`) between matches, on `panel_end_duel`'s inset
bevel once the run is over. The screenshot pass earned its keep twice
over, on defects no assertion saw:

* **`Run the gauntlet` and `Quit Gauntlet` had their last letter sitting
  ON the button's inner rule.** `OriginalDialog.button` floors a button at
  96px — the width `OK` and `Cancel` want — and the 1997 art it wears is a
  double rule 8px deep per side. `GauntletOptions.fit()` now measures the
  label against the button's own font and widens it. **The same tightness
  is on every long dialog-button label in the project** (`Continue match`,
  `Sideboard...`); this pass fixed only its own, and the general fix
  belongs to whoever next touches `OriginalDialog`.
* **A window on a black void.** A gauntlet reaches its first duel through
  nothing else, so the options window had no ground under it at all until
  `_backdrop()` gave it the battle-setup screen's own.

Two smaller things the shots settled: the `Num opponents` box wears
`OriginalDialog.field()`'s sunken bevel rather than a bare `SpinBox`, and
the window's height came down from 520 to 450 so the stone reads as a
window rather than a wall.

**What did NOT get built, deliberately.** `The match continues...`
(`@GAUNTLET` entry 10) is composed and tested and never rendered: the
original showed one window after every duel, and ours shows
`MatchScreen`'s own between-duels window mid-match — which is
`docs/gauntlet-design.md` §1.5's reading, and the only branch of the four
that falls out of it. `&Save gauntlet` / `&Load gauntlet...` stay out of
scope (§5.5); the run logs its seed instead.

**THE FIFTY-FIRST PASS (2026-09-02) — THE GAUNTLET'S 1997 FINISH, AND THE
FORK ESCAPE WALKED THROUGH.**

(The fiftieth is the coin toss, claimed by the file map's `coin_toss.gd`
row.)

**Slice 4 of `docs/gauntlet-design.md`, which the forty-ninth pass left
owed.** Three things, and one of them turned out to be a mistake in the
design:

* **The three next-opponent announcements**
  (`@DIALOG_STARTEXP1MATCH_GAUNTLET`, `Program/UIStrings.txt:149-153`) get
  a small window of their own before each match — the line over the
  opponent's name, first / nth / final. In 1997 they sat on the pre-match
  VERSUS screen (`@DIALOG_STARTEXP1MATCH`'s `vs.` / `playing with %s`,
  whose art is the 240x170 `Face_*` set); we have no versus screen and
  slice 4 does not owe one, so the three SENTENCES get the smallest honest
  home and the two versus-screen strings are left for whoever builds it.
  The middle line's original spelling is
  `You now meet opponent %1!d! (of %2!d!) in the gauntlet:` — Windows
  POSITIONAL printf, so its two arguments are the round and the run length
  in that order.
* **`&Create Deck...`** (`@DIALOG_GAUNTLETSTARTUP` entry 13, `:648`) sits
  on the Gauntlet Options window between `Run the gauntlet` and `Exit`,
  where the original lists it, and is a scene change to the Deck Builder.
  The 1997 rule that comes with it — re-enumerating the decks re-shuffles
  the run — then holds **by construction**: leaving is a scene change, and
  the next entry re-reads the folder in `_ready` and re-shuffles in
  `begin_run`. What diverges, marked at the site: the original came back
  to its startup screen with the parameters still set and ours comes back
  to the title, because honouring the return needs the Deck Builder to
  know who sent it — the same missing piece that keeps `MatchScreen`'s
  `&Edit deck...` greyed.
* **The rest of `@GAUNTLETERRORS`' opponent-deck refusals**, which is where
  the design was WRONG. It asks for four; **three are producible**.
  `Opponent's deck %s is invalid. Wrong version number.` is not, because
  neither deck format this project reads carries a version number: all 55
  shipped 1997 `.dck` files open with a bare name line and no version
  field, our `.deck`/`.dec` text has none, and the only numbered revision
  anywhere is Manalink 3's `;%d` header
  (`shandalar-src/src/deck/deckdll.cpp:5522-5545`, Tier 3). The string is
  kept with that obituary on it, the way `WON_DUEL` and `CONTINUES`
  already are, and a test asserts nothing can return it. Wiring it would
  have meant inventing a condition.

**The screenshot recipe earned its keep a third time on this mode.** The
announcement window was built at 430x190 by analogy with the round
window's 430x250 and the capture showed a hand's width of bare rock
between the opponent's name and the OK button — the round window carries
five lines in that height and this one carries two. It is 430x150 now.
The same run, against the real deck folder, stopped at round 1 with
`Opponent's deck New Deck is invalid.` — a 44-byte `New Deck` left in
`user://decks` by an earlier Deck Builder session, i.e. the per-round
validation working exactly as specified on a file nobody planted for it.

**AND THE FIFTH-EDITION AUDIT'S OPEN FINDING, FIXED.** Under
`attackers_revocable = false` (the 1997 answer, manual p.86)
`_toggle_attacker` refused to take ONE attacker back — *"attackers are
final"* — while `_on_cancel`'s `Mode.ATTACKERS` branch cleared
`_selected_attackers` unconditionally. So **Escape un-declared all of
them**, and so did the Situation Bar's Cancel button, which is the same
door (`_cancel_button.pressed.connect(_on_escape)`). The rule was already
written down: `_can_cancel`'s own doc comment says the declarations are
cancellable *"because ours are revocable up to Done
(`RulesOptions.attackers_revocable`)"*. Only the code did not read the
flag that sentence names.

Two conditions, and **both are needed for different reasons**:
`_on_cancel` clears only when the flag allows it — that is the
load-bearing one, because `_on_escape` falls through to `_on_cancel`
without ever consulting `_can_cancel` — and `_can_cancel` reads the flag
so the bar stops offering a button that would do it. Blockers are
untouched: p.86 is about the ATTACK declaration, and a half-made block is
still the *"situation"* `Duel.hlp` makes the button conditional on.

## 4. Interaction model (v1, implemented)

A single mode machine in duel_screen.gd (mirrors s30's duel screen design,
simplified):

| Mode | Entered by | Clicks mean |
|---|---|---|
| NORMAL | default | hand card → cast (auto-enters TARGETING/X as needed); own land/permanent → tap for mana or ability menu; Pass button → pass priority |
| TARGETING | casting a targeted spell/ability | legal targets are highlighted; click one to choose (multi-target specs collect in order); Cancel aborts cleanly (no cost paid — legality is pre-checked, costs are paid only when the engine accepts the full action) |
| X_PROMPT | casting an {X} spell | `@DIALOG_FIREBALL` (`game/duel/fireball_dialog.gd`): a field for the generic mana, bounded by what the pool can pay — plus, for a spell that also buys targets with it (Fireball), a second field for the count and three live read-outs showing where the mana went |
| ATTACKERS | engine awaits attackers | click own creatures to toggle into the attack (legality errors surface in the prompt); Confirm declares |
| BLOCKERS | engine awaits blockers | click your blocker, then the attacker it blocks; click a blocker again to unassign; Confirm declares |
| DISCARD | engine holds the cleanup step open (`awaiting_discard`, §1.1) | click hand cards to pick and un-pick; `Select card to discard. (n of N)`; Done submits |
| DAMAGE | engine holds a combat damage step open (`awaiting_damage_assignment`, §1.4) | one click = one point onto a blocker (or the opponent's life register, for trample); `%s: Assign damage to blockers, %d points left` counts down and the division submits itself at zero |
| TARGETING, divided slot | casting "N damage divided as you choose" (§6.14) | the SAME click loop, in the original's other wording: `@PYROTECHNICS`'s `Select (1st of 4) target creature or player.` One click is one point, a repeat click on the same target gives it a second, and the cast submits itself when the last point lands. Done is dark throughout; Escape restarts the division without losing the spell |
| ABILITY_MENU | permanent with >1 option | popup lists mana abilities and activated abilities in card text |

Two overlays sit outside the mode machine: the GRAVEYARD VIEW (§1.2, open
over any mode; while TARGETING a card in it is a target) and the OPENING
HAND sequence (§1.5), which runs once between the coin toss and turn 1.

**Hotseat first.** v1 runs both seats as human players — the priority
marker and prompt say whose input is expected. This is deliberate: it
exercises the full UI both ways and is the test bench the AI (M4) will
plug into (the AI simply replaces one seat's input with engine calls —
the UI already only talks to the engine's public API).

Errors: every engine refusal string is shown verbatim in the prompt area.
The engine is the referee; the UI never second-guesses it.

## 5. Quality-of-life — shipped now vs wishlist

Shipped in v1:
- Full game log (the engine's log, scrolling, always visible).
- Legality highlighting: castable cards and legal targets glow.
- Auto-skip: "Pass until something happens" — holding Pass passes priority
  through empty steps (the original's phase-stop settings, simplified).
- Verbatim refusal messages — you always know WHY a click was refused.

Shipped in v1.1 (the 1997-feel pass):
- **The coin toss**: animated flip overlay at duel start with the
  original's own Toss.wav, deciding who plays first (engine start() takes
  the result; the Deck Lab keeps explicit alternation instead).
- **Original sounds throughout**: per-color cast sounds, summon, tap,
  attack, damage, death (Buried), end-of-turn, win/lose — mapped from
  engine events; the original Dueltune.wav loops as duel music. All via
  the skin import (24 sound keys in the importer manifest); silent clean
  fallback without the skin. M toggles mute.
- **F12** saves a screenshot to user:// (path shown in the prompt bar).

Wishlist (ordered; each is a self-contained follow-up):
- **Phase stops config** (the original's duel options panel): choose which
  steps pause for you; per-seat.
- **Auto-tap mana**: click a card with an empty pool → the engine suggests
  a tap set; SHIFT-click casts with auto-tap. (Engine gains a pure
  "suggest_payment" helper — no rules impact.)
- **Undo within your own priority window** (deterministic engine + action
  log makes replay-to-previous-state trivial and safe pre-commitment).
- **Replays & bug reports**: seed + action list = full reproduction; a
  "copy replay" button on the loss screen (mirrors s30's bug reporter).
- **Keyboard/gamepad bindings**: Space=pass, A=attack-all, digits=targets;
  D-pad focus ring for console/TV play.
- **Readability aids**: hover/long-press zoom on any card (oracle text +
  rulings from the card file's own doc header!), colorblind-safe
  highlight palette, UI scale slider.
- **Sound**: original-style cues via the same user-supplied import path as
  graphics; clean synth fallback.
- **The original's duel niceties**: tap animations, damage flashes, the
  "wheel of colors" targeting cursor — all skin-layer work, no engine
  changes.

## 5b. The 2026-09-03 playtest pass — what changed on this screen

Six defects from one duel; `docs/ROADMAP.md` carries the full record and
the citations. What a reader of THIS file needs to know:

**The opponent's turn advances by itself.** `_drive_advance` used to need
a standing order; with none in force it now passes the human's priority
(`_auto_pass_applies` / `_auto_pass_priority`) and stops for exactly the
things 1997 says it must: a required action, something on the chain you
can answer, a Stop, an affordable fast effect. Never in a hotseat duel,
and no new timer — the AI's pacing dwell is already between every pair of
windows. Since 2026-09-03 it is seat-agnostic: an unstopped phase of your
OWN runs itself too, which is what makes the three default Stops the thing
that keeps your turn yours.

*"Something on the chain you can answer"* is 2026-09-04, and it is
`Duel.hlp`'s own word: the clause stops for what *"requires or **permits**
a response"*, and a spell you hold no answer to permits none.
`_could_respond` asks whether an instant in hand or an activated ability
could be paid for out of the **untapped** sources (`MtgGame.could_afford`)
— potential mana, not the floating pool, so a window you could still tap a
land into always waits. Before it, every spell the AI cast cost a Done
click; `docs/ROADMAP.md`, "THE OPPONENT'S TURN".

**The Combat Bar follows the ATTACK, not the phase.**
`CombatBar.shows_attack(step, awaiting_attackers, attacker_count)` is the
screen's span where `covers_step` is the engine's. Declare no attackers and
the Phase Bar comes straight back, with its own combat icon carrying the
phase. `_phase_key` still follows `covers_step`, so a Stop on the Phase
Bar's combat crescent (slot 4) marks a phase nothing consults — the
declaration is what pauses combat instead. `docs/ROADMAP.md`, "THE COMBAT
DOT is drawn but never consulted".

**`Mode.PAYING` — a seventh mode.** A cast the engine refuses ONLY for
mana is held open instead of dropped: the Situation Bar says `Tap %s`
(`@PROMPT_GRABMANA` entry 1), the seat's mana sources light, clicking one
taps it for mana and nothing else (`_tap_for_payment`, and the ability menu
grows a `mana_only` form so a half-paid cast can never be swapped out from
under itself), and the cast re-submits itself the moment the pool covers
it. Done does not apply; Cancel does, and drops the cast leaving whatever
was drawn floating. The mode is entered ONLY while the cost is still
reachable from untapped sources — the screen may never park on a prompt
whose only way forward is Cancel.

**The auto-cast.** A LEFT DOUBLE-CLICK on a card in hand (`_auto_cast`).
It is routed from the widget's own `gui_input` in `_on_card_look` for the
FAN hand, and — since 2026-09-04 — from `_on_hand_card_input` for the
STACK hand, which is the default and whose rows are `CardPile` holder
`Button`s that carry `pressed` and nothing else. Those rows are armed on
the pile's `child_entered_tree`, because the first click of the pair
rebuilds the board and frees the row the second click lands on. The first
click of the pair has already begun the cast — Win32 sends
WM_LBUTTONDOWN/UP before WM_LBUTTONDBLCLK, so the original's did too — and
the second takes over the MANA and only the mana: it fills the X question
to the largest affordable value and confirms it, taps the plan
[ManaPlanner] builds against `MtgGame.spell_payment`, and submits. Targets
and a modal spell's mode stay the player's. `@MENU_SMALLCARD`'s
`Don't auto tap this card` is live and excludes a source from the plan
without stopping the player clicking it by hand.

**Cards can be moved by hand, INSIDE a boundary.** Each board half has a
free layer over its rows; a drag past `DRAG_SLOP` writes `_placements[id]`
(the widget's top-left inside that half) and the card is drawn there
instead of in its row, on top of everything placed before it. A press that
never travels is still a click. `Arrange your cards` clears the placements
of the territory it straightens, which is what the command means.

The card must end WHOLLY inside the visible table of its own half
(`_placement_bounds`: the half, inset exactly as its rows are, and
NOTHING subtracted for chrome), measured against the box the card ever
sweeps (`_placement_span`: the union of upright 132x106 and turned
114x140, so a tap cannot push a parked card out, plus the aura fan's
upward overflow). `_half_of` keeps every drop in its owner's territory.
The clamp runs DURING the drag as well as at the drop, so the edge is
visible rather than a snap-back, and every placement is re-measured when
A HALF CHANGES SIZE and at no other time (`_reclamp_placements`, off the
half's own `resized`). The zone column and the phase/combat bar are
siblings of the board and never over it; the Situation Bar is 36px
against a 106px card and cannot hide one; the fan hand is under the free
layer, so a card over it stays visible; and the floating hand window is
not a bound at all (fifty-fourth pass).

**The Situation Bar is one ruled box.** `OriginalDialog._rule` now draws
the era's measured 2px rule (`RULE_WIDTH`, mitred corners, no black
outline) instead of a hairline; Done and Cancel live INSIDE the box at its
left end and are `OriginalDialog.button()` — `Winbk_Startduelbutton`, the
generic 1997 button art — and the sentence is plain `HIGHLIGHT` with the
era's one-pixel dark shadow and no outline thickening it into white.

**The phase machine is silent.** No sound fires on a phase, step or turn
boundary. Every cue this screen plays belongs to something a player or a
card DID.

## 5c. The Showcase's lettering (2026-09-04 playtest) — and the pass that measured the GROUND

The owner: *"Large card generator: card text, type, illustrator,
power/defense are hardly readable in black — make text bigger, white with
black border, and readable as original."*

**The important finding is not about the ink, it is about what the ink was
standing on.** The seventh pass measured this screen's Showcase off
`Cardbk_White.pic` and wrote the result into `CardPreview`'s class doc:
*"the 1997 frame is a light marble frame"*, so the text on it was set
near-black. That is true of `Cardbk_White` and of nothing else. Mean luma
over the exact rectangles those labels occupy, on the 1997 files
themselves (`Cardart/Cardbk_*.pic`, 1997-01-22 — **Tier 1**):

| frame | type strip | bottom border | rules plate |
|---|---|---|---|
| white | 188 | 184 | 223 |
| blue | 113 | 104 | 208 |
| red | 82 | 73 | 133 |
| artifact | 68 | 64 | 218 |
| green | 49 | 43 | 126 |
| **black** | **22** | **19** | 201 |

Read the columns and the whole fix follows. The **plate** is light on all
six — that is where the rules text lives, it is the ground 1997 used, and
it keeps 1997's dark `47,47,47` ink. The **body** is dark on five of six —
that is where the name, the type line, the illustrator credit and the P/T
live, and nothing legible can be printed there in near-black. So the
Showcase is not one of the fidelity-versus-legibility trades this project
usually has to argue: **the 1997 art rules our old ink out by itself**, and
white with a hard outline is the honest rendering of these frames.
Manalink's replacement renderer letters exactly those strings white over a
dark shadow and the rules text dark, which is the same answer arrived at
from the other side (`config.c:817-822`, Tier 3).

**The geometry survived the audit intact.** Manalink lays the full card
out in an 800x1200 logical space on a 752x1152 frame, and dividing its
rects by that frame gives the same fractions this file has recorded since
the seventh pass — art 0.075-0.926 x 0.063-0.549, type strip y
0.552-0.604, rules box y 0.604-0.920, P/T y 0.920-0.983. Two trees
measured apart landing on the same numbers is the best corroboration this
question gets. The only geometry that MOVED is the type strip, from
0.556-0.601 to the 0.552-0.604 that makes it exactly one line tall — which
is what it is in 1997, where the `Type` rect's height and the subtitle
font's cell are the same 60 units.

**Sizes are ports of ratios, not taste.** Each element's 1997 font cell
divided by the 1152-unit card gives a share of the card's height, applied
to our 428: name 0.0590, type 0.0521, P/T 0.0625, rules 0.0486. The rules
text is instead pinned to the LINE COUNT its box was drawn for — the 1997
`Rulestext` rect is 336 units over a 56-unit cell, exactly six lines, and
ours holds six. The illustrator credit is the one element no source sizes,
so it is `[QoL]` at three quarters of the rules line. Numbers, before and
after: name 13 -> 22, type 11 -> 20, P/T 15 -> 26, rules 12 (shrinking to
10) -> 18, credit 9 -> 13.

**`Expand` is now the help file's sentence.** *"This causes the text area
to grow, WHEN NECESSARY, to display the entire card text."* It used to
move the box for every card; it now measures the text and moves the top up
by exactly the overflow, capped at `TEXT_TOP_EXPANDED` — and the grown box
takes the frame's own rules plate with it (the band `fullcard_expand_text_box`
blits, 60.5-92.7% of the frame image), so the dark rules ink never lands on
bare art. Measured on real Labels across all 897 cards: 685 read at the
full size unexpanded, and with Expand on **not one card in the pool loses
a line**.

## 5d. The card-state catalogue's six defects (2026-09-04)

`docs/card-states.md` catalogued every mark a small card can wear and, in
its §5, named six things wrong. All six are fixed; the catalogue carries
the detail and this is what a reader of THIS document needs to know.

**Three of them were the same shape — a fact the widget could draw that
nothing handed it.**

* **A face-down permanent was drawn face up.** `CardInstance.face_down`
  (Illusionary Mask, Knowledge Vault) never reached `MiniCard.face_down`,
  so a masked creature showed its name, its art, its oracle tooltip and
  its printed mana stripes. `DuelScreen._make_card`, `CardPile._make_card`
  and `GraveyardView._card` carry it now. **It is a card back to EVERY
  seat, the controller's included** — CR 708.2 would let a controller look
  at their own, but `engine/` has no per-seat visibility model to ask
  (`hidden_hands` is the nearest, and it is empty in hotseat and in an
  AI-vs-AI demo), so the table takes the reading that cannot leak. A
  face-down permanent stays CLICKABLE on the battlefield: it attacks, it
  blocks, it is targeted.
* **The yellow castable name existed only in a pile.** `MiniCard.castable`
  was assigned in one place in the whole codebase, `CardPile._make_card`,
  so choosing "Fan of cards" under *Hand display* silently switched off a
  cue — and, since the auto-cast landed, the promise that a double-click
  will work. `_make_card` now takes ONE `_highlight_for` call and uses
  both halves of it: the frame AND the name.
* **The help screen still taught a `+N aura` chip** the forty-first pass
  deleted when the aura peek replaced it.

**One was about what a `StyleBox` can express.** The highlight is a colour
and a WIDTH. `StyleBoxFlat` carries both; `StyleBoxTexture` — which is
what a skinned frame is — has no border width at all, so with the 1997 art
imported `COMMITTED` (green, 2) and `TARGET_CHOSEN` (green, 3) rendered
**byte-identically**. The width is now a ring drawn OVER the frame
(`MiniCard._highlight_ring`), the same device `CardPile.glow_actionable`
already uses, built only when a highlight asks for one and
`MOUSE_FILTER_IGNORE` so it cannot eat the press that taps the land under
it. Rendered proof: before, `committed` and `target_chosen` were the same
file; after, they differ by 1367 bytes, and a card at `Highlight.NONE`
renders byte-identically to what it did before the change.

**One was a comment that had drifted** — `MiniCard._tint_face` claimed a
light-bar/dark-bar contrast rule for the NAME. The code has never done
that and must not: the yellow/white pair is information, not styling, and
a name that went dark on a marble bar would be saying "not castable" in
the one place a player reads castability. The contrast rule is real and
belongs to the STATUS line. The words changed, not the code.

**And one was the art itself.** A ~582x467 Scryfall crop drawn at ~110px
is a 5:1 minification, and with no mipmap chain that lays a diamond
lattice over fur, chainmail and foliage. `GameSkin.card_art` generates
mipmaps now and `MiniCard._art` asks for them
(`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`) — two lines, no re-import, no
texture-format change, +33% (about 0.25 MB) per art actually drawn. The
filter is set on the SMALL CARD only, so the Showcase still draws mip 0
and is unchanged.

## 6. What the duel screen must NEVER do

- Mutate game state directly (it calls MtgGame's public API, full stop).
- Depend on engine internals beyond the documented public surface.
- Import anything from `engine/` into UI-free logic or vice versa — the
  engine stays headless-testable forever.

## 7. File map (game/duel/)

| File | Role |
|---|---|
| duel_screen.tscn | Root scene (thin — layout is built in code for themeability) |
| duel_screen.gd | The controller: mode machine (incl. `Mode.PAYING` — a cast held open for its mana), engine wiring, refresh, the opponent's-turn auto-pass, the auto-cast (on the fan hand's cards AND on the stack hand's rows), and the free layer cards can be dragged into, inside the playfield boundary `_placement_bounds` keeps them |
| card_widget.gd | One card's visual: name/cost/stats, tap & highlight states |
| opening_window.gd | THE START-OF-DUEL WINDOW: one panel on `Winbk_Startduel.pic` carrying `@DIALOG_MULLIGAN`'s twelve entries — who leads, the opponent's mulligan status, BOTH ANTES as full `CardPreview`s, and `Take mulligan` / `Start the duel`. Sized to the cards and to the ground's aspect (977x584) — the forty-third pass |
| graveyard_view.gd | The graveyard, exile and ante laid out and CLICKABLE (`@MENU_GRAVEYARD`'s three views) — the thirtieth pass, `duel-todo.md §1.2`; **[QoL]** a shelf of five full-size MiniCards with ◀ ▶ and the centre card's position, the thirty-third pass |
| coin_toss.gd | THE OPENING TOSS, three ways (`duel-todo.md §6.4`): the original's own movie, our turning coin, or the instant result. **The 1997 coin was a pre-rendered AVI** played through `MCIWndCreateA` (`DUEL.EXE` at `004492ad`, corroborated by `Magic.exe`'s own string table and by `@DIALOG_COINFLIP`'s two captions), which is why there is no coin art to import and why `import_original.py` has to transcode. One stored value (`ShowCoinFlips`) with a 1997 boolean view and a `[QoL]` three-way view; reports the engine's toss, never decides it — the fiftieth pass |
| territory_ground.gd | `Your territory background` (`duel-todo.md §6.4`) — the picture behind each territory, one node per half and never null. Three styles, three ways of drawing them: `patt` nine-patches (its border is art), `mana` tiles, `pict` covers. Paints all fifteen grounds itself when the 1997 skin is absent — the forty-eighth pass |
| exile_plate.gd | The empty-exile plate for the pile right of the graveyard — DERIVED art (the 1997 game drew none: `@MENU_GRAVEYARD` reached exile from the graveyard itself), painted at `Grave_*`'s size and geometry out of that seat's grave-plate palette — the thirty-sixth pass |
| opening_hand.gd | Play-or-draw and the Shandalar mulligan, between the coin toss and turn 1 (`@DIALOG_PLAYORDRAW`, `@DIALOG_MULLIGAN`) — `§1.5` |
| card_menu.gd | THE REST OF THE `@MENU_*` FAMILY (`duel-todo.md §6.12`): `@MENU_SMALLCARD`, `@MENU_LIBRARY`, `@MENU_HAND`, `@MENU_MANAPOOL`, `@MENU_FULLCARD`, and the four WINDOW menus the item's own table omitted. Every table verbatim and complete, greyed where we cannot offer it — the forty-seventh pass |
| fireball_dialog.gd | `@DIALOG_FIREBALL` — the X dialog, and for Fireball the target count and the arithmetic between them. NOT the divided-damage dial (`@PYROTECHNICS` is, and it is a click loop) — the forty-seventh pass |
| death_mark.gd | THE DYING MARK: `@CUECARD_SMALLCARD`'s `Dying` — a ghost MiniCard wearing `Dying.pic`'s silver cracks, held for a beat over the square a DESTROYED permanent has just left. 1997's predicate is `kill_code == KILL_DESTROY` (`windows.c:724`), the same one regeneration targets; raised off `Mtg.EventType.DIES` so a REGENERATED creature can never wear it. HOLD+FADE are `[QoL]` — the fifty-second pass |
| spell_flight.gd | THE SPELL-CAST ANIMATION: a ghost MiniCard from the hand slot to the Spell Chain window and on to where it lands. s30's `duel_spell_animation.go` with the 1997 destination — the forty-seventh pass, `duel-todo.md §2.4` |
| card_pile.gd | The original's strip-stack window: overlapping MiniCards clipped to their title bars, the top one whole. `glow_actionable` (2026-09-03) lets a BATTLEFIELD pile wear the "you may act on this" ring an unpiled permanent already wears — which is what shows the mana sources while a cast waits for them |
| decks.gd | v1 starter decks (implemented-pool-only); replaced by real deck data in M3 |
| gauntlet_state.gd | THE GAUNTLET RUN, pure and headless: the shuffled opponent order and its twenty cap, the random start offset and the original's `(start + round) % n` wrap, the round counter, the SESSION record, and the ten `@GAUNTLET` + four `@DIALOG_GAUNTLETENDDUEL` strings — the forty-ninth pass, `docs/gauntlet-design.md`; plus the three `@DIALOG_STARTEXP1MATCH_GAUNTLET` announcements and the four `@GAUNTLETERRORS` opponent-deck refusals (three reachable, one recorded and unreachable) — the fifty-first pass |
| gauntlet_options.gd | `@DIALOG_GAUNTLETOPTIONS` — Match Size, Ante, the four Enemy Levels, plus the shell page's `&Num opponents:` and `Side&board between duels` and a `[QoL]` `Gauntlet difficulty: %3d (%s)` readout — the forty-ninth pass |
| gauntlet_screen.gd/.tscn | THE OUTER LOOP: one `MatchScreen` per round, the round window between matches, one seed per run split per match — the forty-ninth pass; the next-opponent window before each match and `&Create Deck...`'s way out — the fifty-first pass |

`game/main.gd` boots a minimal menu (Hotseat Duel / Quit) and passes decks
into the scene. The duel scene also runs standalone (F6 in the editor) with
default decks — a deliberate dev-loop convenience.

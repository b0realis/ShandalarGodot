class_name DuelScreen
extends Control
## The duel screen — M2's deliverable. Layout, interaction model, platform
## and faithfulness decisions are all documented in
## docs/duel-screen-design.md; this file implements them.
##
## Contract with the engine (the most important rule here): this screen
## talks to MtgGame EXCLUSIVELY through its public API and signals, and
## shows every refusal string verbatim in the prompt bar. It never reaches
## into engine internals — which is exactly what lets the future AI (M4)
## replace one seat without any UI rework.
##
## v1 is HOTSEAT: both seats are human; the sidebar says whose input is
## expected, and both hands render face-up (a deliberate hotseat/dev choice
## — the vs-AI build hides the opponent's).

## DISCARD is the original's own named phase (`@PROMPT_DISCARD`, "Paused:
## Discard phase") and DAMAGE its `%s: Assign damage to blockers, %d points
## left` loop — both are moments the engine now HOLDS open for the player
## instead of answering for them (docs/duel-todo.md §1.1, §1.4).
##
## PAYING is the 1997 casting flow's missing half, added 2026-09-03 on the
## owner's playtest: *"If you click on a spell you should be able to tap
## lands also AFTER, to cast it — not just before, to the mana pool where a
## spell picks mana up."* `Duel.hlp`, topic **Hands**, states the order
## outright — *"Click on any highlighted card in your hand to begin casting
## that spell… ONCE YOU'VE SELECTED A SPELL TO CAST, you must draw enough
## mana — from your mana pool, land in play, or other mana-producing cards
## — to power the spell"* — and topic **Spells** repeats it: *"Click on it
## to cast it. You're prompted to provide mana to pay the casting cost. At
## this point, you can draw from your mana pool, directly from land, or
## from any other source you have."* So the cast is HELD OPEN while the
## player taps, exactly as the declarations and the discard are, instead of
## being refused for mana it was never given a chance to find.
## The Situation Bar wears the original's own word for that moment
## ([constant GRAB_MANA_PROMPT]).
enum Mode { NORMAL, TARGETING, ATTACKERS, BLOCKERS, DISCARD, DAMAGE, PAYING }

## `@PROMPT_GRABMANA` entry 1, `shandalar-src/Program/UIStrings.txt:1090` —
## `Tap %s`, the original's whole prompt for the moment mana is being drawn
## for a named spell or ability. (`@PROMPT_SPECIALFEPHASE` entries 7-8,
## `:1046`, name the same two moments for the fast-effects line: `Casting`
## and `Tapping`.)
const GRAB_MANA_PROMPT := "Tap %s"

## Everything the battle-setup screen decided: seats, decks, lives, pace.
## Null when the scene runs standalone (F6/dev) — a hotseat default fills
## in. AI seats' hands hide per config.hidden_seats(); AI moves run on the
## config's pacing timer (s30's pacing-delay idea — instant AI turns read
## as nothing-happened; the AI-vs-AI demo slows it further).
var config: DuelConfig = null

var game: MtgGame
var mode: int = Mode.NORMAL
var hidden_hands: Array[int] = []

## THE STOPS the player has marked on the two bars — *"a lasting
## instruction"* (manual p.117), loaded from and saved to `Settings`, so it
## survives the duel exactly as the original's `PhaseStoppers` did. Shared
## with [PhaseBar] and [CombatBar], which only read it.
var stops: PhaseStops = PhaseStops.load_saved()
var _ais: Dictionary = {}   # pid -> AiPlayer
var _ai_pending := false
var _target_cursor: ImageTexture = null

# --- 1997 presentation: coin toss, sounds, music ---
var _toss_active := false
## The pre-duel splash while it is up ([method _run_intro]).
var _intro_overlay: Control
## The Q/Esc **Pause** window while it is up ([DuelPause]).
var _pause_menu: DuelPause = null
var _toss_overlay: Control = null
## The duel's whole sound layer — the cue map, the voice pool and the one
## tune (see [DuelAudio]). Volume and mute live on the [GameAudio] buses,
## not on this node, so the Options sliders reach a duel already in
## progress.
var _audio: DuelAudio = null
# THE PHASE MACHINE IS SILENT. The owner, 2026-09-03: *"The changing
# phases or combat phases have no sound by themselves. Card action and
# other actions that happen in phases have sound effects."* This file used
# to play `sfx_end_turn` off `game.turn_number` moving, from inside
# [method _refresh] — the coarsest phase boundary there is, and the only
# sound here that was not an action. It is gone, and no phase or step
# boundary may grow one: every cue this screen still plays belongs to
# something a player or a card DID (the shuffle that opens the duel, the
# coin toss, a discard, a button, the duel's verdict), and the rest of the
# cue table lives in [DuelAudio], driven by engine EVENTS.

# --- TARGETING state: the pending action collecting its targets ---
var _pending_card: CardInstance = null       # spell being cast (or ability source)
var _pending_ability_index := -1             # -1 = casting; >=0 = activating
var _pending_specs: Array[TargetSpec] = []
## One entry per targeting effect: {spec, min, max, divided}. max -1 means
## "any number"; divided > 0 means the amount is split across the group.
var _pending_slots: Array = []
var _pending_groups: Array = []      # parallel: the refs chosen per slot
var _pending_slot := 0
## Slots [method _advance_pending] filled BY ITSELF — the lone counter
## target (§3.3), the single damage marker — rather than by a click. Escape
## takes back the player's picks only (see [method _clear_picked_targets]).
var _auto_slots := PackedInt32Array()
var _pending_targets: Array = []
var _pending_x := 0
var _pending_pid := 0
var _pending_mode := 0                       # modal spells: chosen mode index

## HumanAgent per human seat — the pre-selection mailbox for mid-resolution
## choices (library searches). pid -> HumanAgent.
var _humans: Dictionary = {}

# --- combat declaration state ---
var _selected_attackers: Array[int] = []
## blocker id -> the attacker ids it is set to block. AN ARRAY PER
## BLOCKER since one-to-many blocks landed (CR 509.1b): almost every entry
## is one long, and [method MtgGame.declare_blockers] takes both shapes,
## but the screen has to be able to build the second block for a
## Two-Headed Giant of Foriys or a creature under Blaze of Glory.
var _block_map: Dictionary = {}
var _selected_blocker := -1

# --- the discard phase (§1.1) and the damage division (§1.4) ---
## Cards picked for the cleanup discard, by instance id.
var _discard_picks: Array[int] = []
## The damage division being dialled in: instance id (or
## MtgGame.DAMAGE_TO_PLAYER) -> points assigned so far.
var _damage_picks: Dictionary = {}

# --- UI nodes (built in _build_ui) ---
var _prompt_label: Label
var _life_buttons: Array[Button] = []
var _poison_labels: Array[Label] = []   # venom-green clock on the life panel
var _pass_button: Button
## The Situation Bar's OTHER button. `@BUTTONLABELS` (UIStrings.txt:178) is
## `Cancel` / `Done` and the bar carries *"a Done button, a Cancel button,
## or both, depending on the situation"* — so this one comes and goes with
## [method _can_cancel] (§6.11).
var _cancel_button: Button = null
var _hand_rows: Array[Control] = []   # [p1 hand (top), p0 hand (bottom fan)]
var _field_rows: Dictionary = {}             # [pid][row] -> HFlowContainer
# Every centre popup is an OriginalDialog (game/duel/original_dialog.gd)
# built when it is needed and freed when it is answered — the 1997
# dialogs are drawn INSIDE the dueling table, never in an OS window, so
# none of these is a Godot Window subclass any more.
var _x_dialog: OriginalDialog
var _x_spin: SpinBox
var _ability_menu: PopupMenu
var _phase_menu: PopupMenu = null       # the @MENU_PHASEBAR mini-menu
var _territory_menu: PopupMenu = null   # the @MENU_TERRITORY mini-menu (§6.3)
## The other `@MENU_*` mini-menus (§6.12, see [CardMenu]). One PopupMenu
## each rather than one shared: they carry different tables and different
## handlers, and a shared menu would have to be re-dressed on every open.
var _card_menu: PopupMenu = null        # @MENU_SMALLCARD
var _library_menu: PopupMenu = null     # @MENU_LIBRARY
var _hand_menu: PopupMenu = null        # @MENU_HAND
var _mana_menu: PopupMenu = null        # @MENU_MANAPOOL
var _full_card_menu: PopupMenu = null   # @MENU_FULLCARD
var _attack_menu: PopupMenu = null      # @MENU_ATTACK / @MENU_MINIMIZEDATTACK
## Which card the open `@MENU_SMALLCARD` belongs to.
var _card_menu_inst: CardInstance = null
## `Concede` → `Yes, I'm sure` (§6.3).
var _concede_dialog: OriginalDialog = null
## THE LIFE REGISTER'S OWN mini-menu — `@MENU_LIFE` / `@MENU_FACE`, the
## pair whose only difference is `Flip over to face` / `Flip back to
## lifepoints` (§6.5, and [DuelistFace] for the whole specification).
var _life_menu: PopupMenu = null
## Which registers the player has TURNED OVER by hand. The automatic flip
## (a spell that can target a player) is not stored: it is asked of the
## pending cast every refresh, so it flips back on its own the moment the
## targeting ends — `Duel.hlp`, topic "Duelist's Face".
var _face_flipped: Array[bool] = [false, false]
var _search_dialog: OriginalDialog            # library picker (tutors)
var _search_list: ItemList
var _over_dialog: OriginalDialog = null       # the duel's last word
## True from the moment the duel ends until the End of Duel window has
## been dismissed — the window itself only exists after the death
## countdown, and [method result_dialog_open] must not say "nothing to
## wait for" in between (2026-09-02).
var _result_pending := false
var _options_dialog: OriginalDialog = null    # `Duel Options...` (§6.4)
var _card_preview: CardPreview = null        # shared enlarged-card popup
var _phase_bar: PhaseBar = null
## The COMBAT BAR, which REPLACES the Phase Bar for the length of an attack
## (manual p.117, Duel.hlp topic "Combat Bar" — see combat_bar.gd). It
## shares the Phase Bar's column: both live in _bar_holder and only one of
## them is ever visible.
var _bar_holder: Control = null
var _combat_bar: CombatBar = null
## The WINDOW ICON in the Phase Bar's centre band — `Winbk_Attackmin`, the
## dagger that restores a minimised Combat window (manual p.126). That blank
## band in the middle of the strip is what it has always been for.
var _window_icon: TextureButton = null
## The COMBAT WINDOW (combat_window.gd) and its minimised state.
var _combat_window: CombatWindow = null
var _combat_minimized := false
# ------------------------------------------------ THE ZONE COLUMN'S INK --
#
# EVERY PILE CARRIES ITS OWN COUNT, in its own bottom-right corner, in the
# life numeral's yellow over a hard black outline. The owner's ask
# (2026-09-03), from a photograph of the column: *"What is this small
# number right of the exile stack? Move this number to the bottom right of
# the relevant stack and colour it some contrasting colour so it can be
# read."*
#
# THE NUMBER IN THE PHOTOGRAPH WAS THE GRAVEYARD'S. `_grave_labels` was
# built as a bare Label appended to the piles row AFTER the exile plate —
# a leftover from when one label read "Deck N / Grave N" for both piles —
# so it floated in the black gap in the default theme's WHITE, while the
# library's and the exile's counts sat on their own art in yellow. That is
# exactly why it read as a stray digit belonging to nothing. It now rides
# the grave plate like the other two, and the gap it vacated is where the
# seat's portrait goes ([method _seat_portrait_block]).
#
# THE COLOUR IS THE ONE ALREADY HERE, and deliberately not a new one: the
# life numeral, the library count and the exile count are all
# Color(0.95, 0.85, 0.20). What the counts lacked was not hue but a FLOOR
# — the library's count had no outline at all and sat on a busy card back.
# A 4px black outline (which the exile count already carried, and which
# [MiniCard] uses to letter a card's name over its art) is what makes one
# yellow work on every ground the column can show: a card scan, a card
# back, the five painted plates, and the black sidebar behind them.
const PILE_COUNT_INK := Color(0.95, 0.85, 0.20)
const PILE_COUNT_OUTLINE := Color(0, 0, 0)
const PILE_COUNT_FONT_SIZE := 13
const PILE_COUNT_OUTLINE_SIZE := 4
# ----------------------------------------------- THE ROW'S ARITHMETIC --
#
# FOUR COLUMNS AND THREE EVEN GAPS, inside a width that is not negotiable.
# The sidebar is CardPreview.SIZE.x = 300 so the examined card fills it
# 1:1; the mana panel takes 128*0.85 = 109 of that and the panel row's own
# separation 6, which leaves this block exactly 185. The owner's ask
# (2026-09-03) is that the four columns read as one row — near-equal, with
# near-equal gaps — EXCEPT the deck, which is bigger on purpose:
#
#     50  +5+  40  +5+  40  +5+  40   =  185
#     deck     grave    exile    face
#
# The three plates and the portrait are the 1997 grave plate's own 40px;
# the deck is 50 because a STACK needs room for its edges (see
# [constant LIBRARY_STEPS]), and its heights match to within a pixel:
# 61 for the stack, 60 for the two plates.
const PILES_SEPARATION := 5

# ----------------------------------------------- THE LIBRARY'S THICKNESS --
#
# `Duel.hlp`, topic **Library**: *"The number of cards left in your library
# is represented — INEXACTLY, as in real life. If you must know, you can
# right-click on a library to find out the exact number of cards left in
# it."* The pile's THICKNESS was the original's readout, and the exact
# number lived behind `@MENU_LIBRARY`'s `Count library cards`. So the
# stack is drawn as a stack whose depth tracks what is left, and the
# yellow count on its top card is the exact answer the original kept in a
# menu — the owner's *"the stack of deck is bigger and should show
# stack"*, which is the faithful reading as well as the asked-for one.
#
# STEPPED, NOT PER-CARD: one card back per threshold crossed, so a
# 60-card library opens at the full six sheets, a 40-card one at five, and
# an EMPTY library draws nothing at all — which is the state
# `Duel.hlp` warns about (*"that player cannot draw and will likely lose
# during his or her next draw phase"*). Six steps, because six is what
# fits: the stack's box is one card back plus five 2px edges.
const LIBRARY_STEPS: Array[int] = [1, 4, 10, 20, 32, 45]
## One card back, and how far the next edge behind it peeks out.
const DECK_SHEET := Vector2(40, 56)
const DECK_STEP := Vector2(2, 1)
## The stack's box — DECK_SHEET + DECK_STEP * (LIBRARY_STEPS.size() - 1),
## written out because a const cannot be derived from another one's size.
## `test_zone_column.gd` pins the two to each other.
const DECK_STACK := Vector2(50, 61)
## The seat portrait's box, right of the exile plate — the piles' own 40px
## width, so the four columns read as one row, and the height a 137x169
## portrait draws into it.
const SEAT_PORTRAIT := Vector2(40, 50)
const SEAT_NAME_FONT_SIZE := 10
const SEAT_NAME_HEIGHT := 13
#
# 1997 PRINTED NO COUNTS AT ALL, and that is a divergence this screen
# already carried before today. `Duel.hlp`, topic **Library**: *"The number
# of cards left in your library is represented — inexactly, as in real
# life. If you must know, you can right-click on a library to find out the
# exact number of cards left in it."* The pile's THICKNESS was the readout
# and `@MENU_LIBRARY`'s `Count library cards` was the exact answer (which
# `_on_pile_input` still gives). So the owner's QoL ask refines a [QoL]
# deviation rather than opening one; docs/ROADMAP.md carries the row.

var _grave_labels: Array[Label] = []   # per-seat graveyard count, ON the plate
var _mana_labels: Array = []           # pid -> {ManaColor: count Label}
var _lib_labels: Array[Label] = []     # per-seat library count on the deck stack
## The library's own box, and how many card backs are drawn in it right
## now (-1 = never dressed). See [method _dress_deck_stack].
var _deck_stacks: Array[Control] = []
var _deck_sheets: Array[int] = []
var _grave_icons: Array[TextureRect] = []   # per-seat graveyard face
## The EXILE pile, right of the graveyard: the same plate treatment for
## "out of play" (manual p.118). The 1997 table had no such pile — the
## zone was reached through `@MENU_GRAVEYARD`'s second entry — so both the
## pile and its empty plate (ExilePlate) are a deliberate divergence.
var _exile_icons: Array[TextureRect] = []   # per-seat exile face
var _exile_labels: Array[Label] = []        # per-seat exile count
## THE SEAT'S OWN FACE, in the black gap right of the exile plate, with
## its name bound to the portrait's width — the owner's ask of
## 2026-09-03. See [method _seat_portrait_block] for the whole record.
var _seat_portraits: Array[TextureRect] = []
var _seat_name_labels: Array[Label] = []
## The pile the open graveyard view was opened from, -1 while it is shut
## (docs/duel-todo.md §1.2). Clicking the same pile again closes it, which
## is s30's handleGraveyardClick and needs this to know which "same".
var _grave_view: GraveyardView = null
var _grave_open_pile := -1
## The 2px yellow ring s30 puts round a pile holding a legal target while
## the duel is targeting (`duel.go:3699-3712`) — otherwise nothing on
## screen says the answer is inside a graveyard.
var _grave_rings: Array[Panel] = []
## HOW FAR EACH ATTACHED CARD PEEKS OUT FROM BEHIND ITS HOST — right and
## up, one step per aura. See [method _make_widget]; the derivation is in
## `docs/duel-screen-design.md`, forty-first pass.
##
## The Y is s30's own step carried onto our card: `duel.go:3223` draws an
## aura at `pos.Y - (j+1)*14` on an 83px-tall field card, and 14 × 106/83
## = 17.9. It lands on 18 a second way, which is why it is right: a
## [MiniCard]'s title bar runs from y=2 to y=18 ([method
## MiniCard._build_face]), so an 18px reveal shows the attachment's WHOLE
## name band and nothing of the art below it.
##
## The X is the 1997 screenshot's, which s30 has no equivalent for — s30
## stacks its auras dead vertically, and the original does not: it slides
## each one right as well, so the card behind is seen "on the right and
## top". Measured off the owner's Urza's Avenger reference, the yellow
## "Ability Effect" card is revealed 43px to the right of a 948px-wide
## host, i.e. 4.5% of the card's width = 5.9px on ours.
const AURA_PEEK := Vector2(6, 18)
var _chain_box: VBoxContainer = null   # the original's floating spell chain
var _mode_overlay: Control = null      # modal-choice dialog (Winbk_Bigcard)
var _preview_dock: Control = null      # sidebar slot for the big card
var _qol_reserve: Control = null       # black strip under it, for future QoL
## ARRANGE CARDS (§2.3): the reserve's first tenant and the flags it sets.
## Off, that seat's zones render in the engine's own play order; on,
## through [BoardOrder]. See [method _display_order] for why that is the
## whole of the toggle's restore semantics.
##
## PER SEAT, because the 1997 command is: it *"straightens up the cards in
## play in the territory where you right-clicked"*, and `@MENU_TERRITORY`
## ships `Arrange your cards` and `Arrange opponent's cards` as two
## separate entries (§6.3). The sidebar toggle is the owner's own control
## and works the whole table at once — it is the door that says "sort the
## table"; the menu entries are the doors that say "sort this one".
var _arrange_button: ArrangeButton = null
var _arranged: Array[bool] = [false, false]
## `Don't auto tap this card` — `@MENU_SMALLCARD` entry 4
## (`shandalar-src/Program/UIStrings.txt:941`), live since the auto-cast
## landed (2026-09-03). `Duel.hlp`, topic **Territory**: *"**Don't Auto
## Tap** marks a land to be ignored — not tapped for mana — when you
## auto-cast any spell or effect. The only way to tap a locked land is
## manually, by clicking on it."* A SET of instance ids, `{id: true}`,
## handed to [ManaPlanner] and to [method MtgGame.could_afford]; per duel,
## like the placements, because the mark is about a card on this table.
##
## The decompilation confirms it is one of the auto-tapper's own flags:
## `AUTOTAP_NO_DONT_AUTO_TAP` in the call at `Magic.exe:0x42e26b`
## (`shandalar-src/src/patches/patch_autotap_artifacts_and_creatures.pl`),
## whose second half exists purely to widen the mark from lands to every
## mana source — so ours applies to every mana source too.
var _no_auto_tap: Dictionary = {}

# ------------------------------------- MOVING A CARD BY HAND (§2.3b) --
#
# THE OWNER'S PLAYTEST, 2026-09-03: *"Summoned mini cards on the table
# should be freely movable on the table as per player choice — selected one
# over the others."*
#
# IT IS THE TABLE THE 1997 GAME HAD. `Duel.hlp`, topic **Territory**, only
# makes sense of a board whose cards are where the player put them:
# *"**Arrange Cards** STRAIGHTENS UP the cards in play in the territory
# where you right-clicked. This has no effect on the duel, it just makes
# things neater."* Nothing needs straightening unless it can be crooked.
# The same topic's *"This has no effect on the duel"* is the licence for
# this whole feature to be a pure view: not one engine call happens here.
#
# WHAT A PLACEMENT IS: the widget's top-left inside its own board HALF, so
# it survives a window resize as an absolute pixel offset would not, and it
# is stored per INSTANCE id rather than per slot, so nothing drifts when a
# neighbour dies. Per DUEL — cleared in [method _new_game] — because a
# placement is about this table.
#
# DRAW ORDER IS INSERTION ORDER: [method _place_card] re-inserts the id it
# moves, and [method _rebuild_placed] adds the widgets in the dictionary's
# order, so the card you last touched is added last and therefore drawn
# over its neighbours. That is the owner's *"selected one over the others"*,
# and while the drag is actually in progress the card also rides
# [constant DRAG_Z].
#
# A DRAG IS NOT A CLICK. `Duel.hlp` gives the left button on a card its own
# job — *"you can simply click on the card to activate that primary
# function"* — so a gesture that MOVED must not also tap the land it moved.
# [method _on_card_look] swallows the release once the pointer has passed
# [constant DRAG_SLOP], which is the same press-that-never-became-a-drag
# rule the hand window's title bar already uses (StackHand, §3.6).
## Instance id -> top-left inside that seat's board half. Insertion-ordered.
var _placements: Dictionary = {}
## The absolute layer each half draws its placed cards in, over the rows.
var _free_layers: Array = [null, null]
## How far the pointer must travel before a press becomes a drag.
const DRAG_SLOP := 5.0
## z_index of the card being dragged: over its neighbours and over a
## right-held card ([constant LIFT_Z]), under the floating windows.
const DRAG_Z := 70
## The widget being dragged (its outermost laid-out node), and the state
## the gesture needs. Null when nothing is being dragged.
var _drag_root: Control = null
var _drag_inst: CardInstance = null
var _drag_from := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _dragging := false
## Blocker/stack/targeting ARROWS over the board (see target_arrows.gd).
var _arrows: TargetArrows = null
## THE DAMAGE MARKERS (§6.20b, §6.8) — the yellow "cards" the 1997 game
## put beside whatever damage was about to hit, and the only way to say
## WHICH packet a Circle of Protection is answering when several wait.
## Populated only while a damage-prevention window holds packets.
var _damage_markers: DamageMarkerLayer = null
## THE SPELL-CAST ANIMATION (§2.4) — the card flying from the hand to the
## Spell Chain and on to wherever it lands (see spell_flight.gd, which
## also carries the evidence that this is [s30] and not [1997]).
var _flight: SpellFlight = null
## The row VBox of each board half, pid-indexed. Each half keeps its FULL
## width: the floating hand window is chrome the player parks where they
## like and the board never rearranges itself around it (§2.3b, §3.6).
var _half_rows: Array = [null, null]
## Board inset: cards never sit flush against a half's edges.
const BOARD_INSET := 8.0
## The same inset TOP AND BOTTOM. It was two `6` literals in the layout
## before the placement boundary needed to name it (§2.3b).
const BOARD_INSET_V := 6.0
## The 1997 line for picking a DAMAGE MARKER, verbatim —
## `@CIRCLE_OF_PROTECTION`, `shandalar-src/Program/prompts.txt:185`. The
## original calls the marker a *card*, which is the third source (with
## manual p.119's *"a yellow 'card'"* and `Duel.hlp`'s *"a card, a damage
## marker, or whatever"*) saying the same thing about what it is.
const DAMAGE_TARGET_PROMPT := "Select damage card."


## Done click: in declare modes it CONFIRMS the declaration (the original
## has no separate Confirm button); otherwise it passes priority.
func _on_done() -> void:
	if _toss_active:
		return   # the table is not in play yet (see _run_coin_toss)
	if mode == Mode.TARGETING:
		_finish_target_slot()   # "that's all the targets I want"
	elif mode == Mode.ATTACKERS or mode == Mode.BLOCKERS:
		_on_confirm()
	elif mode == Mode.DISCARD:
		_confirm_discard()
	elif mode == Mode.DAMAGE:
		_confirm_damage()
	else:
		_on_pass()

## THE DUEL'S RESULT, REPORTED BACK. A seat id, or -1 for a draw —
## exactly what [signal MtgGame.game_ended] carries. Emitted once, when
## the duel ends, so that whatever OWNS this screen can keep a record
## across duels; [MatchScreen] is the one thing that does. Nothing else in
## this file knows a match exists, which is the point: a duel is a duel.
signal duel_finished(winner_id: int)

## Battlefield display rows, in the order the OWNER'S REFERENCE SCREENSHOT
## was measured to have them (the thirteenth pass of
## `docs/duel-screen-design.md`): lands, then the other permanents, then
## creatures — **top-down in BOTH halves, which means the board is not
## mirrored**. The opponent's creatures therefore end up at the battle
## line and the player's at the screen's bottom edge.
##
## This comment used to read *"creatures nearest the battle line, lands
## furthest"*, which is true of the opponent's half and false of the
## player's, and was the only thing in the tree claiming the board was
## mirrored (s30 does mirror it — `duel.go:1372-1436`). `docs/duel-todo.md`
## §4.2 records the evidence search that settled it: `Duel.hlp`'s
## **Territory** topic fixes which half is whose and says nothing about
## rows, the Manalink source has no territory layout in it at all, and the
## screenshot measurement is the only figure anyone has. Do not re-mirror
## this on s30's authority; it would be replacing evidence with a
## reference.
enum Row { LANDS, OTHER, CREATURES }


func _ready() -> void:
	if config == null:
		config = DuelConfig.hotseat_default()
	_build_ui()
	_new_game()


# ================================================================ game glue --

func _new_game() -> void:
	GameAudio.apply_settings()
	# THE DECK IS SHUFFLED, AND THE ORIGINAL SAYS SO. `shuffle_for_exe`
	# (`shandalar-src/src/functions/functions.c:9121-9127`) plays
	# WAV_SHUFFLE and then runs the exe's own shuffle animation, every
	# time a library is shuffled — and the first one is the duel's own
	# opening. `Shuffle.wav` had been imported and never played.
	_play_sfx("sfx_shuffle")
	game = MtgGame.new()
	game.log_appended.connect(_on_log_line)
	game.state_changed.connect(_refresh)
	game.game_ended.connect(_on_game_over)
	game.event_occurred.connect(_on_game_event)
	# Every duel runs on a KNOWN seed, logged on the first line, so a
	# player's bug report can be replayed exactly (DuelConfig.rng_seed).
	# Without one the shuffles were unreproducible (2026-09 audit).
	var duel_seed := config.rng_seed
	if duel_seed == 0:
		duel_seed = randi() | 1     # never 0: that means "roll one"
	game.setup(config.decks[0], config.decks[1],
		config.player_names[0], config.player_names[1],
		config.lives[0], config.lives[1], duel_seed)
	game.log_line("Duel seed: %d" % duel_seed)
	# THE ANTE (§6.19) — the original's `&Ante` match parameter. Staked
	# HERE, between the shuffle and the deal, because that is the manual's
	# own order: p.60 *"Before the duel begins, both players put up one or
	# more cards from their decks as ante"*, and p.118 pins it precisely by
	# describing the minimum-deck padding as lands added *"(after the ante
	# but before the shuffle)"*.
	#
	# The player's stake spares BASIC lands and the opponent's does not —
	# Shandalar's own asymmetry (FAQ 1.9, *"Basic lands are too weak a card
	# to ante"*), and exactly what the owner's 1997 screenshot shows: your
	# Animate Dead against Cromer's Mountain.
	if config.ante > 0:
		for pid in 2:
			game.stake_ante(pid, config.ante, not config.is_ai(pid))
	# The RULES FORKS, per Options (see RulesOptions / Settings.rule).
	# Logged when any of them leaves the modern default, so a bug report
	# says which ruleset the duel was actually played under.
	for fork in RulesOptions.FORKS:
		game.rules.set_fork(fork["key"], Settings.rule(fork["key"]))
	var edition: String = game.rules.edition()
	if edition != "modern":
		game.log_line("Rules: %s" % edition)
	# A placement and a `Don't auto tap` mark are both about THIS table
	# (§2.3b, `@MENU_SMALLCARD`): a new duel starts with neither.
	_placements.clear()
	_no_auto_tap.clear()
	_humans.clear()
	for pid in 2:
		if config.is_ai(pid):
			var ai := AiPlayer.new(pid, config.pilots[pid])
			_ais[pid] = ai
			game.set_agent(pid, ai)
		else:
			# Human seats get the pre-selection agent so tutors ask the
			# player, not a heuristic (see HumanAgent's header).
			var human := HumanAgent.new()
			_humans[pid] = human
			game.set_agent(pid, human)
	# THE PRE-FLIGHT (§1.3): with a human at the table the engine stops a
	# resolution to ASK rather than answering on their behalf. Off without
	# one — an AI-only duel has nobody to ask and nothing to wait for.
	game.interactive_choices = not _humans.is_empty()
	hidden_hands = config.hidden_seats()
	_reset_pacing()
	# The coin toss (the original's Toss.wav moment): who plays first.
	# Rolled on game.rng, not the global RNG, so a seeded game replays
	# its opening exactly — the leader is part of the game's stream.
	var winner := game.rng.randi() % 2
	# THE OPENING HAND (docs/duel-todo.md §1.5, §6.2). Both hands are dealt
	# FIRST, then the toss winner says play or draw, then the mulligans are
	# offered — `Duel.hlp`'s own order, and why the deal is now split from
	# starting turn 1.
	game.deal_opening_hands(7)
	_set_prompt("")
	_play_music()
	if DisplayServer.get_name() == "headless":
		# Tests/CI: no animation and no dialogs — the duel just begins,
		# exactly as it did before the opening sequence existed.
		game.start_duel(winner)
	else:
		# HOW the toss is presented is [CoinToss]'s question, and the
		# player's — three modes behind one `ShowCoinFlips` value (§6.4).
		# WHO won is settled above and never reconsidered.
		_run_coin_toss(winner)
	_refresh()


## Strict on purpose: a seat that does not exist (`-1`, the engine's "no
## winner" / "no assigner") is NOT human, or a drawn duel would greet the
## player with the win sting and an unanswered damage request would open
## the assignment mode for nobody (2026-09-02).
func _is_human(pid: int) -> bool:
	return pid >= 0 and not _ais.has(pid)


func _on_log_line(_line: String) -> void:
	pass   # the log accumulates in game.log_lines; no on-screen pane
	       # (complete-reimplementation rule: the original had none —
	       # a QoL log viewer returns later)


## THE DUEL'S LAST WORD. `@DIALOG_SHANDALARENDDUEL` (UIStrings.txt:514)
## is three lines and no more — "%s won", "You won!", "The duel is a
## draw" — and the original announces them in the End of Duel window,
## whose ground (Winbk_Endduel, blue and gold rings) is the only one in
## the set with a SUNKEN bevel: the duel's verdict is carved in, not
## raised. The Situation Bar carries the same words behind it.
func _on_game_over(winner_id: int) -> void:
	# `@DIALOG_SHANDALARENDDUEL` has THREE lines, and the third one is the
	# draw — which this used to fall through to `game.players[-1]` and
	# announce as a win for seat 2 (found 2026-09-01 while building the
	# match record, which counts draws and so had to be told about them).
	var verdict := "The duel is a draw"
	if winner_id >= 0:
		verdict = "You won!" if _is_human(winner_id) \
			else "%s won" % game.players[winner_id].player_name
	# THE OWNER HEARS OF IT NOW, but the duel keeps its last word: the
	# window below is built only after the countdown, and [MatchScreen]
	# reads [method result_dialog_open] the moment this signal lands.
	# Emitting with nothing yet pending let the match's window open over
	# a verdict that had not appeared, and its OK free this screen while
	# `_on_game_over` still sat on the countdown timer (2026-09-02).
	_result_pending = true
	duel_finished.emit(winner_id)
	_set_prompt(verdict)
	_pass_button.disabled = true
	if _audio != null:
		_audio.stop_music()
	# The original has exactly two stings here — Shell_WinDuel.wav and
	# Shell_LoseDuel.wav (`windows.c:1229-1230`) — and no third for the
	# draw, so a draw ends in silence rather than in either.
	if winner_id >= 0:
		_play_sfx("sfx_win" if _is_human(winner_id) else "sfx_lose")
	if DisplayServer.get_name() == "headless":
		_result_pending = false
		return          # tests/CI: the prompt line is the whole result
	# THE DYING TOTAL COUNTS DOWN (§2.7), and the End of Duel window waits
	# for it. Nothing else about the verdict is deferred — the bar already
	# says who won, the music has stopped, Done is dead.
	await _run_death_countdown()
	if not is_instance_valid(self):
		return
	if _over_dialog != null:
		_over_dialog.queue_free()
	_over_dialog = OriginalDialog.create(verdict, Vector2(272, 300),
		"panel_end_duel")
	_over_dialog.body().add_child(OriginalDialog.label(
		"%s  %d life" % [game.players[0].player_name, game.players[0].life], 14))
	_over_dialog.body().add_child(OriginalDialog.label(
		"%s  %d life" % [game.players[1].player_name, game.players[1].life], 14))
	for line in next_draw_lines():
		_over_dialog.body().add_child(OriginalDialog.label(line, 14))
	# "OK" is one of the three buttons the 1997 game owns (@DIALOGBUTTONS).
	_over_dialog.add_button("OK").pressed.connect(_on_game_over_dismissed)
	add_child(_over_dialog)


## How long the losing numeral takes to fall, and how long it is held at
## the final number before the End of Duel window opens. Both are s30's
## (`duel.go:65-66`: `lossLifeAnimationDuration = 900ms`,
## `lossLifeHoldDuration = 500ms`), which refuses to leave the duel until
## the count is finished (`duel.go:1227-1229`).
const LOSS_COUNT_SECONDS := 0.9
const LOSS_HOLD_SECONDS := 0.5

## Life as of the last repaint, per seat — see the note in [method _refresh].
var _last_life: Array[int] = [0, 0]

## Seats whose numeral is mid-count, mapped to the value being shown.
## Absent = show the engine's number.
var _life_countdown: Dictionary = {}


## The number on a life register: the engine's, or the falling one while a
## death is being counted out (§2.7).
func _shown_life(pid: int) -> int:
	if _life_countdown.has(pid):
		return int(roundf(_life_countdown[pid]))
	return game.players[pid].life


## Count the dead player's total down from where it was to where it ended,
## then hold. Returns at once when nobody died of damage — a duel lost to
## an empty library or to poison has no number to fall, and s30 gates the
## same way (`startLossAnimationFromMessage` only starts a counter for a
## seat whose life is at or below zero).
##
## `start` is idempotent in s30 and so is this: a seat already counting is
## left alone, which matters because game_ended can arrive while an earlier
## repaint is still in flight.
func _run_death_countdown() -> void:
	var dying: Array[int] = []
	for pid in 2:
		if game.players[pid].life <= 0 and _last_life[pid] > game.players[pid].life \
				and not _life_countdown.has(pid):
			dying.append(pid)
	if dying.is_empty():
		return
	var tween := create_tween().set_parallel(true)
	for pid in dying:
		_life_countdown[pid] = float(_last_life[pid])
		tween.tween_method(_set_counted_life.bind(pid),
			float(_last_life[pid]), float(game.players[pid].life),
			LOSS_COUNT_SECONDS)
	await tween.finished
	if not is_instance_valid(self):
		return
	await get_tree().create_timer(LOSS_HOLD_SECONDS).timeout
	if not is_instance_valid(self):
		return
	_life_countdown.clear()


## One frame of the count. Writes the numeral directly rather than calling
## [method _refresh]: this fires every frame for 900ms and a full rebuild
## of both boards per frame is not what the animation is for.
func _set_counted_life(value: float, pid: int) -> void:
	_life_countdown[pid] = value
	if _life_buttons.size() == 2 and _life_buttons[pid] != null \
			and not _face_shown(pid):
		_life_buttons[pid].text = str(int(roundf(value)))


## THE CARDS NOBODY GOT TO DRAW — `@DIALOG_ENDDUEL` (`UIStrings.txt:527`),
## two strings and no more: `%s next draw:` and `Your next draw:`.
##
## `Duel.hlp`, **Dueling Options**, on the switch that governs them:
## *"**See Next Draws** has no effect during the duel. Rather, this
## controls whether, at the end of a duel, you get to see the next cards
## you and your opponent would have drawn. Toggle this option off if you
## don't want to see the next cards."*
##
## `Your next draw:` for a seat the player is sitting in, `%s next draw:`
## for the other, filled with that seat's name — the same you/them split
## `@DIALOG_VIEWANTES` and `@CUECARD_OTHER` use. A seat whose library is
## empty has no next draw and gets no line: it drew itself to death and
## the End of Duel window has just said so.
func next_draw_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if not DuelOptions.toggle("SeeNextDrawsAtEndOfDuel"):
		return lines
	for pid in 2:
		var library: Array = game.players[pid].library
		if library.is_empty():
			continue
		var head := "Your next draw:" if _is_human(pid) \
			else "%s next draw:" % game.players[pid].player_name
		lines.append("%s  %s" % [head, library[-1].data.card_name])
	return lines


## Is the End of Duel window still up? Read by [MatchScreen], which must
## let the duel have its last word before the match's own window opens.
func result_dialog_open() -> bool:
	return _result_pending or _over_dialog != null


func _on_game_over_dismissed() -> void:
	if _over_dialog != null:
		_over_dialog.dismiss()
		_over_dialog = null
	_result_pending = false
	# FREE PLAY ENDS AT THE TITLE. The setup screen hands the tree straight
	# to this scene for a free-play duel, and until 2026-09-02 nothing
	# ever handed it back: OK dismissed the window and left a dead table
	# whose only exit was Exit. A duel an OWNER holds — [MatchScreen], the
	# soak, a test — is not the scene, and is the owner's to drop
	# (MatchScreen._leave does the same for the match).
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://game/main.tscn")


# ------------------------------------------------- 1997 sound & coin toss --

## Play one 1997 cue by manifest key ([DuelAudio.play] does the work).
## A key with no imported sample behind it is silence, not an error.
func _play_sfx(key: String) -> void:
	if _audio != null:
		_audio.play(key)


## The duel's tune. The original has exactly ONE — `Dueltune.wav`, which
## `Shandalar.exe`'s resource list names as `x:sound\dueltune.wav` beside
## the twenty `LocMus` location tracks the ADVENTURE and the deck builder
## use (`src/deck/deckdll.cpp:2047`). A duel has one bed and it loops.
func _play_music() -> void:
	if _audio != null:
		_audio.play_music("music_duel")


# ------------------------------------------------------------------ sound --
#
# THE CUE TABLE LIVES IN `duel_audio.gd`. It moved out of this file on
# 2026-09-02 with the rest of the sound layer, because the map from a
# GameEvent to a 1997 WAV is a pure function that deserves testing without
# a screen, and because the voice pool it feeds is a mechanism with rules
# of its own. [DuelAudio]'s class doc carries the whole provenance —
# `defs.h:2179`, the call sites, and the three timing corrections.
#
# What stays here is the one event whose consequence is not a sound: a
# draw also fills the Showcase.


## Engine events → the original's sound vocabulary ([DuelAudio.cue_for]),
## plus the Showcase's own rule about a drawn card.
func _on_game_event(event: GameEvent) -> void:
	if _audio != null:
		_audio.on_event(event)
	if event.type != Mtg.EventType.CARD_DRAWN:
		return
	# THE SHOWCASE FILLS ITSELF ON A DRAW (§2.14). `Duel.hlp`, topic
	# **Showcase**: *"Whenever the mouse cursor pauses long enough over a
	# card in play, in a visible hand, or even in a graveyard, that card is
	# displayed here. Cards drawn into your hand are displayed when you
	# draw them."* The second sentence is a rule of its own — the only time
	# the original fills the Showcase without being asked — and it is the
	# 1997 answer to the same question §2.14 asks of s30.
	# Only for a seat we can see the hand of; the opponent's draw would
	# otherwise flash their card at us.
	# `turn_number` gates the OPENING DEAL out: it is 0 until start_duel,
	# so the seven (and every mulligan redraw, which also happens before
	# turn 1) leave the Showcase on its card back. Seven cards cannot be
	# shown one at a time anyway, and the opening window is over them while
	# they are dealt.
	# `hidden_hands`, not `_is_human`: the rule is whether this VIEWER may
	# see that hand. In a duel against the AI its seat is hidden and its
	# draw stays hidden; at a hotseat both hands are open, and the player
	# sitting down for their own turn is meant to see the card they just
	# drew.
	var drawn = event.data.get("instance")
	var drawer := int(event.data["player"])
	if drawn != null and game.turn_number >= 1 \
			and not hidden_hands.has(drawer) \
			and _card_preview != null:
		_card_preview.show_card(drawn)


## THE OPENING TOSS. [CoinToss] owns the whole presentation — the 1997
## movie, our recreation, or the instant result — and its class doc
## carries the provenance (the 1997 coin was a pre-rendered AVI, which is
## why no coin art exists to import). What stays here is the only part
## the duel screen cares about: the toss BLOCKS the AI scheduler until it
## and the opening hand are over.
##
## Deliberately not awaited by `_new_game`: this is the duel's opening
## cut and the screen keeps building behind it.
func _run_coin_toss(first: int) -> void:
	if DisplayServer.get_name() == "headless":
		return   # tests/CI: no animation delay, the game just begins
	_toss_active = true
	# THE SPLASH COMES FIRST — who is playing whom, with what — exactly
	# where the 1997 game puts it, between "Go" and the coin. It blocks
	# under the same `_toss_active` flag as the toss, so nothing on the
	# table answers while it is up.
	await _run_intro()
	if not is_inside_tree():
		return           # `Reconfigure duel` took us back to the setup
	_play_sfx("sfx_toss")
	var toss := CoinToss.new()
	toss.z_index = 250
	add_child(toss)
	_toss_overlay = toss
	await toss.run(config, first, _is_human(first), _human_seat())
	if is_instance_valid(toss):
		toss.queue_free()
	_toss_overlay = null
	# THE OPENING HAND (§1.5): play or draw, then the mulligans, and only
	# then turn 1. The AI scheduler stays blocked until it is over.
	await _run_opening_hand(first)
	_toss_active = false
	_refresh()   # releases the AI scheduler


## THE PRE-DUEL SPLASH. Returns when the player has seen it: `Go!`, five
## seconds, or `Reconfigure duel`, which leaves for the setup screen and
## never comes back (the caller checks `is_inside_tree`).
func _run_intro() -> void:
	var intro := DuelIntro.new()
	intro.z_index = 260
	# IN THE TREE FIRST, then built: `build` grabs focus for `Go!`, and a
	# node outside the tree cannot take focus — every soak duel printed
	# `Condition "!is_inside_tree()" is true` until this order was fixed.
	add_child(intro)
	intro.build(config)
	_intro_overlay = intro
	var leaving := [false]
	intro.reconfigure_pressed.connect(func() -> void:
		leaving[0] = true)
	await _first_of(intro.go_pressed, intro.reconfigure_pressed)
	if is_instance_valid(intro):
		intro.queue_free()
	_intro_overlay = null
	if leaving[0]:
		get_tree().change_scene_to_file("res://game/setup_screen.tscn")


## Whichever of the two signals fires first.
func _first_of(a: Signal, b: Signal) -> void:
	var done := [false]
	var finish := func() -> void: done[0] = true
	a.connect(finish, CONNECT_ONE_SHOT)
	b.connect(finish, CONNECT_ONE_SHOT)
	while not done[0]:
		await get_tree().process_frame


## Play-or-draw and the Shandalar mulligan, in the original's own words —
## see OpeningHand, which owns every string.
func _run_opening_hand(winner: int) -> void:
	var opening := OpeningHand.new()
	opening.announced.connect(_set_prompt)
	add_child(opening)
	await opening.run(game, winner, _is_human)
	opening.queue_free()


## Show an engine result: refusals verbatim (they FLASH for a moment,
## s30's warningMsg, then the status message returns), success clears.
##
## THE REFUSAL IS RED (§3.10). s30 paints `warningMsg` in
## `RGBA{255,100,100}` and every other bar state white
## (`duel.go:3145-3168`); ours wrote the refusal in the bar's own pale
## stone, so "not enough mana for Lightning Bolt" and "Main phase (before
## combat): cast spells" arrived in the same voice and the player had to
## READ the bar to notice they had been refused. Rules refusals are the
## one thing on this bar that is not a running commentary.
##
## AND IT EXPIRES ON ITS OWN. [member _flash_until_ms] only ever gated
## the status line inside [method _refresh], so a refusal sat on the bar
## until something else happened to call it — press an illegal card with
## nothing else going on and the red line was permanent. The timer below
## calls the repaint itself when the flash runs out.
func _report(err: String) -> void:
	if err == "":
		_flash_until_ms = 0
		_clear_warning_ink()
		return
	_prompt_label.text = err
	_prompt_label.add_theme_color_override("font_color", WARNING)
	_flash_until_ms = Time.get_ticks_msec() + FLASH_MS
	if _flash_timer != null:
		_flash_timer.start(FLASH_MS / 1000.0)


func _set_prompt(text: String) -> void:
	_prompt_label.text = text
	_clear_warning_ink()


## Put the bar back in its own voice after a red refusal. Cheap enough to
## call unconditionally — Godot's theme overrides are a dictionary write.
func _clear_warning_ink() -> void:
	_prompt_label.add_theme_color_override("font_color",
		OriginalDialog.HIGHLIGHT)


## The flash ran out with nothing else having moved: hand the bar back.
func _on_flash_expired() -> void:
	_flash_until_ms = 0
	_clear_warning_ink()
	_refresh()


## The colour of a refused action on the Situation Bar — s30's
## `color.RGBA{255, 100, 100, 255}` (`duel.go:3151`), the only non-white
## the bar ever wears.
const WARNING := Color8(255, 100, 100)

## How long a refusal holds the bar before the status line takes it back.
## Ours, not s30's: s30 redraws every frame and clears `warningMsg` on the
## next action instead, which a retained-mode UI cannot copy.
const FLASH_MS := 2500

## Milliseconds until a flashed refusal stops overriding the status line.
var _flash_until_ms := 0
## One-shot, armed by [method _report]: repaints the bar when a flash ends
## even if nothing else in the duel moved.
var _flash_timer: Timer = null


## Which of the 8 phase-strip icons a step lights — s30's phaseIndex
## order exactly: Cleanup (the original's "Discard Phase") is slot 6,
## End of Turn is slot 7; every combat step shares the combat icon.
static func _phase_icon_slot(step: int) -> int:
	match step:
		Mtg.Step.UNTAP: return 0
		Mtg.Step.UPKEEP: return 1
		Mtg.Step.DRAW: return 2
		Mtg.Step.MAIN1: return 3
		Mtg.Step.MAIN2: return 5
		Mtg.Step.CLEANUP: return 6
		Mtg.Step.END: return 7
		_: return 4   # every combat step lights the combat icon


## What the 1997 Situation Bar names each phase when it fills the
## "Fast Effects?...%s" blank — `@PROMPT_CHECKFEPHASE`,
## shandalar-src/Program/UIStrings.txt:1024, verbatim and in its own
## capitalisation. The original has a real Discard phase where we run
## CLEANUP, and no End step at all (docs/glossary-1997.md §3), so both
## of ours answer with its "Discard Phase".
static func _fe_phase_name(step: int) -> String:
	match step:
		Mtg.Step.UPKEEP: return "Upkeep Phase"
		Mtg.Step.DRAW: return "Draw Phase"
		Mtg.Step.MAIN1, Mtg.Step.MAIN2: return "Main Phase"
		Mtg.Step.DECLARE_ATTACKERS: return "Assign Attackers"
		Mtg.Step.DECLARE_BLOCKERS: return "Assign Blockers"
		Mtg.Step.END, Mtg.Step.CLEANUP: return "Discard Phase"
		_: return "Main Phase"


## The Situation Bar's line, in the ORIGINAL's own words. Every string
## below is quoted from the 1997 table, shandalar-src/Program/
## UIStrings.txt (see docs/glossary-1997.md); earlier passes paraphrased
## s30's statusMessage, which is how we ended up asking about attackers
## in the fast-effects form — a question the 1997 game never asks.
##   @PROMPT_FASTEFFECTS:1018   Fast Effects?...%s
##   @PROMPT_CHECKFEPHASE:1024  the %s: phase names, "Cast %s", ...
##   @PROMPT_MAIN:1063          the four main-phase lines and the two
##                              combat ones, full stops included
##   @PROMPT_STILLTHINKING:954  Still thinking...
##   @DIALOG_SHANDALARENDDUEL:514  %s won / You won! / a draw
func _status_message() -> String:
	if game.game_over:
		if game.winner < 0:
			return "The duel is a draw"
		if _is_human(game.winner):
			return "You won!"
		return "%s won" % game.players[game.winner].player_name
	var human := 0 if _is_human(0) else 1
	var my_turn := game.active_player == human
	var step := game.current_step()
	# A resolution held open for a question (§1.3): the overlay carries the
	# question itself, so the bar names the CARD that is asking — the same
	# "Process %s" the chain window and the fast-effects line use for a
	# trigger (`@PROMPT_CHECKFEPHASE` entry 4).
	if game.awaiting_choice != null:
		var asking: PlayerChoice = game.awaiting_choice
		if asking.source != "":
			return "Process %s" % asking.source
		return "Paused"
	# THE DAMAGE-PREVENTION WINDOW (§6.8). `Damage prevention` and `Use
	# Regeneration Effects` are entries 0 and 11 of the SAME
	# `@PROMPT_CHECKFEPHASE` table the phase names come from, so they fill
	# the fast-effects blank exactly the way a phase name does.
	if game.awaiting_damage_prevention or game.awaiting_regeneration:
		var window: Dictionary = game.damage_prevention_request()
		var what := String(window.get("prompt", "Damage prevention"))
		if game.priority_player == human:
			return "Fast Effects?..." + what
		return what
	# THE FAMOUS QUESTION. The player holds priority at instant speed — a
	# spell waits on the chain, or it is not their own quiet main phase.
	# The blank after the ellipsis is what is BEING RESPONDED TO: the
	# original names the spell on the chain ("Cast %s") in preference to
	# the phase, which is why its bar reads like a running commentary.
	if game.priority_player == human \
			and (not game.stack.is_empty() or not my_turn):
		var subject := _fe_phase_name(step)
		# WHICH OF THE THREE FRAMES (§6.7). `@PROMPT_FASTEFFECTS`
		# (UIStrings.txt:1018) has three, and `src/functions/events.c:396-399`
		# picks between them off the legal-response type mask:
		# `Interrupts?...` when only TYPE_INTERRUPT may answer,
		# `Fast Effects?...` when TYPE_INSTANT may, `Triggered effects?...`
		# in the trigger window. We have no interrupt/instant split, so it
		# reduces to TWO: a trigger on top of the chain is the trigger
		# window, and everything else is fast effects.
		var frame := "Fast Effects?..."
		if not game.stack.is_empty():
			var top = game.stack.back()
			# "Cast %s" / "Activate %s" / "Process %s" are entries 2-4 of
			# @PROMPT_CHECKFEPHASE — the original's three words for the
			# three kinds of chain object, and the same split the chain
			# window's own captions use (_rebuild_stack).
			var verb := "Cast"
			match top.kind:
				Mtg.StackKind.ABILITY: verb = "Activate"
				Mtg.StackKind.TRIGGER:
					verb = "Process"
					frame = "Triggered effects?..."
			subject = "%s %s" % [verb, top.card.data.card_name]
		return frame + subject
	# Our own turn, nothing waiting: the original spells out what the
	# phase allows, and drops ", play land" once the land drop is spent.
	if my_turn and game.priority_player == human:
		var when := "before combat" if step == Mtg.Step.MAIN1 else "after combat"
		match step:
			Mtg.Step.MAIN1, Mtg.Step.MAIN2:
				if game.players[human].lands_played_this_turn >= 1:
					return "Main phase (%s): cast spells" % when
				return "Main phase (%s): cast spells, play land" % when
			Mtg.Step.DECLARE_ATTACKERS:
				return "Combat phase: Choose attackers."
	if step == Mtg.Step.DECLARE_BLOCKERS and game.priority_player == human \
			and not my_turn:
		return "Combat phase: Choose blockers."
	# Nobody is waiting on us: the referee is working.
	if not _is_human(game.priority_player):
		return "Still thinking..."
	return _fe_phase_name(step)


# ============================================================= interactions --

func _on_card_clicked(inst: CardInstance) -> void:
	if game.game_over or _toss_active:
		return
	match mode:
		Mode.TARGETING:
			_try_take_target(TargetRef.card(inst))
		Mode.ATTACKERS:
			_toggle_attacker(inst)
		Mode.BLOCKERS:
			_pick_block(inst)
		Mode.DISCARD:
			_toggle_discard(inst)
		Mode.DAMAGE:
			_assign_one_point(inst.id)
		Mode.PAYING:
			# *"Once a land is in play, you can tap it for mana at any
			# time. Simply place the mouse pointer over the land you want
			# to tap and click"* (`Duel.hlp`, topic **Using Land**) — and
			# that is the whole of this mode. Only MANA comes out of a
			# permanent here: activating something else would swap the
			# pending cast out from under itself, which is the same trap
			# `_modal_open()` closed for the X dialog (2026-09-02).
			if _modal_open() or not _is_human(inst.controller_id):
				return
			if inst.zone == Mtg.Zone.BATTLEFIELD:
				_tap_for_payment(inst)
		Mode.NORMAL:
			# A CENTRE POPUP OWNS THE TABLE, not only the keyboard: the X
			# question, the tutor picker, the mode menu and the graveyard
			# view answer with their own buttons ([method _done_applies]
			# says the same of Done). The board underneath used to stay
			# live — a second cast started under the X dialog swapped
			# the pending state out from under it, and the dialog's OK
			# then read a card that was no longer there (2026-09-02).
			if _modal_open():
				return
			if not _is_human(inst.controller_id):
				return   # AI cards are not the human's to operate
			if inst.zone == Mtg.Zone.HAND:
				_click_hand_card(inst)
			elif inst.zone == Mtg.Zone.BATTLEFIELD:
				_click_permanent(inst)


## A CLICK ON AN ACTIVATED ABILITY SITTING ON THE CHAIN. While targeting,
## it names the ACTIVATION (`TargetRef.ability`) — which is what
## `TargetSpec.Kind.ABILITY` wants and what a card ref can never be —
## and outside targeting it behaves like a click on the source permanent,
## because that is what the entry is showing.
func _on_chain_ability_clicked(item: StackItem) -> void:
	if game == null or game.game_over:
		return
	if mode == Mode.TARGETING:
		_try_take_target(TargetRef.ability(item))
		return
	_on_card_clicked(item.card)


## [method _target_state_for] for a chain ability: the already-chosen
## stamp, keyed on the STACK ITEM's id rather than an instance id.
func _ability_target_state(item: StackItem) -> int:
	if mode != Mode.TARGETING or _pending_slot >= _pending_slots.size():
		return -1
	for chosen in _pending_groups[_pending_slot]:
		if chosen.is_ability and chosen.ability_id == item.id:
			return MiniCard.State.TARGET_AGAIN
	return -1


## [method _highlight_for]'s TARGETING branch for a chain ability. Without
## it the entry is legal to click and shows no sign of it, which is the
## same gap by a different route.
func _ability_highlight(item: StackItem) -> int:
	if mode != Mode.TARGETING or _pending_slot >= _pending_slots.size():
		return MiniCard.Highlight.NONE
	for chosen in _pending_groups[_pending_slot]:
		if chosen.is_ability and chosen.ability_id == item.id:
			return MiniCard.Highlight.TARGET_CHOSEN
	var spec: TargetSpec = _pending_slots[_pending_slot]["spec"]
	if spec.is_legal(game, TargetRef.ability(item), _pending_card):
		return MiniCard.Highlight.TARGET_LEGAL
	return MiniCard.Highlight.NONE


func _on_life_clicked(pid: int) -> void:
	if mode == Mode.TARGETING:
		_try_take_target(TargetRef.player(pid))
	elif mode == Mode.DAMAGE and pid != _human_seat():
		# Trample's spill: the life register IS the player-target click
		# (`@MENU_LIFE` = "Target %s" / "Target yourself").
		_assign_one_point(MtgGame.DAMAGE_TO_PLAYER)


# ------------------------------------------ THE DUELIST'S FACE (§6.5) --
#
# The life register has two sides and the original turns it over three
# ways: by hand from its own mini-menu, automatically when a spell could
# take a player as a target, and automatically BACK when that targeting is
# over. [DuelistFace] carries the `Duel.hlp` topic that specifies all
# three, and the two string tables (`@MENU_LIFE` / `@MENU_FACE`) whose
# only difference is the verb.

## Which register art each panel is currently wearing: -1 not dressed yet,
## 0 the register's wallpaper, 1 the face. Kept so the styleboxes are
## rebuilt on a FLIP rather than on every refresh — this runs twice per
## redraw and the panel is otherwise unchanged for whole turns at a time.
var _face_dressed: Array[int] = [-1, -1]
## Which register the open mini-menu belongs to (-1 = closed).
var _life_menu_pid := -1


## Is [param pid]'s register showing the face right now? The player's own
## flip, OR the automatic one: *"there is a spell or effect being cast
## that could target a player"*. The automatic half is recomputed rather
## than stored, which is exactly what makes *"when faces are no longer
## needed, they flip back to show the Life Registers automatically"* true
## without anything having to notice that the cast ended.
func _face_shown(pid: int) -> bool:
	return _face_flipped[pid] or _player_is_targetable(pid)


## Could the pending cast legally take [param pid] as a target right now?
## Asked of the very same [TargetSpec] the click would be checked against,
## so the face can never invite a click that `_try_take_target` refuses.
func _player_is_targetable(pid: int) -> bool:
	if mode != Mode.TARGETING or _pending_slot >= _pending_slots.size():
		return false
	var spec: TargetSpec = _pending_slots[_pending_slot]["spec"]
	return spec.is_legal(game, TargetRef.player(pid), _pending_card)


## A panel can only be turned over if there is a face to turn it to — the
## 1997 skin's `duelist_face_<colour>`. Without it the menu entry is
## GREYED rather than missing, on §6.1's precedent for the Help entries.
func _can_flip(pid: int) -> bool:
	return DuelistFace.portrait(config.panel_colors[pid]) != null


## Put the right ground on [param pid]'s register. Cheap to call: it
## returns immediately unless the side actually changed.
func _dress_life_panel(pid: int, face_up: bool) -> void:
	var want := 1 if face_up else 0
	if _face_dressed[pid] == want:
		return
	var life: Button = _life_buttons[pid]
	if life == null:
		return
	var color: String = config.panel_colors[pid]
	var art := DuelistFace.portrait(color) if face_up else DuelistFace.register(color)
	if art == null:
		# No 1997 skin: the flat button stays, and _can_flip has already
		# made sure nothing offered to turn it over.
		_face_dressed[pid] = want
		return
	var box := StyleBoxTexture.new()
	box.texture = art
	box.set_content_margin_all(6)
	life.add_theme_stylebox_override("normal", box)
	var hover: StyleBoxTexture = box.duplicate()
	hover.modulate_color = Color(1.15, 1.15, 1.15)
	life.add_theme_stylebox_override("hover", hover)
	life.add_theme_stylebox_override("pressed", hover)
	life.add_theme_stylebox_override("focus", hover)
	_face_dressed[pid] = want


func _on_life_input(event: InputEvent, pid: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		_open_life_menu(pid, mb.global_position)


## `@MENU_LIFE` / `@MENU_FACE` — four entries, in the table's own order,
## with the third one reading whichever way the panel is facing. The two
## `Target` entries do exactly what a click on the exposed face does
## (*"simply click on the appropriate exposed face"*), so they are live on
## the same condition and route through the same handler; `Help...` is
## disabled because there is no Dueling Help to open, as everywhere else.
func _open_life_menu(pid: int, at: Vector2) -> void:
	if _life_menu == null:
		return
	_life_menu_pid = pid
	var mine := _human_seat()
	var theirs := 1 - mine
	_life_menu.clear()
	var labels := DuelistFace.menu_labels(_face_shown(pid),
		config.player_names[theirs])
	for i in labels.size():
		_life_menu.add_item(labels[i], i)
	var live := [_player_is_targetable(theirs), _player_is_targetable(mine),
		_can_flip(pid), false]
	for i in live.size():
		_life_menu.set_item_disabled(_life_menu.get_item_index(i), not live[i])
	_life_menu.reset_size()
	_life_menu.position = Vector2i(at) + Vector2i(6, 0)
	_life_menu.popup()


func _on_life_menu_chosen(id: int) -> void:
	if _life_menu_pid < 0:
		return
	match id:
		0: _on_life_clicked(1 - _human_seat())
		1: _on_life_clicked(_human_seat())
		DuelistFace.FLIP:
			_face_flipped[_life_menu_pid] = not _face_flipped[_life_menu_pid]
			_refresh()


# ------------------------------------------------- the discard phase (§1.1) --
#
# `@PROMPT_DISCARDACARD` (Program/UIStrings.txt:1106) opens with
# `Select card to discard.`, and `@PROMPT_DISCARD` (:1074) names the pause
# itself: `Paused: Discard phase`. The engine holds the cleanup step open
# (MtgGame.awaiting_discard) and this is where the player answers it.

func _toggle_discard(inst: CardInstance) -> void:
	if inst.zone != Mtg.Zone.HAND or inst.owner_id != game.active_player:
		return
	if _discard_picks.has(inst.id):
		_discard_picks.erase(inst.id)
	elif _discard_picks.size() < game.discard_count:
		_discard_picks.append(inst.id)
	else:
		# Picking one more than the phase wants replaces the oldest, so a
		# misclick never dead-ends the only screen with no Cancel.
		_discard_picks.pop_front()
		_discard_picks.append(inst.id)
	_set_prompt(_discard_prompt())
	_refresh()


func _discard_prompt() -> String:
	var left := game.discard_count - _discard_picks.size()
	if left <= 0:
		return "Select card to discard. (Done)"
	return "Select card to discard. (%d of %d)" % [
		_discard_picks.size(), game.discard_count]


func _confirm_discard() -> void:
	var cards: Array = []
	for id in _discard_picks:
		var inst := game.find_instance(id)
		if inst != null:
			cards.append(inst)
	var err := game.discard_to_hand_size(game.active_player, cards)
	if err == "":
		_discard_picks = []
		mode = Mode.NORMAL
		# WAV_DISCARD, `functions.c:14861` — the original plays it inside
		# the discard itself, once per card put into the graveyard. Ours
		# fires on the confirmed hand-size discard, and [DuelAudio]'s
		# per-frame coalesce makes a two-card discard one sound, which is
		# what a batch discard sounds like anyway.
		_play_sfx("sfx_discard")
	_report(err)
	_refresh()


# --------------------------------------------- the damage division (§1.4) --
#
# `@PROMPT_RESOLVECOMBAT` (Program/UIStrings.txt:999) is a click loop with
# a live counter: `%s: Assign damage to blockers, %d points left`, and
# `%s: Assign trample damage to blockers, %d points left` once trample is
# in play. One click is one point, and the division submits itself the
# moment the last point is spent.

## Which ids may legally take the next point, given what is dialled in so
## far. Mirrors MtgGame's own validation so a click is never a submission
## the engine will refuse: under modern rules (CR 510.1c) the next point
## belongs to the first blocker in the assignment order still short of
## lethal; once they all have lethal any of them may take the excess, and
## trample may spill to the player. RulesOptions.free_damage_assignment —
## the 1997 ruleset, which had no order at all — opens all of them at once.
func _damage_candidates() -> Array[int]:
	var request := game.damage_assignment_request()
	var out: Array[int] = []
	if request.is_empty():
		return out
	var assigned: Dictionary = request["assigned"]
	var all_lethal := true
	var first_short := -1
	for id in request["targets"]:
		var inst := game.find_instance(int(id))
		if inst == null:
			continue
		var need := game.lethal_remaining(inst, assigned) \
			- int(_damage_picks.get(int(id), 0))
		if need > 0:
			all_lethal = false
			if first_short < 0:
				first_short = int(id)
	if game.rules.free_damage_assignment or all_lethal:
		for id in request["targets"]:
			out.append(int(id))
	elif first_short >= 0:
		out.append(first_short)
	if all_lethal and bool(request["trample"]):
		out.append(MtgGame.DAMAGE_TO_PLAYER)
	return out


func _points_left() -> int:
	var request := game.damage_assignment_request()
	if request.is_empty():
		return 0
	var spent := 0
	for key in _damage_picks:
		spent += int(_damage_picks[key])
	return int(request["amount"]) - spent


func _assign_one_point(id: int) -> void:
	var request := game.damage_assignment_request()
	if request.is_empty() or _points_left() <= 0:
		return
	if not _damage_candidates().has(id):
		# The original's own refusal vocabulary (`@PROMPT_ILLEGALTARGET`).
		_set_prompt("Illegal target (wrong attack group)")
		return
	_damage_picks[id] = int(_damage_picks.get(id, 0)) + 1
	if _points_left() <= 0 or _damage_candidates().is_empty():
		_confirm_damage()
		return
	_set_prompt(_damage_prompt())
	_refresh()


## `@PROMPT_RESOLVECOMBAT` entries 1 and 2, verbatim.
func _damage_prompt() -> String:
	var request := game.damage_assignment_request()
	if request.is_empty():
		return ""
	var source: CardInstance = request["source"]
	var verb := "Assign trample damage to blockers" if bool(request["trample"]) \
		else "Assign damage to blockers"
	return "%s: %s, %d points left" % [
		source.data.card_name, verb, _points_left()]


func _confirm_damage() -> void:
	var request := game.damage_assignment_request()
	if request.is_empty():
		return
	var err := game.assign_combat_damage(int(request["assigner"]),
		_damage_picks.duplicate())
	if err == "":
		_damage_picks = {}
		mode = Mode.NORMAL
	else:
		_damage_picks = {}
		_report(err)
	_refresh()


# ------------------------------------------------ the graveyard (§1.2) --
#
# `@MENU_GRAVEYARD` (Program/UIStrings.txt:901) — "View the graveyard /
# View exiled cards / View both antes" — is the original's own answer to
# "how do I reach a card in a pile", and GraveyardView is all three views.
# The engine has had four graveyard target kinds and five cards that use
# them since well before this; they were uncastable purely because nothing
# on this screen could be clicked.

## Click a pile: open it, or close it if it is the one already open
## (s30 `duel.go:3715-3733`). An empty pile does nothing.
func _on_grave_pile_clicked(pid: int) -> void:
	if _grave_open_pile == pid:
		_close_graveyard()
		return
	if game.players[pid].graveyard.is_empty() \
			and game.players[pid].exile.is_empty() \
			and game.players[pid].ante.is_empty():
		return
	_open_graveyard(pid)


func _open_graveyard(pid: int) -> void:
	if _grave_view == null:
		_grave_view = GraveyardView.new()
		_grave_view.card_picked.connect(_on_graveyard_card)
		_grave_view.dismissed.connect(_close_graveyard)
		add_child(_grave_view)
	# The pile's cards fill the SAME docked big card as the hand and the
	# battlefield ([QoL], the owner's "only big preview and mini cards").
	_grave_view.preview = _card_preview
	# A pile always OPENS on its first shelf of five (or, while targeting,
	# on the one holding the first legal card) — never where the player
	# left it several casts ago.
	_grave_view.reset_paging()
	_grave_open_pile = pid
	_grave_view.visible = true
	_repopulate_graveyard()


func _close_graveyard() -> void:
	_grave_open_pile = -1
	if _grave_view != null:
		_grave_view.visible = false


## Is the graveyard overlay showing? (Escape peels it first, and the
## screenshot tour asks.)
func graveyard_is_open() -> bool:
	return _grave_open_pile >= 0


func _repopulate_graveyard() -> void:
	if _grave_view == null or not _grave_view.visible:
		return
	var legal := Callable()
	if mode == Mode.TARGETING and _pending_slot < _pending_slots.size():
		var spec: TargetSpec = _pending_slots[_pending_slot]["spec"]
		legal = func(inst: CardInstance) -> bool:
			return spec.is_legal(game, TargetRef.card(inst), _pending_card)
	# The dim covers the screen (s30) but the SHELVES lay out over the
	# BOARD only: the sidebar holds the big card they fill, and a pile
	# sitting on top of it would hide the very thing hovering is for.
	_grave_view.board_area = _board_area()
	_grave_view.populate(game, _human_seat(), legal)


## A card in the open view was clicked. While targeting it is a target
## (s30 `handleGraveyardTargetClick`, `duel.go:2305-2328`: a valid card
## submits and closes, an invalid one is refused); otherwise it is just
## something to look at, which is the original's Showcase.
func _on_graveyard_card(inst: CardInstance) -> void:
	if mode != Mode.TARGETING:
		if _card_preview != null:
			_card_preview.show_card(inst)
		return
	var before := _pending_slot
	var had := _pending_card
	_try_take_target(TargetRef.card(inst))
	# The pick landed and the cast either finished or moved to a slot that
	# no pile can answer: get out of the player's way, exactly as s30 does.
	if _pending_card == null or _pending_slot != before:
		_close_graveyard()
	elif had != null:
		_repopulate_graveyard()


func _click_hand_card(inst: CardInstance) -> void:
	var pid := inst.owner_id
	if inst.is_land():
		_report(game.play_land(pid, inst))
		return
	_pending_card = inst
	_pending_ability_index = -1
	_pending_pid = pid
	_pending_targets = []
	_pending_x = 0
	_pending_mode = 0
	# Choice chain: mode (modal) → library pick (tutor) → X → targets.
	if inst.data.is_modal():
		_open_mode_menu(inst)
		return
	_pending_specs = _specs_for_cast(inst, 0)
	_build_target_slots(inst.data, 0)
	_continue_cast_chain()


## The steps of the cast chain AFTER any mode is known.
func _continue_cast_chain() -> void:
	var search := _search_effect_of(_pending_card.data, _pending_mode)
	if search != null and _humans.has(_pending_pid) \
			and not _humans[_pending_pid].has_preselection():
		_open_search_dialog(search)
		return
	if _pending_card.data.cost.has_x:
		_open_x_dialog()
	else:
		_advance_pending()


func _click_permanent(inst: CardInstance) -> void:
	var mana_count := inst.cur_mana_abilities.size()
	var ability_count := inst.cur_activated_abilities.size()
	if mana_count == 1 and ability_count == 0:
		_report(game.tap_for_mana(inst.controller_id, inst))
	elif mana_count + ability_count > 0:
		_open_ability_menu(inst)
	# Permanents with nothing to activate: click is a no-op (hover shows
	# the card's oracle text via tooltip).


## A click on a permanent while a cast is waiting for its mana
## ([constant Mode.PAYING]): MANA ONLY. One mana ability taps straight
## away; several open the same menu the normal click does, with the
## activated abilities left out of it.
func _tap_for_payment(inst: CardInstance) -> void:
	var mana_count := inst.cur_mana_abilities.size()
	if mana_count == 0:
		return
	if mana_count == 1:
		_report(game.tap_for_mana(inst.controller_id, inst))
		return
	_open_ability_menu(inst, true)
	# Permanents with nothing to activate: click is a no-op (hover shows
	# the card's oracle text via tooltip).


## Move the pending cast/activation forward: collect the next target, or
## submit to the engine when everything is gathered.
## Targeting walks one SLOT per targeting effect. A slot wants between
## min and max targets (max -1 = any number, X-based counts resolved from
## the chosen X), so "Tap X target creatures", "one or more target
## creatures" and "N damage divided among any number of targets" all fit
## the same loop. Done/Confirm closes a variable slot once its minimum is
## met; a fixed slot closes itself.
func _advance_pending() -> void:
	while _pending_slot < _pending_slots.size():
		var slot: Dictionary = _pending_slots[_pending_slot]
		var picked: int = _pending_groups[_pending_slot].size()
		var want_max: int = slot["max"]
		# THE DIVIDED SLOT COUNTS POINTS, NOT TARGETS (§6.14) — see
		# [method _divided_prompt]. It closes when the last point is
		# spent, exactly as the combat division does.
		var total: int = slot["divided"]
		if total > 0:
			if _points_dialled(_pending_slot) >= total:
				_pending_slot += 1
				continue
			mode = Mode.TARGETING
			_set_target_cursor(true)
			_set_prompt(_divided_prompt(slot, _pending_slot))
			_refresh()
			return
		if want_max >= 0 and picked >= want_max:
			_pending_slot += 1
			continue
		# THE LONE COUNTER-TARGET (§3.3). Countering the opponent's only
		# spell needs no aim; take it and move on.
		var lone := _lone_counter_target(slot)
		if lone != null:
			_pending_groups[_pending_slot].append(lone)
			_auto_slots.append(_pending_slot)
			continue
		# THE DAMAGE MARKER (§6.8, §6.20b). A Circle of Protection's target
		# is one waiting DAMAGE PACKET, and since the marker widget landed
		# the player clicks it exactly as they click a card
		# ([DamageMarkerLayer]). Two cases still short-circuit:
		#
		#  * ONE legal packet — §3.3's own gesture. There is nothing to
		#    decide, and the original's help says the same of the whole
		#    family of lone targets.
		#  * NONE — which is every duel played under the modern default,
		#    where no window ever holds a packet. The OPTIONAL slot goes
		#    untaken and the Circle puts up the colour shield it always
		#    did; a slot that REQUIRES one is cancelled rather than
		#    stranding the player in front of an empty table.
		#
		# Two or more falls through to the targeting loop below, which is
		# where the markers are lit and waiting.
		var damage_spec: TargetSpec = slot["spec"]
		if damage_spec.kind == TargetSpec.Kind.DAMAGE:
			var markers := damage_spec.legal_targets(game, _pending_card)
			if markers.size() == 1:
				_pending_groups[_pending_slot].append(markers[0])
				_auto_slots.append(_pending_slot)
				continue
			if markers.is_empty():
				if int(slot["min"]) > 0:
					_on_cancel()
					return
				_pending_slot += 1
				continue
		mode = Mode.TARGETING
		_set_target_cursor(true)   # the original's targeting cursor
		var spec: TargetSpec = slot["spec"]
		# The 1997 targeting line is one sentence and no more —
		# "Select target creature." is the whole of most entries in
		# prompts.txt / promptsX2.txt. When several picks are wanted the
		# original counts them in brackets: @PROMPT_GRABMANA
		# (UIStrings.txt:1090) is "%s(%d so far)" and
		# "%s(%d so far, max %d)". Same two forms here.
		var how := "Select %s." % spec.description
		if spec.kind == TargetSpec.Kind.DAMAGE:
			# The original has its OWN sentence for this one click, and it
			# calls the marker a card: `@CIRCLE_OF_PROTECTION`,
			# `Program/prompts.txt:185` — `Select damage card.` It replaces
			# the generic form because the generic form would read "Select
			# target damage from a green source.", which is the
			# REQUIREMENT, and §6.10's rule is that the prompt says what to
			# do while the brackets say what is wrong.
			how = DAMAGE_TARGET_PROMPT
		elif want_max < 0:
			how = "Select %s. (%d so far)" % [spec.description, picked]
		elif want_max > 1:
			how = "Select %s. (%d so far, max %d)" % [
				spec.description, picked, want_max]
		_set_prompt(how)
		_refresh()
		return
	_set_target_cursor(false)
	_pending_targets = _flatten_pending_targets()
	# All targets chosen — submit, or hold the cast open for its mana.
	_submit_pending()
	_refresh()


## Hand the finished cast or activation to the engine.
##
## THE ONE REFUSAL THAT IS NOT A MISTAKE is "not enough mana"
## ([method MtgGame.is_unpaid_refusal]). In 1997 the payment comes AFTER
## the click — *"Once you've selected a spell to cast, you must draw enough
## mana… to power the spell"* (`Duel.hlp`, topic **Hands**) — so an unpaid
## cast is a cast in progress and the screen goes to [constant Mode.PAYING]
## and waits for the player to tap, instead of throwing the whole cast away
## with a red line. Every OTHER refusal is a real refusal and is reported
## as it always was.
##
## Does NOT refresh: the two callers own that (one is inside a refresh
## already).
func _submit_pending() -> void:
	if _pending_card == null:
		return
	var err: String
	if _pending_ability_index < 0:
		err = game.cast_spell(_pending_pid, _pending_card, _pending_targets,
			_pending_x, _pending_mode)
	else:
		err = game.activate_ability(_pending_pid, _pending_card,
			_pending_ability_index, _pending_targets, _pending_x)
	if MtgGame.is_unpaid_refusal(err) and _pending_is_reachable():
		mode = Mode.PAYING
		_set_target_cursor(false)
		_paying_pool = game.players[_pending_pid].mana_pool.total()
		_set_prompt(GRAB_MANA_PROMPT % _pending_card.data.card_name)
		return
	# A cast that WENT THROUGH keeps its tutor pick: the search happens
	# when the spell resolves, priority rounds from now, and the pick is
	# parked for exactly that (HumanAgent.preselect). Clearing it here
	# made Demonic Tutor ask twice (2026-09-02). A refused one drops it.
	_clear_pending(err == "")
	_report(err)


## COULD THE PENDING ACTION STILL BE PAID FOR, from everything this seat
## has untapped? [constant Mode.PAYING] is only ever entered while the
## answer is yes.
##
## THE RULE THIS ENFORCES: the screen may never park on a prompt whose only
## way forward is Cancel. A spell the player simply cannot afford is
## refused with the engine's own sentence exactly as it was before the mode
## existed — *"not enough mana for Grizzly Bears ({1}{G})"* — and the cast
## is dropped. (Found by `duel_soak.sh`, which fuzzes the human seat and
## deliberately clicks an unaffordable card one try in ten: without this
## guard the fuzzer sat in the mode until the 240s stall detector fired.)
##
## [member _no_auto_tap] is deliberately NOT applied: a locked land is
## still a land the player may click. *"The only way to tap a locked land
## is manually, by clicking on it"* (`Duel.hlp`, topic **Territory**).
func _pending_is_reachable() -> bool:
	if _pending_card == null:
		return false
	var payment: Dictionary
	if _pending_ability_index < 0:
		payment = game.spell_payment(_pending_pid, _pending_card.data,
			_pending_x, maxi(_flatten_pending_targets().size(), 1))
	elif _pending_ability_index < _pending_card.cur_activated_abilities.size():
		payment = game.ability_payment(_pending_pid, _pending_card,
			_pending_ability_index, _pending_x)
	else:
		return false
	if ManaPlanner.cost_is_free(payment["cost"]) and int(payment["extra"]) == 0:
		return false     # free and still refused: not a mana problem
	return not ManaPlanner.plan(game, _pending_pid, payment["cost"],
		int(payment["extra"]), payment["usage"]).is_empty()


## The floating total the held-open cast was last priced against, so the
## retry below costs nothing until the player actually produces mana.
var _paying_pool := -1


# ------------------------------------------- THE AUTO-CAST (§6.20c) --
#
# THE OWNER'S PLAYTEST, 2026-09-03: *"If you double-click a spell with a
# yellow name that can be cast, suitable lands should auto-tap and the card
# is cast quickly."*
#
# IT IS 1997's OWN GESTURE, named twice in the shipped help file.
# `Duel.hlp`, topic **Hands**: *"if you are not in one of those situations
# and don't care to manage your mana, you can AUTO-CAST a spell by
# DOUBLE-CLICKING on it. This is a convenient shortcut, but keep in mind
# that you momentarily give up control over which of your mana is used…
# If you double-click to auto-cast an X spell, ALL of the mana you have
# available in your pool and from land sources will be put into that
# spell."* Topic **Spells** says it again and adds the order of operations:
# *"Alternatively, you can double-click on a card in your hand to auto-cast
# it. The casting cost is taken from your available MANA SOURCES
# automatically… If the spell is a targeted one, you need to choose a
# target."* So the auto-cast automates the MANA and only the mana — the
# targets are still the player's, and so is a modal spell's mode.
#
# The Tier 2 decompilation names the routine it called and its default
# flags: `try_to_pay_for_mana_by_autotapping(player, &amt, &v46,
# AUTOTAP_NO_CREATURES|AUTOTAP_NO_ARTIFACTS|AUTOTAP_NO_DONT_AUTO_TAP|
# AUTOTAP_NO_NONBASIC_LANDS, v47)` at `Magic.exe:0x42e26b`, replaced by
# `shandalar-src/src/patches/patch_autotap_artifacts_and_creatures.pl`,
# which introduces itself as *"the logic for human left-double-click mana
# autotapping"*. Ours plans over every source [ManaPlanner] can pay for —
# Manalink's widened set rather than 1997's basics-only one, which is the
# same choice the AI seat already made — minus the one exclusion the 1997
# player controls, [member _no_auto_tap].


## Auto-cast [param inst] — the second click of a left double-click on a
## card in hand.
func _auto_cast(inst: CardInstance) -> void:
	if game == null or game.game_over or _toss_active:
		return
	if inst.zone != Mtg.Zone.HAND or not _is_human(inst.owner_id):
		return
	if inst.is_land():
		# *"If you have a land in your hand, click on it to put it into
		# play. You can also double-click, but the effect is the same."*
		return
	if _pending_card != inst:
		# The first click did not leave this card pending — it was refused,
		# or it is already on the chain, or a popup swallowed it. Start the
		# cast now rather than second-guessing which.
		if mode != Mode.NORMAL or _modal_open() or _pending_card != null:
			return
		_click_hand_card(inst)
		if _pending_card != inst:
			return
	# THE X QUESTION IS ANSWERED BY THE GESTURE: "all of the mana you have
	# available in your pool and from land sources". The dialog's own spin
	# is filled to that number and confirmed, so the per-target arithmetic,
	# the target count and the slot rebuild all still run through
	# [method _on_x_confirmed] and cannot drift from the typed answer.
	if _x_dialog != null and _x_spin != null:
		var budget := _auto_x_budget()
		_x_spin.max_value = maxi(budget, int(_x_spin.max_value))
		_x_spin.value = budget
		_on_x_confirmed()
	if _pending_card != inst:
		return          # the X answer finished or abandoned the cast
	if _modal_open():
		return          # a mode or a tutor pick is the player's to make
	_auto_tap_for_pending()
	_refresh()


## The largest EXTRA GENERIC the pending cast could find from untapped
## sources — [method _open_x_dialog]'s own budget loop, asked of potential
## mana instead of the floating pool.
func _auto_x_budget() -> int:
	var cost: ManaCost = _pending_card.data.cost
	var surcharge := game.spell_surcharge(_pending_pid, _pending_card.data)
	var usage: Array = game.mana_usage_keys(_pending_card.data)
	if _pending_ability_index >= 0:
		cost = _pending_card.cur_activated_abilities[_pending_ability_index].cost
		surcharge = 0        # surcharges are a SPELL tax (Gloom et al.)
		usage = []
	var src := ManaPlanner.sources(game, _pending_pid, _no_auto_tap)
	var budget := 0
	# 40 is the same kind of safety net the advance driver carries: no
	# board in this pool makes more mana than that in one step.
	while budget < 40 and not ManaPlanner.plan_from(
			src, cost, surcharge + budget + 1, usage).is_empty():
		budget += 1
	return budget


## Tap what the pending cast costs and submit it. The plan is built against
## the payment the ENGINE will demand ([method MtgGame.spell_payment] /
## [method MtgGame.ability_payment]), so it cannot ask for the wrong
## colours or the wrong total.
##
## A plan that comes up short leaves the cast in [constant Mode.PAYING]
## with whatever it did produce floating, and the player finishes it by
## hand — which is the same place a single click leaves them, so the
## gesture can never cost them the cast.
func _auto_tap_for_pending() -> void:
	if _pending_card == null:
		return
	var payment: Dictionary
	if _pending_ability_index < 0:
		payment = game.spell_payment(_pending_pid, _pending_card.data,
			_pending_x, maxi(_flatten_pending_targets().size(), 1))
	else:
		payment = game.ability_payment(_pending_pid, _pending_card,
			_pending_ability_index, _pending_x)
	var tap_plan := ManaPlanner.plan(game, _pending_pid, payment["cost"],
		int(payment["extra"]), payment["usage"], _no_auto_tap)
	ManaPlanner.run_plan(game, _pending_pid, tap_plan)
	# Targets still to pick? Then the mana is all this gesture owed and the
	# targeting loop takes over ("If the spell is a targeted one, you need
	# to choose a target"). Otherwise finish the cast.
	if mode == Mode.PAYING or _pending_slot >= _pending_slots.size():
		_submit_pending()


## The pool moved while a cast is waiting on it: try the cast again. Called
## from [method _refresh], which is where every mana source's `tap_for_mana`
## lands (through `state_changed`), so it does not matter WHICH door the
## mana came through — a land click, the ability menu, a mana ability with
## a colour choice.
func _retry_payment() -> void:
	if mode != Mode.PAYING or _pending_card == null:
		return
	var now: int = game.players[_pending_pid].mana_pool.total()
	if now == _paying_pool:
		return
	_paying_pool = now
	_submit_pending()


## The ONE spell a counter can only be aimed at, or null (§3.3).
##
## s30's `autoCounterTarget` (`duel.go:2006-2041`, pinned by
## `duel_counter_target_test.go`): *"the single valid target for a spell
## that targets a spell on the stack (e.g. Counterspell) when the opponent
## has exactly one such spell there. This spares the player from manually
## picking the only sensible target when countering a lone opposing
## spell."* With two or more, targeting opens normally.
##
## THREE CONDITIONS, all s30's, and each one is load-bearing:
##  1. the slot's kind is [constant TargetSpec.Kind.SPELL] — s30 gates on
##     `*mage.SpellOnStackTarget` and nothing else. It is NOT generalised
##     to "any slot with one legal target": a Terror aimed at the board's
##     only creature would then fire without the player ever seeing the
##     targeting cursor, and there is no undo after a cast. The chain is
##     the one zone where the target is already named on screen, in its own
##     window, which is why it is safe to skip the aiming step there.
##  2. the slot wants exactly one — a divided or any-number slot has a
##     count to choose even with one candidate.
##  3. the OPPONENT controls exactly one legal chain object. s30 skips
##     everything else (`item.Controller != oppName` is a `continue`), so
##     your OWN spells are neither counted nor eligible: countering your
##     own is legal — Counterspell says "target spell", not "target spell
##     an opponent controls" — but it is never what "the only sensible
##     target" means, and a shortcut that guessed it would be countering
##     the player's own play for them.
##
## [constant TargetSpec.Kind.SPELL_OR_PERMANENT] — the Laces — is left out
## for the same reason as (1): its candidates are mostly on the
## battlefield, so "the only one" is not a chain object at all.
func _lone_counter_target(slot: Dictionary) -> TargetRef:
	var spec: TargetSpec = slot["spec"]
	if spec.kind != TargetSpec.Kind.SPELL:
		return null
	if int(slot["min"]) != 1 or int(slot["max"]) != 1:
		return null
	if int(slot["divided"]) > 0:
		return null
	var foe := game.opponent_of(_pending_pid)
	var only: TargetRef = null
	for item in game.stack:
		if item.controller != foe:
			continue
		var ref := TargetRef.card(item.card)
		if not spec.is_legal(game, ref, _pending_card):
			continue
		if only != null:
			return null   # two or more: the player chooses
		only = ref
	return only


func _try_take_target(ref: TargetRef) -> void:
	if _pending_slot >= _pending_slots.size():
		return
	var slot: Dictionary = _pending_slots[_pending_slot]
	var spec: TargetSpec = slot["spec"]
	var why := spec.refusal_reason(game, ref, _pending_card)
	if why != "":
		# @PROMPT_ILLEGALTARGET, UIStrings.txt:1145 — "Illegal target."
		# and "Illegal target (%s)." with the reason in the brackets, and
		# the reason is one of `@PROMPT_ILLEGALTARGETWHY`'s 29 words
		# ([constant TargetSpec.WHY], §6.10). It used to be the spec's own
		# DESCRIPTION, i.e. the requirement — but the requirement is the
		# sentence the player is already reading in the prompt above
		# ("Select target creature."), so repeating it told them nothing.
		# The original puts what is WRONG in the brackets instead.
		_set_prompt("Illegal target (%s)." % why)
		return
	# ALREADY PICKED → TAKE IT BACK (§3.1, s30 `selectTarget`
	# `duel.go:2248-2266`, pinned by its `duel_targeting_test.go:20-91`).
	# This used to refuse the click with @CUECARD_SMALLCARD entry 7's "Is a
	# target, can't target again", which is the right SENTENCE — it is the
	# cue card the original prints under a card that is already a target —
	# but the wrong ACTION: it made a misclick cost the whole cast, on a
	# screen that until now had no Cancel button to recover with either.
	# The cue card belongs on the card (§6.15); the click belongs to the
	# player.
	#
	# s30's other branch — "at a maximum of one, a new click REPLACES the
	# previous choice" — has no counterpart here and needs none:
	# [method _advance_pending] closes a slot the instant its maximum is
	# met, so a one-target slot is never still open to re-click. Replacing
	# only ever mattered because s30 holds every selection open until Done.
	var group: Array = _pending_groups[_pending_slot]
	# A DIVIDED SLOT: one click is one POINT (§6.14). Clicking the same
	# creature twice gives it two damage rather than taking the choice
	# back — `@PYROTECHNICS` is a `Select (2nd of 4)` loop, and the
	# original's loops have no deselect in them (the combat division,
	# §1.4, is the same gesture). Cancel is the way out of a misclick.
	var divided: int = int(slot["divided"])
	if divided > 0:
		for chosen in group:
			# TargetRef.same_object covers the whole union (players, cards
			# and damage packets) — comparing instance_id by hand made two
			# different packets look identical (§6.8).
			if chosen.same_object(ref):
				chosen.amount += 1
				_advance_pending()
				return
		ref.amount = 1
		group.append(ref)
		_advance_pending()
		return
	for i in group.size():
		var chosen2: TargetRef = group[i]
		if chosen2.same_object(ref):
			group.remove_at(i)
			_advance_pending()   # re-prompts with the lower count
			return
	group.append(ref)
	_advance_pending()


## Close a variable-count slot once its minimum is satisfied (the Done
## button doubles as "that's all my targets").
func _finish_target_slot() -> void:
	if _pending_slot >= _pending_slots.size():
		return
	var slot: Dictionary = _pending_slots[_pending_slot]
	# A division has no Done: it submits itself when the last point lands
	# (§6.14), so the button can only say what is still owed.
	var total: int = slot["divided"]
	if total > 0 and _points_dialled(_pending_slot) < total:
		_set_prompt(_divided_prompt(slot, _pending_slot))
		return
	if _pending_groups[_pending_slot].size() < int(slot["min"]):
		_set_prompt("%s needs at least %d target(s)" % [
			_pending_card.data.card_name, slot["min"]])
		return
	_pending_slot += 1
	_advance_pending()


## Flatten the slot groups into the flat ref list the engine takes.
##
## A DIVIDED slot's shares are already on the refs: the player dialled
## them one click at a time through [method _divided_prompt]. This used to
## spread the total as evenly as it would go, and carried a shortcut
## marker saying so; the marker and its `docs/ROADMAP.md` row are both
## gone, and what lifted them was finding the original's own dial —
## `@PYROTECHNICS` (`Program/prompts.txt:698`), §6.14.
func _flatten_pending_targets() -> Array:
	var out: Array = []
	for group in _pending_groups:
		out.append_array(group)
	return out


## How many points of a divided slot's total are dialled in so far.
func _points_dialled(index: int) -> int:
	var spent := 0
	for ref in _pending_groups[index]:
		spent += maxi(ref.amount, 1)
	return spent


## THE DIVIDED-DAMAGE DIAL — `@PYROTECHNICS` (`Program/prompts.txt:698`),
## four entries and every one of them a whole prompt:
##
##     Select (1st of 4) target creature or player.
##     Select (2nd of 4) target creature or player.
##     Select (3rd of 4) target creature or player.
##     Select (4th of 4) target creature or player.
##
## **This is what `docs/duel-todo.md` §6.14 was looking for**, and it is
## not a dialog: *"N damage divided as you choose"* is a CLICK LOOP, one
## click per point, the same gesture as `@PROMPT_RESOLVECOMBAT`'s
## `%d points left` (§1.4). The table hardcodes four because Pyrotechnics
## divides exactly four; the form generalises to any total.
##
## The ordinal is the original's own: literal `1st` / `2nd` / `3rd` / `4th`
## in the string table, so the numbers are spelled the English way rather
## than as `(1 of 4)`.
func _divided_prompt(slot: Dictionary, index: int) -> String:
	var spec: TargetSpec = slot["spec"]
	var total: int = slot["divided"]
	return "Select (%s of %d) %s." % [
		_ordinal(_points_dialled(index) + 1), total, spec.description]


## `1st`, `2nd`, `3rd`, `4th`… — the suffixes `@PYROTECHNICS` writes out.
static func _ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]


## [param cast] says the pending spell was SUBMITTED and accepted: its
## tutor pick, if any, stays parked for the resolution that will ask for
## it. Every other way out of the chain abandons the cast and the pick.
func _clear_pending(cast := false) -> void:
	mode = Mode.NORMAL
	_close_mode_overlay()
	_pending_card = null
	_pending_specs = []
	_pending_slots = []
	_pending_groups = []
	_pending_slot = 0
	_auto_slots = PackedInt32Array()
	_pending_targets = []
	_pending_mode = 0
	_pending_target_count = -1
	_paying_pool = -1
	# A parked-but-uncast tutor pick must not leak into the next search.
	if not cast and _humans.has(_pending_pid):
		_humans[_pending_pid].preselect("")
	_set_target_cursor(false)


## `Input.set_custom_mouse_cursor` is PROCESS-GLOBAL: begin targeting,
## right-click away, Concede → Yes, and the crosshair used to outlive the
## freed screen for the rest of the session (2026-09-02). The screen puts
## the system cursor back on its way out, whichever way it leaves.
func _exit_tree() -> void:
	if _target_cursor_active:
		_set_target_cursor(false)


## Whether the crosshair is the pointer right now — kept so the teardown
## above never touches a cursor some other screen owns.
var _target_cursor_active := false


## Swap in the original 1997 targeting cursor (first 61x61 frame of
## Target.pic) while picking targets; restore the system cursor after.
func _set_target_cursor(active: bool) -> void:
	_target_cursor_active = active
	if not active:
		Input.set_custom_mouse_cursor(null)
		return
	if _target_cursor == null:
		var sheet := GameSkin.texture("target_cursor")
		if sheet == null:
			return
		var frame := sheet.get_image().get_region(
			Rect2i(0, 0, sheet.get_height(), sheet.get_height()))
		_target_cursor = ImageTexture.create_from_image(frame)
	Input.set_custom_mouse_cursor(_target_cursor, Input.CURSOR_ARROW,
		_target_cursor.get_size() / 2.0)


## Targets for casting: aura target or the spell effects' specs — mirrors
## MtgGame._spell_target_specs (kept in sync; the engine re-validates
## everything anyway, this only drives the picker UI).
func _specs_for_cast(inst: CardInstance, chosen_mode: int) -> Array[TargetSpec]:
	if inst.data.is_aura():
		var out: Array[TargetSpec] = [inst.data.aura_target]
		return out
	var effects: Array = inst.data.spell_effects
	if inst.data.is_modal():
		effects = inst.data.modes[chosen_mode]["effects"]
	var specs: Array[TargetSpec] = []
	for e in effects:
		if e.target_spec != null:
			specs.append(e.target_spec)
	return specs


## Build one targeting SLOT per targeting effect of the pending cast,
## reading each effect's own count vocabulary (EffectBase.target_range,
## divided_amount) so "X target creatures" / "one or more" / "divided
## among any number" all drive the same picking loop. Auras keep their
## single enchant target.
func _build_target_slots(data: CardData, chosen_mode: int) -> void:
	_pending_slots = []
	_pending_groups = []
	_pending_slot = 0
	_auto_slots = PackedInt32Array()
	if data.is_aura():
		_pending_slots.append({"spec": data.aura_target, "min": 1, "max": 1,
			"divided": 0})
		_pending_groups.append([])
		return
	var effects: Array = data.spell_effects
	if data.is_modal():
		effects = data.modes[chosen_mode]["effects"]
	var counted := false
	for e in effects:
		if e.target_spec == null:
			continue
		var span: Vector2i = e.target_range(_pending_x)
		# `# Targets:` (§6.14): when the X dialog asked how many, the
		# answer IS the count — the surcharge for those targets is
		# already inside the X the player just dialled, so a different
		# number here would not be the cast they paid for. Only the first
		# variable-count slot takes it; no card in the pool has two.
		if not counted and _pending_target_count > 0 and span.y < 0:
			span = Vector2i(_pending_target_count, _pending_target_count)
			counted = true
		_pending_slots.append({
			"spec": e.target_spec, "min": span.x, "max": span.y,
			"divided": e.divided_amount(_pending_x),
		})
		_pending_groups.append([])


## Slots for an ACTIVATED ability, same vocabulary as a spell's.
## [param x_value] feeds X-based counts (the Candelabra's "Untap X target
## lands"); it is 0 on the first build and the real X once the dialog has
## answered, which is why _on_x_confirmed rebuilds.
func _build_ability_slots(ability: ActivatedAbility, x_value := 0) -> void:
	_pending_slots = []
	_pending_groups = []
	_pending_slot = 0
	for e in ability.effects:
		if e.target_spec == null:
			continue
		var span: Vector2i = e.target_range(x_value)
		_pending_slots.append({
			"spec": e.target_spec, "min": span.x, "max": span.y,
			"divided": e.divided_amount(x_value),
		})
		_pending_groups.append([])


## The SearchLibraryEffect a cast would run (null when none) — the UI opens
## the library picker before such casts (see HumanAgent).
func _search_effect_of(data: CardData, chosen_mode: int) -> SearchLibraryEffect:
	var effects: Array = data.spell_effects
	if data.is_modal():
		effects = data.modes[chosen_mode]["effects"]
	for e in effects:
		if e is SearchLibraryEffect:
			return e
	return null


# ---------------------------------------------------- modal & tutor popups --

## The modal-choice dialog exactly as the reference's Primal Clay screen:
## the ENLARGED CARD on the left, the modes as clickable lines on the
## original Winbk_Bigcard dark panel — now framed and lettered by
## OriginalDialog, so it wears the same bevel, the same rules and the
## same voice as every other popup in the duel.
##
## The header is the 1997 one: `@PROMPT_NEWFULLCARD` (UIStrings.txt:1114)
## is "%s selects:" — the original announces WHO is choosing, then lists
## the choices (Primal Clay's own lines are "Creature type? / 1/6 Wall. /
## 2/2 Creature with flying. / 3/3 Creature.", prompts.txt:670).
func _open_mode_menu(inst: CardInstance) -> void:
	_close_mode_overlay()
	var dialog := OriginalDialog.create("", Vector2(552, 402),
		"big_card_panel")
	_mode_overlay = dialog
	# The enlarged card, left — inside the panel's own bevel.
	var face := CardPreview.new()
	face.scale = Vector2(0.9, 0.9)
	face.position = Vector2(18, 12)
	face.show_card(inst)
	dialog.add_child(face)
	# The choice lines, right.
	var lines := VBoxContainer.new()
	lines.position = Vector2(300, 40)
	lines.custom_minimum_size = Vector2(235, 0)
	lines.add_theme_constant_override("separation", 8)
	var ask := OriginalDialog.label("You select:" if _is_human(inst.controller_id)
		else "%s selects:" % game.players[inst.controller_id].player_name,
		16, true)
	lines.add_child(ask)
	var name_line := OriginalDialog.label(inst.data.card_name, 14)
	name_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(name_line)
	for i in inst.data.modes.size():
		var opt := OriginalDialog.choice_line(inst.data.modes[i]["label"])
		opt.pressed.connect(_on_mode_chosen.bind(i))
		lines.add_child(opt)
	# Cancel goes in the LIST COLUMN, not the dialog's foot: the enlarged
	# card fills the bottom-left of this window, and a centred foot row
	# would be drawn behind it.
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	lines.add_child(gap)
	var back := OriginalDialog.button("Cancel", Vector2(96, 26))
	# SHRINK_BEGIN or the column stretches the button to its full width,
	# which no 1997 dialog does.
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_on_mode_canceled)
	lines.add_child(back)
	dialog.add_child(lines)
	add_child(dialog)


func _on_mode_canceled() -> void:
	_close_mode_overlay()
	_on_cancel()


func _close_mode_overlay() -> void:
	if _mode_overlay != null:
		_mode_overlay.queue_free()
		_mode_overlay = null


func _on_mode_chosen(id: int) -> void:
	_close_mode_overlay()
	if _pending_card == null:
		return
	_pending_mode = id
	_pending_specs = _specs_for_cast(_pending_card, id)
	_build_target_slots(_pending_card.data, id)
	_continue_cast_chain()


## The LIBRARY PICKER (tutors). The original asks for one in three words —
## "Select target card." is the whole of `@DEMONIC_TUTOR` and `@REGROWTH`
## in prompts.txt:246,742 — so the dialog says that, names the card that
## is asking above it, and offers `@DIALOGBUTTONS`' OK and Cancel.
## Winbk_Changetext's blue knotwork is the original's ground for a dialog
## that asks the player to pick from a LIST, which is exactly this one.
func _open_search_dialog(search: SearchLibraryEffect) -> void:
	if _search_dialog != null:
		_search_dialog.queue_free()
	_search_dialog = OriginalDialog.create(
		_pending_card.data.card_name, Vector2(392, 452), "panel_knot")
	_search_dialog.body().add_child(
		OriginalDialog.label("Select target card.", 15))
	# The effect's own English narrows the ask ("a basic land card") — but
	# only when it says more than the line above already does.
	if search.description != "" and search.description != "a card":
		var hint := OriginalDialog.label(search.description, 13)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_search_dialog.body().add_child(hint)
	_search_list = ItemList.new()
	_search_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_search_list.add_theme_stylebox_override("panel",
		OriginalDialog.panel_style("panel_dark_stone", 4.0))
	_search_list.add_theme_color_override("font_color", OriginalDialog.CHOICE)
	_search_list.add_theme_color_override("font_selected_color",
		OriginalDialog.CHOICE_LIT)
	var seen := {}   # one row per NAME — duplicates add nothing to a tutor
	for inst in game.players[_pending_pid].library:
		if search.filter.is_valid() and not search.filter.call(inst):
			continue
		if seen.has(inst.data.card_name):
			continue
		seen[inst.data.card_name] = true
		_search_list.add_item(inst.data.card_name)
	_search_dialog.body().add_child(_search_list)
	_search_dialog.add_button("OK").pressed.connect(_on_search_confirmed)
	_search_dialog.add_button("Cancel").pressed.connect(_on_search_canceled)
	add_child(_search_dialog)


func _close_search_dialog() -> void:
	if _search_dialog != null:
		_search_dialog.dismiss()
		_search_dialog = null


func _on_search_canceled() -> void:
	_close_search_dialog()
	_on_cancel()


func _on_search_confirmed() -> void:
	var picked := _search_list.get_selected_items()
	var chosen := "" if picked.is_empty() \
		else _search_list.get_item_text(picked[0])
	_close_search_dialog()
	if _pending_card == null:
		return
	if chosen != "" and _humans.has(_pending_pid):
		_humans[_pending_pid].preselect(chosen)
	# No selection = deliberate "fail to find" — legal for searches.
	_continue_cast_chain()


# ----------------------------------------------------------------- combat --

func _toggle_attacker(inst: CardInstance) -> void:
	if inst.controller_id != game.active_player or not inst.is_creature():
		return
	if _selected_attackers.has(inst.id):
		# Taking an attacker back. The 1997 game did NOT allow this
		# (manual p.86) — it is a rules fork, revocable by default and
		# switchable in Options (RulesOptions.attackers_revocable).
		if not game.rules.attackers_revocable:
			_set_prompt("%s is already attacking — attackers are final."
				% inst.data.card_name)
			return
		_selected_attackers.erase(inst.id)
	else:
		var why := CombatState.attack_illegality(game, inst, game.opponent_of(game.active_player))
		if why != "":
			# @PROMPT_MAIN entry 6, UIStrings.txt:1063 — the original says
			# "Illegal attacker." and stops; we keep the engine's reason
			# after it, because our refusals are the player's only clue.
			_set_prompt("Illegal attacker. %s" % why)
			return
		_selected_attackers.append(inst.id)
	_refresh()


## THE BLOCK GESTURE: click your creature to pick it up, click an attacker
## to set it against that one. Unchanged for the ordinary creature, which
## may block exactly one attacker and is therefore put down again the
## moment it is assigned.
##
## WHAT ONE-TO-MANY BLOCKS ADDED (CR 509.1b, 2026-09-02): a creature an
## effect lets block more than one — Two-Headed Giant of Foriys, anything
## under Blaze of Glory — STAYS in the hand after an assignment, so the
## next attacker clicked is its second block and no re-pick is needed.
## Clicking the creature you are holding puts it down and takes back every
## block it had, which is the same take-back gesture as before and the only
## way to undo a multi-block.
##
## THE HALF-MADE BLOCK (the playtest defect of 2026-09-04 — see
## docs/ROADMAP.md, "THE BLOCK THAT WAS NEVER DECLARED"). A creature that
## has been PICKED UP but never pointed at an attacker stands in the
## Combat window's shield lane ([method _combat_lineup]) looking exactly
## like a blocker, and this method used to lift ANY creature there and say
## nothing about it — no "which attacker?", no word when the next click
## missed. So a gesture that ended one click early read on screen as a
## completed block, and Done then declared no blockers at all. The three
## sentences the original speaks here are `@PROMPT_DEFENDWHOM`
## (`Program/UIStrings.txt:993`) — *"Block which attacker?"*, *"Illegal
## block."*, *"That isn't an attacker."* — and all three are now said.
func _pick_block(inst: CardInstance) -> void:
	var defender := game.opponent_of(game.active_player)
	if inst.controller_id == defender and inst.is_creature():
		if _selected_blocker == inst.id or _blocks_left_for(inst) <= 0:
			# Holding it already, or it is full: the click means "put it
			# back", blocks and all.
			_block_map.erase(inst.id)
			_selected_blocker = -1
			# @PROMPT_MAIN entry 8: back to the standing question.
			_set_prompt("Combat phase: Choose blockers.")
		else:
			# A CREATURE THAT CAN BLOCK NOTHING IS NOT LIFTED. It would
			# otherwise leave its territory for the shield lane and stand
			# there as a blocker that every attacker click refuses — which
			# is what a tapped Giant Spider did. The rule is the engine's
			# own (CombatState.block_illegality); only the moment it is
			# asked is new. Nothing already pencilled in is touched, so
			# the take-back gesture above is still reachable for a
			# multi-blocker that has run out of legal targets.
			if not _block_map.has(inst.id):
				var cannot := _cannot_block_anything(inst)
				if cannot != "":
					_set_prompt("Illegal block. %s" % cannot)
					return
			_selected_blocker = inst.id
			# @PROMPT_DEFENDWHOM entry 1 / @PROMPT_CHOOSEBLOCKERS entry 2,
			# UIStrings.txt:995 and :1142 — the question the original asks
			# from the moment a blocker is in hand until it is aimed.
			_set_prompt("Block which attacker?")
		_refresh()
	elif _selected_blocker != -1:
		if not game.combat.attackers.has(inst.id):
			# @PROMPT_DEFENDWHOM entry 3, UIStrings.txt:997 — verbatim.
			_set_prompt("That isn't an attacker.")
			return
		var blocker := game.find_instance(_selected_blocker)
		if blocker == null or blocker.zone != Mtg.Zone.BATTLEFIELD:
			# The creature in hand left the battlefield between the two
			# clicks (a trigger, a sacrifice): there is nothing to point.
			_block_map.erase(_selected_blocker)
			_selected_blocker = -1
			_set_prompt("Combat phase: Choose blockers.")
			_refresh()
			return
		var against: Array = (_block_map.get(_selected_blocker, []) as Array)
		if against.has(inst.id):
			return   # already set against that attacker
		if _blocks_left_for(blocker) <= 0:
			_set_prompt("Illegal block. %s can block only %d attacker(s)"
				% [blocker.data.card_name, game.blocks_allowed(blocker)])
			return
		var why := CombatState.block_illegality(game, blocker, inst, defender)
		if why != "":
			# @PROMPT_DEFENDWHOM / @PROMPT_CHOOSEBLOCKERS, UIStrings.txt:993
			# and :1139 — "Illegal block.", plus the engine's reason.
			_set_prompt("Illegal block. %s" % why)
			return
		against = against.duplicate()
		against.append(inst.id)
		_block_map[_selected_blocker] = against
		# Keep holding it while it can still take another (the whole point
		# of the two cards); put it down when it is full.
		if _blocks_left_for(blocker) <= 0:
			_selected_blocker = -1
			_set_prompt("Combat phase: Choose blockers.")
		_refresh()
	# An attacker clicked with NOTHING in hand needs no sentence of its own:
	# the bar is already standing on @PROMPT_MAIN entry 8, "Combat phase:
	# Choose blockers.", which is the instruction — and writing it again
	# here would rub out a refusal the previous click had just put up.


## Why [param blocker] can block NONE of the declared attackers, or "" when
## it can block at least one it is not already set against. The reason is
## the first attacker's, which for the case that matters — a tapped
## creature — is the same for all of them ("tapped creatures can't block").
func _cannot_block_anything(blocker: CardInstance) -> String:
	var defender := game.opponent_of(game.active_player)
	var first := ""
	var already: Array = (_block_map.get(blocker.id, []) as Array)
	for attacker_id in game.combat.attackers:
		if already.has(int(attacker_id)):
			continue
		var attacker := game.find_instance(int(attacker_id))
		if attacker == null:
			continue
		var why := CombatState.block_illegality(game, blocker, attacker, defender)
		if why == "":
			return ""
		if first == "":
			first = why
	return first


## How many MORE attackers [param blocker] may be set against, given what
## the screen has already pencilled in. The rule itself is
## [method MtgGame.blocks_allowed] — this is only the subtraction.
func _blocks_left_for(blocker: CardInstance) -> int:
	if blocker == null:
		return 0
	var allowed := game.blocks_allowed(blocker)
	var taken: int = (_block_map.get(blocker.id, []) as Array).size()
	if allowed < 0:
		return 99      # "any number"
	return allowed - taken


func _on_confirm() -> void:
	match mode:
		Mode.ATTACKERS:
			var err := game.declare_attackers(game.active_player, _selected_attackers)
			if err == "":
				_selected_attackers = []
				mode = Mode.NORMAL
			_report(err)
		Mode.BLOCKERS:
			# A BLOCKER STILL IN HAND IS AN UNANSWERED QUESTION, and Done
			# must not answer it by throwing the creature away. It is
			# standing in the Combat window's shield lane
			# ([method _combat_lineup]) and the bar is asking "Block which
			# attacker?"; declaring here would submit a block the player
			# can see and the engine never got — the 2026-09-04 playtest
			# defect, where a Giant Spider stood opposite a Mahamoti Djinn
			# and the Djinn arrived unblocked. So the first Done puts the
			# creature DOWN (keeping every block already made) and says
			# so, and the second declares. One extra click, and never a
			# lost block; refusing outright instead would wedge a
			# multi-blocker that has no second attacker to take.
			if _selected_blocker != -1:
				var held := game.find_instance(_selected_blocker)
				_selected_blocker = -1
				_refresh()
				_report("%s is not blocking. Press Done again to declare." % (
					held.data.card_name if held != null else "That creature"))
				return
			var err := game.declare_blockers(
				game.opponent_of(game.active_player), _block_map)
			if err == "":
				_block_map = {}
				_selected_blocker = -1
				mode = Mode.NORMAL
			_report(err)
	_refresh()


func _on_cancel() -> void:
	# A pending cast that has not reached its targets yet — the mode
	# menu, the tutor picker or the X question is still on screen — is
	# still a pending cast, and backing out of any of those must drop it.
	# It used to survive, because this only cleared in TARGETING and none
	# of those three rungs has entered TARGETING yet: `_pending_card`,
	# `_pending_pid` and a parked tutor pre-selection all leaked into
	# whatever the player did next. Found while building §6.14.
	if mode == Mode.NORMAL and _pending_card != null:
		_clear_pending()
		_set_prompt("")
		_refresh()
		return
	match mode:
		Mode.TARGETING, Mode.PAYING:
			# *"Cancel is a convenient way to cancel a spell or effect"*
			# (`Duel.hlp`, topic **Territory**). Mana already drawn STAYS
			# in the pool — the original's does too, and it empties at the
			# end of the step (CR 500.4) with a burn if the ruleset has
			# one.
			_clear_pending()
			_set_prompt("")
		Mode.ATTACKERS:
			# NOT UNDER THE 1997 ANSWER. `attackers_revocable = false`
			# (manual p.86) makes a named attacker final, and clearing the
			# whole selection is a bigger take-back than the single one
			# [method _toggle_attacker] already refuses — so Escape used to
			# walk straight through the fork that method guards (found by
			# the fifth-edition audit, 2026-09-02). [method _can_cancel]
			# now keeps the key and the Situation Bar's button off it; this
			# is the guard for every OTHER door into this method.
			if game.rules.attackers_revocable:
				_selected_attackers = []
		Mode.BLOCKERS:
			# Blockers are not forked: manual p.86 is about the ATTACK
			# declaration, and a half-made block is still cancellable under
			# either ruleset.
			_block_map = {}
			_selected_blocker = -1
	_refresh()


# ------------------------------------------- THE CANCEL LADDER (§3.2, §6.11) --
#
# `Duel.hlp`, **Situation Bar**: *"At the rightmost end of this bar is a
# **Done** button, a **Cancel** button, or both, depending on the
# situation. Clicking either is the same as selecting the option of the
# same name from the mini-menu. You can also use the keyboard in place of
# the buttons on the Situation Bar: [Esc] is just like Cancel · Return has
# the same effect as Done · Spacebar: if there is only one button, pressing
# this is the same as clicking that button."*
#
# The Manalink source states the same contract as a bit spec: `allow_cancel`
# (`shandalar-src/src/defs.h:2390`) is two bits — 0 no buttons, 1 Cancel, 2
# Done, 3 both. WHICH BUTTONS APPEAR IS A PROPERTY OF THE PROMPT.
#
# `Duel.hlp`, **Territory**, says what Cancel is FOR: *"**Cancel** is a
# convenient way to cancel a spell or effect. You can sometimes use the
# Cancel button on the Situation Bar for the same effect."* — so the key,
# the bar button and the (not yet built) territory menu entry are three
# doors onto one action, which is why they all come through here.


## Is a centre popup or the graveyard view holding the screen? Those own
## the keyboard while they are up: their own OK/Cancel answer them, and the
## bar's keys must not reach past them into the duel (Return used to
## fast-forward several priority windows with the X question still open).
func _modal_open() -> bool:
	return graveyard_is_open() or _mode_overlay != null \
		or _search_dialog != null or _x_dialog != null \
		or _choice_overlay != null or is_paused()


## Is there anything to cancel? Drives BOTH the Escape key and whether the
## Situation Bar shows its Cancel button, so the two can never disagree —
## which is the whole of *"Esc is just like Cancel"*.
##
## s30's `canCancel` (`duel.go:1352-1354`) is the graveyard view, the two
## choosers and targeting. Ours adds the declarations, because ours are
## revocable up to Done (`RulesOptions.attackers_revocable`) and a half-made
## declaration is exactly the *"situation"* the help file makes the button
## conditional on.
func _can_cancel() -> bool:
	# The one popup with NO way out: a question the engine has stopped a
	# resolution for must be ANSWERED (§1.3). `@PROMPT_PAYUPKEEP` has two
	# entries and neither of them is Cancel; the original's upkeep prompt
	# offers "Don't pay Upkeep.", not an escape. A COST question is the
	# exception — nothing has been paid yet, so the action it belongs to
	# can be withdrawn (see _choice_withdrawable).
	if _choice_overlay != null:
		return _choice_withdrawable()
	# The Pause window is not a rung of the cancel ladder: Esc closes it
	# ([method _unhandled_key_input]) but the bar must not grow a Cancel
	# button behind the scrim, and Space must stay dead under it. It IS a
	# modal for every other purpose, which is why this reads it out again
	# rather than leaving it out of [method _modal_open].
	if is_paused():
		return false
	if _modal_open():
		return true
	if mode == Mode.TARGETING or mode == Mode.PAYING:
		return true
	if mode == Mode.ATTACKERS:
		# ...and only while they can be TAKEN BACK. The sentence above
		# already made that the reason ("because ours are revocable up to
		# Done"); until the fifth-edition audit (2026-09-02) the code did
		# not read the flag it names, so under the 1997 answer the bar
		# offered a Cancel button that un-declared every attacker at once.
		return game.rules.attackers_revocable \
			and not _selected_attackers.is_empty()
	if mode == Mode.BLOCKERS:
		return not _block_map.is_empty() or _selected_blocker != -1
	return false


## How much the Situation Bar's Done button brightens when it is the thing
## to click. s30 draws a 2px yellow stroke around the button instead
## (`duel.go:3122-3138`, gated on `humanHasPriority`); we lighten the
## button's own 1997 stone rather than ring it, because the bar button is
## a nine-patch of `Statbutt` art and a stroke over it reads as a second
## border on a control that already has one.
const DONE_LIT := Color(1.25, 1.25, 1.1)


## Is Done the thing to click right now? (§3.7)
##
## The COMPANION of [method _can_cancel], and written the same way for the
## same reason: `Duel.hlp`, topic **Situation Bar**, makes both buttons
## conditional in one sentence — *"At the rightmost end of this bar is a
## **Done** button, a **Cancel** button, or both, depending on the
## situation."* Manalink states it as a bit spec (`allow_cancel`,
## `shandalar-src/src/defs.h:2390`: 0 none, 1 Cancel, 2 Done, 3 both), so
## the two predicates here ARE those two bits.
##
## We keep Done on the bar at all times and light it instead of showing and
## hiding it, because the button is also the duel's only Pass control and a
## control that vanishes is worse to aim at than one that dims. The CUE is
## therefore what changes, which is s30's answer too: it outlines Done
## whenever `humanHasPriority()` — *any* option at all — rather than only
## during the declarations, which is all we lit before this item.
##
## The four cases, in the order [method _on_done] handles them:
##  - TARGETING: only for a slot Done can actually CLOSE, i.e. a variable
##    slot (`max` -1 or above its `min`) whose minimum is already met. On a
##    fixed one-target slot Done has nothing to do and stays dark — the old
##    code excluded targeting wholesale for exactly that reason, and this
##    keeps the honest half of it.
##  - the declarations, the discard and the damage division: always, they
##    exist to be confirmed.
##  - NORMAL: whenever the human holds priority.
## A modal that owns the keyboard (the X question, the tutor picker, the
## mode menu, the graveyard view, the held-open choice) answers with its
## OWN buttons, so Done applies to none of them.
func _done_applies() -> bool:
	if game == null or game.game_over:
		return false
	if _modal_open():
		return false
	match mode:
		Mode.TARGETING:
			if _pending_slot >= _pending_slots.size():
				return false
			var slot: Dictionary = _pending_slots[_pending_slot]
			var want_max: int = slot["max"]
			var want_min: int = slot["min"]
			# A DIVIDED slot is a click loop that submits itself on the
			# last point (§6.14, `@PYROTECHNICS`), so Done is never the
			# way out of one and must not offer to be.
			if int(slot["divided"]) > 0:
				return false
			if want_max >= 0 and want_max <= want_min:
				return false   # a fixed slot closes itself
			return _pending_groups[_pending_slot].size() >= want_min
		Mode.ATTACKERS, Mode.BLOCKERS, Mode.DISCARD, Mode.DAMAGE:
			return true
		Mode.PAYING:
			# The bar shows Cancel here and nothing else: the only way on
			# is mana, and the only way out is dropping the cast. Passing
			# priority with a half-built cast hanging is exactly what the
			# 2026-09-02 guard closed for the X dialog.
			return false
	return _is_human(game.priority_player)


## Escape: PEEL EXACTLY ONE LAYER, never the whole cast (§3.2).
##
## s30's `handleEscape` (`duel.go:1329-1350`) in its own order — graveyard
## view, ability chooser, X chooser, *clear the chosen targets only*, then
## leave targeting — with our two extra popups slotted in where they sit in
## the cast chain (`_click_hand_card`: mode → library pick → X → targets),
## so Escape unwinds that chain in the reverse of the order it was built.
##
## The ability menu needs no rung: it is a real [PopupMenu] and Godot
## closes it on Escape before this handler ever runs.
##
## With nothing open, Escape does NOTHING — it never leaves the duel. The
## original has no "quit" on that key either; leaving is Concede
## (`docs/duel-todo.md` §6.3), and it asks first.
func _on_escape() -> void:
	if _choice_overlay != null:
		if _choice_withdrawable():
			_withdraw_choice()
		return   # otherwise answer it (see _can_cancel)
	if graveyard_is_open():
		_close_graveyard()
		return
	if _mode_overlay != null:
		_on_mode_canceled()
		return
	if _search_dialog != null:
		_on_search_canceled()
		return
	if _x_dialog != null:
		_on_x_canceled()
		return
	# The rung that was missing: with targets already picked, Escape drops
	# THE PICKS and leaves you aiming. Only the next press abandons the
	# spell. Ours used to throw away the whole pending cast on the first
	# press, which is what made a mis-aimed Fireball unrecoverable.
	if mode == Mode.TARGETING and _clear_picked_targets():
		return
	_on_cancel()


## Drop every target picked for the pending cast and go back to the first
## slot. Returns false when there was nothing picked, so [method _on_escape]
## falls through to the next rung.
func _clear_picked_targets() -> bool:
	# Only the PLAYER'S picks count: a slot the chain filled by itself
	# (the lone counter target, the single damage marker) is filled again
	# the moment _advance_pending re-runs, so counting it here made this
	# rung true forever and Escape could never reach _on_cancel for a
	# spell whose first slot auto-fills (2026-09-02).
	var had_any := false
	for i in _pending_groups.size():
		if not _pending_groups[i].is_empty() and not _auto_slots.has(i):
			had_any = true
	if not had_any:
		return false
	for group in _pending_groups:
		group.clear()
	_auto_slots = PackedInt32Array()
	_pending_slot = 0
	_advance_pending()   # re-prompts from the top of the chain
	return true


## Which AI seat (if any) is the game waiting on right now? -1 = none.
func _ai_seat_to_act() -> int:
	if _ais.is_empty() or game.game_over:
		return -1
	# The turn machine is HELD OPEN for a decision that is not an AI's to
	# make (§1.1, §1.4): every engine action is refused until it arrives, so
	# scheduling the AI here would only spin its pacing timer.
	if game.awaiting_discard or game.awaiting_damage_assignment \
			or game.awaiting_choice != null:
		return -1
	var deciding: int
	if game.awaiting_attackers:
		deciding = game.active_player
	elif game.awaiting_blockers:
		deciding = game.opponent_of(game.active_player)
	else:
		deciding = game.priority_player
	return deciding if _ais.has(deciding) else -1


# --------------------------------------------- PER-EVENT DWELL (§2.6) --
#
# s30 gives every game MESSAGE a minimum time on screen before the next one
# is allowed to replace it (`duel.go:497-514`, `555-574`, and the diff
# detectors at `:576-611`), because a run of AI actions at one flat delay
# reads as a flicker rather than as a turn:
#
#     phaseDisplayDelay = 100ms   // normally
#     enemyPhaseDelay   = 300ms   // the active player is not you
#     lifeChangeDelay   = 600ms   // either life changed, any permanent's
#                                 // marked damage changed, or a new log
#                                 // line matches " deals " + " damage to "
#
# WE HAVE NO MESSAGE QUEUE, so the thing that waits is the one wait we
# already had: the AI's own pacing timer. [member DuelConfig.pace] keeps
# meaning exactly what it meant — the ordinary gap between AI actions —
# and it maps onto s30's MIDDLE tier, because an AI action is by
# definition the opponent acting. The other two are its multiples, in
# s30's own ratios (100/300 and 600/300).
#
# WHAT THIS DOES NOT DO: add a single wait a headless run did not have.
# The only timer in this file is still the one below; everything else here
# is arithmetic over state the screen already reads.
const DWELL_QUIET := 1.0 / 3.0    ## s30 100ms — the active player is YOU
const DWELL_ENEMY := 1.0          ## s30 300ms — the opponent's turn
const DWELL_EVENT := 2.0          ## s30 600ms — life or damage moved

## The board figures the last AI action left behind — s30's `prev.State`,
## which is what its detectors diff against.
var _pace_life: Array[int] = [0, 0]
var _pace_damage: Dictionary = {}


## How long the state now on screen should stand, as a multiple of
## [member DuelConfig.pace]. Pure, so the three tiers can be pinned
## without running a duel.
##
## [param active_is_yours] is s30's `cur.State.ActivePlayer ==
## cur.State.You.Name`. A DEMO has no "you", so every turn is somebody
## else's and every gap is the enemy tier — which is exactly the 0.8s
## `DuelConfig.demo_default` has always meant.
static func dwell_multiplier(active_is_yours: bool, stirred: bool) -> float:
	if stirred:
		return DWELL_EVENT
	return DWELL_QUIET if active_is_yours else DWELL_ENEMY


## Did life or marked damage move since the last AI action? s30's
## `phaseDelay` asks three questions — either life total, any permanent's
## marked damage, and a log line reading "X deals N damage to Y" — and the
## third is a consequence of the first two, so two diffs answer all three.
## Re-snapshots as it goes, which is what makes it the "since last time".
func _board_stirred() -> bool:
	var life: Array[int] = [game.players[0].life, game.players[1].life]
	var marked: Dictionary = {}
	for pid in 2:
		for inst in game.players[pid].battlefield:
			marked[inst.id] = inst.damage
	var stirred := life != _pace_life
	if not stirred:
		# Per PERMANENT, not a total: one creature healing while another
		# takes a wound is two events, and a sum would cancel them out.
		# s30 builds the same id→damage map (`permanentDamageByID`), and
		# like s30 a permanent that has LEFT the battlefield is not a
		# change — it is gone, and its death had its own dwell.
		for id in marked:
			if _pace_damage.has(id) and int(_pace_damage[id]) != int(marked[id]):
				stirred = true
				break
	_pace_life = life
	_pace_damage = marked
	return stirred


## Reset the dwell's memory to the board as it stands — called once the
## duel is set up, so the first AI action is not spuriously "eventful".
func _reset_pacing() -> void:
	_pace_life = [game.players[0].life, game.players[1].life]
	_pace_damage = {}


func _maybe_schedule_ai() -> void:
	# PAUSE MEANS PAUSE (see [DuelPause]): no new dwell is armed while the
	# window is up, and [method _ai_step] refuses an already-armed one, so
	# a player who walks away does not come back to three lost turns.
	if _ai_pending or _toss_active or is_paused() or _ai_seat_to_act() == -1:
		return
	_ai_pending = true
	var mine := _humans.has(game.active_player)
	var wait: float = config.pace \
		* dwell_multiplier(mine, _board_stirred())
	get_tree().create_timer(wait).timeout.connect(
		_ai_step, CONNECT_ONE_SHOT)


func _ai_step() -> void:
	_ai_pending = false
	# The dwell this timer belongs to was armed before the Pause window
	# opened. Drop it on the floor: [method _close_pause] refreshes, and
	# that arms a fresh one.
	if is_paused():
		return
	var pid := _ai_seat_to_act()
	if pid != -1:
		_ais[pid].act(game)
	_refresh()   # act() already refreshed via signals; this reschedules


func _on_pass() -> void:
	if mode == Mode.NORMAL and _is_human(game.priority_player):
		# A mid-resolution question no longer needs catching here: the ENGINE
		# holds the resolution open (MtgGame.awaiting_choice) whatever drove
		# the pass, so the overlay comes up from _refresh instead (§1.3).
		_report(game.pass_priority(game.priority_player))
		_refresh()


# ============================ THE CHOICE OVERLAY — every question (§1.3) --
#
# The engine is synchronous: when Junún Efreet's upkeep trigger resolves it
# asks "Pay {B}{B} to keep Junún Efreet?" and needs the answer inside that
# call, so no dialog can open in the middle of it. The engine's answer is a
# PRE-FLIGHT (MtgGame._preflight): it resolves the item once over a
# GameSnapshot to find out what it asks, rewinds, and HOLDS the resolution
# open on MtgGame.awaiting_choice. This is where that question is answered.
#
# One overlay serves all four kinds, which is s30's design
# (`duel.go:2596-2762` — handleChoiceRequest / initChoiceUI /
# respondToChoice / drawChoiceUI): dim the board, put the REASON at the top,
# show the reason's CARD, and list the options as `"%d. %s"` lines answerable
# by the number keys 1-9. Ours wears the 1997 window that already asks this
# kind of question — the Primal Clay modal screen, enlarged card left and
# choice lines right (`prompts.txt:670`) — because the original had no
# generic chooser of its own and that is the closest thing it had.
#
# The WORDS are the original's, per kind:
# - YES_NO   `Yes` / `No` (`@CYCLONE`, promptsX1.txt:88-90), except an upkeep
#            cost, which has its own pair (`@PROMPT_PAYUPKEEP`).
# - COLOR    `Select a color.` (`@ALCHORS_TOMB`, promptsX2.txt:11) over
#            `White` / `Blue` / `Black` / `Red` / `Green` (UIStrings.txt:610).
# - CARD     the candidates by name, and `Cancel.` (prompts.txt:949) only
#            where declining is legal — a search may fail to find.
# - DISCARD  `Select card to discard.` (`@PROMPT_DISCARDACARD` entry 1,
#            UIStrings.txt:1106), one click per card until the count is met.

var _choice_overlay: Control = null
## DISCARD questions take several clicks: the option INDICES picked so far.
## Indices, not names, because a hand can hold two Grizzly Bears and picking
## the same LINE twice must not read as picking two different cards.
var _choice_picks := PackedInt32Array()


## The two buttons a yes/no card question wears. `Yes` / `No` are the
## original's general pair (`@CYCLONE`, promptsX1.txt:88-90), but an
## UPKEEP COST has its own words — `@PROMPT_PAYUPKEEP`
## (Program/UIStrings.txt:1129) is `Pay Upkeep costs.` / `Don't pay
## Upkeep.` — and naming the action beats a bare Yes on the one question
## the player meets every single turn.
##
## What makes a question an upkeep cost: it begins with "Pay" (how all 50
## of the "you may pay" triggers phrase themselves) AND it is asked in the
## upkeep step, or names the upkeep outright. [param step] is the
## PlayerChoice's own — 33 of the 47 in-resolution questions are asked by an
## UPKEEP_START trigger, and the step is what tells "Pay {B}{B} to keep
## Junún Efreet?" from Urza's Chalice's "Pay {1} to gain 1 life?", which
## wears no cost of upkeep and keeps the general pair.
##
## Attack and block costs have their own strings again (`Pay for attacker` /
## `Pay for blocker`) and are asked in the combat steps, so they are not
## swallowed here — they are a separate item (§6.17).
static func yes_no_labels(prompt: String, step := -1) -> Array:
	if prompt.begins_with("Pay") and (step == Mtg.Step.UPKEEP
			or prompt.to_lower().contains("upkeep")):
		return ["Pay Upkeep costs.", "Don't pay Upkeep."]
	return ["Yes", "No"]


## The colours a COLOR question offers, in the original's own order and
## spelling — `@DIALOG_DUELOPTIONS`' territory list, UIStrings.txt:610-614.
const COLOR_CHOICES := [
	Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B,
	Mtg.ManaColor.R, Mtg.ManaColor.G,
]


## The colours [param choice] actually offers, in the order the lines list
## them. Every question asked inside a resolution offers all five; a mana
## source's does not — Fellwar Stone offers only what the opponent's lands
## could make, and a line the engine would then have to substitute away is
## worse than no line at all.
static func choice_colors(choice: PlayerChoice) -> Array:
	return COLOR_CHOICES if choice.colors.is_empty() else Array(choice.colors)


## The option LABELS [param choice] wears, in order. Static and pure so the
## wording can be pinned without a screen (tests/ui/test_duel_prompts.gd).
static func choice_options(choice: PlayerChoice) -> Array:
	match choice.kind:
		PlayerChoice.Kind.YES_NO:
			return yes_no_labels(choice.prompt, choice.step)
		PlayerChoice.Kind.COLOR:
			var colors: Array = []
			for flag in choice_colors(choice):
				colors.append(Mtg.COLOR_NAMES[flag])
			return colors
		PlayerChoice.Kind.CARD:
			var names: Array = []
			for line in choice_card_lines(choice):
				names.append(line["label"])
			if choice.optional:
				names.append("Cancel.")       # prompts.txt:949 — fail to find
			return names
		PlayerChoice.Kind.DISCARD:
			var hand: Array = []
			for inst in choice.candidates:
				hand.append((inst as CardInstance).data.card_name)
			return hand
		PlayerChoice.Kind.OPTION:
			# The caller already wrote the labels and reads the INDEX back,
			# so nothing here needs to know what an option means.
			return Array(choice.options)
	return []


## A CARD question's lines, `{label, answer}` each, in order — the labels
## are what [method choice_options] lists and the answers what
## [method _on_choice_option] hands to MtgGame.answer_choice, built
## together so the two cannot drift.
##
## A card in a HIDDEN zone — the library a tutor searches, a hand — is
## interchangeable with its namesakes, so a NAME is listed once and
## answered by name (a shuffle between the question and the answer can
## replace the instances; see HumanAgent.answer_card). A PERMANENT is not:
## two Grizzly Bears on the battlefield are two objects, one of them
## pumped or blocking, and "Select creature to sacrifice." (Ashnod's
## Altar) must be able to name either — so those are listed one line per
## object, told apart by the number the card's own ID tag shows (Ctrl+T),
## and answered by INSTANCE ID (2026-09-02).
static func choice_card_lines(choice: PlayerChoice) -> Array:
	var lines: Array = []
	var seen := {}
	var namesakes := {}
	for inst in choice.candidates:
		var card_name: String = (inst as CardInstance).data.card_name
		namesakes[card_name] = int(namesakes.get(card_name, 0)) + 1
	for inst in choice.candidates:
		var card: CardInstance = inst
		var card_name := card.data.card_name
		if card.zone == Mtg.Zone.BATTLEFIELD:
			var label := card_name
			if int(namesakes[card_name]) > 1:
				label += " #%d" % card.id
			lines.append({"label": label, "answer": card.id})
			continue
		if seen.has(card_name):
			continue
		seen[card_name] = true
		lines.append({"label": card_name, "answer": card_name})
	return lines


## The line above the options: the question in the caller's own words, or
## the original's for a discard, which has no prompt of its own.
static func choice_question(choice: PlayerChoice) -> String:
	if choice.kind == PlayerChoice.Kind.COLOR and not choice.is_cost:
		return "Select a color."
	# A COST's colour question is asked as a MANA SOURCE is tapped, and the
	# original gives that its own line rather than the generic one:
	# `@MULTIMANA` (Text.res:2057-2059) is `%s: What kind of mana?`, spelled
	# out for this pool's one such card by `@FELLWAR_STONE`
	# (prompts.txt:372-374) as `Fellwar Stone: What kind of mana?`. The
	# engine writes it (PlayerChoice.mana_color_prompt), so it arrives here
	# as the choice's own prompt.
	return choice.prompt


## Is the overlay showing a question that is not answered by ONE click?
## Only DISCARD, which takes [member PlayerChoice.count] of them.
static func choice_is_multi(choice: PlayerChoice) -> bool:
	return choice.kind == PlayerChoice.Kind.DISCARD and choice.count > 1


## Open the overlay for whatever the engine is holding open. Idempotent —
## _refresh calls it on every state change.
func _open_choice_overlay() -> void:
	if _choice_overlay != null or game.awaiting_choice == null:
		return
	var choice: PlayerChoice = game.awaiting_choice
	if not _humans.has(choice.pid) or DisplayServer.get_name() == "headless":
		return
	_choice_picks = PackedInt32Array()
	_build_choice_overlay(choice)


func _build_choice_overlay(choice: PlayerChoice) -> void:
	# s30's `vector.FillRect(..., color.RGBA{0,0,0,160})`: the board stays
	# readable behind the question but stops competing with it.
	var scrim := ColorRect.new()
	scrim.color = Color8(0, 0, 0, 160)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.z_index = 190
	add_child(scrim)
	_choice_overlay = scrim

	var dialog := OriginalDialog.create("", Vector2(552, 402), "big_card_panel")
	scrim.add_child(dialog)
	# The REASON'S CARD, left — s30 draws `req.Reason`'s image and so do we.
	var asking := _choice_source_card(choice)
	if asking != null:
		var face := CardPreview.new()
		face.scale = Vector2(0.9, 0.9)
		face.position = Vector2(18, 12)
		face.show_card(asking)
		dialog.add_child(face)
	var lines := VBoxContainer.new()
	lines.position = Vector2(300, 26)
	lines.custom_minimum_size = Vector2(235, 0)
	lines.add_theme_constant_override("separation", 6)
	# `@PROMPT_NEWFULLCARD` (UIStrings.txt:1114) is "%s selects:" — the
	# original announces WHO is choosing before it lists the choices.
	lines.add_child(OriginalDialog.label("You select:", 16, true))
	if choice.source != "":
		var reason := OriginalDialog.label(choice.source, 14)
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lines.add_child(reason)
	var question := OriginalDialog.label(choice_question(choice), 14)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.add_theme_color_override("font_color", OriginalDialog.HIGHLIGHT)
	lines.add_child(question)
	# The options scroll: a library search can offer thirty names where an
	# upkeep cost offers two, and the window is one size.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(235, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 219
	scroll.add_child(column)
	lines.add_child(scroll)
	var labels := choice_options(choice)
	for i in labels.size():
		# s30's `fmt.Sprintf("%d. %s", i+1, opt.Label)` and its number keys.
		var text: String = "%d. %s" % [i + 1, labels[i]] if i < 9 \
			else String(labels[i])
		if _choice_picks.has(i):
			text += "  *"
		var line := OriginalDialog.choice_line(text)
		line.pressed.connect(_on_choice_option.bind(i))
		column.add_child(line)
	if choice.is_cost and not choice.adverse:
		# A COST question can be backed out of — nothing is paid until the
		# whole cost is known (CR 601.2h; MtgGame.cancel_choice). "Cancel"
		# is one of the three 1997 buttons (@DIALOGBUTTONS), and the scrim
		# otherwise leaves no way even to the territory menu: one click on
		# Ashnod's Altar used to mean a sacrifice or a concede.
		var back := OriginalDialog.button("Cancel")
		back.pressed.connect(_withdraw_choice)
		lines.add_child(back)
	dialog.add_child(lines)


## The card the question came from, so the overlay can show its face.
func _choice_source_card(choice: PlayerChoice) -> CardInstance:
	if choice.source == "":
		return null
	if not game.stack.is_empty():
		var top: StackItem = game.stack.back()
		if top.card != null and top.card.data.card_name == choice.source:
			return top.card
	for inst in game.all_battlefield():
		if inst.data.card_name == choice.source:
			return inst
	# A CAST's additional cost (Metamorphosis, Sacrifice) is paid while the
	# spell is still IN HAND — the question is put before it reaches the
	# stack (CR 601.2h), so the face to show is the one the player is
	# holding (docs/duel-todo.md §1.3).
	if choice.is_cost and choice.pid >= 0 and choice.pid < game.players.size():
		for inst in game.players[choice.pid].hand:
			if inst.data.card_name == choice.source:
				return inst
	return null


func _close_choice_overlay() -> void:
	if _choice_overlay != null:
		_choice_overlay.queue_free()
		_choice_overlay = null


## One option clicked (or its number key pressed).
func _on_choice_option(index: int) -> void:
	if game.awaiting_choice == null:
		return
	var choice: PlayerChoice = game.awaiting_choice
	var labels := choice_options(choice)
	if index < 0 or index >= labels.size():
		return
	match choice.kind:
		PlayerChoice.Kind.YES_NO:
			_answer_choice(index == 0)
		PlayerChoice.Kind.OPTION:
			_answer_choice(index)   # the answer IS the index
		PlayerChoice.Kind.COLOR:
			_answer_choice(choice_colors(choice)[index])
		PlayerChoice.Kind.CARD:
			# The trailing `Cancel.` is the legal "fail to find".
			if choice.optional and index == labels.size() - 1:
				_answer_choice("")
			else:
				_answer_choice(choice_card_lines(choice)[index]["answer"])
		PlayerChoice.Kind.DISCARD:
			if _choice_picks.has(index):
				_choice_picks.remove_at(_choice_picks.find(index))
			else:
				_choice_picks.append(index)
			if _choice_picks.size() >= mini(choice.count, labels.size()):
				var picks: Array = []
				for i in _choice_picks:
					picks.append(String(labels[i]))
				_answer_choice(picks)
			else:
				# More to pick: redraw with the ticks in place. A second
				# click on a picked line takes it back — the discard phase's
				# own rule (§1.1), and this dialog has no Cancel either.
				_close_choice_overlay()
				_build_choice_overlay(choice)


func _answer_choice(value: Variant) -> void:
	_close_choice_overlay()
	_choice_picks = PackedInt32Array()
	_report(game.answer_choice(value))
	_refresh()


## Can the held question be WITHDRAWN rather than answered? Only a cost
## question of the player's own — a cast's, an activation's, a mana
## ability's — and never one put to the opponent (an adverse target,
## Arena's or Preacher's). The engine's gate is MtgGame.cancel_choice;
## this is its mirror, so the overlay offers Cancel exactly where the
## engine will honour it, and Escape and the bar's Cancel agree with both.
func _choice_withdrawable() -> bool:
	var choice: PlayerChoice = game.awaiting_choice
	return choice != null and choice.is_cost and not choice.adverse


## Withdraw the held cost question: the action is retracted unpaid, the
## overlay closes, and the table is exactly as it was before the click.
func _withdraw_choice() -> void:
	_close_choice_overlay()
	_choice_picks = PackedInt32Array()
	_report(game.cancel_choice())
	_refresh()


# =========================== STOPS, RUN TO, and Done as a standing order --
#
# Three 1997 behaviours, one driver. All quotes are the manual's, verbatim.
#
# RUN TO (p.116): *"You can move forward ('run') to any phase by clicking on
# the icon for that phase… This instructs the computer — acting as referee —
# that you do not intend to do anything until the phase you clicked on. The
# duel blithely skips through all the intervening phases, then stops."*
# THREE exceptions, and they are exhaustive:
#   1. *"If there are any required actions to perform during a specific
#      phase (dealing with upkeep effects, for example), movement through
#      the phases will stop at that phase until you do what is necessary."*
#   2. *"If your opponent does something that requires or permits a response
#      (casts a spell, uses a fast effect, declares an attack, or whatever),
#      movement through phases stops so that you have a chance to respond."*
#   3. *"If you have placed a Stop on a phase, progress pauses at that
#      phase."*
# and then: *"When the duel pauses to take care of something like this, your
# original 'destination' phase is forgotten."* — [member _run_slot] is
# cleared on ANY of the three, which is the difference between a run and a
# modern auto-pass.
#
# DONE (p.112, docs/duel-todo.md §6.20a) is a run with NO destination:
# *"it tells the 'referee' that you do not intend any action until (1) you
# reach a phase that has a Stop on it, (2) an action or decision is
# required…, or (3) you are able to use a fast effect. (Note that 'able to'
# means that you have a fast effect handy and you have the mana available to
# use that effect.)"* Note the two lists DIFFER, deliberately: Done stops
# for an affordable fast effect and does not list the opponent's actions;
# Run to stops for the opponent's actions and does not weigh affordability.
# Both are honoured as written.
#
# A STOP (p.117) *"does not end until you tell it to manually; it cannot
# pass automatically"* — so a Stop halts progress on the phases you ENTER,
# never on the one you are standing in when you give the order. Giving the
# order IS telling it manually. [member _advance_from] is what remembers
# where the order was given, and it is the whole of that rule.
#
# The driver runs from [method _refresh], not in one blocking loop, because
# an AI seat's moves arrive on its own pacing timer: a run that reaches the
# opponent's priority simply waits, and the next `state_changed` resumes it.

## What the standing order is, if any. [constant Advance.NEXT_PHASE] is
## the territory menu's `Go to: next phase` (§6.3) — *"ends the current
## phase and moves you on to the next one"* (`Duel.hlp`, **Territory**) —
## which is a run with the shortest possible destination: the first phase
## key that is not this one.
enum Advance { NONE, RUN_TO, DONE, NEXT_PHASE }

var _advance_mode := Advance.NONE
## Destination of a RUN_TO, as `[half, bar, slot]`; empty for DONE.
var _run_to: Array = []
## The phase key the order was given in, and whether the duel has left it
## yet. A Stop on the phase you gave the order in has already done its job —
## giving the order IS telling it manually — so it must not re-trap the run
## (see the block comment above). Once the duel has moved, every Stop counts
## again, including a second visit to that same phase next turn.
var _advance_from: Array = []
var _advance_moved := false
## Stack items already on the chain when the order was given: only something
## NEW from the opponent is *"something that requires or permits a
## response"*.
var _advance_seen: Array = []
## Re-entrancy guard: every pass_priority emits `state_changed`, which calls
## [method _refresh], which calls the driver again.
var _advancing := false
## WHERE A STANDING ORDER CAME TO REST, as a [method _phase_key] — the one
## phase the automatic pass ([method _auto_pass_applies]) may not touch.
## *"The duel blithely skips through all the intervening phases, then
## stops"* (manual p.116): a destination you named is a phase you are
## standing in on purpose, so arriving is not a window to pass for you.
## Dropped the moment the duel is anywhere else.
var _rested_at: Array = []


## Where the duel is on the two bars right now, as `[half, bar, slot]` —
## the key Stops, run destinations and the `_advance_from` rule all use.
func _phase_key() -> Array:
	var step: int = game.current_step()
	var half := PhaseStops.half_for_seat(game.active_player, _human_seat())
	if CombatBar.covers_step(step):
		return [half, PhaseStops.Bar.COMBAT,
			CombatBar.slot_for_step(step, game.awaiting_attackers,
				game.awaiting_blockers)]
	return [half, PhaseStops.Bar.PHASE, _phase_icon_slot(step)]


## Does the human seat hold a fast effect it *"has the mana available to
## use"* (manual p.112)? Instants in hand and non-mana activated abilities
## on your permanents, priced through the engine's own payability check so
## the answer can never disagree with what casting would accept.
##
## SIMPLIFIED, and since 2026-09-03 DELIBERATELY so: [method
## MtgGame.can_afford] prices against FLOATING mana, not against lands you
## could still tap. The potential-mana query the old note said was missing
## now exists ([method MtgGame.could_afford], and the castable highlight
## uses it) — this predicate is left on the floating pool on purpose.
##
## The original auto-tapped, so its *"mana available"* meant untapped
## sources, and pointing this at `could_afford` would be the stricter,
## more faithful reading. It would also stop BOTH the Done order and the
## opponent's-turn auto-pass at every phase in which the player merely
## HOLDS an instant with a land untapped — which is the clicking the
## owner's 2026-09-03 playtest was about. As it stands the duel stops here
## only when the player has actually floated mana for a response, i.e.
## when they have visibly prepared one. `docs/ROADMAP.md` carries the row
## and what it would take to switch.
func _has_affordable_fast_effect(pid: int) -> bool:
	if not _is_human(pid):
		return false
	for inst in game.players[pid].hand:
		if inst.data.is_type(Mtg.CardType.INSTANT) \
				and game.can_afford(pid, inst.data):
			return true
	for inst in game.all_battlefield():
		if inst.controller_id != pid:
			continue
		# `cur_activated_abilities` never holds mana abilities — those are
		# their own list (`cur_mana_abilities`), which is right: "Drawing
		# mana from a mana source is neither a spell nor an effect"
		# (manual p.95), so it is not a fast effect either.
		for ability in inst.cur_activated_abilities:
			if game.can_afford_cost(pid, ability.cost):
				return true
	return false


## HAS [param pid] A RESPONSE AT ALL — an instant in hand or an activated
## ability whose cost the untapped sources could still reach? This is
## [method _has_affordable_fast_effect]'s question asked of POTENTIAL mana
## ([method MtgGame.could_afford], the same query the castable highlight
## uses) rather than of the floating pool, so it is true wherever a play
## is possible and false only when there is genuinely nothing to make.
##
## IT EXISTS FOR ONE CLAUSE. `Duel.hlp`, topic **Phase Bar**: *"if your
## opponent does something that requires or permits a response… movement
## through phases stops so that you have a chance to respond."* A chain
## item PERMITS a response only if the player has one; with an empty hand
## and tapped-out lands the sentence's own condition is not met, and the
## automatic pass used to stop there anyway — one click per spell the
## opponent cast, every turn, which is the second half of the owner's
## 2026-09-04 report (`docs/ROADMAP.md`, "THE OPPONENT'S TURN").
##
## NOT the floating-pool test, deliberately: passing a window in which the
## player could still tap a land and answer would take a play away from
## them, and no saving of clicks is worth that.
func _could_respond(pid: int) -> bool:
	if not _is_human(pid):
		return false
	for inst in game.players[pid].hand:
		if inst.data.is_type(Mtg.CardType.INSTANT) \
				and game.could_afford(pid, inst.data, _no_auto_tap):
			return true
	for inst in game.all_battlefield():
		if inst.controller_id != pid:
			continue
		for ability in inst.cur_activated_abilities:
			# No potential-mana query for an ABILITY cost, so this stays on
			# the floating pool — the conservative half of the answer, and
			# the same one `_has_affordable_fast_effect` gives.
			if game.can_afford_cost(pid, ability.cost):
				return true
	return false


## THE MANUAL'S FIRST EXCEPTION, on its own — *"If there are any required
## actions to perform during a specific phase (dealing with upkeep
## effects, for example), movement through the phases will stop at that
## phase until you do what is necessary"* (`Duel.hlp`, topic **Phase
## Bar**). Every moment the engine HOLDS the turn machine open, plus an
## action of the player's own already in progress. "" when it is holding
## nothing.
##
## Split out so the standing orders ([method _advance_stop_reason]) and
## the opponent's-turn auto-pass ([method _auto_pass_applies]) read ONE
## list and can never drift apart.
func _required_action_reason() -> String:
	if game.awaiting_attackers:
		return "attackers must be declared"
	if game.awaiting_blockers:
		return "blockers must be declared"
	if game.awaiting_discard:
		return "the discard phase is waiting"
	if game.awaiting_damage_assignment:
		return "combat damage must be divided"
	# THE DAMAGE-PREVENTION WINDOW (§6.8). A run must not blow through it —
	# it is the one moment a Circle of Protection can be used at all. The
	# original made leaving it a deliberate click of its own
	# (`@PROMPT_ENDHEALING` = `end damage prevention`), and here that click
	# is the Done button's single pass.
	if game.awaiting_damage_prevention or game.awaiting_regeneration:
		return "damage prevention is waiting"
	if mode != Mode.NORMAL:
		return "an action is in progress"
	# The upkeep cost the manual names outright: a question the engine has
	# stopped a resolution for, which §1.3 puts to the player rather than
	# guessing. This is the manual's "an action or decision is required".
	if game.awaiting_choice != null:
		return "a choice is waiting"
	return ""


## Why the duel must not advance one more time, or "" to keep going. The
## three run-to exceptions plus the arrival check, in the manual's order.
func _advance_stop_reason() -> String:
	if game == null or game.game_over:
		return "the duel is over"
	# (1) "any required actions to perform during a specific phase… until
	# you do what is necessary" — every moment the engine HOLDS open.
	var held := _required_action_reason()
	if held != "":
		return held
	# (3) "If you have placed a Stop on a phase, progress pauses at that
	# phase" — but not on the phase the order was given in.
	var here := _phase_key()
	if _advance_moved and stops != null \
			and stops.is_marked(here[0], here[1], here[2]):
		return "Stop"
	# (2) the opponent did something. A run-to exception only: Done's own
	# list weighs affordability instead (see the block comment above).
	if _advance_mode == Advance.RUN_TO and not game.stack.is_empty():
		var top: StackItem = game.stack.back()
		if top.controller != _human_seat() and not _advance_seen.has(top):
			return "%s is on the chain" % top.description
	# Done's third condition, which run-to does not share.
	if _advance_mode == Advance.DONE \
			and _has_affordable_fast_effect(_human_seat()):
		return "a fast effect is available"
	return ""


## What the Situation Bar says when a run or a Done order comes to rest —
## `@PROMPT_STOPANYWAY`, `shandalar-src/Program/UIStrings.txt:1078`, nine
## entries, verbatim but for the trailing space each carries in the table.
## The name is the original's own: it is the "you asked to stop anyway"
## line, and `Paused: Discard phase` (entry 6) is the one the discard
## phase already uses through `@PROMPT_DISCARD`.
##
## The bare `Paused` covers what the table has no entry for — the combat
## sub-phases before damage, which the Combat Bar names instead.
static func paused_message(step: int) -> String:
	match step:
		Mtg.Step.UNTAP: return "Paused: Untap phase"
		Mtg.Step.UPKEEP: return "Paused: Upkeep phase"
		Mtg.Step.DRAW: return "Paused: Draw phase"
		Mtg.Step.MAIN1, Mtg.Step.MAIN2: return "Paused: Main phase"
		Mtg.Step.END, Mtg.Step.CLEANUP: return "Paused: Discard phase"
		Mtg.Step.FIRST_STRIKE_DAMAGE:
			return "Paused: First strike damage resolution"
		Mtg.Step.COMBAT_DAMAGE: return "Paused: Combat damage resolution"
	return "Paused"


## Order a run to one icon — the manual's *"click on the icon for that
## phase"*. [param bar] is a [enum PhaseStops.Bar].
func _order_run_to(half: int, bar: int, slot: int) -> void:
	if mode != Mode.NORMAL or game.game_over or _toss_active or _modal_open():
		return
	_run_to = [half, bar, slot]
	_begin_advance(Advance.RUN_TO)


## Order the manual's Done: a standing instruction with no destination.
func _order_done_advance() -> void:
	_run_to = []
	_begin_advance(Advance.DONE)


## Order the territory menu's `Go to: next phase` — *"ends the current
## phase and moves you on to the next one"*. The coarsest of the three
## verbs the original gives the player and the one we had no equivalent
## for: our Done button passes priority exactly once, Run to aims at a
## named destination, and this simply leaves the phase it is standing in.
func _order_next_phase() -> void:
	if mode != Mode.NORMAL or game.game_over or _toss_active or _modal_open():
		return
	_run_to = []
	_begin_advance(Advance.NEXT_PHASE)


func _begin_advance(kind: int) -> void:
	_advance_mode = kind
	_advance_from = _phase_key()
	_advance_moved = false
	_advance_seen = game.stack.duplicate()
	_drive_advance()
	_refresh()


## Forget the order. *"your original 'destination' phase is forgotten"*
## (manual p.116).
func _cancel_advance() -> void:
	_advance_mode = Advance.NONE
	_run_to = []
	_advance_from = []
	_advance_moved = false
	_advance_seen = []


# ----------------------------- AN UNSTOPPED PHASE RUNS ITSELF (§6.20a) --
#
# THE OWNER'S PLAYTEST, 2026-09-03, in two instalments. First:
# *"I should not be clicking through AI opponent phases, they should go
# automatically — as it is opponent playing (in a human pace of course)."*
# Then, once that had landed: *"My main phase precombat, combat and main
# phase post-combat should be selected to stop (red dot) by default. If
# nothing happens on a phase (no card needs it) and I DON'T have it
# selected for stoppage by red dot — then it should go automatically EVEN
# FOR ME."*
#
# THE RULE BELOW IS SEAT-AGNOSTIC, AND MICROPROSE SAY SO IN SO MANY WORDS.
# `Readme.txt` (14 January 1998, MicroProse's own; `shandalar-xp/MagicTG/`
# and byte-for-byte the same file in `s30/assets/text/`), under **Dueling
# Table**, lines 70-80 — and note that every example in it is a card of
# YOUR OWN, on YOUR OWN turn:
#
#   *"If you do not put a Stop (the red marker) on a phase, play will
#   BYPASS THAT PHASE without bothering to ask you if you want to use
#   optional effects (a Brass Man's untap or Land Tax, for example). This
#   is a handy way to prevent the duel from bogging down, but if you are
#   not careful, you could accidentally miss an opportunity. Thus, if you
#   plan to use an optional effect (especially during the upkeep phase),
#   make sure to Run To … or put a Stop on the phase you have in mind."*
#
# ...and its FAQ (`:645-659`) states the safety rule with equal force:
#
#   *"You must put a Stop marker on your upkeep phase for the program to
#   stop there. OTHERWISE, THE GAME WILL ONLY STOP AT YOUR UPKEEP PHASE
#   FOR MANDATORY EFFECTS (such as a creature getting a counter for
#   Unstable Mutation or taking damage for Cursed Land)."*
#
# Those two sentences are this whole feature: an unstopped phase of YOUR
# OWN is bypassed, and what still stops it is a MANDATORY effect. The
# safety list below is our "mandatory", and it is checked before any Stop
# is consulted. What keeps your own turn comfortable rather than merely
# correct is [method PhaseStops.default_masks] — the main-phase Stops a
# fresh profile starts with, which the original had too.
#
# ONE READING WE DID NOT TAKE. The same FAQ answer adds that a Stop means
# *"the program will stop there IF YOU HAVE A VALID ACTION"* — i.e. a
# marked phase with nothing to do in it might still pass. `Duel.hlp`,
# topic **Stop**, is flatly unconditional (*"that phase does not end until
# you tell it to manually; it cannot pass automatically"*), it is the more
# specific source, and a Stop that sometimes ignores you is worse than one
# that always waits. Recorded in `docs/ROADMAP.md` rather than built.
#
# WHAT WAS WRONG, exactly. [method _drive_advance] returns on its first
# line unless a STANDING ORDER is in force, and the only three things that
# arm one are the player's own Done (`_order_done_advance`), a Run to
# (`_order_run_to`) and the territory menu's Go to (`_order_next_phase`).
# Nothing arms one by itself. So every priority window the human held —
# one per step, thirteen steps a turn on BOTH turns — sat there waiting
# for a click that carried no decision at all.
#
# THIS IS THE 1997 ANSWER, not a modern auto-pass. `Duel.hlp`, topic
# **Stop**, defines a Stop by what it takes away: *"that phase does not end
# until you tell it to manually; IT CANNOT PASS AUTOMATICALLY."* A phase
# with no Stop on it therefore CAN pass automatically, and that sentence is
# the only place any 1997 source says what the duel does when nobody is
# holding it.
#
# WHERE IT STOPS is the union of the two lists the sources give, because
# they overlap and neither contradicts the other:
#
#  * `Duel.hlp`, topic **Phase Bar**, written about *"movement through the
#    phases"* rather than about any one order — (a) *"if there are any
#    REQUIRED ACTIONS to perform during a specific phase… movement through
#    the phases will stop at that phase until you do what is necessary"*,
#    (b) *"if your opponent DOES SOMETHING THAT REQUIRES OR PERMITS A
#    RESPONSE (casts a spell, uses a fast effect, declares an attack, or
#    whatever), movement through phases stops so that you have a chance to
#    respond"*, (c) *"if you have placed a STOP on a phase, progress pauses
#    at that phase."*
#  * manual p.112's third Done condition — *"you are able to use a FAST
#    EFFECT. (Note that 'able to' means that you have a fast effect handy
#    and you have the mana available to use that effect.)"* — which is also
#    the owner's own *"priority with something castable"*.
#
# It carries [method _has_affordable_fast_effect]'s documented SIMPLIFIED
# pricing with it: that predicate asks the FLOATING pool, so in practice
# the duel stops here only when the player has actually floated mana for a
# response. That is the under-report already on `docs/ROADMAP.md`, and it
# is what makes this feel like the owner asked rather than like a brake.
#
# NEVER IN A HOTSEAT DUEL, where both seats are somebody's and there is no
# "opponent" for the screen to run on anyone's behalf.
#
# AND NEVER IN THE PHASE A STANDING ORDER CAME TO REST IN ([member
# _rested_at]). *"The duel blithely skips through all the intervening
# phases, THEN STOPS"* (manual p.116) — naming a destination is telling
# the duel manually where you want to be, so arriving there is not a
# window to pass for you. Without this the second half of the feature
# eats the first: a `Run to` would arrive and, the same frame, walk on.
# The mark is dropped the moment the duel leaves that phase.
#
# THE PACE IS THE AI'S OWN, and NO NEW TIMER IS ADDED. The active player
# takes priority first in every step (CR 117.3a), and on your own turn the
# pass hands priority to the AI seat, whose reply rides [method
# _maybe_schedule_ai] and its dwell. Either way the duel cannot walk a
# whole turn inside one frame: one `DuelConfig.pace` gap per step.


## May the human's priority be passed for them right now? See the block
## comment above; every clause there is one line here.
func _auto_pass_applies() -> bool:
	if game == null or game.game_over or _toss_active:
		return false
	if _ais.is_empty():
		return false              # hotseat: no seat is "the opponent"
	if _modal_open() or _pending_card != null:
		return false
	if not _is_human(game.priority_player):
		return false              # nothing of ours to pass
	# (a) a required action, and (implicitly) any mode but NORMAL. THIS IS
	# THE SAFETY RULE, and it comes first on purpose: a phase the ENGINE
	# is holding open for this seat is never passed for them, marked or
	# not, on anybody's turn. Auto-passing a window the game is waiting in
	# is a hang, which is what `duel_soak.sh` exists to catch.
	if _required_action_reason() != "":
		return false
	# (b) "your opponent does something that requires or permits a
	# response" — something on the chain is that something, and this is
	# the whole of the protection against being rushed past a play. It
	# reads PERMITS literally ([method _could_respond]): a chain item you
	# have nothing to answer with permits nothing, and stopping for it
	# cost the owner one click per spell the opponent cast (2026-09-04).
	# The test is potential mana, not floating mana, so a window you could
	# still tap a land into always waits.
	if not game.stack.is_empty() and _could_respond(_human_seat()):
		return false
	# (c) "if you have placed a Stop on a phase, progress pauses at that
	# phase". Unconditional here, where a standing order excuses the phase
	# the order was given in: an automatic pass is exactly the thing a
	# Stop says "cannot pass automatically". On your own turn the three
	# defaults (PhaseStops.default_masks()) are what this catches.
	var here := _phase_key()
	if stops != null and stops.is_marked(here[0], here[1], here[2]):
		return false
	# ...and the phase a Run to / Go to / Done order stopped in, which the
	# player named and is therefore standing in on purpose.
	if here == _rested_at:
		return false
	# manual p.112's third condition, the owner's "something castable".
	if _has_affordable_fast_effect(_human_seat()):
		return false
	return true


## Pass ONE priority window for the human. Returns true when it did. Runs
## under [member _advancing] like the standing orders do, because
## `pass_priority` emits `state_changed` and that re-enters [method
## _refresh] — and therefore this — before it returns. One window per
## refresh is the whole pacing model: the next one needs a new state
## change, which on either turn means the AI seat has moved.
func _auto_pass_priority() -> bool:
	if _advancing or not _auto_pass_applies():
		return false
	_advancing = true
	var refused := game.pass_priority(game.priority_player)
	_advancing = false
	return refused == ""


## Take the duel as far as the standing order allows. Called from
## [method _refresh], so an AI seat's pacing timer resumes it for free.
func _drive_advance() -> void:
	if _advancing or game == null:
		return
	# The rest mark belongs to ONE phase; the moment the duel is anywhere
	# else it has been left manually and is spent.
	if not _rested_at.is_empty() and _phase_key() != _rested_at:
		_rested_at = []
	if _advance_mode == Advance.NONE:
		# No order standing: an unstopped phase still runs itself, on
		# either seat's turn (see the block comment above).
		_auto_pass_priority()
		return
	_advancing = true
	# 200 is a safety net, not a design: every real run ends on an arrival
	# or one of the three exceptions long before this.
	for _i in 200:
		if not _advance_moved and _phase_key() != _advance_from:
			_advance_moved = true
		if _advance_mode == Advance.RUN_TO and _advance_moved \
				and _phase_key() == _run_to:
			_rested_at = _phase_key()
			_cancel_advance()      # arrived: "then stops"
			break
		# `Go to: next phase` has arrived the moment the phase changed —
		# it is a run whose destination is "not here" (§6.3).
		if _advance_mode == Advance.NEXT_PHASE and _advance_moved:
			_rested_at = _phase_key()
			_cancel_advance()
			break
		var reason := _advance_stop_reason()
		if reason != "":
			# The order is spent HERE, and the automatic pass must not
			# pick the duel up again in the same phase (see [member
			# _rested_at]). Only when the order actually TRAVELLED: an
			# order refused on the spot took the player nowhere, so
			# there is no arrival to respect and the phase goes back to
			# passing itself once whatever refused it is gone.
			if _advance_moved:
				_rested_at = _phase_key()
			# The original has its own word for a run that halted, and it
			# is not "stopped": @PROMPT_STOPANYWAY (UIStrings.txt:1078).
			# Only said when the duel actually moved — a refused order is
			# not a pause — and never over a prompt the phase itself owns
			# (the discard and damage loops write their own).
			# _report, not _set_prompt: in NORMAL mode _refresh writes the
			# running status line straight over anything _set_prompt left,
			# and this is a MOMENT rather than a state — it should flash
			# and hand the Situation Bar back.
			if _advance_moved and mode == Mode.NORMAL and not game.game_over:
				_report(paused_message(game.current_step()))
			_cancel_advance()
			break
		if not _is_human(game.priority_player):
			break                   # the AI's timer takes it from here
		if game.pass_priority(game.priority_player) != "":
			_cancel_advance()
			break
	_advancing = false


## Enter / the old Fast-forward: the manual's **Done**, which p.116 binds to
## Return. Kept under its old name because it is still "take the duel as far
## as it will go"; what changed is that it now honours Stops and stops for a
## fast effect you can afford (docs/duel-todo.md §6.20a).
func _on_pass_turn() -> void:
	if mode != Mode.NORMAL or _toss_active:
		return
	_order_done_advance()


# ------------------------------------------------------------- popups (X) --

## How many targets the X dialog was told to take (-1 = it did not ask).
## `# Targets:` is the second half of `@DIALOG_FIREBALL` and it decides
## the target slot's count, so it has to survive from the dialog to
## [method _build_target_slots].
var _pending_target_count := -1


## Ask for X on whatever is pending — a spell's own cost, or the cost of
## the activated ability being paid for (Voodoo Doll's {X}{X}, the
## Candelabra's {X}). The window is [FireballDialog], which carries
## `@DIALOG_FIREBALL`'s seven strings and the arithmetic behind them.
##
## The bound is what the pool can ACTUALLY pay, so the dialog can never
## set up a guaranteed refusal. Three things earlier versions got wrong:
##   * {X}{X} costs (Part Water, Voodoo Doll) charge x_count mana per
##     point of X — the engine multiplies internally (mtg_game.gd:620,
##     762), so the payable bound must multiply too, or the dialog offers
##     double the X the player can afford.
##   * an ability's X is paid in COLOURED mana when x_color is set
##     (Goblin Polka Band), which the generic bound can't model — those
##     fall back to the engine's own refusal.
##   * **THE PER-TARGET SURCHARGE (§6.14).** Fireball costs *"{1} more to
##     cast for each target beyond the first"*, and X used to be asked
##     BEFORE targets and priced without them: the dialog offered the
##     whole pool as X, the player then picked a second target, and the
##     cast was refused because the surcharge had nowhere to come from.
##     `@DIALOG_FIREBALL` asks for both in one window precisely so the
##     budget adds up, which is what the extra five strings are for.
func _open_x_dialog() -> void:
	var pool := game.players[_pending_pid].mana_pool
	var cost: ManaCost = _pending_card.data.cost
	var surcharge := game.spell_surcharge(_pending_pid, _pending_card.data)
	var label := _pending_card.data.card_name
	var per_target := 0
	if _pending_ability_index >= 0:
		var ability: ActivatedAbility = \
			_pending_card.cur_activated_abilities[_pending_ability_index]
		cost = ability.cost
		surcharge = 0        # surcharges are a SPELL tax (Gloom et al.)
		label = "%s — %s" % [label, ability.text]
	else:
		per_target = _pending_card.data.extra_cost_per_target
	var per_x: int = maxi(cost.x_count, 1)
	# The BUDGET is in mana, which is what entry 1 asks for: the largest
	# extra generic this pool can cover on top of the printed cost.
	var budget := 0
	while pool.can_pay(cost, surcharge + budget + 1):
		budget += 1
	if per_target <= 0:
		# A plain {X} spell: only entries 1 and 2, and the field steps by
		# x_count so every value on it buys a whole point of X.
		budget -= budget % per_x
	_pending_target_count = -1
	if _x_dialog != null:
		_x_dialog.queue_free()
	_x_dialog = FireballDialog.window(label, budget, per_target,
		_legal_target_ceiling(), per_x)
	_x_spin = _x_dialog.get_meta("mana")
	_x_dialog.add_button("OK").pressed.connect(_on_x_confirmed)
	_x_dialog.add_button("Cancel").pressed.connect(_on_x_canceled)
	add_child(_x_dialog)


## How many legal targets the pending spell's first variable-count slot
## can actually see — the `(max %d)` beside `# Targets:`. *"Any number of
## targets"* is bounded by what exists (CR 601.2c), and offering a count
## the board cannot fill would be the same guaranteed refusal the mana
## bound exists to prevent.
func _legal_target_ceiling() -> int:
	for slot in _pending_slots:
		if int(slot["max"]) < 0:
			var spec: TargetSpec = slot["spec"]
			return maxi(spec.legal_targets(game, _pending_card).size(), 1)
	return 1


## Backing out of the X question cancels the whole cast, exactly as the
## dialog's own Cancel did when it was an AcceptDialog.
func _on_x_canceled() -> void:
	if _x_dialog != null:
		_x_dialog.dismiss()
		_x_dialog = null
	_on_cancel()


func _on_x_confirmed() -> void:
	if _pending_card == null:
		# The cast this window asked about is gone (the same guard
		# _on_mode_chosen and _on_search_confirmed carry).
		_on_x_canceled()
		return
	var per_x: int = maxi(_pending_card.data.cost.x_count, 1)
	if _pending_ability_index >= 0:
		per_x = maxi(_pending_card.cur_activated_abilities[
			_pending_ability_index].cost.x_count, 1)
	var mana := int(_x_spin.value)
	var per_target := 0 if _pending_ability_index >= 0 \
		else _pending_card.data.extra_cost_per_target
	if _x_dialog != null and _x_dialog.has_meta("targets"):
		_pending_target_count = int(_x_dialog.get_meta("targets").value)
	# `X cost:` — the generic that is left once the additional targets are
	# paid for, divided by the number of printed `{X}` symbols.
	var seen := FireballDialog.plan(mana, mana,
		maxi(_pending_target_count, 1), per_target, per_x)
	_pending_x = int(seen["x"])
	if _x_dialog != null:
		_x_dialog.dismiss()
		_x_dialog = null
	# Target COUNTS can depend on X ("Untap X target lands", "N damage
	# divided among any number of targets"), and the slots were built
	# before X was known — rebuild them now that it is.
	if _pending_ability_index >= 0:
		_build_ability_slots(
			_pending_card.cur_activated_abilities[_pending_ability_index],
			_pending_x)
	else:
		_build_target_slots(_pending_card.data, _pending_mode)
	_advance_pending()


## The menu lists the permanent's LIVE abilities, not its printed ones:
## the engine indexes cur_mana_abilities / cur_activated_abilities, so
## reading the printed lists both offered abilities a silenced or retyped
## permanent no longer has (a Strip Mine under Blood Moon taps for {R}
## and has lost its sacrifice ability) and shifted the indices out from
## under the engine. Found by the 2026-09 audit.
## [param mana_only] lists the mana abilities and nothing else — what
## [constant Mode.PAYING] wants, where anything but mana would replace the
## cast the player is in the middle of paying for.
func _open_ability_menu(inst: CardInstance, mana_only := false) -> void:
	_ability_menu.clear()
	var id := 0
	for ability in inst.cur_mana_abilities:
		_ability_menu.add_item(str(ability), id)
		id += 1
	if not mana_only:
		for ability in inst.cur_activated_abilities:
			_ability_menu.add_item(ability.text, id)
			id += 1
	_ability_menu.set_meta("mana_only", mana_only)
	_ability_menu.set_meta("instance_id", inst.id)
	_ability_menu.position = Vector2i(get_global_mouse_position())
	_ability_menu.popup()


func _on_ability_chosen(id: int) -> void:
	var inst := game.find_instance(_ability_menu.get_meta("instance_id"))
	if inst == null:
		return
	var mana_count := inst.cur_mana_abilities.size()
	if id < mana_count:
		_report(game.tap_for_mana(inst.controller_id, inst, id))
		return
	if bool(_ability_menu.get_meta("mana_only", false)):
		return   # the menu offered nothing else; the board changed under it
	var ability_index := id - mana_count
	if ability_index >= inst.cur_activated_abilities.size():
		return   # the board changed under the open menu
	var ability: ActivatedAbility = inst.cur_activated_abilities[ability_index]
	_pending_card = inst
	_pending_ability_index = ability_index
	_pending_pid = inst.controller_id
	_pending_specs = ability.target_specs()
	_build_ability_slots(ability)
	_pending_targets = []
	_pending_x = 0
	# An ability's X needs asking for exactly like a spell's — without
	# this the player silently paid X=0 and Voodoo Doll fired for free
	# (found by the 2026-09 audit).
	if ability.cost.has_x:
		_open_x_dialog()
	else:
		_advance_pending()


# ================================================================== refresh --

## Rebuild the whole board from engine state. Full rebuild is deliberate:
## at duel scale (tens of cards) it is instant, and it can never drift out
## of sync with the engine — the classic immediate-mode trade documented in
## the design doc.
func _refresh() -> void:
	if game == null:
		return
	# THE CHOICE OVERLAY (§1.3): the engine holds a resolution open the
	# moment it finds a question this seat has not answered, and it can do
	# that from ANY driver — a pass, a Done order, the AI's own turn — so
	# the overlay is raised here rather than at any one call site.
	if game.awaiting_choice != null:
		_open_choice_overlay()
	else:
		_close_choice_overlay()
	# Auto-enter combat modes when the engine is waiting on a HUMAN
	# declaration (the AI's own declarations run through its timer).
	if game.awaiting_attackers and mode != Mode.ATTACKERS \
			and _is_human(game.active_player):
		mode = Mode.ATTACKERS
		_selected_attackers = []
		# The 1997 line, verbatim — @PROMPT_MAIN entry 5, UIStrings.txt:1063,
		# full stop included. What stood here was ours, and it borrowed the
		# "?..." form: that form belongs to @PROMPT_FASTEFFECTS and to
		# nothing else, so using it here invented a question the game never
		# asks (docs/glossary-1997.md).
		_set_prompt("Combat phase: Choose attackers.")
	elif game.awaiting_blockers and mode != Mode.BLOCKERS \
			and _is_human(game.opponent_of(game.active_player)):
		mode = Mode.BLOCKERS
		_block_map = {}
		_selected_blocker = -1
		# @PROMPT_MAIN entry 8.
		_set_prompt("Combat phase: Choose blockers.")
	# ...and DROP a declaration the engine has stopped waiting for (§3.5,
	# s30 duel.go:1629-1656, which clears pendingAttackers the moment the
	# declare-attackers step ends and pendingBlockers/selectedBlocker when
	# the blockers prompt ends). We used to clear only on confirm or cancel,
	# so a step advanced by anything else left stale selections on screen —
	# and now they would put phantom creatures in the Combat window as well
	# as phantom arrows on the board.
	elif mode == Mode.ATTACKERS \
			and game.current_step() != Mtg.Step.DECLARE_ATTACKERS:
		_selected_attackers = []
		mode = Mode.NORMAL
	elif mode == Mode.BLOCKERS \
			and game.current_step() != Mtg.Step.DECLARE_BLOCKERS:
		_block_map = {}
		_selected_blocker = -1
		mode = Mode.NORMAL
	# THE DISCARD PHASE (§1.1) and THE DAMAGE DIVISION (§1.4): two more
	# moments the engine now HOLDS OPEN for the player instead of answering
	# for them, entered and left the same way the declarations are.
	elif game.awaiting_discard and mode != Mode.DISCARD \
			and _is_human(game.active_player):
		mode = Mode.DISCARD
		_discard_picks = []
		_set_prompt(_discard_prompt())
	elif game.awaiting_damage_assignment and mode != Mode.DAMAGE \
			and _is_human(int(game.damage_assignment_request().get("assigner", -1))):
		mode = Mode.DAMAGE
		_damage_picks = {}
		_set_prompt(_damage_prompt())
	elif mode == Mode.DISCARD and not game.awaiting_discard:
		_discard_picks = []
		mode = Mode.NORMAL
	elif mode == Mode.DAMAGE and not game.awaiting_damage_assignment:
		_damage_picks = {}
		mode = Mode.NORMAL
	# A cast HELD OPEN for its mana (Mode.PAYING) is re-offered the moment
	# the pool moves — see [method _retry_payment].
	_retry_payment()
	_maybe_schedule_ai()

	for pid in 2:
		# THE TWO FACES OF ONE PANEL (§6.5). Face up, the register shows
		# the duelist and no number — *"click on the face instead of a
		# card"* — and the flip back happens on its own the moment nothing
		# can target a player any more.
		var face_up := _face_shown(pid)
		_dress_life_panel(pid, face_up)
		# The original's huge life NUMERAL (s30 drawLife: 64px text) —
		# through _shown_life, which lets the dying total COUNT DOWN
		# instead of jumping (§2.7).
		_life_buttons[pid].text = "" if face_up else str(_shown_life(pid))
		# The life this refresh painted, remembered so the death animation
		# knows where to count DOWN FROM. It is one refresh behind the
		# engine by construction: MtgGame deals the lethal damage, then
		# emits game_ended, and only then emits state_changed — so when
		# _on_game_over runs, this still holds the life the player had
		# before the blow, which is exactly s30's `prev.State`.
		if not _life_countdown.has(pid):
			_last_life[pid] = game.players[pid].life
		# The poison clock, shown only once a counter lands (CR 704.5c).
		if _poison_labels.size() == 2 and _poison_labels[pid] != null:
			var venom: int = game.players[pid].poison
			_poison_labels[pid].visible = venom > 0
			_poison_labels[pid].text = "%d/10" % venom
		if _lib_labels.size() == 2 and _lib_labels[pid] != null:
			var left_in_library: int = game.players[pid].library.size()
			_lib_labels[pid].text = str(left_in_library)
			# ...and the pile gets THINNER as it empties, which is the
			# readout `Duel.hlp` says the original relied on.
			_dress_deck_stack(pid, left_in_library)
		if _grave_labels.size() == 2 and _grave_labels[pid] != null:
			var pile := game.players[pid].graveyard
			# Quiet while the pile is empty, exactly as the exile count
			# beside it is: a "0" written across the red skull plate is
			# noise, and the empty plate already says "empty".
			_grave_labels[pid].text = "" if pile.is_empty() \
				else "%d" % pile.size()
			if _grave_icons.size() == 2 and _grave_icons[pid] != null:
				var top_face: Texture2D = null
				if not pile.is_empty():
					var top: CardInstance = pile[-1]
					top_face = GameSkin.card_scan(top.data.card_name)
					if top_face == null:
						top_face = GameSkin.card_art(top.data.card_name)
				if top_face == null:
					top_face = GameSkin.texture(
						"grave_panel_" + config.panel_colors[pid])
				_grave_icons[pid].texture = top_face
				# The names ride the PLATE's tooltip now, the way the exile
				# plate's do: the count is a MOUSE_FILTER_IGNORE child of
				# the plate, so a tooltip on it could never be reached.
				_grave_icons[pid].tooltip_text = _grave_tooltip(pid)
		# THE EXILE PILE, right of the graveyard and read exactly the same
		# way: its top card when it holds one, its own empty plate when it
		# does not.
		if _exile_icons.size() == 2 and _exile_icons[pid] != null:
			var gone := game.players[pid].exile
			var exile_face: Texture2D = null
			if not gone.is_empty():
				var top_gone: CardInstance = gone[-1]
				# A card exiled FACE DOWN (Knowledge Vault) shows nothing:
				# nobody may look at it, so the pile keeps its plate.
				if not top_gone.face_down:
					exile_face = GameSkin.card_scan(top_gone.data.card_name)
					if exile_face == null:
						exile_face = GameSkin.card_art(top_gone.data.card_name)
			if exile_face == null:
				exile_face = ExilePlate.plate(config.panel_colors[pid])
			_exile_icons[pid].texture = exile_face
			_exile_icons[pid].tooltip_text = _exile_tooltip(pid)
			if _exile_labels.size() == 2 and _exile_labels[pid] != null:
				# An empty pile — which most duels' is — stays quiet.
				_exile_labels[pid].text = "" if gone.is_empty() \
					else "%d" % gone.size()
		# §1.2: ring a pile that holds a legal target for the pending cast.
		if _grave_rings.size() == 2 and _grave_rings[pid] != null:
			_grave_rings[pid].visible = _pile_holds_a_target(pid)
		# Mana pool counts beside the painted symbols (s30 drawManaPool).
		# total_of, NOT amount_of: the latter counts only UNRESTRICTED
		# mana, so tapping Mishra's Workshop floated three colourless and
		# the panel still read all zeroes (2026-09 audit).
		if _mana_labels.size() == 2 and _mana_labels[pid] is Dictionary:
			var pool: ManaPool = game.players[pid].mana_pool
			for color in _mana_labels[pid]:
				_mana_labels[pid][color].text = str(pool.total_of(color))
	if _phase_bar != null:
		# "First and foremost, the current phase is always highlighted"
		# (manual p.116) — the highlight is the ONLY current-phase cue; the
		# red dots belong to the Stops.
		_phase_bar.set_state(
			PhaseStops.half_for_seat(game.active_player, _human_seat()),
			_phase_icon_slot(game.current_step()))
		_phase_bar.refresh_stops()
	# The status line owns the message bar whenever no interaction or
	# flashed refusal claims it (s30's statusMessage/warningMsg split).
	if mode == Mode.NORMAL and _pending_card == null \
			and Time.get_ticks_msec() >= _flash_until_ms:
		_prompt_label.text = _status_message()
		_clear_warning_ink()
	# Done doubles as the declaration Confirm (the original has no
	# separate buttons); light it up when it's the thing to click (§3.7).
	_pass_button.modulate = DONE_LIT if _done_applies() else Color.WHITE
	# ...and Cancel appears beside it only when there is something to
	# cancel — *"a Done button, a Cancel button, or both, depending on the
	# situation"* (§6.11).
	if _cancel_button != null:
		_cancel_button.visible = _can_cancel()
	# The table-wide toggle reads back the per-territory flags the menu
	# entries set. no_signal, or setting it here would re-enter the handler
	# that set the flags in the first place.
	if _arrange_button != null:
		_arrange_button.set_arranged(_arranged[0] and _arranged[1])

	# THE SPELL FLIGHT (§2.4) reads the chain BEFORE the rebuild, for two
	# reasons: its source rect is where the card was drawn LAST frame, and
	# the widgets built below have to know which cards are in the air so
	# they can leave them out (s30's `spellIsAnimating`).
	if _flight != null:
		_flight.note(game)
	# The Combat Bar and the Combat window resolve FIRST: the window takes
	# the creatures in combat out of their territories, so the board rebuild
	# below has to know what it is holding.
	_update_combat()
	_rebuild_stack()
	for pid in 2:
		_rebuild_field(pid)
	_rebuild_hand(1, _hand_rows[0])
	_rebuild_hand(0, _hand_rows[1])
	_update_arrows()
	_update_damage_markers()
	_repopulate_graveyard()
	# LAST: a standing Run to / Done order takes the duel as far as it can.
	# Here rather than in a blocking loop of its own, so that a run waiting
	# on an AI seat resumes the moment its pacing timer moves the game.
	_drive_advance()


## Where a spell that left the chain WITHOUT becoming a permanent went:
## its owner's graveyard pile (§2.4). s30 falls back the same way
## (`spellAnimationDestination` — the battlefield slot if there is one,
## otherwise the graveyard rect).
func _graveyard_rect(pid: int) -> Rect2:
	if _grave_icons.size() != 2 or _grave_icons[pid] == null:
		return Rect2()
	return TargetArrows.anchor_rect(_grave_icons[pid])


## Does [param pid]'s graveyard, exile or ante hold anything the pending
## cast could legally take? What rings the pile, and the only cue the
## player gets that the answer is not on the battlefield (§1.2).
func _pile_holds_a_target(pid: int) -> bool:
	if mode != Mode.TARGETING or _pending_slot >= _pending_slots.size():
		return false
	var spec: TargetSpec = _pending_slots[_pending_slot]["spec"]
	for zone in [game.players[pid].graveyard, game.players[pid].exile,
			game.players[pid].ante]:
		for inst in zone:
			if spec.is_legal(game, TargetRef.card(inst), _pending_card):
				return true
	return false


## The exile pile's hover text: the zone's own 1997 name and what is in it.
## A face-down card (Knowledge Vault) is listed but never named — nobody
## may look at it.
func _exile_tooltip(pid: int) -> String:
	var whose := "Your" if pid == _human_seat() else config.player_names[pid] + "'s"
	var gone := game.players[pid].exile
	if gone.is_empty():
		return "%s exiled cards (out of play) — empty" % whose
	var names := PackedStringArray()
	for card in gone:
		names.append("(face down)" if card.face_down else card.data.card_name)
	return "%s exiled cards (out of play)\n%s" % [whose, "\n".join(names)]


## The graveyard plate's tooltip — the twin of [method _exile_tooltip].
## The card names used to hang on the count Label instead, and a Label is
## MOUSE_FILTER_IGNORE by default, so nothing could ever reach them.
func _grave_tooltip(pid: int) -> String:
	var whose := "Your" if pid == _human_seat() else config.player_names[pid] + "'s"
	var pile := game.players[pid].graveyard
	if pile.is_empty():
		return "%s graveyard — empty" % whose
	var names := PackedStringArray()
	for dead in pile:
		names.append(dead.data.card_name)
	return "%s graveyard\n%s" % [whose, "\n".join(names)]


# =================================================== the combat furniture --

## Which seat the human is sitting in (seat 0 unless both are AI).
func _human_seat() -> int:
	return 0 if _is_human(0) else 1


## The board's rectangle — both halves together. The Combat window is laid
## out inside it so it never rides over the sidebar or the Phase Bar.
func _board_area() -> Rect2:
	var area := Rect2()
	for pid in 2:
		var rows: Control = _half_rows[pid]
		if rows == null or rows.get_parent() == null:
			continue
		var half: Rect2 = (rows.get_parent() as Control).get_global_rect()
		if half.size.x <= 0.0 or half.size.y <= 0.0:
			continue        # not laid out yet (boot, or a hidden screen)
		area = half if area.size == Vector2.ZERO else area.merge(half)
	if area.size == Vector2.ZERO:
		area = get_global_rect()
	return area


## THE LINEUP the Combat window holds: `[attacker_ids, blocker_ids]`.
##
## Attackers are the engine's own declarations plus whatever the player has
## added and not yet submitted; blockers likewise, plus the one creature
## picked but not yet pointed at an attacker (it is already out of the
## territory and waiting — "To make one of your creatures a blocker, click
## on it", manual p.127). Both lists follow their controller's battlefield
## order, so a lineup never reshuffles itself as it grows.
func _combat_lineup() -> Array:
	var attacker_ids: Array = []
	var blocker_ids: Array = []
	if game == null or not CombatBar.covers_step(game.current_step()):
		return [attacker_ids, blocker_ids]
	var attacking := game.active_player
	var defending := game.opponent_of(attacking)
	for inst in game.players[attacking].battlefield:
		if game.combat.attackers.has(inst.id) \
				or (mode == Mode.ATTACKERS and _selected_attackers.has(inst.id)):
			attacker_ids.append(inst.id)
	for inst in game.players[defending].battlefield:
		if game.combat.blocks.has(inst.id) or _block_map.has(inst.id) \
				or inst.id == _selected_blocker:
			blocker_ids.append(inst.id)
	return [attacker_ids, blocker_ids]


## Card ids the Combat window is currently showing — `_rebuild_field` skips
## these, because in the original a creature in combat is IN THE WINDOW and
## not also in its territory (see combat_window.gd). Empty while the window
## is closed or minimised.
var _windowed_ids: Dictionary = {}


## Swap the Phase Bar for the Combat Bar, and open, fill, or close the
## Combat window. Runs BEFORE the board rebuild so `_windowed_ids` is
## already right when `_rebuild_field` asks.
func _update_combat() -> void:
	var step: int = game.current_step()
	var in_combat := CombatBar.covers_step(step)
	# THE BAR FOLLOWS THE ATTACK, NOT THE PHASE (the owner's playtest,
	# 2026-09-03: *"If no attackers are declared the combat subphases
	# should not show"*). `Duel.hlp`, topic **Combat Bar**: it *"appears
	# during an ATTACK"* — see [method CombatBar.shows_attack], which is
	# the whole of the evidence. With no attack the Phase Bar stays up and
	# its combat icon carries the phase, exactly as it does for every other
	# phase the duel walks through without stopping.
	var attacking := CombatBar.shows_attack(step, game.awaiting_attackers,
		game.combat.attackers.size())
	if not in_combat:
		# A fresh attack always opens its window (manual p.126).
		_combat_minimized = false
	if _combat_bar != null and _phase_bar != null:
		# "the Combat Bar takes the place of the Phase Bar" — one column,
		# one bar visible at a time.
		_combat_bar.visible = attacking
		_phase_bar.visible = not attacking
		if attacking:
			# The sheet's BLUE half is the player's own attack and the GOLD
			# half the opponent's — the Phase Bar's colour convention, one
			# seat per column instead of one seat per half. The Stops it
			# draws are the ATTACKING seat's half, because these are that
			# seat's sub-phases.
			_combat_bar.set_state(game.active_player == _human_seat(),
				CombatBar.slot_for_step(step, game.awaiting_attackers,
					game.awaiting_blockers),
				PhaseStops.half_for_seat(game.active_player, _human_seat()))
	var lineup := _combat_lineup()
	# "As soon as you add the first creature to the attack, the Combat
	# window opens" — an attack with no attacker yet has no window.
	var open: bool = in_combat and not lineup[0].is_empty()
	var showing := open and not _combat_minimized
	_windowed_ids = {}
	if _combat_window != null:
		if showing:
			for id in lineup[0]:
				_windowed_ids[id] = true
			for id in lineup[1]:
				_windowed_ids[id] = true
			_combat_window.fit(_board_area())
			_combat_window.present(game, lineup[0], lineup[1],
				game.active_player, _human_seat())
		# Keep the window's own flag in step with ours FIRST — leaving it
		# stuck true after combat ended would make the next attack's
		# minimise button a no-op (its setter short-circuits on no change).
		_combat_window.minimized = _combat_minimized
		_combat_window.visible = showing
	if _window_icon != null and _bar_holder != null:
		_window_icon.visible = open and _combat_minimized
		# The strip's blank centre band: Winbk_Phase runs the opponent's
		# eight icons from y=2 and the player's from y=431 of 760.
		var scale_y: float = _bar_holder.size.y / CombatBar.SHEET_SIZE.y
		_window_icon.size = Vector2(39.0, 70.0)
		_window_icon.position = Vector2((_bar_holder.size.x - 39.0) * 0.5,
			380.0 * scale_y - 35.0)


## The window icon in the Phase Bar's centre band: `Restore`
## (`@MENU_MINIMIZEDATTACK`, UIStrings.txt:848).
func _on_window_icon_pressed() -> void:
	_combat_minimized = false
	if _combat_window != null:
		_combat_window.minimized = false
	_play_sfx("sfx_button")
	_refresh()


func _on_combat_minimized(is_minimized: bool) -> void:
	_combat_minimized = is_minimized
	_play_sfx("sfx_button")
	_refresh()


## A click on a Combat Bar icon. Two manual sentences meet here and they
## agree: p.126, *"Satisfied with the attack line-up? Use the Done option on
## the mini-menu, the Done button on the Situation Bar, or click a sub-phase
## on the Combat Bar"*, and `Duel.hlp`'s *"[the Combat Bar] functions in
## exactly the same way as the larger bar"* — on the larger bar a click is a
## **Run to**. With a declaration pending, running on IS submitting it; with
## none, the click is a plain run to that sub-phase.
func _on_combat_bar_slot(slot: int) -> void:
	if mode == Mode.ATTACKERS or mode == Mode.BLOCKERS:
		_on_done()
		return
	_order_run_to(PhaseStops.half_for_seat(game.active_player, _human_seat()),
		PhaseStops.Bar.COMBAT, slot)


## A click on a Phase Bar icon: *"You can move forward ('run') to any phase
## by clicking on the icon for that phase"* (manual p.116).
func _on_phase_bar_slot(half: int, slot: int) -> void:
	_order_run_to(half, PhaseStops.Bar.PHASE, slot)


func _on_phase_bar_context(half: int, slot: int, at: Vector2) -> void:
	_open_phase_menu(half, PhaseStops.Bar.PHASE, slot, at)


func _on_combat_bar_context(slot: int, at: Vector2) -> void:
	_open_phase_menu(
		PhaseStops.half_for_seat(game.active_player, _human_seat()),
		PhaseStops.Bar.COMBAT, slot, at)


# ------------------------------------------------- the @MENU_PHASEBAR menu --

## Which icon the open mini-menu belongs to, as `[half, bar, slot]`.
var _phase_menu_target: Array = []

## Item ids, in the table's own order (see [constant PhaseStops.MENU_ENTRIES]).
enum PhaseMenu { RUN_TO, MARK, HELP_PHASE, HELP }


## The mini-menu a right-click on a phase icon opens — the manual's own
## word for a context menu (p.110) — carrying `@MENU_PHASEBAR`'s four
## entries verbatim (`shandalar-src/Program/UIStrings.txt:947`).
##
## TWO DIVERGENCES, both recorded in docs/duel-todo.md §6.1:
##   * the 1997 table ships no "unmark" string, so **Mark this phase to
##     always stop** is a CHECK item that toggles — the tick is the only
##     thing added, and it is how the player takes a Stop off again;
##   * both `Help` entries are present and DISABLED, because there is no
##     Dueling Help yet (§6.20l). Showing them greyed says the menu is
##     complete and the help is missing; dropping them would say the
##     original's menu had two items.
func _open_phase_menu(half: int, bar: int, slot: int, at: Vector2) -> void:
	if _phase_menu == null:
		return
	_phase_menu_target = [half, bar, slot]
	_phase_menu.clear()
	_phase_menu.add_item(PhaseStops.MENU_RUN_TO, PhaseMenu.RUN_TO)
	_phase_menu.add_check_item(PhaseStops.MENU_MARK, PhaseMenu.MARK)
	_phase_menu.set_item_checked(
		_phase_menu.get_item_index(PhaseMenu.MARK),
		stops != null and stops.is_marked(half, bar, slot))
	_phase_menu.add_item(PhaseStops.MENU_HELP_PHASE, PhaseMenu.HELP_PHASE)
	_phase_menu.add_item(PhaseStops.MENU_HELP, PhaseMenu.HELP)
	for id in [PhaseMenu.HELP_PHASE, PhaseMenu.HELP]:
		_phase_menu.set_item_disabled(_phase_menu.get_item_index(id), true)
	_phase_menu.reset_size()
	_phase_menu.position = Vector2i(at) + Vector2i(6, 0)
	_phase_menu.popup()


func _on_phase_menu_chosen(id: int) -> void:
	if _phase_menu_target.size() != 3:
		return
	var half: int = _phase_menu_target[0]
	var bar: int = _phase_menu_target[1]
	var slot: int = _phase_menu_target[2]
	match id:
		PhaseMenu.RUN_TO:
			_order_run_to(half, bar, slot)
		PhaseMenu.MARK:
			var now := stops.toggle(half, bar, slot)
			stops.save()
			# A Stop set on the phase we are standing in takes hold at once:
			# "that phase does not end until you tell it to manually."
			if now:
				_cancel_advance()
			# Flashed over the Situation Bar (see the note in
			# _drive_advance): the confirmation is a moment, not a state.
			# No 1997 string exists for it — the original's own feedback is
			# the marker appearing on the bar, which ours does too.
			_report("%s: %s" % [
				_phase_menu_label(half, bar, slot),
				"Stop set" if now else "Stop removed"])
			_refresh()


## The name of one icon, for the message bar — its 1997 cue card.
func _phase_menu_label(half: int, bar: int, slot: int) -> String:
	if bar == PhaseStops.Bar.COMBAT:
		return CombatBar.TOOLTIPS[clampi(slot, 0, CombatBar.TOOLTIPS.size() - 1)]
	return PhaseBar.cue_card(half, slot,
		config.player_names[1 - _human_seat()])


# ------------------------------------------------ the @MENU_TERRITORY menu --

## Which territory the open menu belongs to (-1 = closed).
var _territory_menu_pid := -1

## Item ids: the fourteen `Go to:` entries keep their index in
## [constant TerritoryMenu.GO_TO]; the rest follow above [constant REST_BASE]
## so the two blocks can never collide.
const REST_BASE := 100


func _on_territory_input(event: InputEvent, pid: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	# Not under a centre popup (the X dialog has no scrim, and `Go to:`
	# used to pass priority with a half-built cast hanging), and not
	# under the coin toss, where Concede ended a duel that had not begun.
	if _toss_active or _modal_open():
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		_open_territory_menu(pid, mb.global_position)


## `Duel.hlp`, topic **Territory**: *"When you right-click on either
## territory, a mini-menu pops open."* Either — the opponent's half opens
## the same menu, which is why `Arrange opponent's cards` exists at all.
func _open_territory_menu(pid: int, at: Vector2) -> void:
	if _territory_menu == null:
		return
	_territory_menu_pid = pid
	_territory_menu.clear()
	for i in TerritoryMenu.GO_TO.size():
		_territory_menu.add_item(TerritoryMenu.GO_TO[i]["label"], i)
	_territory_menu.add_separator()
	for i in TerritoryMenu.REST.size():
		var entry: Dictionary = TerritoryMenu.REST[i]
		var id := REST_BASE + i
		# The two Arrange entries are CHECK items for the same reason the
		# Stops' Mark is one: the 1997 table ships no "unarrange" string, so
		# the tick is the only thing added and it is how the command is
		# taken off again (§6.1's precedent). The three display toggles are
		# check items because they ARE toggles.
		if i < 2:
			_territory_menu.add_check_item(TerritoryMenu.rest_label(entry), id)
			_territory_menu.set_item_checked(
				_territory_menu.get_item_index(id),
				_arranged[_menu_seat() if i == 0 else 1 - _menu_seat()])
		elif entry.has("toggle"):
			_territory_menu.add_check_item(TerritoryMenu.rest_label(entry), id)
			_territory_menu.set_item_checked(
				_territory_menu.get_item_index(id),
				DuelOptions.toggle(String(entry["toggle"])))
			# The accelerator the table writes after its tab, for the live
			# toggles only (§6.3a) — `Ctrl+I` stays quiet while its command
			# stays dark.
			_territory_menu.set_item_accelerator(
				_territory_menu.get_item_index(id),
				DuelOptions.menu_toggle_accelerator(String(entry["toggle"])))
		else:
			_territory_menu.add_item(TerritoryMenu.rest_label(entry), id)
		if not TerritoryMenu.rest_is_live(entry):
			_territory_menu.set_item_disabled(
				_territory_menu.get_item_index(id), true)
	_territory_menu.reset_size()
	_territory_menu.position = Vector2i(at) + Vector2i(6, 0)
	_territory_menu.popup()


## WHOSE menu is it? "My cards", and the Concede that follows, belong to
## the seat whose territory was right-clicked — when a human sits there.
## At a hotseat both do, and [method _human_seat] (seat 0 whenever seat 0
## is human) made every Concede seat 0's and every "Arrange my cards" seat
## 0's, whichever half the second player had clicked (2026-09-02). Against
## the AI, its territory's menu still speaks for the human.
func _menu_seat() -> int:
	if _is_human(_territory_menu_pid):
		return _territory_menu_pid
	return _human_seat()


func _on_territory_menu_chosen(id: int) -> void:
	if id < REST_BASE:
		_order_go_to(id)
		return
	var index := id - REST_BASE
	var entry: Dictionary = TerritoryMenu.REST[index] if index >= 0 \
		and index < TerritoryMenu.REST.size() else {}
	if entry.has("toggle"):
		_flip_display_toggle(String(entry["toggle"]))
		return
	match index:
		0: _arrange_seat(_menu_seat(), not _arranged[_menu_seat()])
		1: _arrange_seat(1 - _menu_seat(), not _arranged[1 - _menu_seat()])
		2: _open_duel_options()
		6: _minimize_window()
		8: _ask_to_concede()


## One of the three display toggles ([constant DuelOptions.MENU_TOGGLES]),
## flipped and applied. They are settings, so they persist the way every
## other duel switch does — *"These settings are retained for future
## duels"* (`Duel.hlp`, **Dueling Options**) — and the whole table is
## repainted, because that is where both of them are drawn.
func _flip_display_toggle(key: String) -> void:
	DuelOptions.set_toggle(key, not DuelOptions.toggle(key))
	_refresh()


## `Ctrl+T` / `Ctrl+I` / `Ctrl+U` — the accelerators `@MENU_TERRITORY`
## entries 18-20 write after their tab (`UIStrings.txt:927-929`; the same
## three on `@MENU_SMALLCARD`). ONE ROUTE with the menus, so the two can
## never disagree: [method _flip_display_toggle], which reads and writes
## the one setting both menus draw their check marks from. A dark command
## stays dark from the keyboard too — the menu's own grey is the message,
## so this says nothing (§6.3a) — and the keys fire only while the TABLE
## is what the player is looking at: not under a modal popup, and not
## under one of the duel's own windows either.
func _accelerate_toggle(key: String) -> void:
	if _modal_open() or _dialogs_open():
		return
	if not DuelOptions.menu_toggle_live(key):
		return
	_flip_display_toggle(key)


## Is one of the duel's own [OriginalDialog] windows up — the concede
## question, Duel Options, the End of Duel window? Deliberately NOT folded
## into [method _modal_open]: these windows are not part of the cast chain,
## so they are no rung of the cancel ladder and no reason for the bar to
## show Cancel. The display accelerators ask this (§6.3a), and so do Return
## and Space — under those windows *"the dialog's own OK answers it"*, and
## until 2026-09-02 a Return under the concede question fell through to a
## standing Done order instead, because no dialog button holds focus.
func _dialogs_open() -> bool:
	for child in get_children():
		if child is OriginalDialog and not child.is_queued_for_deletion():
			return true
	return false


## `Minimize` — `@MENU_TERRITORY` entry 21. `Duel.hlp`, **Territory**:
## *"shrinks the **Magic: The Gathering** window so that you can
## temporarily pursue other Windows functions."* It is the OS window, not
## anything on the table, which is why it does nothing headless.
func _minimize_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


# ------------------------------------------------ THE PAUSE WINDOW (Q/Esc) --
#
# The owner's playtest, 2026-09-03: *"When a player types Q or ESC keys
# during a duel, a menu should pop up with buttons: concede the duel (you
# lost), exit duel (return to duel config), return to main menu, exit
# game"*, and then *"And another button: return to game. Pressing Q or ESC
# again would close the menu. The menu should be named Pause on top!"*
#
# `[QoL]` — the 1997 duel has no pause and no menu on any key (see
# [DuelPause] and `docs/ROADMAP.md`). The window itself is [DuelPause],
# which wears [VersusPanel]'s marble; what is here is the five actions and
# the key contract.
#
# THE KEY CONTRACT, and Esc keeps its 1997 job first. *"Esc is just like
# Cancel"*, and the 2026-09-02 cancel ladder (`tests/ui/test_cancel_contract.gd`)
# depends on it, so the precedence is:
#
#   1. the Pause window is OPEN      -> Esc (or Q) closes it;
#   2. there is something to cancel  -> Esc cancels it ([method _on_escape]);
#   3. nothing pending               -> Esc opens the Pause window.
#
# `Q` carries no 1997 duty at all, so it opens and closes unconditionally.
# Neither key does anything under the coin toss and the opening hand,
# which [method _unhandled_key_input] has refused every key since
# 2026-09-02.

## Is the Pause window up? Public, because it is what "the duel is standing
## still" MEANS: [method _modal_open] counts it, so the automatic pass, the
## card clicks, the territory menus, the order buttons and Return/Space all
## stop with it, and [method _maybe_schedule_ai] stops the AI's clock.
func is_paused() -> bool:
	return _pause_menu != null and is_instance_valid(_pause_menu)


## Q, and Esc with nothing to cancel: open the window, or close the one
## that is open.
func _toggle_pause() -> void:
	if is_paused():
		_close_pause()
	else:
		_open_pause()


func _open_pause() -> void:
	if is_paused() or game == null or _toss_active:
		return
	var menu := DuelPause.new()
	menu.z_index = 270          # over the splash's 260 and the toss's 250
	# IN THE TREE FIRST, then built — `build` grabs focus for `Return to
	# game`, and a node outside the tree cannot take focus. The same order
	# [method _run_intro] needs, and for the same reason.
	add_child(menu)
	menu.build(config)
	menu.chosen.connect(_on_pause_chosen)
	_pause_menu = menu
	_refresh()


func _close_pause() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	# Cleared BEFORE the refresh, and before the free actually happens:
	# `queue_free` is deferred, so [method is_paused] has to stop being
	# true on this line or the refresh below would run as if still paused
	# and leave every clock stopped.
	_pause_menu = null
	_refresh()


func _on_pause_chosen(action: int) -> void:
	match action:
		DuelPause.Action.RESUME:
			_close_pause()
		DuelPause.Action.CONCEDE:
			# Never without the question. Losing a duel to a mis-key is the
			# worst thing this window can do, and the original already has
			# the confirmation for it — `@MENU_TERRITORY` entry 25, the
			# same `Yes, I'm sure` the territory menu's own Concede opens
			# ([method _ask_to_concede]). One window, not a second copy.
			_close_pause()
			_territory_menu_pid = -1     # this concede is the HUMAN's
			_ask_to_concede()
		DuelPause.Action.EXIT_DUEL:
			_close_pause()
			get_tree().change_scene_to_file("res://game/setup_screen.tscn")
		DuelPause.Action.MAIN_MENU:
			_close_pause()
			get_tree().change_scene_to_file("res://game/main.tscn")
		DuelPause.Action.QUIT:
			get_tree().quit()


## `Concede` → `Yes, I'm sure` — `@MENU_TERRITORY` entries 24 and 25.
## *"You must confirm this decision."*
func _ask_to_concede() -> void:
	if _concede_dialog != null and is_instance_valid(_concede_dialog):
		return
	_concede_dialog = TerritoryMenu.concede_window()
	_concede_dialog.add_button(TerritoryMenu.CONCEDE_CONFIRM) \
		.pressed.connect(_confirm_concede)
	_concede_dialog.add_button("Cancel").pressed.connect(
		func() -> void: _concede_dialog.dismiss())
	_concede_dialog.closed.connect(func() -> void: _concede_dialog = null)
	add_child(_concede_dialog)


func _confirm_concede() -> void:
	var seat := _menu_seat()
	if _concede_dialog != null and is_instance_valid(_concede_dialog):
		_concede_dialog.dismiss()
	_report(game.concede(seat))
	_refresh()


# --------------------------------------- the rest of the mini-menus (§6.12) --
#
# The tables and the evidence are in [CardMenu]; what is here is the
# wiring. Every one of them obeys `Duel.hlp`'s **Territory** rule —
# *"Depending on the situation, one or more of these options is
# available"* — by GREYING what we cannot offer rather than dropping it,
# so each menu reads as complete and the missing features read as missing.

## Build one mini-menu in the duel's own stone and voice.
func _dress_menu(handler: Callable, menu_font: Font) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.id_pressed.connect(handler)
	menu.add_theme_stylebox_override("panel",
		OriginalDialog.panel_style("panel_dark_stone", 6.0))
	menu.add_theme_color_override("font_color", OriginalDialog.CHOICE)
	menu.add_theme_color_override("font_hover_color", OriginalDialog.CHOICE_LIT)
	if menu_font != null:
		menu.add_theme_font_override("font", menu_font)
	menu.add_theme_font_size_override("font_size", 14)
	add_child(menu)
	return menu


func _popup_menu_at(menu: PopupMenu, at: Vector2) -> void:
	menu.reset_size()
	menu.position = Vector2i(at) + Vector2i(6, 0)
	menu.popup()


## `@MENU_SMALLCARD` — a right-click on a card, the gesture `Duel.hlp`
## names in the same breath as the lift: *"Right-clicking on a card also
## opens a mini-menu"*, and *"You can also right-click and HOLD to bring a
## card in your hand to the front for as long as you hold the mouse
## button."* Both live on the same button, and the HOLD is what tells them
## apart — see [method _on_card_look].
## `Don't auto tap this card` is entry 4 of `@MENU_SMALLCARD`.
const CARD_MENU_NO_AUTO_TAP := 3


func _open_card_menu(inst: CardInstance, at: Vector2) -> void:
	_card_menu_inst = inst
	CardMenu.build(_card_menu, CardMenu.SMALL_CARD)
	# The mark is a property of THIS card, so its tick and its greying are
	# settled here: only a permanent that makes mana has anything to lock.
	var at_lock := _card_menu.get_item_index(CARD_MENU_NO_AUTO_TAP)
	if at_lock >= 0:
		var lockable := inst.zone == Mtg.Zone.BATTLEFIELD \
			and _is_human(inst.controller_id) \
			and not inst.cur_mana_abilities.is_empty()
		_card_menu.set_item_disabled(at_lock, not lockable)
		_card_menu.set_item_checked(at_lock, _no_auto_tap.has(inst.id))
	_popup_menu_at(_card_menu, at)


func _on_card_menu_chosen(id: int) -> void:
	if _card_menu_inst == null or id < 0 or id >= CardMenu.SMALL_CARD.size():
		return
	var row: Dictionary = CardMenu.SMALL_CARD[id]
	if row.has("toggle"):
		_flip_display_toggle(String(row["toggle"]))
		return
	match id:
		# `Original type` and `Show full card` are the same view for us and
		# that is the ORIGINAL's doing, not a shortcut: *"the Showcase
		# always displays the original card, except for the text"*
		# (`Duel.hlp`, **Showcase**), so the Showcase IS the original type.
		# §2.12's stamp reads the entry the same way.
		0, 1:
			if _card_preview != null:
				_card_preview.show_card(_card_menu_inst)
		CARD_MENU_NO_AUTO_TAP:
			# *"marks a land to be ignored — not tapped for mana — when you
			# auto-cast any spell or effect. The only way to tap a locked
			# land is manually, by clicking on it"* (`Duel.hlp`, topic
			# **Territory**). Toggles, for the same reason the Stops'
			# `Mark` does: the 1997 table ships no un-mark string.
			if _no_auto_tap.has(_card_menu_inst.id):
				_no_auto_tap.erase(_card_menu_inst.id)
				_report("%s: auto tap on" % _card_menu_inst.data.card_name)
			else:
				_no_auto_tap[_card_menu_inst.id] = true
				_report("Don't auto tap this card: %s"
					% _card_menu_inst.data.card_name)
			_refresh()


## A right-click on a deck stack opens `@MENU_LIBRARY`; a left click
## falls through to whatever the stack already did (nothing).
func _on_pile_input(event: InputEvent, pid: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		_open_library_menu(pid, mb.global_position)


## A right-click anywhere in the mana column opens `@MENU_MANAPOOL`.
func _on_mana_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		_open_mana_menu(mb.global_position)


## A right-click on the Showcase opens `@MENU_FULLCARD` — *"Right-click on
## the text area, then click on the Expand toggle."*
func _on_showcase_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		_open_full_card_menu(mb.global_position)


## A right-click on the Attack window opens `@MENU_ATTACK`.
func _on_attack_window_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		_open_attack_menu(mb.global_position)


## `@MENU_LIBRARY` — a right-click on a deck stack. *"The number of cards
## left in your library is represented inexactly, as in real life. If you
## must know, you can right-click on a library to find out the exact
## number of cards left in it."*
func _open_library_menu(pid: int, at: Vector2) -> void:
	_library_menu.set_meta("pid", pid)
	CardMenu.build(_library_menu, CardMenu.LIBRARY)
	_popup_menu_at(_library_menu, at)


func _on_library_menu_chosen(id: int) -> void:
	if id != 0:
		return
	var pid := int(_library_menu.get_meta("pid", _human_seat()))
	# `@CUECARD_OTHER` (`UIStrings.txt:673`) is where the two libraries get
	# their names: `Your library` and `%s library`.
	var whose := "Your library" if pid == _human_seat() \
		else "%s library" % game.players[pid].player_name
	_set_prompt("%s: %d cards" % [whose, game.players[pid].library.size()])


## A right-click on a hand WINDOW (not on a card in it — a card has its
## own menu) opens `@MENU_HAND`.
func _on_hand_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		_open_hand_menu(mb.global_position)


## `@MENU_HAND` and `@MENU_MANAPOOL` — both complete, both entirely
## greyed. They answer the gesture rather than swallowing it, which is the
## point of listing a menu you cannot yet fill.
func _open_hand_menu(at: Vector2) -> void:
	CardMenu.build(_hand_menu, CardMenu.HAND)
	_popup_menu_at(_hand_menu, at)


func _open_mana_menu(at: Vector2) -> void:
	CardMenu.build(_mana_menu, CardMenu.MANA_POOL)
	_popup_menu_at(_mana_menu, at)


## `@MENU_FULLCARD` — the SHOWCASE's own menu, and its one live entry is
## the `Expand` toggle the help file describes.
func _open_full_card_menu(at: Vector2) -> void:
	CardMenu.build(_full_card_menu, CardMenu.FULL_CARD)
	var at_index := _full_card_menu.get_item_index(0)
	_full_card_menu.set_item_as_checkable(at_index, true)
	_full_card_menu.set_item_checked(at_index,
		bool(Settings.get_value("ExpandTextBoxOnBigCard", false)))
	_popup_menu_at(_full_card_menu, at)


func _on_full_card_menu_chosen(id: int) -> void:
	if id != 0:
		return
	var on := not bool(Settings.get_value("ExpandTextBoxOnBigCard", false))
	Settings.set_value("ExpandTextBoxOnBigCard", on)
	if _card_preview != null:
		_card_preview.set_text_expanded(on)


## `@MENU_ATTACK` / `@MENU_MINIMIZEDATTACK` — the Attack window's own
## menu, and the menu of the icon it shrinks to. One entry each, and both
## actions already existed.
func _open_attack_menu(at: Vector2) -> void:
	CardMenu.build(_attack_menu,
		CardMenu.MINIMIZED_ATTACK if _combat_minimized else CardMenu.ATTACK)
	_popup_menu_at(_attack_menu, at)


func _on_attack_menu_chosen(id: int) -> void:
	if id == 0:
		_on_combat_minimized(not _combat_minimized)


## `Duel Options...`, entry 17 of `@MENU_TERRITORY` (§6.4). Everything in
## the panel writes its setting the moment it is touched, so closing it is
## the only thing this has to react to — and what it reacts WITH is a full
## redress: the territory ground, the small cards' badges and P/T, and the
## cue-card tooltips are all rebuilt from the new values.
func _open_duel_options() -> void:
	if _options_dialog != null and is_instance_valid(_options_dialog):
		return
	_options_dialog = DuelOptions.window()
	_options_dialog.closed.connect(_on_duel_options_closed)
	add_child(_options_dialog)


func _on_duel_options_closed() -> void:
	_options_dialog = null
	# The territory ground is built once, in _build_ui, so a colour or
	# style change has to be painted onto the live halves.
	for pid in 2:
		_redress_territory(pid)
	_refresh()


## THE GROUND NODE for one half — `Your territory background` (§6.4).
##
## The PLAYER's half answers to the two lists in the Duel Options panel
## (and to the same pair on the battle-setup screen, which writes the same
## two settings); the opponent's never does — `Duel.hlp`, **Dueling
## Options**: *"You cannot do anything to change the background in your
## opponent's territory; it matches the predominant color in her deck."*
##
## [TerritoryGround] decides how the chosen style is drawn — a framed
## pattern nine-patches, a wallpaper of mana symbols tiles, a line drawing
## covers — and paints one itself when the 1997 art is absent, so this
## always gets a node back.
func _ground_node(pid: int) -> Control:
	var ground := TerritoryGround.node(
		DuelOptions.ground_color_for(pid, _human_seat(),
			config.panel_colors[pid]),
		DuelOptions.territory_type())
	ground.modulate = GROUND_DIM
	return ground


## Repaint one half's ground from the current Duel Options (§6.4). The
## node is REPLACED rather than repointed: the three styles are drawn by
## different kinds of Control (a nine-patch, a tiled rect, a covering
## rect), so changing the style changes the node.
func _redress_territory(pid: int) -> void:
	var rows: Control = _half_rows[pid]
	if rows == null:
		return
	var holder: Control = rows.get_parent()
	if holder == null:
		return
	for child in holder.get_children():
		if child != rows:
			holder.remove_child(child)
			child.queue_free()
	var ground := _ground_node(pid)
	holder.add_child(ground)
	holder.move_child(ground, 0)


## One `Go to:` entry. Thirteen of them are the SAME destinations **Run
## to** already reaches from the bars, resolved through the same driver —
## the menu is the reading route to them, not a second mechanism. The
## fourteenth, `Go to: next phase`, is the original's other verb: *"ends
## the current phase and moves you on to the next one."*
func _order_go_to(index: int) -> void:
	if index < 0 or index >= TerritoryMenu.GO_TO.size():
		return
	var entry: Dictionary = TerritoryMenu.GO_TO[index]
	if int(entry["where"]) == TerritoryMenu.Where.NEXT_PHASE:
		_order_next_phase()
		return
	var here: int = _phase_key()[0]
	_order_run_to(TerritoryMenu.half_for(entry, here),
		int(entry["bar"]), int(entry["slot"]))


## Feed the arrow layer, LAST — every card widget it anchors on was just
## rebuilt above, so the arrows must be worked out after the rebuild, not
## before it (target_arrows.gd resolves the actual pixels at draw time).
func _update_arrows() -> void:
	if _arrows == null:
		return
	var picked: Array = []
	var aiming: CardInstance = null
	if mode == Mode.TARGETING:
		aiming = _pending_card
		for group in _pending_groups:
			picked.append_array(group)
	_arrows.rebuild(game, _block_map, aiming, picked)


## THE DAMAGE MARKERS (§6.20b). One yellow card per packet waiting in an
## open prevention window, anchored on whatever the damage is aimed at.
##
## The layer is told which packets the pending cast MAY take and which it
## already HAS, so a marker wears the same frame a card would in the same
## situation — [constant MiniCard.Highlight.TARGET_LEGAL] while it is a
## legal choice, TARGET_CHOSEN once picked. Both lists are empty unless a
## [constant TargetSpec.Kind.DAMAGE] slot is actually open, which is what
## keeps the markers quiet the rest of the time: they are still on the
## table (the player has to see what is coming), just not lit.
func _update_damage_markers() -> void:
	if _damage_markers == null:
		return
	var legal: Array = []
	var chosen: Array = []
	var slot := _damage_slot()
	if not slot.is_empty():
		var spec: TargetSpec = slot["spec"]
		for ref in spec.legal_targets(game, _pending_card):
			legal.append(ref.packet_id)
		for ref in _pending_groups[_pending_slot]:
			if ref.is_damage:
				chosen.append(ref.packet_id)
	_damage_markers.rebuild(game, not slot.is_empty(), legal, chosen)


## The open targeting slot, when it is one that wants DAMAGE — otherwise
## an empty dictionary. Both the marker highlighting and the 1997 prompt
## ask the same question, so they ask it in one place.
func _damage_slot() -> Dictionary:
	if mode != Mode.TARGETING or _pending_slot >= _pending_slots.size():
		return {}
	var slot: Dictionary = _pending_slots[_pending_slot]
	if slot["spec"].kind != TargetSpec.Kind.DAMAGE:
		return {}
	return slot


## A damage marker was clicked — the 1997 gesture `Duel.hlp` describes
## three times over (*"click on any valid target — a card, a damage
## marker, or whatever"*). It goes down exactly the path a card click
## does; only the ref's arm differs.
func _on_damage_marker_clicked(packet: DamagePacket) -> void:
	if game == null or game.game_over:
		return
	if mode != Mode.TARGETING:
		return
	_try_take_target(TargetRef.damage(packet))


## The 1997 words for a chain object, from the tags the original captions
## its chain objects with — and NOT from `Legacy.csv`'s per-card
## `Effect Title` column, which is where the reference screenshot's
## *"Ability Effect"* actually comes from (row `0539,"Urza's Avenger"`;
## `windows.c:1533` reads `effect_title_text` for csvid 903 effect cards).
## We carry no effect-card table, so the generic captions are the ones we
## can say truthfully:
##
##     @PROMPT_CAST1  Program/UIStrings.txt:1118  %s casts...
##                                                %s casts...\nX is %d.
##     @PROMPT_TAP1                        :1123  %s activates...
##     @PROMPT_PROC1                       :1134  %s processes...
##
## The `%s` is the PLAYER: `src/functions/events.c:563` loads
## `PROMPT_PROC1` and fills it with `opponent_name`. Each tag's SECOND
## line is the X variant — the original puts an X spell's chosen value on
## the chain object itself, which is why our own `x_value` rides here.
func _chain_caption(item: StackItem) -> String:
	var who: String = game.players[item.controller].player_name
	var line := "%s casts..." % who
	match item.kind:
		Mtg.StackKind.ABILITY:
			line = "%s activates..." % who
		Mtg.StackKind.TRIGGER:
			line = "%s processes..." % who
	if item.x_value > 0:
		line += "\nX is %d." % item.x_value
	return line


func _rebuild_stack() -> void:
	# THE SPELL CHAIN — waiting spells and abilities as SMALL CARDS
	# floating at the board's left (`@WINDOWTITLES[2]` = `Spell Chain`;
	# s30: Winbk_Spellchain).
	#
	# A CHAIN OBJECT IS A CARD LIKE EVERY OTHER CARD. The original has one
	# card size and one card widget for the whole duel:
	# `set_smallcard_size(mainwindow_width)` (`windows.c:1088`) writes a
	# single global `smallcard_width`/`smallcard_height`, and every chain
	# object goes through `DrawSmallCard` + `DrawSmallCardTitle` — the
	# same pair the battlefield uses. So this is a [MiniCard] at
	# [constant MiniCard.SIZE], unscaled, like the table, the hand, the
	# piles and the graveyard shelves (tests/ui/test_card_dimensions.gd).
	# It is also why the NAME is no longer written into the caption: the
	# small card titles itself, exactly as `DrawSmallCardTitle` does.
	_clear_children(_chain_box)
	var chain_root: Control = _chain_box
	if _chain_box.get_parent() is PanelContainer:
		chain_root = _chain_box.get_parent()
	chain_root.visible = not game.stack.is_empty()
	for item in game.stack:
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 0)
		# The TAN band over the card — the reference's gold `Ability
		# Effect` strip, which in the original is an effect card's own
		# title bar peeking above the card it belongs to.
		var caption_box := PanelContainer.new()
		var caption_style := StyleBoxFlat.new()
		caption_style.bg_color = Color(0.80, 0.72, 0.52)
		caption_style.border_color = Color(0.42, 0.32, 0.18)
		caption_style.set_border_width_all(1)
		caption_style.set_content_margin_all(3)
		caption_box.add_theme_stylebox_override("panel", caption_style)
		var caption := Label.new()
		caption.text = _chain_caption(item)
		# Wrapped and pinned to the card's width so a long player name
		# widens the BAND's line count, never the strip: the entry is one
		# card wide, and the card is the thing that sets the width.
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.custom_minimum_size.x = MiniCard.SIZE.x - 8
		caption.add_theme_font_size_override("font_size", 10)
		caption.add_theme_color_override("font_color", Color(0.16, 0.11, 0.06))
		caption_box.add_child(caption)
		entry.add_child(caption_box)
		# The card itself — fully wired by _make_card: clickable (which is
		# how a counterspell TAKES a chain object as its target, through
		# `_on_card_clicked` → `_try_take_target`), hover-docked in the
		# Showcase, highlighted and cued like any other card.
		var w := _make_card(item.card, item)
		entry.add_child(w)
		# The chain object's description (its TARGETS) on top of the card's
		# own tooltip. A `Button` stops Godot's tooltip walk at itself, so
		# the entry's copy below would never be reached over the card.
		w.tooltip_text = "%s\n%s" % [item.description, w.tooltip_text]
		entry.tooltip_text = item.description
		_chain_box.add_child(entry)


## Cards per battlefield pile — the original groups lands and other
## permanents into strip-stack windows of about this many (reference:
## "Black Vise / Library of Leng / Howling Mine / Ivory Tower").
const PILE_SIZE := 5


func _rebuild_field(pid: int) -> void:
	# A rebuild frees every widget on the board, including one the player
	# is holding to the front with the right button (§2.15) — the release
	# would arrive at a dead object, so let go of it here.
	_drop_lifted_card()
	# ...and one being DRAGGED (§2.3b): its placement is committed where it
	# stands rather than lost, so a state change mid-drag cannot swallow it.
	_commit_drag(false)
	var by_row := {Row.LANDS: [], Row.OTHER: [], Row.CREATURES: []}
	for inst in game.players[pid].battlefield:
		# Attached auras don't get their own slot — they render as bands
		# stacked over their host (s30: attachedPerms, -14px per aura).
		if inst.attached_to != -1:
			continue
		# A creature in combat has LEFT its territory for the Combat window
		# (combat_window.gd). Minimising the window sends the lineup back to
		# the board — [QoL]: the original leaves it hidden inside the icon,
		# but a lineup nobody can see is not a lineup, and minimising exists
		# precisely to look at the board underneath.
		if _windowed_ids.has(inst.id):
			continue
		# A card the player has MOVED lives in the free layer instead
		# (§2.3b) — the rows must not lay it out as well.
		if _placements.has(inst.id):
			continue
		if inst.is_creature():
			by_row[Row.CREATURES].append(inst)
		elif inst.is_land():
			by_row[Row.LANDS].append(inst)
		else:
			by_row[Row.OTHER].append(inst)
	for row in by_row:
		var container: Container = _field_rows[pid][row]
		_clear_children(container)
		if row == Row.CREATURES:
			# Creatures stay individual mini-cards — combat must read.
			for inst in _display_order(pid, by_row[row], row):
				container.add_child(_make_widget(inst))
			continue
		# Lands and other permanents group into the original's piles. The
		# arrange runs BEFORE the slicing, or the piles would re-shuffle
		# their membership every time a land taps.
		var cards: Array = _display_order(pid, by_row[row], row)
		var i := 0
		while i < cards.size():
			var chunk := cards.slice(i, i + PILE_SIZE)
			if chunk.size() == 1:
				container.add_child(_make_widget(chunk[0]))
			else:
				var pile := CardPile.new()
				pile.preview = _card_preview
				pile.framed = true   # the original's tan window border
				# A permanent in a pile carries the same "you may act on
				# this" ring an unpiled one does — and while a cast waits
				# for its mana that ring IS the prompt, on cards that are
				# nearly always piled (see CardPile.glow_actionable).
				pile.glow_actionable = true
				pile.populate(chunk, false, _on_card_clicked, _highlight_for)
				_arm_pile_drag(pile)
				# The row sizes by minimum size; the pile computed its own.
				container.add_child(pile)
			i += PILE_SIZE
	_rebuild_placed(pid)


## THE CARDS THE PLAYER HAS MOVED (§2.3b), drawn absolutely over the rows
## in the order they were last touched — so the one just moved is on top.
## Placements of cards that have left the battlefield are dropped here,
## which is the only pruning the dictionary needs.
func _rebuild_placed(pid: int) -> void:
	var layer: Control = _free_layers[pid]
	if layer == null:
		return
	_clear_children(layer)
	var live: Dictionary = {}
	for inst in game.players[pid].battlefield:
		live[inst.id] = inst
	for id in _placements.keys():
		var inst: CardInstance = live.get(id)
		if inst == null:
			if game.find_instance(id) == null \
					or game.find_instance(id).zone != Mtg.Zone.BATTLEFIELD:
				_placements.erase(id)   # it left the table; so does its seat
			continue
		if inst.attached_to != -1 or _windowed_ids.has(id):
			continue
		# NORMALISE ON THE WAY OUT as well as on the way in: an aura that
		# attached, a half that shrank or a placement written before the
		# first layout pass all reach the boundary here, so the dictionary
		# and what the player can see never drift apart.
		var at: Vector2 = _clamp_in_half(pid, _placements[id], inst)
		_placements[id] = at
		var w := _make_widget(inst)
		w.position = at
		layer.add_child(w)


## The opponent's hand window title. `@WINDOWTITLES` (`UIStrings.txt:155`)
## gives it the single word **`Opponent`** — s30's `Opp Hand` is s30's, and
## `docs/duel-todo.md` §9.1 has listed ours as wrong since the thirty-fourth
## pass. The count in brackets is [QoL], in the same form the player's own
## `Your hand (N)` uses, and it is the whole reason manual p.114 gives for
## showing this bar: *"to keep you aware of how many cards are in that
## hand."* The ▲ / ▼ are NOT in the text — they are painted into the
## `hand_panel_<colour>` sheet itself.
const OPPONENT_HAND_TITLE := "Opponent (%d)"


func _rebuild_hand(pid: int, container: Control) -> void:
	var hidden := hidden_hands.has(pid)
	if container is StackHand:
		container.populate(_hand_order(pid), hidden,
			_on_card_clicked, _highlight_for)
		_arm_hand_auto_cast(container)
		return
	_clear_children(container)
	# Hidden opponent hand: the original shows THE HAND WINDOW'S TITLE BAR
	# and nothing under it — manual p.114, *"Only the title bar of your
	# opponent's hand is visible; this is to keep you aware of how many
	# cards are in that hand."* Never a row of card backs.
	#
	# It is built by StackHand itself ([method StackHand.title_plate]) so it
	# is the SAME window as the player's own — same nine-patch, same patch
	# margins, same label placement. It used to be a disabled Button wearing
	# the raw 145x51 sheet as an unpatched StyleBoxTexture at 150x22, which
	# squashed the whole window into a strip and crushed the ▲ painted into
	# its left edge (the owner's "cropped at left end"), and then wrote its
	# own ↑ ↓ on top of the pair the sheet already paints.
	if hidden:
		container.add_child(StackHand.title_plate(config.panel_colors[pid],
			OPPONENT_HAND_TITLE % game.players[pid].hand.size()))
		return
	for inst in _hand_order(pid):
		container.add_child(_make_widget(inst))
	if container is FanHand:
		container.relayout()


# ----------------------------- THE DOUBLE-CLICK IN THE HAND (§6.20c) --
#
# The owner's playtest, 2026-09-04: *"I cannot double-click a castable
# card and lands do not automatically auto-tap."*
#
# THE AUTO-CAST WAS BUILT AND IT WAS UNREACHABLE. [method _auto_cast] is
# called from exactly one place — [method _on_card_look], which
# [method _make_card] connects to a [MiniCard]'s own `gui_input`. That
# covers the battlefield and the FAN hand, both of which are rows of
# MiniCards. It does not cover the STACK hand, which is the original's
# window, the default (`Settings.hand_style`) and the one the owner
# plays with: a [StackHand] is a [CardPile], and a pile draws each card
# as a `MOUSE_FILTER_IGNORE` picture inside a holder `Button` carrying
# `pressed` and NOTHING ELSE. Nothing in that chain ever looks at
# `double_click`, so the gesture could not fire however hard it was
# clicked. Measured under Xvfb with real press/release/press/release
# before this fix: the row's `pressed` fired twice, `_pending_card` was
# the spell, `mode` was PAYING — and `tapped=0`, `stack=0`. The first
# click worked; the second was an ordinary click for the second time.
#
# (The yellow name was never the problem: the same probe read
# `could_afford=true` and `Highlight.CASTABLE` on the same card.)
#
# ARMED FROM HERE, like the pile drag beside it, because `card_pile.gd`
# belongs to another pass today. It hangs on the pile's
# `child_entered_tree` rather than on a sweep after `populate`, and that
# is load-bearing rather than tidy: the FIRST click rebuilds the board,
# which frees the very holder the second click is about to land on, and
# `StackHand._set_collapsed` re-populates without going through
# [method _rebuild_hand] at all. A row armed as it enters the tree is
# armed whoever built it and however often.


## Give every row of the player's hand window the double-click (§6.20c).
func _arm_hand_auto_cast(hand: Control) -> void:
	var pile: CardPile = null
	for child in hand.get_children():
		if child is CardPile:
			pile = child
			break
	if pile == null:
		return
	if pile.child_entered_tree.is_connected(_arm_hand_row):
		return          # every row since is armed as it arrives
	pile.child_entered_tree.connect(_arm_hand_row)
	for holder in pile.get_children():
		_arm_hand_row(holder)


## One row of that window. A face-down row (the opponent's hand) holds a
## `ColorRect` and no [MiniCard], so it names no card and is left alone.
func _arm_hand_row(node: Node) -> void:
	if not (node is Button):
		return
	for face in node.get_children():
		if face is MiniCard and (face as MiniCard).instance != null:
			(node as Button).gui_input.connect(
				_on_hand_card_input.bind((face as MiniCard).instance))
			return


## A press on a card in the hand window. ONLY the double-click: the row's
## own `pressed` still performs the single click exactly as it did, so the
## 1997 *"click on it to cast it. You're prompted to provide mana"* path is
## untouched and this adds the *"alternatively, you can double-click"* one
## beside it (`Duel.hlp`, topic **Spells**).
##
## THE SECOND PRESS IS SWALLOWED. `accept_event()` inside a `gui_input`
## handler stops `BaseButton` seeing the press at all, so its release
## emits no `pressed` and the auto-cast is not followed by a stray single
## click on the same card. The FIRST press is untouched, which is what
## keeps a click a click — and what lets a double-click form at all.
func _on_hand_card_input(event: InputEvent, inst: CardInstance) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed \
			or not mb.double_click:
		return
	accept_event()
	_auto_cast(inst)


# ------------------------------------------------------ ARRANGE CARDS (§2.3) --
#
# THE TOGGLE'S RESTORE SEMANTICS, which are the whole of its design.
#
# Nothing is snapshotted, because nothing needs to be: the engine's own
# zone arrays ARE the unarranged order, and they are never touched. An
# arrange is a VIEW — `BoardOrder` hands back a sorted copy and the
# rebuild iterates that instead. Untoggling therefore restores the exact
# order the table was in before, for free and forever, with no snapshot to
# go stale.
#
# That also answers the only hard question in the item — what happens to a
# card that arrives while the table is arranged. It takes its arranged
# place immediately (it is simply another card in the sorted copy), and
# when the toggle goes off it appears where the ENGINE put it, which for a
# freshly drawn or freshly played card is the end of its zone. A snapshot
# design would have had to invent an answer here; this one inherits the
# right answer from the engine.
#
# It is also the reason the arrange can never desynchronise a click from
# its card: every MiniCard binds its own CardInstance
# (`w.pressed.connect(_on_card_clicked.bind(inst))`), so there is no index
# to drift. s30 has to keep drawing and hit-testing in the same order for
# exactly this reason; we have nothing to keep in step.

## One battlefield row, in the order it should be drawn. Unarranged, the
## engine's own play order; arranged, [BoardOrder]'s. Other permanents are
## never sorted — the reference leaves that row in play order too, and it
## is the row where the player's own grouping carries meaning.
func _display_order(pid: int, cards: Array, row: int) -> Array:
	if not _arranged[pid]:
		return cards
	match row:
		Row.CREATURES: return BoardOrder.creatures(cards)
		Row.LANDS: return BoardOrder.lands(cards)
	return cards


## [param pid]'s hand, in the order it should be drawn.
##
## The 1997 hand window has no arrange of its own — it only scrolls
## (`Duel.hlp`, topic **Hands**) — so this half of the toggle is `[s30]`
## riding a `[1997]` control. The owner asked for both: *"sort the hand
## and the battlefield"*.
func _hand_order(pid: int) -> Array:
	var cards: Array = game.players[pid].hand
	return BoardOrder.hand(cards) if _arranged[pid] else cards


## The sidebar toggle: the whole table at once, which is the control the
## owner specified. No engine call — *"This has no effect on the duel, it
## just makes things neater"* (`Duel.hlp`, topic **Territory**).
func _on_arrange_toggled(pressed: bool) -> void:
	for pid in 2:
		_arranged[pid] = pressed
		if pressed:
			_clear_placements(pid)
	# The 1997 table ships no confirmation string for it — its own feedback
	# was the cards moving, which ours do too. Flashed the way a Stop's is
	# (see _on_phase_menu_chosen): a moment, not a state.
	_report("Arrange your cards: %s" % ("on" if pressed else "off"))
	_refresh()


## One territory, from `@MENU_TERRITORY`'s own two entries (§6.3). The
## sidebar toggle then shows pressed only while BOTH halves are arranged,
## which is the only honest thing a table-wide control can say.
func _arrange_seat(pid: int, on: bool) -> void:
	_arranged[pid] = on
	if on:
		_clear_placements(pid)
	_report("%s: %s" % [
		"Arrange your cards" if pid == _human_seat()
			else "Arrange opponent's cards",
		"on" if on else "off"])
	_refresh()


## ARRANGE UNDOES A MOVE, because that is what the command IS: *"Arrange
## Cards STRAIGHTENS UP the cards in play in the territory where you
## right-clicked"* (`Duel.hlp`, topic **Territory**). A card the player
## dropped where they liked goes back into its row, and the toggle's
## restore semantics are untouched — the rows were never the thing that
## changed (see [method _display_order]).
func _clear_placements(pid: int) -> void:
	for inst in game.players[pid].battlefield:
		_placements.erase(inst.id)


## ONE small card, fully wired: highlighted, cued, clickable, and hooked
## to the sidebar's enlarged view. Split out of [method _make_widget] in
## the forty-first pass because an ATTACHED card is a card too — it gets
## exactly this treatment, and the aura band it replaced had to re-hand-
## wire a `Button` to keep even half of it.
## [param chain_item] is set only for the entry the CHAIN draws for that
## stack object. It matters for exactly one kind: an ACTIVATED ABILITY on
## the chain is a different object from the permanent that made it
## (CR 113.7a), the permanent has its own widget on the battlefield, and
## `TargetSpec.Kind.ABILITY` — Rust, Ayesha Tanaka — refuses a card ref
## outright. Until 2026-09-02 the picker had no case for the kind at all,
## so the AI could play those two cards and a human could not.
func _make_card(inst: CardInstance, chain_item: StackItem = null) -> MiniCard:
	# The small card answers most of `@CUECARD_SMALLCARD` off the instance,
	# but "Is a target" is a question about the STACK — hand it the game.
	# It goes in through the CONSTRUCTOR: assigning `w.game` afterwards
	# tripped the setter's refresh and re-derived the whole face a second
	# time, on every card of every rebuild (see MiniCard._init).
	var w := MiniCard.new(inst, game)
	# **A CARD THAT IS FACE DOWN IN THE GAME IS FACE DOWN ON THE TABLE.**
	# `MtgGame.put_from_hand_face_down` (Illusionary Mask) sets
	# [member CardInstance.face_down]; until 2026-09-04 nothing carried it
	# onto the widget, so a masked creature was drawn with its name, its
	# art, its oracle tooltip and its printed mana stripes on show — the
	# exact information the card exists to hide (`docs/card-states.md`
	# §5.1). The exile plate and the game log already got this right; the
	# table did not.
	#
	# TO EVERY SEAT, the controller's included. `engine/` has no per-seat
	# visibility model to ask (no `may_look_at`, and `CardInstance`'s flag
	# blanks the card's characteristics for everybody — CR 708.2), so this
	# takes the only reading that cannot leak. See [member
	# MiniCard.face_down] for what changes the day the engine can answer.
	w.face_down = inst.face_down
	# A card the flight layer is carrying is not drawn where it is going
	# until it gets there — s30's `spellIsAnimating` skip (§2.4). It keeps
	# its slot, so nothing on the board shuffles under the animation.
	if _flight != null and _flight.is_flying(inst.id):
		w.modulate.a = 0.0
	var as_ability := chain_item != null \
		and chain_item.kind == Mtg.StackKind.ABILITY
	w.set_target_state(_ability_target_state(chain_item) if as_ability \
		else _target_state_for(inst))
	if as_ability:
		w.pressed.connect(_on_chain_ability_clicked.bind(chain_item))
		# THE ARROW LAYER anchors an ability TARGET (Rust, Ayesha Tanaka)
		# on this widget, not on the source card's own — see
		# TargetArrows._collect.
		w.set_meta("chain_ability_id", chain_item.id)
	else:
		w.pressed.connect(_on_card_clicked.bind(inst))
	# Hovering ANY visible card docks its enlarged view in the sidebar
	# (the original's examine behavior; the last card persists).
	w.mouse_entered.connect(func() -> void:
		if _card_preview != null and not w.face_down:
			_card_preview.show_card(inst))
	w.mouse_exited.connect(func() -> void:
		if _card_preview == null:
			return
		if not _card_preview.docked:
			_card_preview.visible = false
			return
		# TOP-OF-CHAIN FALLBACK (§2.14). s30's hover chain ends with the
		# top stack item (`updateHoverPreview`, `duel.go:1930-1953`), so
		# *"the card currently resolving is always the one in the
		# magnifier"*. The docked Showcase otherwise keeps the last card
		# hovered, which is the owner's rule and still holds whenever the
		# chain is empty — this only takes over while something is
		# actually waiting to resolve, which is the moment the player most
		# needs to read it.
		_show_top_of_chain())
	# ONE call to the highlight, not two, and BOTH halves of it are used:
	# the frame ([method MiniCard.set_highlight]) and the yellow NAME
	# ([member MiniCard.castable]).
	#
	# **THE YELLOW NAME USED TO EXIST ONLY IN A PILE.** `castable` was
	# assigned in exactly one place in the whole codebase — `card_pile.gd`
	# — so a hand drawn as a FAN never yellowed a card however castable it
	# was, and which hand style the player had chosen in Options silently
	# changed what the game told them (`docs/card-states.md` §5.5). It is
	# the same yellow that now also promises the double-click auto-cast
	# will work (§6.20c), so a fan player was being denied the promise as
	# well as the cue. Same predicate as the pile's, from the same call.
	var highlight: int = _ability_highlight(chain_item) if as_ability \
		else _highlight_for(inst)
	w.castable = highlight == MiniCard.Highlight.CASTABLE
	w.set_highlight(highlight)
	# §2.15 — the two 1997 "just look at it" gestures, neither of which
	# performs the card's action. See [method _on_card_look].
	w.gui_input.connect(_on_card_look.bind(w, inst))
	return w


## Put the top of the spell chain in the Showcase, if anything is on it
## (§2.14). No-op with an empty chain: the docked Showcase then keeps
## whatever it was last shown, which is the behaviour the owner asked for.
func _show_top_of_chain() -> void:
	if _card_preview == null or game == null or game.stack.is_empty():
		return
	_card_preview.show_card(game.stack.back().card)


## RIGHT-BUTTON GESTURES ON A CARD (§2.15) — *look*, never *act*.
##
## The item was filed as [s30] off `duel.go:1909-1928` (`handleRightClick`
## loads the preview for whatever is under the cursor). It is [1997]:
## `Duel.hlp` names both gestures, and `@MENU_SMALLCARD`
## (`Program/UIStrings.txt:936`) carries one of them as a printed
## accelerator on the card mini-menu's second entry —
## `Show full card\tR DblClk`.
##
##  - **Right-double-click** = Show full card. `Duel.hlp`, topic
##    **Territory**: *"**Show full card** displays the card in the
##    Showcase. (When you're using the Advanced Layout, this opens a
##    temporary Showcase in which to display the card. You can also
##    double-right-click to perform the same function.)"*
##  - **Right-press and HOLD** = bring the card to the front for as long
##    as the button is down. Stated twice, under **Hands** and again under
##    **Territory**: *"You can also right-click and hold to bring a card
##    in your hand to the front for as long as you hold the mouse
##    button."* In a stacked hand the cards overlap to their name bands,
##    so "to the front" is literal — the held card lifts clear of the two
##    beside it. We raise it and dock it in the Showcase at the same time,
##    because our Showcase is permanent where the original's Advanced
##    Layout conjures one.
##
## A single right-click is NOT handled here: it belongs to the card's
## mini-menu (`@MENU_SMALLCARD`, §6.12), which is the entry point BOTH of
## these gestures are shortcuts past.
func _on_card_look(event: InputEvent, w: MiniCard, inst: CardInstance) -> void:
	# THE LEFT BUTTON'S DRAG (§2.3b). Motion only ever reaches here while
	# this widget holds the mouse, which is exactly the span of a drag.
	if event is InputEventMouseMotion and _drag_inst == inst:
		_drag_motion()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	# THE LEFT BUTTON'S SECOND CLICK — the 1997 auto-cast (§6.20c). The
	# widget is a Button, so its own `pressed` has already fired for the
	# FIRST click of the pair and the cast has begun; this picks it up
	# where it stands. Win32 orders the messages the same way
	# (WM_LBUTTONDOWN, WM_LBUTTONUP, WM_LBUTTONDBLCLK), so the original's
	# first click began the cast too — which is exactly why `Duel.hlp`
	# describes the double-click as taking over the MANA and nothing else.
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if mb.double_click:
				accept_event()
				_cancel_drag()
				_auto_cast(inst)
				return
			_begin_drag(w, inst)
			return
		# THE RELEASE. A press that never travelled [constant DRAG_SLOP] is
		# a CLICK and is left alone — the Button's own `pressed` fires and
		# the card does its primary function. One that did travel is a
		# MOVE, and swallowing the release here is what stops it also
		# tapping the land or taking it as a target.
		var moved := _dragging
		_commit_drag()
		if moved:
			accept_event()
		return
	if mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	if mb.pressed:
		if not w.face_down and _card_preview != null:
			_card_preview.show_card(inst)
		# The lift, held only while the button is. z_index, not a reparent:
		# the card stays exactly where the row put it and simply stops
		# being overlapped.
		w.z_index = LIFT_Z
		_lifted_card = w
		_right_press_ms = Time.get_ticks_msec()
	else:
		_drop_lifted_card()
		# THE SAME BUTTON CARRIES TWO GESTURES, and `Duel.hlp` names them
		# one after the other: *"Right-clicking on a card also opens a
		# mini-menu"* and *"You can also right-click and HOLD to bring a
		# card in your hand to the front for as long as you hold the mouse
		# button."* Holding is what tells them apart, so a right-click
		# that was let go quickly is the MENU and a longer one was the
		# look (§2.15, §6.12).
		if Time.get_ticks_msec() - _right_press_ms < HOLD_MS:
			_open_card_menu(inst, mb.global_position)


## z_index a right-held card lifts to — above its neighbours in the row and
## below the floating windows (the chain sits at 80, the Situation Bar 90).
const LIFT_Z := 60

## How long the right button has to be down for the gesture to count as a
## HOLD rather than a click (§6.12). Windows' own press-and-hold threshold
## is a shade under half a second; a quarter is enough here, because the
## thing a short click does — open a menu — is undone by pressing Escape
## and the thing a long one does is undone by letting go.
const HOLD_MS := 250

## When the right button went down on a card.
var _right_press_ms := 0

## The card currently held to the front by the right button, if any.
var _lifted_card: MiniCard = null


## Put a right-held card back down. Called on release and defensively from
## [method _rebuild_field], because a rebuild frees the widget the release
## would otherwise have arrived at.
func _drop_lifted_card() -> void:
	if _lifted_card != null and is_instance_valid(_lifted_card):
		_lifted_card.z_index = 0
	_lifted_card = null


# ---------------------------------------- MOVING A CARD BY HAND (§2.3b) --
# See the block comment beside [member _placements] for the whole feature.


## The outermost node the LAYOUT positions for [param w] — a tapped card
## sits inside its rotation holder and an enchanted one inside its aura
## wrap ([method _make_widget]), and it is that outer node a placement
## records and a drag moves, never the card inside it.
## GIVE EVERY ROW OF A BATTLEFIELD PILE THE DRAG GESTURE (§2.3b, added
## 2026-09-03). A [CardPile] draws each card as a `MOUSE_FILTER_IGNORE`
## picture inside a holder `Button` that carries `pressed` and nothing
## else, so the press that arms a drag reached nothing that knew how to
## start one — and lands, artifacts and enchantments group into a pile the
## moment there are two of them, which is why the owner's report was the
## flat *"Card on board still cannot be dragged across the board"* rather
## than "only creatures move".
##
## CONNECTED FROM HERE rather than from `CardPile.populate`, because that
## file belongs to another pass today. The walk is the pile's own drawing
## order and nothing more: one `Button` per row, one [MiniCard] inside it
## naming the card. When the pile grows a hook of its own this collapses
## into passing a callable to `populate`.
func _arm_pile_drag(pile: CardPile) -> void:
	for holder in pile.get_children():
		if not (holder is Button):
			continue
		for face in holder.get_children():
			if face is MiniCard:
				holder.gui_input.connect(_on_piled_card_input.bind(
					holder, (face as MiniCard).instance))
				break


## A PRESS ON A CARD INSIDE A PILE (§2.3b). Only the drag: the pile's
## holder is a `Button` and its own `pressed` signal still does the card's
## primary function, exactly as it always did — this adds the gesture that
## was missing and takes nothing away.
##
## Two things differ from [method _on_card_look] and both are the pile's
## doing. The node that moves is the ROW HOLDER, not a [MiniCard] (the
## MiniCard inside it is `MOUSE_FILTER_IGNORE` and is only a picture); and
## a covered row is CLIPPED to its title bar, so the clip comes off the
## moment the gesture becomes a real drag and the whole card slides out of
## the stack under the pointer.
func _on_piled_card_input(event: InputEvent, holder: Control,
		inst: CardInstance) -> void:
	if event is InputEventMouseMotion and _drag_inst == inst:
		# There used to be a second difference from `_on_card_look`, and
		# the pile removed it: a covered row was CLIPPED to its title bar,
		# so the clip came off the moment the gesture became a real drag
		# and the whole card slid out of the stack under the pointer. A
		# battlefield pile row is a WHOLE card now, occluded by the row in
		# front of it rather than cropped (`CardPile.populate`,
		# 2026-09-04), so there is no clip left to take off — the card was
		# already whole before the drag began.
		_drag_motion()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		if mb.double_click:
			# The pile's own double-click is the 1997 auto-cast, and the
			# holder's `pressed` has already begun it — do not also start
			# dragging the card out from under it.
			_cancel_drag()
			return
		_begin_drag_node(holder, inst)
		return
	# The release. A press that never travelled [constant DRAG_SLOP] is a
	# CLICK and is left for the holder's own `pressed`; one that did travel
	# is a MOVE, and swallowing it here is what stops the same gesture also
	# tapping the land it just carried across the table.
	var moved := _dragging
	_commit_drag()
	if moved:
		accept_event()


func _layout_root(w: Control) -> Control:
	var node: Control = w
	while node.get_parent() is Control:
		var parent: Control = node.get_parent()
		if parent is SqueezeRow or _free_layers.has(parent):
			return node
		node = parent
	return w


## Which board half [param inst] is drawn in, or -1.
func _half_of(inst: CardInstance) -> int:
	if inst.zone != Mtg.Zone.BATTLEFIELD:
		return -1
	for pid in 2:
		if game.players[pid].battlefield.has(inst):
			return pid
	return -1


## Arm the gesture. Nothing moves and nothing is claimed yet: until the
## pointer travels [constant DRAG_SLOP] this is still an ordinary click.
func _begin_drag(w: MiniCard, inst: CardInstance) -> void:
	_begin_drag_node(_layout_root(w), inst)


## The same gesture, armed on a node the caller has already chosen. A card
## inside a [CardPile] cannot use [method _layout_root]: its holder's
## parent chain runs through the PILE, so the walk would hand back the
## whole pile and the player would drag five cards at once.
func _begin_drag_node(root: Control, inst: CardInstance) -> void:
	_cancel_drag()
	if game == null or root == null or _half_of(inst) == -1:
		return
	_drag_inst = inst
	_drag_root = root
	_drag_from = get_global_mouse_position()
	_drag_origin = root.global_position
	_dragging = false


## The pointer moved with the button down.
func _drag_motion() -> void:
	if _drag_root == null or not is_instance_valid(_drag_root):
		_cancel_drag()
		return
	var delta := get_global_mouse_position() - _drag_from
	if not _dragging:
		if delta.length() < DRAG_SLOP:
			return
		_dragging = true
		_drag_root.z_index = DRAG_Z
	# THE BOUNDARY IS VISIBLE, not a snap-back on release: the card stops
	# dead at the edge of its own territory and the pointer runs on
	# without it (§2.3b). Clamping only on drop let the player carry a
	# card right off the table, see it vanish under the half's
	# `clip_contents`, and only learn where it really went when they let
	# go — the owner's *"the mini-cards can be moved out of the playfield
	# and hide"*. The offset is measured from [member _drag_from] rather
	# than accumulated, so a pointer that leaves and comes back picks the
	# card up again exactly where it left it.
	var want := _drag_origin + delta
	var pid := _half_of(_drag_inst)
	var layer: Control = _free_layers[pid] if pid != -1 else null
	if layer != null:
		want = layer.global_position + _clamp_in_half(pid,
			want - layer.global_position, _drag_inst)
	_drag_root.global_position = want


## Finish the gesture: a drag that happened is written into
## [member _placements] and the board is rebuilt around it. A press that
## never became a drag simply forgets itself.
## [param refresh] is off for the call inside [method _rebuild_field],
## which is already rebuilding.
func _commit_drag(refresh := true) -> void:
	if _drag_root == null or _drag_inst == null or not _dragging \
			or not is_instance_valid(_drag_root):
		_cancel_drag()
		return
	var inst := _drag_inst
	var pid := _half_of(inst)
	var where := _drag_root.global_position
	_cancel_drag()
	if pid != -1:
		_place_card(pid, inst, where)
	if refresh:
		_refresh()


## Record where [param inst] now sits, in its own half's coordinates and
## clamped inside [method _placement_bounds] so a card can never be
## dropped where it cannot be seen.
## Re-inserting the id is what puts the moved card ON TOP of the others.
func _place_card(pid: int, inst: CardInstance, at_global: Vector2) -> void:
	var layer: Control = _free_layers[pid]
	if layer == null:
		return
	var local := _clamp_in_half(pid, at_global - layer.global_position, inst)
	_placements.erase(inst.id)
	_placements[inst.id] = local


# ------------------------------------- THE PLAYFIELD BOUNDARY (§2.3b) --
#
# The owner's playtest, 2026-09-04: *"The mini-cards can be moved out of
# the playfield and hide — make the playfield boundary for mini cards so
# they cannot possibly be moved and hidden out of the playfield!"*
#
# WHOLLY INSIDE, NOT A CORNER INSIDE. The first pass clamped the widget's
# TOP-LEFT against `layer.size - span`, which is right only while `span`
# is right, and `span` was read off the node being dragged
# (`max(node.size, MiniCard.SIZE)`). Three things that node does not know
# then walked cards off the table:
#
#   1. A CARD THAT TAPS LATER. `MiniCard.turn_holder` is
#      [constant MiniCard.TURN_HOLDER_SIZE] = 114x140 against a card's
#      132x106: a card parked flush with the bottom of its half untapped
#      grew 34px DOWNWARD the moment it tapped, straight through the
#      half's `clip_contents`. The span below is therefore the UNION of
#      the two footprints, reserved whether or not the card is tapped
#      right now — a placement is a promise, and a card must not shuffle
#      itself upward just because it turned.
#   2. AN ENCHANTED CARD. The aura fan is drawn at `-AURA_PEEK.y` per
#      attachment ABOVE the host's own box (see [method _make_widget],
#      which says why it overflows rather than reserves), so a host at
#      the top edge had its auras cut off. That overflow is part of the
#      footprint here, which is why a span is a [Rect2] with an origin
#      and not just a size.
#   3. THE SEAT. `_half_of` already sends every drop back to its owner's
#      half, and that is deliberate rather than incidental: a card in the
#      other territory would say something false about who controls it.
#
# WHAT THE BOUNDS ARE, AND WHY. The visible table, not merely the half:
#
#   * THE HALF, INSET exactly as its rows are ([constant BOARD_INSET] /
#     [constant BOARD_INSET_V]) — the reference leaves a clear margin all
#     round, and a card flush with the seam reads as being in neither
#     territory.
#
# ...AND NOTHING SUBTRACTED FOR CHROME — not even the floating hand
# window, which for one day it was. The owner settled it on 2026-09-04:
# *"Yes, the hand stack can be present anywhere — only cast mini-cards
# are bound to the playfield."* The window is opaque and taller than a
# card, so it CAN cover one; that is not the same as losing one. The
# player owns both objects, and one more drag of either uncovers the
# card. What it cost to pretend otherwise is in [method
# _reclamp_placements].
#
# The rest of the chrome needs no bound and it is worth writing down why,
# because "clamp to the visible area" could otherwise eat the table:
#
#   * The zone column, the seat portraits and the phase/combat bar are
#     SIBLINGS of the board in the root `HBoxContainer` — they are beside
#     the halves, never over them, so there is nothing to subtract.
#   * The Situation Bar floats over the seam but is ~36px tall against a
#     106px card; it cannot hide one, and shrinking both halves by a
#     whole card to clear a bar the cards read fine under would cost the
#     board its two best rows.
#   * The FAN hand is a row INSIDE the half, and the free layer is added
#     after the rows, so a card dropped over it is drawn on top of it and
#     stays visible. (What it covers is the player's own hand, which one
#     more drag — or `Arrange my cards` — undoes.)


## The rectangle a placed card must lie WHOLLY inside, in [param pid]'s
## free-layer coordinates. Empty when the half has not been laid out yet,
## which is the caller's signal to leave the placement alone.
func _placement_bounds(pid: int) -> Rect2:
	var layer: Control = _free_layers[pid]
	if layer == null or layer.size.x <= 0.0 or layer.size.y <= 0.0:
		return Rect2()
	var inset := Vector2(BOARD_INSET, BOARD_INSET_V)
	return Rect2(inset, layer.size - inset * 2.0)


## The box the widget for [param inst] sweeps out, RELATIVE to the
## top-left a placement records — see the block comment above for the
## three things it has to cover. `position` is normally zero and negative
## only for the upward overflow of an aura fan.
func _placement_span(inst: CardInstance) -> Rect2:
	# The union of a card and the footprint its 90° turn needs, so tapping
	# never pushes a parked card out of its own territory.
	var span := Vector2(
		maxf(MiniCard.SIZE.x, MiniCard.TURN_HOLDER_SIZE.x),
		maxf(MiniCard.SIZE.y, MiniCard.TURN_HOLDER_SIZE.y))
	var auras := 0
	if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
		auras = inst.attachments.size()
	if auras == 0:
		return Rect2(Vector2.ZERO, span)
	# The fan: a whole card wide per step to the RIGHT, off the turned
	# host's own corner (`_make_widget`), and AURA_PEEK.y per step ABOVE
	# the host's box, which is the part that falls outside it.
	var corner := (MiniCard.TURN_HOLDER_SIZE.x - MiniCard.SIZE.y) / 2.0
	span.x = maxf(span.x,
		corner + MiniCard.SIZE.x + AURA_PEEK.x * float(auras))
	var up := AURA_PEEK.y * float(auras)
	return Rect2(Vector2(0.0, -up), Vector2(span.x, span.y + up))


## [param local] pulled back until the whole of [param inst]'s widget sits
## inside [method _placement_bounds]. A half too small to hold a card pins
## it to the top-left corner rather than inventing room.
func _clamp_in_half(pid: int, local: Vector2, inst: CardInstance) -> Vector2:
	var bounds := _placement_bounds(pid)
	if bounds.size == Vector2.ZERO:
		return local
	var span := _placement_span(inst)
	var lo := bounds.position - span.position
	var hi := bounds.end - span.size - span.position
	return Vector2(
		clampf(local.x, lo.x, maxf(lo.x, hi.x)),
		clampf(local.y, lo.y, maxf(lo.y, hi.y)))


## RE-CLAMP EVERY PLACEMENT the board already holds, and rebuild the halves
## whose cards actually moved.
##
## A placement lives for the whole duel and is stored in HALF coordinates,
## so it survives a resize as an absolute offset would not — but surviving
## is not the same as still fitting. Under this project's `canvas_items` /
## `expand` stretch a 1920x1080 window is a 1422x800 CANVAS and a 1280x800
## one is 1280x800, so parking a card at the right edge of the first and
## reopening in the second leaves it 142px out in the dark behind the
## half's `clip_contents` (measured). A RESIZE IS THE ONLY CALLER, wired
## from each half's own `resized` ([method _board_half]).
##
## AND IT IS THE ONLY ONE IT MAY EVER HAVE. For one day the floating hand
## window called this too: the playfield boundary subtracted the window's
## band, and the window drove it through `item_rect_changed` — a signal a
## Control emits when it MOVES, not merely when it resizes. So every drag
## of the hand window redrew the boundary and shoved the placements that
## fell outside the new one, which is the owner's *"When I move my hand
## stack, also other cards move on the table. They shouldn't."* Measured
## under Xvfb with a real press-move-release on the window's grip: ONE
## 480px drag fired this twelve times and moved two of three placed cards,
## collapsing both onto the same x.
##
## The maths was right and the behaviour was still wrong, which is the
## lesson worth keeping. A PLACEMENT IS A STATEMENT OF INTENT. A re-clamp
## is a rescue for a card that would otherwise be off-screen and
## unreachable — never a tidy-up, and never something a piece of chrome
## the player is free to move gets to trigger.
func _reclamp_placements() -> void:
	if game == null:
		return
	if _dragging:
		# A card in the player's hand right now is clamped by
		# [method _drag_motion] on every move and again by
		# [method _place_card] when it lands. Rebuilding the layer here
		# would free the widget under the pointer mid-gesture, which is the
		# same hazard [method _rebuild_field] answers with its
		# `_commit_drag(false)`.
		return
	var dirty := {}
	for id in _placements.keys():
		var inst: CardInstance = game.find_instance(id)
		if inst == null:
			continue
		var pid := _half_of(inst)
		if pid == -1:
			continue
		var at: Vector2 = _clamp_in_half(pid, _placements[id], inst)
		if not at.is_equal_approx(_placements[id]):
			_placements[id] = at
			dirty[pid] = true
	# DEFERRED: this arrives from a `resized` notification, and freeing and
	# rebuilding the layer's children in the middle of a layout pass is how
	# a duel screen gets a "Condition ... is true" at teardown.
	for pid in dirty:
		_rebuild_placed.call_deferred(pid)


## Forget a gesture in progress, putting a lifted widget back down.
func _cancel_drag() -> void:
	if _drag_root != null and is_instance_valid(_drag_root):
		_drag_root.z_index = 0
	_drag_root = null
	_drag_inst = null
	_dragging = false


func _make_widget(inst: CardInstance) -> Control:
	var w := _make_card(inst)
	var result: Control = w
	if w.wants_rotation():
		# 1997 tapped rotation: the card keeps its exact dimensions and
		# simply turns 90°. A Container zeroes a child's rotation on every
		# sort (`fit_child_in_rect`), so the card turns INSIDE a plain
		# holder sized to the footprint the turn sweeps out. THE ANGLE,
		# the timing, the resume across rebuilds and the tween all belong
		# to the card — it is the thing that knows it is tapped. See
		# `MiniCard.turn_holder` and `MiniCard.tap_turn`, which the card
		# calls for itself when it reaches the tree.
		result = MiniCard.turn_holder(w)
	# EVERY ATTACHED CARD IS A WHOLE CARD BEHIND ITS HOST, offset right and
	# up by [constant AURA_PEEK] per attachment, so its title bar and its
	# right edge show and the host overlaps the rest. TWO CARDS STACKED —
	# which is what the original draws and what s30 draws.
	#
	# THIS USED TO BE A 16px `Button` GLUED ON TOP OF THE CARD, wearing a
	# StyleBoxFlat in the aura's darkened frame colour, and it read as a
	# grey label attached to a card rather than as a second card: the
	# owner's Savannah Lions shot, "Artifact Ward" in a flat band with a
	# hard seam under it. The comment here even claimed s30's -14px offset
	# while doing something else entirely. s30's real path
	# (`duel.go:3223-3242`) blits the aura's FULL card art at `fieldCardW`
	# behind the host and only falls back to a 14px name strip when the art
	# is missing — we had shipped the fallback as the design.
	#
	# Reading the peek: the attachment nearest the host is `attachments[0]`
	# and sits ONE step out, so a fresh aura lands on the outside of the
	# fan and nothing already on the card moves. s30 orders them the same
	# way (`slices.Backward`: last drawn first, `attachments[0]` last and
	# therefore on top of its neighbours).
	if not inst.attachments.is_empty() and inst.zone == Mtg.Zone.BATTLEFIELD:
		var attached: Array[CardInstance] = []
		for id in inst.attachments:
			var aura := game.find_instance(id)
			if aura != null:
				attached.append(aura)
		if attached.is_empty():
			return result
		var steps := float(attached.size())
		var wrap := Control.new()
		# A TAPPED host is already inside its rotation holder, which is
		# WIDER and TALLER than a card and holds the turning card centred
		# in it — so the fan is anchored to the card's own visible corner,
		# not the holder's, and a tapped host's auras still sit one clean
		# band above the picture rather than 17px of empty holder above it.
		var base_size: Vector2 = result.custom_minimum_size if result != w \
			else MiniCard.SIZE
		var seen := Vector2(MiniCard.SIZE.y, MiniCard.SIZE.x) if result != w \
			else MiniCard.SIZE
		var corner := (base_size - seen) / 2.0
		# THE FAN RESERVES WIDTH BUT NOT HEIGHT, and that asymmetry is the
		# whole reason the row still reads:
		#
		#   * WIDTH is reserved, because the card to the right is at the
		#     same height and would be overlapped by the fan otherwise.
		#   * HEIGHT is NOT, because reserving it makes the line taller and
		#     `SHRINK_CENTER` then re-centres everything in it — which
		#     drops the enchanted host half the fan's height BELOW its
		#     neighbours (measured: 27px with three auras) and jolts the
		#     whole row upward the moment an aura resolves. The fan simply
		#     OVERFLOWS upward instead, which is what s30 does — its field
		#     cards sit on a fixed grid (`getFieldCardPos`) and the aura is
		#     drawn at `pos.Y - 14` over whatever is up there. Both creature
		#     rows are the LAST row of their board half, under an expanding
		#     spacer, so the overflow lands in empty board and inside the
		#     half's own `clip_contents`.
		#
		# So the host keeps EXACTLY the footprint it would have with no
		# aura at all: same row centre line, no jump when one attaches, and
		# a tap still pivots in place.
		# The width reserved is the FURTHEST ATTACHMENT's right edge, and an
		# attachment is a whole card wide (132) even behind a host that is
		# turned and therefore only 106 wide — measure the card, not the
		# host, or a tapped enchanted creature overhangs its neighbour.
		wrap.custom_minimum_size = Vector2(
			maxf(base_size.x, corner.x + MiniCard.SIZE.x + AURA_PEEK.x * steps),
			base_size.y)
		# Shrink, like the card itself (MiniCard._init) — the row holds
		# things taller than a card (a tapped card's holder, a five-card
		# pile) and the host must not be stretched by them.
		wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# The wrap reserves a strip to the right of the host that only the
		# fan's thin edges occupy, so it must not swallow clicks meant for
		# the board behind it.
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Furthest-out first: later children draw over earlier ones, so the
		# host — added last — overlaps every card behind it.
		for j in range(attached.size() - 1, -1, -1):
			var out := float(j + 1)
			var back := _make_card(attached[j])
			# NOT SHRUNK, NOT SCALED: an attachment is a card, so it is
			# `MiniCard.SIZE` like every other card on the table and is
			# merely mostly hidden (tests/ui/test_card_dimensions.gd).
			back.size = MiniCard.SIZE
			back.position = corner \
				+ Vector2(AURA_PEEK.x * out, -AURA_PEEK.y * out)
			wrap.add_child(back)
		if result == w:
			w.size = MiniCard.SIZE
		wrap.add_child(result)
		return wrap
	return result


## Which of the small card's TARGETING states is this card in? The two
## states in `@CUECARD_SMALLCARD` that are about the PROMPT IN PROGRESS
## rather than about the card — "Can't target this" and "Is a target,
## can't target again" — and they can only be answered here, because
## `_pending_slots` / `_pending_groups` live in this screen.
func _target_state_for(inst: CardInstance) -> int:
	if mode != Mode.TARGETING or _pending_slot >= _pending_slots.size():
		return -1
	for chosen in _pending_groups[_pending_slot]:
		if not chosen.is_player and chosen.instance_id == inst.id:
			return MiniCard.State.TARGET_AGAIN
	# Only cards that could plausibly be aimed at get the refusal stamp —
	# stamping every land and every card in hand would be noise, not news.
	if inst.zone != Mtg.Zone.BATTLEFIELD:
		return -1
	var spec: TargetSpec = _pending_slots[_pending_slot]["spec"]
	if spec.is_legal(game, TargetRef.card(inst), _pending_card):
		return -1
	return MiniCard.State.CANT_TARGET


## What state should this card's frame show right now?
##
## The COLOUR CODE is the manual's (p.128 — *"Mandatory effects are
## highlighted in orange, while optional effects are in yellow"*) and the
## COVERAGE is s30's (`duel.go:3302-3377`, nine border states). Where the
## two disagree they are reconciled in `MiniCard.Highlight`'s own comment:
## s30's orange means "there is something you can do here", the manual's
## means "you must", and the manual wins on meaning.
func _highlight_for(inst: CardInstance) -> int:
	match mode:
		Mode.TARGETING:
			# Highlight against the CURRENT slot's spec (the targeting
			# flow is slot-based since variable/divided targets landed).
			if _pending_slot < _pending_slots.size():
				var spec: TargetSpec = _pending_slots[_pending_slot]["spec"]
				for chosen in _pending_groups[_pending_slot]:
					if not chosen.is_player and chosen.instance_id == inst.id:
						return MiniCard.Highlight.TARGET_CHOSEN
				if spec.is_legal(game, TargetRef.card(inst), _pending_card):
					return MiniCard.Highlight.TARGET_LEGAL
		Mode.ATTACKERS:
			if _selected_attackers.has(inst.id):
				return MiniCard.Highlight.COMMITTED
			if inst.controller_id == game.active_player \
					and inst.is_creature() \
					and CombatState.attack_illegality(game, inst, game.opponent_of(game.active_player)) == "":
				# ORANGE for a creature that MUST attack (manual p.128:
				# forced attackers are "highlighted, and you must add them
				# to the Combat window"). Juggernaut's printed keyword and
				# the one-turn compulsion both count.
				if inst.must_attack_this_turn \
						or inst.has_keyword(Mtg.Keyword.MUST_ATTACK):
					return MiniCard.Highlight.MANDATORY
				return MiniCard.Highlight.OPTIONAL
		Mode.BLOCKERS:
			if _block_map.has(inst.id) or inst.id == _selected_blocker:
				return MiniCard.Highlight.COMMITTED
			if game.combat.attackers.has(inst.id):
				# An attacker that MUST be blocked (Lure) is the defender's
				# mandatory case.
				if inst.cur_must_be_blocked:
					return MiniCard.Highlight.MANDATORY
				return MiniCard.Highlight.TARGET_LEGAL
		Mode.DISCARD:
			if _discard_picks.has(inst.id):
				return MiniCard.Highlight.COMMITTED
			if inst.zone == Mtg.Zone.HAND and inst.owner_id == game.active_player:
				return MiniCard.Highlight.TARGET_LEGAL
		Mode.DAMAGE:
			if int(_damage_picks.get(inst.id, 0)) > 0:
				return MiniCard.Highlight.COMMITTED
			if _damage_candidates().has(inst.id):
				return MiniCard.Highlight.TARGET_LEGAL
		Mode.PAYING:
			# The mana the cast is waiting for is on these cards, and the
			# manual gives every "you may act on this" cue one word and one
			# colour (p.115/p.120/p.126) — so the sources light exactly as
			# an eligible attacker or a legal target does. A source marked
			# `Don't auto tap this card` still lights: *"the only way to
			# tap a locked land is manually, by clicking on it"*, and this
			# IS clicking on it.
			if inst.zone == Mtg.Zone.BATTLEFIELD \
					and inst.controller_id == _pending_pid \
					and not inst.tapped \
					and not inst.cur_mana_abilities.is_empty() \
					and not (inst.is_creature() and inst.summoning_sick):
				return MiniCard.Highlight.OPTIONAL
		Mode.NORMAL:
			# Hand hint: yellow = the pool could pay for it right now.
			# A hint only — the engine remains the referee on timing etc.
			# PRIORITY is part of the hint: both play_land and cast_spell
			# refuse without it, so highlighting a card the player cannot
			# act on would be a lie (found in the 2026-08 code review).
			if inst.zone == Mtg.Zone.BATTLEFIELD:
				# THE CUE WE LACKED ENTIRELY: an ACTIONABLE PERMANENT.
				# s30 paints it (`duel.go:3302-3377`, block 2b) and the
				# 1998 guide's routine — "go from left to right and
				# evaluate each card on the board" (p.106) — needs it.
				return MiniCard.Highlight.OPTIONAL if _can_act_on(inst) \
					else MiniCard.Highlight.NONE
			if inst.zone != Mtg.Zone.HAND or game.priority_player != inst.owner_id:
				return MiniCard.Highlight.NONE
			if inst.is_land():
				# The land drop, mirroring MtgGame.play_land's conditions
				# (CR 305.1): your main phase, empty stack, drop unspent.
				if inst.owner_id == game.active_player \
						and Mtg.is_main_step(game.current_step()) \
						and game.stack.is_empty() \
						and (game.players[inst.owner_id].lands_played_this_turn < 1
							or game.unlimited_land_plays.has(inst.owner_id)):
					return MiniCard.Highlight.CASTABLE
			# could_afford, not can_afford: the engine's own answer folds
			# in cost modifiers (Gloom's tax, the Mana Matrix's discount),
			# restricted mana (Mishra's Workshop) and colour
			# substitutions, so the hint — and the yellow name riding on
			# it — cannot drift from what cast_spell accepts (2026-09
			# audit) — and since 2026-09-03 it prices against the mana the
			# seat could still TAP rather than only what is floating.
			#
			# That is what the word meant in 1997. `Duel.hlp`, topic
			# **Hands**: *"you must have enough MANA AVAILABLE… When all
			# the necessary conditions are met, a card in your hand is
			# useable, and therefore will be highlighted as such."* In a
			# game that auto-tapped for you, "available" is your untapped
			# lands. It is also what makes the owner's two asks of
			# 2026-09-03 coherent: the yellow name is the promise that
			# clicking it (Mode.PAYING) or double-clicking it (the
			# auto-cast) will work.
			elif game.could_afford(inst.owner_id, inst.data, _no_auto_tap):
				return MiniCard.Highlight.OPTIONAL
	return MiniCard.Highlight.NONE


## Has this permanent an ACTIVATED ability its controller could use right
## now? The "this has something you can do" cue.
##
## Deliberately narrower than s30's, which counts anything actionable:
## MANA abilities are excluded, because every untapped land has one and
## lighting the whole mana base up turns the cue into wallpaper. Ask the
## engine what a cost costs (`can_afford_cost` folds in the modifiers);
## never re-derive it here.
func _can_act_on(inst: CardInstance) -> bool:
	if inst.controller_id != game.priority_player:
		return false
	for ability in inst.cur_activated_abilities:
		if ability.tap_cost and (inst.tapped
				or (inst.summoning_sick and inst.is_creature()
					and not inst.has_keyword(Mtg.Keyword.HASTE))):
			continue
		if game.can_afford_cost(inst.controller_id, ability.cost):
			return true
	return false


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# ================================================================= UI build --
# The whole layout in code — see design doc §3 for the diagram this follows
# and §2 for why (skinnable later without scene surgery).

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The original's ground is pure BLACK; every pane floats on top of it.
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# (Each board half tiles its OWN seat's terrain pattern — see
	# _board_half; no whole-screen backdrop needed.)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# ------------------------------------------------------------- sidebar --
	# The original's left column: BLACK ground, two floating pane blocks —
	# opponent's (life numeral at the top corner) and the player's
	# (life at the bottom corner) — and nothing else. No buttons, no
	# log, no turn text (complete reimplementation; QoL returns later).
	# Width measured off the owner's screenshots: the left column is 23.4%
	# of the screen — exactly CardPreview.SIZE.x, so the big card fills it
	# at 1:1 (its height then lands on the reference's 52% too).
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = CardPreview.SIZE.x
	sidebar.add_theme_constant_override("separation", 4)
	root.add_child(sidebar)

	sidebar.add_child(_player_panel(1, true))
	# The LARGE examined card lives HERE — the left bar, directly under
	# the opponent's block (the owner's screenshots: Island/Urza's
	# Avenger enlarged in the column). Docked: it persists after hover.
	# It rides as HIGH as the column allows, on the owner's instruction:
	# an earlier pass held it 40px lower to match the reference's y
	# 0.258, but ALL slack now belongs to the reserve below it.
	_preview_dock = Control.new()
	_preview_dock.custom_minimum_size = CardPreview.SIZE
	sidebar.add_child(_preview_dock)
	# Every spare pixel of the column collects HERE, between the card and
	# the player's block — the black strip reserved for the QoL controls
	# (fast-forward, cancel, log, settings) when they land.
	_qol_reserve = Control.new()
	_qol_reserve.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(_qol_reserve)
	# ARRANGE CARDS, the reserve's first tenant — the owner's placement:
	# *"this should have its own new icon under the large card on the
	# right"*. Right-aligned against the column's inner edge and hard up
	# under the card, so the rest of the strip stays free for the controls
	# that follow it.
	_arrange_button = ArrangeButton.create(_on_arrange_toggled)
	_arrange_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_arrange_button.offset_left = -ArrangeButton.FACE.x - 4.0
	_arrange_button.offset_top = 4.0
	_arrange_button.offset_right = -4.0
	_arrange_button.offset_bottom = 4.0 + ArrangeButton.FACE.y
	_qol_reserve.add_child(_arrange_button)
	# Last child of the column, so the player's life numeral finishes
	# flush with the bottom edge of the screen.
	sidebar.add_child(_player_panel(0, false))

	# ---------------------------------------------------------- main board --
	# The playfield splits EXACTLY in half (the reference), each half
	# tiled with its seat's terrain pattern; the compact Done/message
	# popup floats at the seam.
	var board := VBoxContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", 0)
	root.add_child(board)

	var top_half := _board_half(1)
	board.add_child(top_half[0])
	var top_rows: VBoxContainer = top_half[1]

	# Opponent rows read top-down: lands, other, creatures (creatures
	# nearest the battle line — design doc §3).
	# Piles size to content and hug the RIGHT; the creatures row is pushed
	# to the BOTTOM of the half by an expanding spacer — measured off the
	# owner's screenshot, where each player's creatures hug the far edge
	# of their own half (the opponent's just above the seam).
	#
	# [SqueezeRow], not [HFlowContainer]: a territory row is a reading
	# order and wrapping destroys it (§2.13). An overflowing row now
	# shrinks its pitch and the cards slide under one another, which is
	# what s30 does and what the original's own **Arrange Cards** verb
	# presupposes.
	_field_rows[1] = {}
	for row in [Row.LANDS, Row.OTHER]:
		var c := SqueezeRow.new()
		c.align = SqueezeRow.Align.END
		top_rows.add_child(c)
		_field_rows[1][row] = c
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_rows.add_child(top_spacer)
	var opp_creatures := SqueezeRow.new()
	top_rows.add_child(opp_creatures)
	_field_rows[1][Row.CREATURES] = opp_creatures

	# The opponent's hand window — its TITLE BAR only (manual p.114), built
	# by StackHand.title_plate so it is the same object as the player's.
	# BOTTOM-RIGHT of the opponent's half, level with their creature row
	# (the owner's screenshots), not at the top of the board.
	var opp_hand_row := MarginContainer.new()
	# Keep it clear of the right edge — the player's hand window lives there.
	opp_hand_row.add_theme_constant_override("margin_right", 200)
	var opp_hand := HFlowContainer.new()
	# Room for the whole plate: the window's top cap plus its foot. It read
	# 24 while the old chip was a squashed 22px strip.
	opp_hand.custom_minimum_size.y = StackHand.TITLE_HEIGHT + StackHand.FOOT
	opp_hand.alignment = FlowContainer.ALIGNMENT_END
	opp_hand_row.add_child(opp_hand)
	top_rows.add_child(opp_hand_row)
	_hand_rows.append(opp_hand)

	# NO message row in the board — the halves meet directly; the
	# Done/message box floats as a POPUP over the seam (built after the
	# board so it draws on top; see below).

	var bottom_half := _board_half(0)
	board.add_child(bottom_half[0])
	var bottom_rows: VBoxContainer = bottom_half[1]

	# BOTH halves read the same top-down order — measured off the owner's
	# screenshot: the player's artifact/land piles sit just BELOW the seam
	# (y 290-350 of 563) and their creatures LOWER (y 450-520). The board
	# is not mirrored; non-creatures lead, creatures follow.
	_field_rows[0] = {}
	for row in [Row.LANDS, Row.OTHER]:
		# Right-hugging piles, across the half's FULL width. They used to
		# squeeze for the floating hand window; they no longer do, because
		# the window moves and a row that yields to it slides every pile in
		# it every time the player drags it (§2.3b, §3.6).
		var c := SqueezeRow.new()
		c.align = SqueezeRow.Align.END
		bottom_rows.add_child(c)
		_field_rows[0][row] = c
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_rows.add_child(bottom_spacer)
	var my_creatures := SqueezeRow.new()
	bottom_rows.add_child(my_creatures)
	_field_rows[0][Row.CREATURES] = my_creatures

	# The player's own hand: the fan (our default) or the ORIGINAL's
	# draggable stacked list window ("Hand display" in Options). The stack
	# floats over the board — the board keeps the reclaimed vertical space.
	if Settings.hand_style() == "stack":
		var stack := StackHand.new()
		stack.position = Settings.hand_stack_pos()
		stack.set_deck_color(config.panel_colors[0])
		add_child(stack)   # child of the SCREEN, not the board: it floats
		# AND IT FLOATS FREELY: nothing on the board listens to it. It used
		# to drive the board's layout through `item_rect_changed`, which a
		# Control emits when it MOVES as well as when it resizes — see
		# `_reclamp_placements` for the regression that caused.
		_hand_rows.append(stack)
	else:
		var my_hand := FanHand.new()
		bottom_rows.add_child(my_hand)
		_hand_rows.append(my_hand)

	# The ORIGINAL's vertical phase bar (Winbk_Phase) between sidebar and
	# board — "the central control for the progress of the duel" (manual
	# p.116) — with the current phase highlighted, a red dot on every phase
	# the player has marked with a Stop, and both of its clicks live.
	# Skipped cleanly without the skin.
	var bar_texture := GameSkin.texture("phase_bar")
	if bar_texture != null:
		var bar_holder := Control.new()
		bar_holder.custom_minimum_size.x = 50
		root.add_child(bar_holder)
		_bar_holder = bar_holder
		# The original puts the phase strip BETWEEN sidebar and board
		# (s30: phaseX=250, board at 293) — not at the right edge.
		root.move_child(bar_holder, 1)
		# THE PHASE BAR — sixteen live icons, each with its 1997 cue card,
		# a left-click that RUNS to it and a right-click that opens the
		# @MENU_PHASEBAR mini-menu (game/duel/phase_bar.gd).
		_phase_bar = PhaseBar.new()
		_phase_bar.stops = stops
		_phase_bar.opponent_name = config.player_names[1 - _human_seat()]
		_phase_bar.slot_pressed.connect(_on_phase_bar_slot)
		_phase_bar.slot_context.connect(_on_phase_bar_context)
		bar_holder.add_child(_phase_bar)

		# THE COMBAT BAR, in the same column and hidden until an attack —
		# "the Combat Bar takes the place of the Phase Bar" (manual p.125).
		_combat_bar = CombatBar.new()
		_combat_bar.visible = false
		_combat_bar.stops = stops
		_combat_bar.slot_pressed.connect(_on_combat_bar_slot)
		_combat_bar.slot_context.connect(_on_combat_bar_context)
		bar_holder.add_child(_combat_bar)

		# THE WINDOW ICON, in the strip's blank CENTRE BAND. Winbk_Phase
		# runs the opponent's eight icons from y=2 and the player's from
		# y=431 of 760, so 330..431 is bare stone — the band the manual
		# means by "the window icon in the center area of the Phase Bar".
		# Winbk_Attackmin is 39x70 against a 41px column: it was drawn to
		# sit here.
		var min_icon := GameSkin.texture("attack_min")
		if min_icon != null:
			_window_icon = TextureButton.new()
			_window_icon.texture_normal = min_icon
			_window_icon.ignore_texture_size = true
			_window_icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			_window_icon.visible = false
			_window_icon.tooltip_text = "Minimized attack window"
			_window_icon.pressed.connect(_on_window_icon_pressed)
			bar_holder.add_child(_window_icon)

	# --------------------------------------------------- the combat window --
	# Opens as soon as the first creature joins the attack (manual p.126).
	# Added BEFORE the arrow layer so the red blocker→attacker arrows draw
	# over it — they run between its two lanes.
	_combat_window = CombatWindow.new()
	_combat_window.card_builder = _make_widget
	_combat_window.visible = false
	_combat_window.minimize_toggled.connect(_on_combat_minimized)
	# `@MENU_ATTACK` / `@MENU_MINIMIZEDATTACK` (§6.12).
	_combat_window.gui_input.connect(_on_attack_window_input)
	add_child(_combat_window)
	move_child(_combat_window, root.get_index() + 1)

	# ----------------------------------------------------------- arrows --
	# Blocker and spell-target arrows (s30 duel.go:3449-3554). s30's Draw()
	# puts them after drawBattlefield and BEFORE drawHandPanel, so they ride
	# over the board but under the hand window — move_child reproduces that
	# order here. The layer resolves its own positions from the MiniCard
	# widgets; the screen only feeds it state (see _update_arrows).
	# Sits directly ABOVE the Combat window, so the blocker arrows drawn
	# between its two lanes are not buried by the window's own ground.
	_arrows = TargetArrows.new()
	_arrows.board_root = self
	_arrows.player_anchors = _life_buttons
	_arrows.hand_anchors = [_hand_rows[1], _hand_rows[0]]
	# Above the Combat window (z 10) and its cards, below the hand window
	# (z 60): the red blocker→attacker arrows run BETWEEN the window's two
	# lanes, so they must not be buried by the window's own ground.
	_arrows.z_index = 20
	add_child(_arrows)
	move_child(_arrows, _combat_window.get_index() + 1)

	# --------------------------------------------------- the damage markers --
	# Manual p.119: *"a damage marker — a yellow 'card' on or near the
	# target of that damage"*. Above the arrows, because a marker is a
	# clickable object and an arrow drawn across it would look like part of
	# it; below the hand window (z 60) and the spell flight (z 70), which
	# are both in front of everything the table draws.
	_damage_markers = DamageMarkerLayer.new()
	_damage_markers.board_root = self
	_damage_markers.player_anchors = _life_buttons
	_damage_markers.marker_clicked.connect(_on_damage_marker_clicked)
	_damage_markers.z_index = 25
	add_child(_damage_markers)
	move_child(_damage_markers, _arrows.get_index() + 1)

	# THE SPELL FLIGHT (§2.4), above everything the board draws — a card
	# in the air is in front of the table it is crossing, including the
	# hand window it just left (z 60).
	_flight = SpellFlight.new()
	_flight.board_root = self
	_flight.fallback = _graveyard_rect
	_flight.landed.connect(func(_id: int) -> void: _refresh())
	_flight.z_index = 70
	add_child(_flight)

	# ----------------------------------------------------------- popups --
	# The X question and the library picker build themselves on demand
	# (_open_x_dialog / _open_search_dialog) as OriginalDialogs. Only the
	# ability menu is long-lived, because it is the one popup that opens
	# AT THE POINTER rather than at the centre of the table — the
	# original's "mini-menu" (manual p.116).
	_ability_menu = PopupMenu.new()
	_ability_menu.id_pressed.connect(_on_ability_chosen)
	# Dressed in the same stone and the same voice as the dialogs.
	_ability_menu.add_theme_stylebox_override("panel",
		OriginalDialog.panel_style("panel_dark_stone", 6.0))
	_ability_menu.add_theme_color_override("font_color",
		OriginalDialog.CHOICE)
	_ability_menu.add_theme_color_override("font_hover_color",
		OriginalDialog.CHOICE_LIT)
	var menu_font := GameSkin.font("font_body")
	if menu_font != null:
		_ability_menu.add_theme_font_override("font", menu_font)
	_ability_menu.add_theme_font_size_override("font_size", 14)
	add_child(_ability_menu)

	# THE PHASE BAR'S OWN mini-menu (`@MENU_PHASEBAR`), in the same stone:
	# Run to / Mark / the two Help entries. Rebuilt on every open because
	# the Mark entry's tick depends on the icon it was opened over.
	_phase_menu = PopupMenu.new()
	_phase_menu.id_pressed.connect(_on_phase_menu_chosen)
	_phase_menu.add_theme_stylebox_override("panel",
		OriginalDialog.panel_style("panel_dark_stone", 6.0))
	_phase_menu.add_theme_color_override("font_color", OriginalDialog.CHOICE)
	_phase_menu.add_theme_color_override("font_hover_color",
		OriginalDialog.CHOICE_LIT)
	if menu_font != null:
		_phase_menu.add_theme_font_override("font", menu_font)
	_phase_menu.add_theme_font_size_override("font_size", 14)
	add_child(_phase_menu)

	# The floating spell chain (original: framed cards at the board's
	# left edge while spells wait — see _rebuild_stack).
	# The chain items float DIRECTLY on the battlefield (the reference has
	# no panel behind them — each item carries its own tan caption box),
	# just inside the board's left edge, above the seam.
	_chain_box = VBoxContainer.new()
	_chain_box.position = Vector2(CardPreview.SIZE.x + 62, 150)
	_chain_box.add_theme_constant_override("separation", 6)
	_chain_box.z_index = 80
	add_child(_chain_box)


	# THE SITUATION BAR (the original's own name for it — manual p.118,
	# docs/glossary-1997.md §1): Done + the Winbk_Telluser stone, floating
	# over the board seam at its left, reading
	# "Done | Fast Effects?...Discard Phase".
	# ONE RULED BOX, with the buttons INSIDE it at the left end. The
	# owner's playtest of 2026-09-03, over his own photograph of the 1997
	# bar: *"In the central message I am missing the lighter border, and
	# the correct button, and the blue-like text like in the photo."*
	#
	# What was here: Done and Cancel floating to the LEFT of a separate
	# ruled panel, so the border ran round the sentence only and the
	# buttons sat on bare board. The photograph has one box — stone,
	# ruled all the way round, with the button inside its left end and the
	# sentence beside it. `Duel.hlp`, topic **Situation Bar**, agrees:
	# *"AT THE RIGHTMOST END OF THIS BAR is a Done button, a Cancel
	# button, or both"* — the buttons are AT AN END OF THE BAR, i.e.
	# inside it. (Ours are at the left end, because the sentence grows to
	# the right and a control that moves is one you cannot aim at.)
	var msg_panel := PanelContainer.new()
	msg_panel.anchor_left = 0.0
	msg_panel.anchor_top = 0.5
	msg_panel.anchor_right = 0.0
	msg_panel.anchor_bottom = 0.5
	# Measured: the reference puts Done at x 0.31 of the screen — INSIDE
	# the board, just right of the phase strip (ours sat on top of it).
	msg_panel.offset_left = 372
	msg_panel.offset_top = -18
	msg_panel.z_index = 90
	# The bar's stone is RULED — Winbk_Telluser carries no frame of its
	# own (`OriginalDialog.PANELS`, "the ONE ground with no bevel of its
	# own"), so the era's own rule is painted onto the tile: 2px of pale
	# (207,209,209) along the top and left, 2px of slate along the bottom
	# and right, measured off `Winbk_Startduelbutton`
	# (`OriginalDialog._rule`). The stone between the rules tiles at its
	# native grain instead of being stretched to fit.
	msg_panel.add_theme_stylebox_override("panel", OriginalDialog.bar_style(5.0))
	var msg_row := HBoxContainer.new()
	msg_row.add_theme_constant_override("separation", 8)
	msg_panel.add_child(msg_row)
	_pass_button = _make_done_button()
	msg_row.add_child(_pass_button)
	# THE MISSING CANCEL (§6.11). `@DIALOGBUTTONS` (UIStrings.txt:172) and
	# `@BUTTONLABELS` (:178) both spell it `Cancel`, and `Duel.hlp` puts it
	# on this bar beside Done — *"a Done button, a Cancel button, or both,
	# depending on the situation"* — in that order. It appears only when
	# there is something to cancel (_can_cancel, applied in _refresh), which
	# is the help file's *"depending on the situation"* and the Manalink
	# `allow_cancel` bit spec's whole point. Until now the targeting prompt
	# said "(Cancel to abort)" and offered no control to click.
	_cancel_button = OriginalDialog.button("Cancel", Vector2(64, 26))
	_cancel_button.tooltip_text = "Cancel  [Esc]"
	_cancel_button.pressed.connect(_on_escape)
	_cancel_button.visible = false
	msg_row.add_child(_cancel_button)
	# LARGE, PALE, with the hard one-pixel dark shadow and NOTHING ELSE —
	# the photograph's "Main phase (before combat): cast spells" in its
	# blue-grey. It used to carry `bold`, which weights the letters with a
	# hairline outline IN THEIR OWN COLOUR: at 16px that doubles the
	# coverage of every stroke and the pale blue-grey reads as flat white,
	# which is exactly the voice the owner said was wrong. The colour was
	# already right; the outline was hiding it.
	_prompt_label = OriginalDialog.label("", 16)
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.custom_minimum_size.x = 340
	msg_row.add_child(_prompt_label)
	add_child(msg_panel)
	# A refusal is red and TEMPORARY (§3.10): this one-shot puts the bar
	# back in its own voice when the flash runs out, so the red line is not
	# left standing by a duel in which nothing else happens to move.
	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.timeout.connect(_on_flash_expired)
	add_child(_flash_timer)

	# The enlarged card, DOCKED large in the sidebar middle (the owner's
	# screenshots) — every hover renders here and the last card PERSISTS.
	_card_preview = CardPreview.new()
	_card_preview.docked = true
	_preview_dock.add_child(_card_preview)
	# Nothing examined yet: the slot holds a face-down card back rather
	# than a black hole (the owner's note) — the first hover replaces it.
	_card_preview.show_back()
	# `@MENU_FULLCARD` (§6.12) and the `Expand` toggle it carries, restored
	# from the setting the 1997 executable calls `ExpandTextBoxOnBigCard`.
	_card_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_preview.gui_input.connect(_on_showcase_input)
	_card_preview.set_text_expanded(
		bool(Settings.get_value("ExpandTextBoxOnBigCard", false)))
	if _hand_rows[1] is StackHand:
		_hand_rows[1].preview = _card_preview
	# `@MENU_HAND` (§6.12) on both hand windows. The 1997 table has one
	# entry and it is `Help...`, so the whole menu is grey — it is here so
	# the gesture answers rather than falling through to the territory
	# underneath, which would open a menu about the wrong thing.
	for row in _hand_rows:
		if row != null:
			row.gui_input.connect(_on_hand_input)

	# THE TERRITORY MENU (`@MENU_TERRITORY`, §6.3), in the same stone as the
	# other two. Rebuilt on every open because which entries are live
	# depends on the seat the right-click landed in — *"Depending on the
	# situation, one or more of these options is available."*
	_territory_menu = PopupMenu.new()
	_territory_menu.id_pressed.connect(_on_territory_menu_chosen)
	_territory_menu.add_theme_stylebox_override("panel",
		OriginalDialog.panel_style("panel_dark_stone", 6.0))
	_territory_menu.add_theme_color_override("font_color", OriginalDialog.CHOICE)
	_territory_menu.add_theme_color_override("font_hover_color",
		OriginalDialog.CHOICE_LIT)
	if menu_font != null:
		_territory_menu.add_theme_font_override("font", menu_font)
	_territory_menu.add_theme_font_size_override("font_size", 14)
	add_child(_territory_menu)

	# The rest of the `@MENU_*` family (§6.12, [CardMenu]) — same stone,
	# same voice, one menu per table.
	_card_menu = _dress_menu(_on_card_menu_chosen, menu_font)
	_library_menu = _dress_menu(_on_library_menu_chosen, menu_font)
	_hand_menu = _dress_menu(func(_i: int) -> void: pass, menu_font)
	_mana_menu = _dress_menu(func(_i: int) -> void: pass, menu_font)
	_full_card_menu = _dress_menu(_on_full_card_menu_chosen, menu_font)
	_attack_menu = _dress_menu(_on_attack_menu_chosen, menu_font)

	# THE LIFE REGISTER'S mini-menu (`@MENU_LIFE` / `@MENU_FACE`, §6.5),
	# same stone again. Rebuilt on every open because its third entry is
	# whichever way the panel is facing at that moment.
	_life_menu = PopupMenu.new()
	_life_menu.id_pressed.connect(_on_life_menu_chosen)
	_life_menu.add_theme_stylebox_override("panel",
		OriginalDialog.panel_style("panel_dark_stone", 6.0))
	_life_menu.add_theme_color_override("font_color", OriginalDialog.CHOICE)
	_life_menu.add_theme_color_override("font_hover_color",
		OriginalDialog.CHOICE_LIT)
	if menu_font != null:
		_life_menu.add_theme_font_override("font", menu_font)
	_life_menu.add_theme_font_size_override("font_size", 14)
	add_child(_life_menu)
	# A right-click anywhere in a territory that is not on a card opens it.
	# The row containers PASS so the empty air between piles falls through
	# to the half's own VBox, which is the control that spans the territory;
	# a MiniCard is MOUSE_FILTER_STOP and keeps its own right-clicks, which
	# is right — a card has its own mini-menu (`@MENU_SMALLCARD`, §6.12).
	for pid in 2:
		for row in _field_rows[pid]:
			_field_rows[pid][row].mouse_filter = Control.MOUSE_FILTER_PASS
		var rows: Control = _half_rows[pid]
		if rows != null:
			rows.mouse_filter = Control.MOUSE_FILTER_STOP
			rows.gui_input.connect(_on_territory_input.bind(pid))

	# ONE NODE FOR THE WHOLE SOUND LAYER (§3.8, 2026-09-02). This used to
	# be two bare `AudioStreamPlayer`s with `Settings` volumes copied onto
	# them: one voice for every effect in the duel, so a tap during a
	# damage sound cut it off, and a volume that could not be changed
	# without restarting the duel. [DuelAudio] pools its voices and
	# [GameAudio] owns the volume, on a bus.
	_audio = DuelAudio.new()
	add_child(_audio)

	# (The original body font — MPlantin, the card face of the era — is
	# applied by OriginalDialog.label, the one place the bar's voice and
	# every dialog's reading surface are defined.)




## How far down the territory ground is taken so the cards on it read.
## The 1997 art is a full-strength picture and our cards are drawn with
## more contrast than the original's, so the table is dimmed rather than
## the cards brightened.
const GROUND_DIM := Color(0.55, 0.55, 0.55)


## One half of the playfield: the seat's territory ground with the row
## VBox on top. Both halves get equal stretch, so the board splits EXACTLY
## in half at the message seam (the reference layout).
func _board_half(pid: int) -> Array:
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.size_flags_stretch_ratio = 1.0
	holder.clip_contents = true
	holder.add_child(_ground_node(pid))
	# Inset the rows so cards never sit flush against the half's edges
	# (the reference leaves a clear margin all round).
	var rows := VBoxContainer.new()
	rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	rows.offset_left = BOARD_INSET
	rows.offset_right = -BOARD_INSET
	rows.offset_top = BOARD_INSET_V
	rows.offset_bottom = -BOARD_INSET_V
	rows.add_theme_constant_override("separation", 2)
	holder.add_child(rows)
	_half_rows[pid] = rows
	# THE FREE LAYER, over the rows: the cards the player has moved by hand
	# (§2.3b). Mouse-transparent itself — only its children take clicks —
	# and inset exactly like the rows, so a placement reads in the same
	# coordinates whichever way a card got there.
	var free := Control.new()
	free.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	free.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(free)
	_free_layers[pid] = free
	# The half only knows its own rect after the first layout pass, and the
	# reservation is measured against that rect — so recompute whenever it
	# changes (boot, window resize, stretch mode).
	# A HALF THAT CHANGES SIZE MOVES THE BOUNDARY (§2.3b). A placement is
	# kept for the whole duel in this half's own coordinates, so a card
	# parked at the right edge of a 1920-wide window is 320px outside a
	# 1280-wide one — and `clip_contents` above means outside is INVISIBLE.
	# THE HALF'S OWN RECT IS THE ONLY THING THAT MAY FIRE THIS: a re-clamp
	# is a correction for a card that would otherwise be off-screen, never
	# a tidy-up, so nothing else gets to move a placement (§2.3b).
	holder.resized.connect(_reclamp_placements)
	return [holder, rows]


## One player's sidebar block, per the reference: the huge life numeral
## at the panel's EXTREME corner (a Button — it IS the "any target"
## click target), the deck/graveyard piles toward the middle, the
## mana-pool column beside. [param life_first] mirrors the block
## (opponent: life on top; player: life at the bottom corner).
func _player_panel(pid: int, life_first := true) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var life := Button.new()
	life.custom_minimum_size = Vector2(96, 76)
	life.add_theme_font_size_override("font_size", 44)
	life.add_theme_color_override("font_color", Color(0.95, 0.85, 0.20))
	life.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.35))
	life.pressed.connect(_on_life_clicked.bind(pid))
	# `Duel.hlp`, topic Duelist's Face: the panel is turned over from its
	# own mini-menu, which a right-click opens (§6.5).
	life.gui_input.connect(_on_life_input.bind(pid))
	_life_buttons.resize(2)
	_life_buttons[pid] = life
	_dress_life_panel(pid, false)

	# POISON: ten counters lose the game (CR 704.5c), and the duel had no
	# clock for it at all — a game lost to Marsh Viper simply ended
	# (2026-09 audit). Rides the life panel's bottom corner, in venom
	# green, and stays hidden while the count is zero.
	var poison := Label.new()
	poison.add_theme_font_size_override("font_size", 15)
	poison.add_theme_color_override("font_color", Color(0.42, 0.85, 0.30))
	poison.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	poison.add_theme_constant_override("shadow_offset_x", 1)
	poison.add_theme_constant_override("shadow_offset_y", 1)
	poison.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	poison.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	poison.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poison.set_anchors_preset(Control.PRESET_FULL_RECT)
	poison.offset_right = -5
	poison.offset_bottom = -3
	poison.visible = false
	life.add_child(poison)
	_poison_labels.resize(2)
	_poison_labels[pid] = poison

	# Library as a PHYSICAL stack of card backs with the count on its top
	# card, beside the graveyard panel (the original's [deck] [graveyard]
	# pair). The stack itself is drawn by [method _dress_deck_stack] and
	# REDRAWN as the library empties; see [constant LIBRARY_STEPS].
	var piles_row := HBoxContainer.new()
	piles_row.add_theme_constant_override("separation", PILES_SEPARATION)
	var deck_stack := Control.new()
	deck_stack.custom_minimum_size = DECK_STACK
	# SHRINK_CENTER, not the container's default FILL: the row is as tall
	# as the portrait block beside it, and a pile stretched to that height
	# draws its art letterboxed inside a taller box — which would leave
	# every count floating BELOW the plate it counts.
	deck_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_deck_stacks.resize(2)
	_deck_stacks[pid] = deck_stack
	_deck_sheets.resize(2)
	_deck_sheets[pid] = -1
	# The TOP card back never moves — the stack grows and shrinks BEHIND
	# it, up and to the left — so the count can simply take the box's own
	# bottom-right corner and be right at every thickness.
	_lib_labels.resize(2)
	_lib_labels[pid] = _pile_count_label(deck_stack)
	# `@MENU_LIBRARY` (§6.12): *"you can right-click on a library to find
	# out the exact number of cards left in it."*
	deck_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	deck_stack.gui_input.connect(
		func(event: InputEvent) -> void: _on_pile_input(event, pid))
	piles_row.add_child(deck_stack)
	# The graveyard shows its TOP CARD when it has one, and the original's
	# empty-grave art otherwise (the reference: a card face in a full
	# graveyard, the red skull plate in an empty one).
	var grave_icon := TextureRect.new()
	_grave_icons.resize(2)
	_grave_icons[pid] = grave_icon
	var grave_texture := GameSkin.texture("grave_panel_" + config.panel_colors[pid])
	if grave_texture != null:
		grave_icon.texture = grave_texture
		grave_icon.custom_minimum_size = Vector2(40, 60)
		grave_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grave_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		grave_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		# THE PILE IS A CONTROL, not decoration (docs/duel-todo.md §1.2):
		# `@MENU_GRAVEYARD` is the original's own right-click menu on it,
		# and until this line the four graveyard target kinds had nothing
		# clickable to point at. s30's handleGraveyardClick: a non-empty
		# pile opens the view, the same pile again closes it.
		grave_icon.mouse_filter = Control.MOUSE_FILTER_STOP
		grave_icon.tooltip_text = "Your graveyard" if pid == _human_seat() \
			else "%s graveyard" % config.player_names[pid]
		grave_icon.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
				_on_grave_pile_clicked(pid))
		var ring := Panel.new()
		var ring_box := StyleBoxFlat.new()
		ring_box.bg_color = Color(0, 0, 0, 0)
		ring_box.set_border_width_all(2)
		ring_box.border_color = MiniCard.HIGHLIGHT_COLORS[MiniCard.Highlight.TARGET]
		ring.add_theme_stylebox_override("panel", ring_box)
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.visible = false
		grave_icon.add_child(ring)
		_grave_rings.resize(2)
		_grave_rings[pid] = ring
		# THE GRAVEYARD'S COUNT, on the graveyard — see the record beside
		# [constant PILE_COUNT_INK]. Until 2026-09-03 this number was a
		# loose Label at the END of the row, so it stood in the black gap
		# to the right of the EXILE plate and read as a stray digit.
		_grave_labels.resize(2)
		_grave_labels[pid] = _pile_count_label(grave_icon)
		piles_row.add_child(grave_icon)
		# THE EXILE PILE, immediately RIGHT of the graveyard (the owner's
		# ask): the same 40x60 plate, the same click, the same viewer. It is
		# built inside this branch on purpose — a seat with no grave plate
		# gets no exile plate either, and ExilePlate paints one only when the
		# grave plate it borrows its palette from exists.
		var exile_icon := TextureRect.new()
		_exile_icons.resize(2)
		_exile_icons[pid] = exile_icon
		exile_icon.texture = ExilePlate.plate(config.panel_colors[pid])
		exile_icon.custom_minimum_size = Vector2(40, 60)
		exile_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		exile_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		exile_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		exile_icon.mouse_filter = Control.MOUSE_FILTER_STOP
		exile_icon.tooltip_text = "Exiled cards (out of play)"
		# `@MENU_GRAVEYARD`'s three views live in ONE overlay, so this plate
		# opens the very viewer the graveyard does — the exile section is
		# already in it — rather than a second one of its own.
		exile_icon.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
				_on_grave_pile_clicked(pid))
		# The count rides ON the plate (the row has no width to spare beside
		# the mana column) and is blank while the pile is empty.
		_exile_labels.resize(2)
		_exile_labels[pid] = _pile_count_label(exile_icon)
		piles_row.add_child(exile_icon)
	else:
		# NO 1997 PLATES: there is no graveyard art for the count to ride,
		# so it stays what it always was — a bare number at the end of the
		# row. The seat's portrait still stands beside it.
		_grave_labels.resize(2)
		_grave_labels[pid] = _pile_count_label(null)
		piles_row.add_child(_grave_labels[pid])
	# THE SEAT'S PORTRAIT, in the space the stray count used to occupy.
	piles_row.add_child(_seat_portrait_block(pid, not life_first))

	# Mirrored blocks: the life numeral hugs the screen corner (opponent:
	# top; player: bottom), the deck/grave piles sit toward the middle.
	# The block stands as tall as the mana column beside it, which is
	# taller than life+piles, so the slack is parked on the MIDDLE side.
	# Without it the player's numeral floated short of the screen's
	# bottom edge and the piles sat too high (the owner caught the gap).
	var slack := Control.new()
	slack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if life_first:
		left.add_child(life)
		left.add_child(piles_row)
		left.add_child(slack)
	else:
		left.add_child(slack)
		left.add_child(piles_row)
		left.add_child(life)

	row.add_child(left)
	row.add_child(_mana_column(pid))
	return row


## ONE PILE'S COUNT, in the bottom-right corner of the art it belongs to.
## [param host] is that art — the top card back, the grave plate, the
## exile plate — and the label anchors to its whole rect so the corner
## stays the corner however the row is stretched. A null [param host]
## (no 1997 skin, so no plate to ride) returns the label unparented for
## the caller to place; the colouring is the same either way.
##
## The voice is [constant PILE_COUNT_INK] over a hard black outline; see
## the record beside that constant for why yellow and why an outline.
func _pile_count_label(host: Control) -> Label:
	var count := Label.new()
	count.add_theme_font_size_override("font_size", PILE_COUNT_FONT_SIZE)
	count.add_theme_color_override("font_color", PILE_COUNT_INK)
	# OUTLINED, not shadowed: the number sits on whatever card art the
	# pile's top card happens to have, and a 1px shadow vanished on a
	# pale one (Healing Salve).
	count.add_theme_color_override("font_outline_color", PILE_COUNT_OUTLINE)
	count.add_theme_constant_override("outline_size", PILE_COUNT_OUTLINE_SIZE)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if host != null:
		count.set_anchors_preset(Control.PRESET_FULL_RECT)
		count.offset_right = -2
		count.offset_bottom = -1
		host.add_child(count)
	return count


## HOW MANY CARD BACKS A LIBRARY OF [param cards] IS DRAWN AS — one per
## threshold in [constant LIBRARY_STEPS] that the count has reached, so
## nought to six. Static, and the whole rule: "how thick is the deck at N
## cards" is exactly the kind of number that drifts, so it lives in one
## place and `tests/ui/test_zone_column.gd` pins every step of it.
static func library_thickness(cards: int) -> int:
	var sheets := 0
	for step in LIBRARY_STEPS:
		if cards >= step:
			sheets += 1
	return sheets


## Redraw one seat's library as a stack of that thickness. Cheap by
## construction: it returns at once unless the count has crossed a step,
## which happens six times in a duel, and the TOP card back stays put —
## the stack grows and shrinks behind it, up and to the left — so the
## count label riding the box's corner never has to move.
func _dress_deck_stack(pid: int, cards: int) -> void:
	if _deck_stacks.size() != 2 or _deck_stacks[pid] == null:
		return
	var want := library_thickness(cards)
	if _deck_sheets[pid] == want:
		return
	_deck_sheets[pid] = want
	var stack: Control = _deck_stacks[pid]
	for child in stack.get_children():
		if child is TextureRect:
			stack.remove_child(child)
			child.queue_free()
	var back := GameSkin.texture("card_back")
	# The FRONT sheet is always the last step's slot, whatever the depth.
	var first: int = LIBRARY_STEPS.size() - want
	for j in want:
		var sheet := TextureRect.new()
		if back != null:
			sheet.texture = back
		sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sheet.stretch_mode = TextureRect.STRETCH_SCALE
		sheet.size = DECK_SHEET
		sheet.position = DECK_STEP * (first + j)
		# The whole stack answers to ONE click target, the box below it
		# (`@MENU_LIBRARY`), so the sheets take no input of their own.
		sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if back == null:
			var filler := ColorRect.new()
			filler.color = Color(0.16, 0.10, 0.22)
			filler.set_anchors_preset(Control.PRESET_FULL_RECT)
			sheet.add_child(filler)
		stack.add_child(sheet)
	# ...and the count stays on top of what was just drawn.
	if _lib_labels.size() == 2 and _lib_labels[pid] != null:
		stack.move_child(_lib_labels[pid], -1)


## THE SEAT'S OWN FACE AND NAME, the fourth column of the piles row.
##
## The owner's ask, 2026-09-03: *"There is space right of the exile stack!
## Put there the player's chosen portrait, and his name above it. Same for
## the opponent — name BELOW the portrait, to be symmetric."* That space
## is the black gap the graveyard's stray count used to stand in, so
## moving the counts onto their piles and putting the face here are one
## move, not two. [param name_above] is the player's half of the mirror
## (the bottom panel, whose life numeral is last); the opponent's block is
## flipped so the two names sit closest to the screen's own edges.
##
## THE PORTRAIT IS THE ONE THE SEAT CHOSE on the battle-setup screen
## (`DuelConfig.portraits` -> [PortraitLibrary]), resolved through
## [method DuelIntro.portrait_for] rather than by a second resolver of our
## own, so the duel and the pre-duel splash can never disagree — and so a
## seat that chose nothing falls back to its DUELIST face exactly as the
## splash does. Nothing in a duel read that choice before today.
##
## WHY IT IS SMALL, and why the name has to be trimmed. The row has 185
## to give and the three piles and their gaps spend 50+5+40+5+40+5 = 145
## of it (the arithmetic is written out beside [constant
## PILES_SEPARATION]), so the portrait takes the plates' own 40 — which is
## also what makes the four columns read as one row. A Label's minimum
## width is its WHOLE string, so a long name in that column would push the
## mana panel off the screen; hence the ellipsis, which is [MiniCard]'s
## own treatment for a card name that outruns its band, and a tooltip
## carrying the name in full.
func _seat_portrait_block(pid: int, name_above: bool) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 1)
	block.custom_minimum_size.x = SEAT_PORTRAIT.x
	block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var seat_name := String(config.player_names[pid]) if config != null else ""
	var name_label := Label.new()
	name_label.text = seat_name
	name_label.add_theme_font_size_override("font_size", SEAT_NAME_FONT_SIZE)
	name_label.add_theme_color_override("font_color", PILE_COUNT_INK)
	name_label.add_theme_color_override("font_outline_color", PILE_COUNT_OUTLINE)
	name_label.add_theme_constant_override("outline_size", PILE_COUNT_OUTLINE_SIZE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# BOUND TO THE PORTRAIT'S WIDTH. Trimming is what turns a Label's
	# minimum width off — without it "Wolfgang Amadeus Mozart" would make
	# this column 110px wide and push the mana panel off the screen.
	#
	# ..._FORCE, NOT the plain `OVERRUN_TRIM_ELLIPSIS`. Measured under
	# Xvfb at this exact size (40px box, 10px text): the plain behaviour
	# trims to "Wolfgan" and DROPS the ellipsis, so the name silently
	# looks like a short name. Only the FORCE variant reserves room for
	# the dots and renders "Wolfg…", which is what the owner asked for.
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS_FORCE
	name_label.clip_text = true
	name_label.custom_minimum_size = Vector2(SEAT_PORTRAIT.x, SEAT_NAME_HEIGHT)
	name_label.tooltip_text = seat_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seat_name_labels.resize(2)
	_seat_name_labels[pid] = name_label

	var face := TextureRect.new()
	face.texture = DuelIntro.portrait_for(config, pid) if config != null else null
	face.custom_minimum_size = SEAT_PORTRAIT
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# COVERED, not CENTERED: the chosen portraits are 137x169 (0.81) and
	# the box is 0.80, so the crop is a pixel — but the DUELIST fallback is
	# a 120x88 landscape plate, and letterboxed into 40 wide it shrank to a
	# 29px smear. Covered, both fill the box at their own aspect.
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# The 1997 faces are 137x169 pixel art; smoothing them at this size
	# turns them to mush (the same call DuelIntro makes for its wells).
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if face.texture == null:
		# No skin AND no chosen portrait: the clean skin's frame, so the
		# block reads as an empty portrait rather than as a hole. Exactly
		# what DuelIntro does for an unskinned well.
		var frame := Panel.new()
		frame.add_theme_stylebox_override("panel", UiChrome.stone_panel(0.0))
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(frame)
	_seat_portraits.resize(2)
	_seat_portraits[pid] = face

	if name_above:
		block.add_child(name_label)
		block.add_child(face)
	else:
		block.add_child(face)
		block.add_child(name_label)
	return block


## The mana pool as the original's Winbk_Manapool panel: six painted
## symbols (B U G R W X, 30px rows — s30's drawManaPool order) with the
## live counts beside them. Letter rows when the skin is absent.
func _mana_column(pid: int) -> Control:
	var holder := Control.new()
	# `@MENU_MANAPOOL` (§6.12) — complete and entirely greyed; see
	# [constant CardMenu.MANA_POOL] for why the seven spends cannot be
	# wired without an engine change.
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.gui_input.connect(_on_mana_input)
	# The reference fits [life|pool] + big card + [life|pool] into a 563-tall
	# screen; ours is 800 tall but proportionally taller-carded, so the pool
	# scales to whatever is left beside the 428px card: (800-428)/2 per
	# block, minus margins.
	var pool_scale := 0.85
	holder.custom_minimum_size = Vector2(128, 188) * pool_scale
	var tex := GameSkin.texture("mana_pool_panel")
	if tex != null:
		var bg := TextureRect.new()
		bg.texture = tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(bg)
	var order: Array = [Mtg.ManaColor.B, Mtg.ManaColor.U, Mtg.ManaColor.G,
		Mtg.ManaColor.R, Mtg.ManaColor.W, Mtg.ManaColor.C]
	var letters := {Mtg.ManaColor.B: "B", Mtg.ManaColor.U: "U", Mtg.ManaColor.G: "G",
		Mtg.ManaColor.R: "R", Mtg.ManaColor.W: "W", Mtg.ManaColor.C: "C"}
	_mana_labels.resize(2)
	_mana_labels[pid] = {}
	for i in order.size():
		var count := Label.new()
		count.text = "0"
		count.add_theme_font_size_override("font_size", 18)
		count.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))
		count.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		count.add_theme_constant_override("shadow_offset_x", 1)
		count.add_theme_constant_override("shadow_offset_y", 1)
		count.position = Vector2(46 * pool_scale, 2 + i * 30.5 * pool_scale)
		holder.add_child(count)
		if tex == null:
			var letter := Label.new()
			letter.text = letters[order[i]] + ":"
			letter.add_theme_font_size_override("font_size", 12)
			letter.position = Vector2(8, count.position.y)
			holder.add_child(letter)
		_mana_labels[pid][order[i]] = count
	return holder


## The Situation Bar's Done button — `@DIALOGBUTTONS` names exactly three
## buttons in the whole 1997 game ("OK", "Cancel", "Done"), and this is
## the one the duel wears.
##
## It used to blit Statbutt cells 11-13, which s30 uses for it. That sheet
## is the ADVENTURE's button strip — its neighbours are "WIZ STATS" and
## "JOURNAL" — and its DONE is a flat grey 48x22 tile that had to be
## stretched to 64x24 and could not carry a bevel at that size. The
## owner's reference photo shows the seam button BEVELLED, light on its
## top-left and dark on its bottom-right, with a pale label: that is the
## era's generic three-state button art, which is what OriginalDialog
## builds. Same word, same place, the original's own frame.
func _make_done_button() -> Button:
	# The reference's Done is ~37px of a 750-wide screen — 64 at our 1280.
	#
	# THE ERA'S RAISED BUTTON, and this is the second reading of that
	# photograph. The first (2026-08-31) took the button's face for a
	# LIGHTENED PATCH OF THE BAR'S OWN STONE, on the grounds that the shot
	# looked tan; `OriginalDialog.bar_button_texture` still carries that
	# derivation and `ArrangeButton` still wears it. The owner's playtest
	# of 2026-09-03 — *"the correct button"* — settles it the other way:
	# the Situation Bar's Done is `Winbk_Startduelbutton`, the one piece
	# of generic button art the 1997 game ships, double-ruled and lettered
	# in dark ink on its light face. A phone photograph of a CRT is not a
	# colour reference; the art is.
	var done := OriginalDialog.button("Done", Vector2(64, 26))
	done.tooltip_text = "Pass priority  [Space]"
	done.pressed.connect(_on_done)
	return done


## Fold the player's hand window away, or unfold it (§3.6). A no-op with
## the FAN hand, which is laid out inside the board and covers nothing —
## the "Hand display" option picks between the two (`game/settings.gd`).
func _toggle_hand() -> void:
	if _hand_rows.size() > 1 and _hand_rows[1] is StackHand:
		_hand_rows[1].toggle_collapsed()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# NOTHING UNDER THE COIN TOSS. The toss and the opening hand play
		# over a table the engine has not started (turn 0): a Return here
		# used to leave a standing Done order that auto-passed the first
		# main phase, and a Space walked turn 0's steps (2026-09-02).
		if _toss_active:
			return
		# THE PAUSE WINDOW owns both its keys while it is up, and nothing
		# else reaches the table under it (§ the Pause block above).
		if is_paused():
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_Q:
				_close_pause()
			return
		# s30's choice overlay answers to the NUMBER KEYS (`duel.go:2643-2649`
		# — `ebiten.Key1 + ebiten.Key(i)` for the first nine options), and so
		# does ours; while it is up they mean nothing else (§1.3) — except
		# Esc, which withdraws a COST question and nothing else
		# ([method _on_escape]).
		if _choice_overlay != null:
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				_on_choice_option(event.keycode - KEY_1)
			elif event.keycode == KEY_ESCAPE:
				_on_escape()
			return
		match event.keycode:
			KEY_SPACE:
				# THE SPACEBAR RULE, verbatim (`Duel.hlp`, Situation Bar):
				# *"if there is only one button, pressing this is the same
				# as clicking that button."* Done is always on the bar, so
				# Space is Done — right up until Cancel joins it, at which
				# point the bar has two buttons and the key is ambiguous.
				# The original says so; Return and Esc still name one each.
				if not _can_cancel() and not _dialogs_open():
					_on_done()
			KEY_ENTER, KEY_KP_ENTER:
				# Manual p.116: "Return has the same effect as clicking the
				# Done button", and Done (p.112) is the STANDING instruction
				# — run on until a Stop, a required decision, or a fast
				# effect you can afford (docs/duel-todo.md §6.20a). It used
				# to be a blind 60-pass fast-forward that burned every
				# priority window on the way.
				#
				# In every mode BUT normal, Done means what the button
				# means: confirm the declaration, finish the discard or the
				# damage division, or close a variable target slot. Return
				# used to dead-end in all four of those (_on_pass_turn
				# returns at once unless the mode is NORMAL), so the one
				# keystroke the manual names could not answer the prompts
				# that most need answering.
				if _modal_open() or _dialogs_open():
					pass          # the dialog's own OK answers it
				elif mode == Mode.NORMAL:
					_on_pass_turn()
				else:
					_on_done()
			KEY_ESCAPE:
				# *"Esc is just like Cancel"* — one door, and it peels
				# exactly one layer per press (§3.2). ONLY when there is
				# something to peel: with nothing pending the same key
				# opens the Pause window, and a player mid-cast who
				# presses it wants their cast back, not a quit dialog.
				# [method _can_cancel] is the same predicate the Situation
				# Bar's Cancel button uses, so the key and the button can
				# never disagree about whether there is anything to undo.
				if _can_cancel() or _dialogs_open():
					_on_escape()
				else:
					_toggle_pause()
			KEY_Q:
				# The Pause window's own key, and it carries no 1997 duty
				# of any kind — so unlike Esc it opens the window whatever
				# else is going on, and closes it again.
				_toggle_pause()
			KEY_H:
				# s30's one-key hand fold (`duel.go:1172-1174`). §3.6: the
				# control exists so the hand stops covering your own
				# attackers, which is a thing you need MID-DECLARATION,
				# with the pointer already busy on the board — so it has
				# to be reachable without aiming at a 22px title bar.
				_toggle_hand()
			KEY_M:
				# A SESSION HUSH, not a preference: `M` silences both
				# buses and writes nothing to `user://settings.cfg`
				# ([GameAudio.set_hushed]). Muting to take a phone call
				# must not still be muted next week.
				GameAudio.set_hushed(not GameAudio.is_hushed())
				_set_prompt("Sound %s" %
					("muted" if GameAudio.is_hushed() else "on"))
			KEY_T:
				# `Show ID tags\tCtrl+T` (§6.3a). Ctrl is load-bearing: a
				# bare T stays free, so each arm checks it itself rather
				# than a table that could eat the plain key.
				if event.ctrl_pressed:
					_accelerate_toggle("ShowIDTagsOnCards")
			KEY_I:
				# `Show invisible effects\tCtrl+I` — dark, so it does
				# nothing, through the same gate the menu obeys.
				if event.ctrl_pressed:
					_accelerate_toggle("ShowInvisibleEffectCards")
			KEY_U:
				# `Show all cards' summoning sickness\tCtrl+U`.
				if event.ctrl_pressed:
					_accelerate_toggle("ShowAllCardsSummonSickness")
			KEY_F12:
				var shot := get_viewport().get_texture().get_image()
				var shot_path := "user://screenshot_%d.png" % Time.get_ticks_msec()
				shot.save_png(shot_path)
				_set_prompt("Screenshot: %s" %
					ProjectSettings.globalize_path(shot_path))

class_name DeathMark
extends Control
## THE DYING MARK — the 1997 game's `Dying` state, held on the table for a
## beat over the square a destroyed permanent has just left.
##
## **WHAT THE ORIGINAL'S `Dying` STATE ACTUALLY IS**, and it is not "lethal
## damage". `@CUECARD_SMALLCARD` (`UIStrings.txt:732`) entry 8 is the word
## `Dying`, and the small card's own tooltip handler says exactly when a
## card wears it (`shandalar-src/src/functions/windows.c:724`, the hook
## around `wndproc_CardClass`, quoting the 1997 exe's own string at
## `0x786f08`):
##
## [codeblock]
## else if (instance->kill_code == KILL_DESTROY)
##   strcpy(tooltip, EXE_STR(0x786f08));   // CUECARD_SMALLCARD[7] = Dying
## [/codeblock]
##
## `KILL_DESTROY` (`src/defs.h:428`) is the DESTRUCTION kill code — set on
## a permanent that has been marked to go to the graveyard and has not been
## reaped yet. It is the same predicate a regeneration effect targets:
## `TARGET_SPECIAL_REGENERATION` *"checks both the `kill_code` for
## `KILL_DESTROY` and `token_status` for `STATUS_CANNOT_REGENERATE`"*
## (`defs.h:2481`), and its refusal string is the one three cards carry —
## `Illegal target (not dying).` (`Program/prompts.txt:239` Death Ward,
## `promptsX1.txt:167` Elephant Graveyard, `:323` Pyramids).
##
## `Duel.hlp` says the same thing in words, topic **Regeneration**: *"You
## can use regeneration ONLY at the time when a creature is about to go to
## the graveyard."* So the mark is worn for exactly the window between
## "this is destroyed" and "this is in the graveyard" — not while damage
## merely sits on a creature, and not after it lands in the graveyard.
##
## Three consequences, and each is a decision this class makes:
##
##  1. **It is DESTRUCTION, not death.** `KILL_SACRIFICE` and `KILL_BURY`
##     are separate codes and neither reads `Dying` — which is the same
##     line our own engine draws, since [method MtgGame.sacrifice_permanent]
##     never enters [method MtgGame.destroy] and regeneration cannot answer
##     it. So a sacrificed permanent gets no mark (the `DIES` event carries
##     `sacrificed`, and that is what it is read for here).
##  2. **A REGENERATED CREATURE MUST NOT WEAR IT.** In 1997 the mark goes
##     when `regenerate_target_exe` clears the kill code; here it never
##     appears at all, because the mark is raised off
##     [constant Mtg.EventType.DIES] and [method MtgGame.destroy] returns
##     from its regeneration branch long before that is dispatched. The
##     mark cannot lie about a creature that survived, which is the whole
##     reason it is hung on the death rather than on the damage.
##  3. **[QoL] THE HOLD IS OURS.** 1997's window has the duration of a
##     player's decision — the regeneration step waits to be passed. This
##     engine only holds that step open under
##     `RulesOptions.damage_prevention_window` (and even then it auto-skips
##     when no seat holds a regeneration effect), so under the default
##     modern ruleset the moment is real but has no duration at all. The
##     hold below is the honest translation of a step into a beat, and it
##     is the one invented number here (`docs/ROADMAP.md`).
##
## **WHERE IT IS DRAWN.** Over the card's ART, which is where the original
## puts it: the same tooltip handler makes the `Dying` cue the answer for
## the rect `5%..95%` of the card's width by `15%..95%` of its height — the
## art window — and `Dying.pic` is 194x97, i.e. a 97x97 image beside a 97x97
## mask, the exact shape of `Summon.pic`, whose spiral this widget already
## draws over that same window. So the mark is a [MiniCard] wearing
## [member MiniCard.force_dying], and the placement is not re-derived here:
## it is [constant MiniCard.ART_LEFT] and its three neighbours, once.
##
## **IT IS A WHOLE CARD, not bare cracks over the felt**, and that is a
## correctness choice rather than a decorative one. The board re-flows the
## instant a creature leaves it, so a row closes over the gap within a
## frame or two; cracks alone would then be sitting on top of a LIVE
## neighbour and saying that it was the one dying. The dead card's own face
## under them can be mistaken for nothing else.

## How long the mark stands at full strength before it starts to go, and
## how long it takes to go. **[QoL]** — see the class docs: 1997's window
## is as long as a player takes to pass the regeneration step.
const HOLD := 0.45
const FADE := 0.55

## Above the board, the Combat window (z 10), the target arrows (20) and
## the damage markers (25); below the spell flight (70) and everything
## modal. The duel screen's own ladder, `duel_screen.gd:5258-5348`.
const Z := 30

## The dead card's face, wearing the `Dying` cracks over its art.
var ghost: MiniCard = null

## Seconds since the mark was raised. Advanced by [method _process] in the
## running game and by [method advance] directly in a test, so the fade is
## checkable without waiting a second of wall clock for it.
var _age := 0.0


## Raise a mark over [param card]'s square and hand it to the highest
## Control above the card, which outlives the board rebuild that is about
## to free the card itself (`DuelScreen._rebuild_field` frees every widget
## on the table on every refresh — a mark parented to the card, or to its
## row, would be freed with it in the same frame it was made).
##
## Returns null, and draws nothing, whenever the card is not somewhere a
## mark could go: off the tree, hidden, clipped out of its half, or with no
## Control above it to hang from. That is the rule [TargetArrows] and
## [DamageMarkerLayer] already follow — a mark floating over nothing is
## worse than no mark.
static func raise_over(card: MiniCard) -> DeathMark:
	if card == null or not is_instance_valid(card):
		return null
	if not card.is_inside_tree() or not card.visible:
		return null
	var host := host_for(card)
	if host == null:
		return null
	# The anchor rect, not `get_global_rect()`: a TAPPED card is turned 90°
	# inside an upright holder and its own rect ignores the rotation, and a
	# card scrolled out of its board half comes back empty.
	var rect := TargetArrows.anchor_rect(card)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return null
	var mark := DeathMark.new(card.instance)
	host.add_child(mark)
	mark.size = rect.size
	mark.global_position = rect.position
	return mark


## The highest [Control] ABOVE [param card] — the duel screen itself, in
## practice. Null when the card has no Control parent at all, which is the
## case in a bare unit test and is why a test that wants a mark parents its
## card inside one.
static func host_for(card: Control) -> Control:
	if card == null or not is_instance_valid(card):
		return null
	var host: Control = null
	var walk: Node = card.get_parent()
	while walk is Control:
		host = walk
		walk = walk.get_parent()
	return host


func _init(instance: CardInstance = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = Z
	custom_minimum_size = MiniCard.SIZE
	size = MiniCard.SIZE
	if instance == null:
		return
	# NO GAME REFERENCE ON THE GHOST, deliberately. `game` is what connects
	# a MiniCard to `MtgGame.event_occurred` ([method MiniCard._on_game_event]),
	# and a ghost that heard events could raise a mark of its own. It has no
	# live state to ask about either: its instance is in the graveyard, so
	# every [method MiniCard.active_states] answer is already false and the
	# forced one below is the only thing it wears.
	ghost = MiniCard.new(instance)
	ghost.force_dying = true
	# It is a picture, not a card: no clicks, no hover preview, no focus.
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.focus_mode = Control.FOCUS_NONE
	ghost.disabled = true
	ghost.set_anchors_preset(Control.PRESET_CENTER)
	ghost.offset_left = -MiniCard.SIZE.x / 2.0
	ghost.offset_top = -MiniCard.SIZE.y / 2.0
	ghost.offset_right = MiniCard.SIZE.x / 2.0
	ghost.offset_bottom = MiniCard.SIZE.y / 2.0
	add_child(ghost)
	ghost.refresh()


func _process(delta: float) -> void:
	advance(delta)


## Age the mark by [param delta] seconds, fading it once [constant HOLD] is
## up and freeing it when [constant FADE] is done. Split out of
## [method _process] so a test can run the whole life of a mark in three
## calls instead of waiting a second for it.
func advance(delta: float) -> void:
	_age += delta
	if _age <= HOLD:
		return
	var gone := (_age - HOLD) / FADE
	if gone >= 1.0:
		# Detach BEFORE freeing: a queue_free()d child is still in the tree
		# until the frame ends, and anything walking the board for MiniCards
		# would still find the ghost (the rule TargetArrows._collect records).
		if get_parent() != null:
			get_parent().remove_child(self)
		queue_free()
		return
	modulate.a = 1.0 - gone


## How far through its life this mark is, 0..1 — what a test reads instead
## of counting frames.
func spent() -> float:
	return clampf(_age / (HOLD + FADE), 0.0, 1.0)

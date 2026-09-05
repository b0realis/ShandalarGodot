class_name SpellFlight
extends Control
## THE SPELL-CAST ANIMATION — `docs/duel-todo.md` §2.4. The card you cast
## travels from your hand to the **Spell Chain** window, and from there to
## wherever it ends up.
##
## **THE ITEM IS FILED [1997] AND IT IS [s30].** Nothing in the 1997
## sources describes a card in motion, and three things say the opposite:
##
##  * the 1997 duel is a Win32 application whose windows are registered
##    window CLASSES — `MAGICGAME_SpellChainClass`,
##    `MAGICGAME_BigCardCardClass`, `MAGICGAME_BigCardChoiceClass` are all
##    in `Program/Magic.exe`'s string table. A window opens; it does not
##    fly across the desktop.
##  * `@DIALOG_DUELOPTIONS`'s nineteen strings contain exactly one
##    animation switch — `Show coin flip animations` — and `coin_flip` is
##    the only 1997 entry point that takes a *"show dialog if animation is
##    off"* argument (`shandalar-src/src/manalink.h:266`). The coin is the
##    duel's one animated thing.
##  * `Duel.hlp`, **Showcase**, lists the ways it fills — hover, and
##    *"Cards drawn into your hand are displayed when you draw them"* —
##    and then closes the question: *"The Showcase is a display only; it
##    has no other function."* Casting is not one of the ways.
##
## So the flight is s30's (`duel_spell_animation.go`), and it is kept
## because it is good, and labelled because it is a divergence.
##
## **WHAT IS 1997 IS THE DESTINATION.** s30 flies the card to its
## magnifier and holds it there for 200ms, because s30 has no Spell Chain
## window to put it in. The original does: *"the Spell Chain window opens.
## The spell in progress, any other spells in the batch, and all their
## targets are displayed"* (`Duel.hlp`, **Spell Chain**; manual p.122 says
## it again). So the card flies to THE CHAIN, and the 200ms hold is
## unnecessary — the card stays on the chain for as long as the chain
## holds it, which is the duel's own pacing rather than a constant.
##
## The other half of s30's animation survives unchanged: when the object
## leaves the chain it flies on to where it landed — its battlefield slot,
## or its owner's graveyard — and `spellIsAnimating` (`:250-261`) makes
## the board skip a card that is in flight so it is never drawn in two
## places at once. [method is_flying] is that predicate.
##
## SIZE IS NOT INTERPOLATED, and that is a fidelity gain rather than a
## shortcut: s30 grows the card from 83px to 342px because its magnifier
## is a different widget. The original has ONE card size for the whole
## duel — `set_smallcard_size(mainwindow_width)` writes a single global
## `smallcard_width`/`smallcard_height` (`windows.c:1088`) and every chain
## object goes through the same `DrawSmallCard` the battlefield does — so
## ours is a [MiniCard] at [constant MiniCard.SIZE] at both ends of the
## flight, and only the position moves. Same finding as the forty-second
## pass of `docs/duel-screen-design.md`.

## s30's `spellAnimationMoveDuration` (`duel_spell_animation.go:18`).
const MOVE_SECONDS := 0.3

## One flight finished — the duel screen repaints so the real card, which
## was hidden while the ghost carried it, comes back.
signal landed(instance_id: int)

## The subtree scanned for live [MiniCard]s — the duel screen itself.
var board_root: Node = null
## `func(controller_id: int) -> Rect2` — where an object that left the
## chain went when no widget can be found for it. The graveyard pile, in
## practice; s30 falls back the same way (`spellAnimationDestination`).
var fallback: Callable = Callable()

## instance id → the global rect that card occupied LAST FRAME. Sampled
## every frame rather than at rebuild time because Godot lays containers
## out after the rebuild returns — the same reason [TargetArrows] resolves
## its positions in `_draw`.
var _rects: Dictionary = {}
## instance id → the ghost [MiniCard] currently in the air.
var _ghosts: Dictionary = {}
## Chain contents at the last [method note], id → [CardInstance] — the
## "previous message" s30's `syncSpellAnimations` diffs against. The
## INSTANCE is kept, not just the id, because a card that has left the
## chain is no longer anywhere the layer could look it up: a Lightning
## Bolt on its way to the graveyard has no widget at either end.
var _chain: Dictionary = {}
## Flights waiting for the rebuild to lay itself out:
## id → `{"from": Rect2, "wait": frames}`.
var _pending: Dictionary = {}

## How many frames a flight waits before its destination is read. Godot
## sorts a container's children on a queued notification, so the rect of a
## card the rebuild just created is not trustworthy in the very next
## `_process`; one whole frame of slack is, and one frame at 60Hz is 3% of
## the flight.
const SETTLE_FRAMES := 1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	# A headless run has no pixels to move and must not pay for the scan:
	# with no samples nothing is ever queued, which is the same gate
	# `DuelScreen._run_coin_toss` uses for the other animation in the duel.
	# In `_ready` rather than `_init` because entering the tree is what
	# turns processing on in the first place.
	if DisplayServer.get_name() == "headless":
		set_process(false)


## WHAT MOVED between two chain states, as s30's two loops read them: a
## non-ability object that is on the chain now and was not is an ARRIVAL,
## one that was and is not has LEFT. Pure, so the diff can be pinned
## without a board.
static func moved(before: Array, after: Array) -> Dictionary:
	var arrived: Array = []
	var left: Array = []
	for id in after:
		if not before.has(id):
			arrived.append(id)
	for id in before:
		if not after.has(id):
			left.append(id)
	return {"arrived": arrived, "left": left}


## The ids of the SPELLS on the chain. Abilities and triggers are skipped
## — s30 skips them too (`if item.IsAbility { continue }`), and in the
## original an activation is a card of its own that was never in a hand.
static func chain_ids(game: MtgGame) -> Array:
	var out: Array = []
	for item in game.stack:
		if item.kind != Mtg.StackKind.SPELL or item.card == null:
			continue
		out.append(item.card.id)
	return out


## Is this card in the air? s30's `spellIsAnimating` — the board must not
## draw a card that a ghost is carrying.
func is_flying(id: int) -> bool:
	return _ghosts.has(id) or _pending.has(id)


## Tell the layer what the chain holds now. Called once per
## [method DuelScreen._refresh], from game state alone, so it costs a
## couple of array walks and nothing else on a headless run.
func note(game: MtgGame) -> void:
	var now: Dictionary = {}
	for item in game.stack:
		if item.kind != Mtg.StackKind.SPELL or item.card == null:
			continue
		now[item.card.id] = item.card
	var change := moved(_chain.keys(), now.keys())
	for id in change["arrived"]:
		_queue(int(id), now[id])
	for id in change["left"]:
		_queue(int(id), _chain[id])
	_chain = now


func _queue(id: int, inst: CardInstance) -> void:
	if _pending.has(id):
		return   # already waiting; it will resolve to the newest place
	var from: Rect2 = _rects.get(id, Rect2())
	# A SPELL THAT RESOLVES MID-FLIGHT re-routes rather than losing its
	# animation: with nobody responding, a chain object can leave the chain
	# before the flight that put it there has landed, and its second
	# journey simply starts from wherever the first had got to. s30 handles
	# the same race by pushing `resolvedAt` out past the first tween; we
	# turn the card instead, which suits a duel whose pacing (§2.6) is the
	# player's to set.
	var ghost: MiniCard = _ghosts.get(id)
	if ghost != null and is_instance_valid(ghost):
		from = Rect2(ghost.global_position, ghost.size)
	# No remembered rect means the card was never drawn — a cast out of an
	# opening hand nothing has painted yet, or a token. Nothing to fly.
	if inst == null or from.size == Vector2.ZERO:
		return
	_pending[id] = {"from": from, "inst": inst, "wait": SETTLE_FRAMES}


func _process(_delta: float) -> void:
	var live := _scan()
	if not _pending.is_empty():
		_launch_pending(live)
	_rects = {}
	for id in live:
		var rect: Rect2 = TargetArrows.anchor_rect(live[id])
		if rect.size != Vector2.ZERO:
			_rects[id] = rect


## Start every flight whose rebuild has now been laid out.
func _launch_pending(live: Dictionary) -> void:
	for id in _pending.keys():
		var entry: Dictionary = _pending[id]
		if int(entry["wait"]) > 0:
			entry["wait"] = int(entry["wait"]) - 1
			continue
		var from: Rect2 = entry["from"]
		var inst: CardInstance = entry["inst"]
		_pending.erase(id)
		var to := Rect2()
		var card: MiniCard = live.get(id)
		if card != null:
			to = TargetArrows.anchor_rect(card)
		# Nothing on the board draws a card in a GRAVEYARD — the pile shows
		# its top card as a plate, not as a MiniCard — so a spell that
		# resolved and died has no widget to fly to and the fallback is
		# what gives it a destination. s30 falls back the same way.
		if to.size == Vector2.ZERO and fallback.is_valid():
			to = fallback.call(inst.controller_id)
		if to.size == Vector2.ZERO or to.position.is_equal_approx(from.position):
			continue
		_fly(inst, from, to)


func _fly(inst: CardInstance, from: Rect2, to: Rect2) -> void:
	# Re-routing (see [method _queue]): the outgoing ghost goes now, in the
	# same frame its replacement appears at the same point, so the card is
	# never missing from the screen for a frame.
	var old: MiniCard = _ghosts.get(inst.id)
	if old != null and is_instance_valid(old):
		_ghosts.erase(inst.id)
		# ITS TWEEN GOES WITH IT. A tween whose target has been freed does
		# not stop: it finishes on its next step and emits `finished`, so
		# the first leg's landing ran against a ghost that was already gone
		# — three whole duels played through this screen under Xvfb printed
		# "Lambda capture at index 1 was freed" thirty-seven times
		# (2026-09-02). Killed, it emits nothing, and the second leg's own
		# landing is the one that counts.
		var stale: Tween = old.get_meta(FLIGHT_META, null)
		if stale != null and stale.is_valid():
			stale.kill()
		old.queue_free()
	var ghost := MiniCard.new(inst)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.position = from.position - global_position
	add_child(ghost)
	_ghosts[inst.id] = ghost
	var tween := create_tween()
	ghost.set_meta(FLIGHT_META, tween)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "position",
		to.position - global_position, MOVE_SECONDS)
	tween.finished.connect(_on_landed.bind(inst.id, ghost.get_instance_id()))


## The ghost's meta key for the tween carrying it, so a re-route can find
## the first leg's tween and kill it.
const FLIGHT_META := &"flight"


## The end of a flight. The ghost is named by INSTANCE ID rather than
## captured: a ghost freed early is a null here, not an error at the call.
func _on_landed(id: int, ghost_id: int) -> void:
	var ghost: Object = instance_from_id(ghost_id)
	# Only if this ghost is still THE ghost: a re-route replaced it, and
	# the replacement must not be cleared by its predecessor.
	if ghost != null and _ghosts.get(id) == ghost:
		_ghosts.erase(id)
	if ghost != null:
		ghost.queue_free()
	landed.emit(id)


## Every live [MiniCard] in the board, by instance id — the same scan
## [TargetArrows] does, and for the same reason: the board is
## immediate-mode, so a widget cached one refresh ago is already gone.
## The ghosts themselves are skipped, or a flight would chase itself.
func _scan() -> Dictionary:
	var found := {}
	if board_root != null and is_instance_valid(board_root):
		_collect(board_root, found)
	return found


func _collect(node: Node, found: Dictionary) -> void:
	if node == self or node.is_queued_for_deletion():
		return
	# A HIDDEN SUBTREE IS NOT ON SCREEN, so nothing in it is somewhere to
	# point at. `DuelScreen._close_graveyard` closes the graveyard overlay
	# by setting `visible = false` and leaves its MiniCards parented at
	# their last laid-out rect; a graveyard card has no board widget, so
	# that stale one was the only match for its id and won the lookup.
	# The LOCAL flag, not `is_visible_in_tree()`: the duel screen itself is
	# not always visible (a headless test never draws it), and pruning on
	# the tree-wide answer would collect nothing at all.
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is MiniCard:
		var card: CardInstance = (node as MiniCard).instance
		if card != null and not found.has(card.id):
			found[card.id] = node
	for child in node.get_children():
		_collect(child, found)

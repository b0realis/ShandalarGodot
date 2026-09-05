class_name TargetArrows
extends Control
## The duel's ARROWS: who blocks whom, and what each spell is aimed at.
##
## A straight port of s30's three routines
## (s30/game/screens/duel/duel.go):
##
##   drawArrowLine   :3482-3499  — a 2px line plus a 10px two-stroke head
##                                 at the DESTINATION end.
##   drawBlockerArrows :3449-3480 — RED (255,0,0), from each blocker's
##                                 TOP-CENTRE to its attacker's
##                                 BOTTOM-CENTRE. Drawn for the player's
##                                 pending assignments always, and for the
##                                 opponent's DECLARED blocks during the
##                                 declare-blockers and damage steps.
##   drawStackArrows :3501-3524  — AMBER (255,200,0), from the casting
##                                 player's hand panel to every target of
##                                 every spell on the stack. s30's own
##                                 comment: "so the user can see what is
##                                 being cast (especially by the opponent)
##                                 and what it targets".
##   targetPosition  :3535-3552  — a PLAYER as target resolves to a fixed
##                                 point on that seat's life panel (s30
##                                 uses (30, Y+32); drawLife :3644 paints
##                                 the 64px numeral at (15, Y), so that
##                                 point is the numeral's own centre —
##                                 here, the life button's centre).
##
## This layer OWNS no game state. The duel screen hands it the live state
## once per [method DuelScreen._refresh]; it then resolves screen positions
## from the MiniCard widgets that refresh just rebuilt. Positions are
## resolved in [method _draw] rather than in [method rebuild] because Godot
## lays containers out AFTER the rebuild returns — asking a freshly added
## card where it is would read a stale rect.
##
## Divergence from s30, deliberate and marked: s30 draws stack arrows only
## once a spell is ON the stack. We also draw them WHILE the player is
## picking targets (the same amber), so a half-declared Fireball shows what
## it has caught so far. Same vocabulary, one moment earlier.
## Attacker→defender arrows are NOT drawn: s30 has none, and the original
## marks attackers by lifting them instead.

## Line thickness of both the shaft and the head (s30: StrokeLine width 2).
const LINE_WIDTH := 2.0
## Length of each of the head's two strokes (s30: arrowLen = 10).
const HEAD_LENGTH := 10.0
## Half-spread of the head, as a fraction of HEAD_LENGTH (s30: 0.5).
const HEAD_SPREAD := 0.5
## Blocker → attacker.
const BLOCK_COLOR := Color8(255, 0, 0)
## Spell/ability → target.
const SPELL_COLOR := Color8(255, 200, 0)

## Which point of an anchor's rectangle an arrow touches.
enum Edge { CENTER, TOP, BOTTOM }

## The subtree scanned for MiniCard widgets — the duel screen itself.
var board_root: Node = null
## pid → the Control that stands for that player as a TARGET (life panel).
var player_anchors: Array = [null, null]
## pid → the Control a spell's arrow springs from (that seat's hand window),
## used when the casting card itself has no widget on screen.
var hand_anchors: Array = [null, null]

## The logical arrows: {from, from_edge, to, to_edge, color}. `from`/`to`
## are an int (card instance id), a Control, or a Vector2 (screen point).
var _links: Array = []
## instance id → the widget to anchor on, captured at rebuild time.
var _cards: Dictionary = {}
## [member StackItem.id] → the chain widget an ABILITY on the stack is
## drawn as (tagged by DuelScreen._make_card), captured with [member _cards].
var _abilities: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# An overlay must never swallow a click meant for the card beneath it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Redraw every frame while any arrow is live, so the arrows follow the
## board as containers settle and as the player DRAGS the hand window.
func _process(_delta: float) -> void:
	queue_redraw()


## Take the live state and work out which arrows exist.
## [param p_block_map] is the player's PENDING blocker→attacker assignments
## (the engine's own declared blocks come from [code]game.combat[/code]).
## [param p_pending_source] is the spell/ability being aimed right now, and
## [param p_pending_refs] the TargetRefs already picked for it.
func rebuild(p_game: MtgGame, p_block_map: Dictionary = {},
		p_pending_source: CardInstance = null,
		p_pending_refs: Array = []) -> void:
	_links = []
	_cards = _scan_cards()
	if p_game != null:
		_add_block_links(p_game, p_block_map)
		_add_stack_links(p_game)
	_add_pending_links(p_pending_source, p_pending_refs)
	set_process(not _links.is_empty())
	queue_redraw()


## How many arrows are live (tests and the screenshot tour ask this).
func link_count() -> int:
	return _links.size()


## The live arrows, for inspection. Read-only by convention.
func links() -> Array:
	return _links


# ------------------------------------------------------------- the arrows --

## s30 drawBlockerArrows: the player's pending assignments ALWAYS, plus the
## blocks the engine already holds while the declare-blockers or damage
## step is running — s30 gates on stepDeclareBlockers/stepFirstStrikeDamage
## and we now have both of theirs plus our normal-damage step
## (docs/duel-todo.md §1.6).
func _add_block_links(p_game: MtgGame, p_block_map: Dictionary) -> void:
	# blocker id -> the attackers it is blocking. A creature may block more
	# than one (CR 509.1b — Two-Headed Giant of Foriys, a creature under
	# Blaze of Glory), so this is a list per blocker and the blocker gets
	# an arrow to each of them.
	var declared := {}
	var step: int = p_game.current_step()
	if step == Mtg.Step.DECLARE_BLOCKERS \
			or step == Mtg.Step.FIRST_STRIKE_DAMAGE \
			or step == Mtg.Step.COMBAT_DAMAGE:
		for blocker_id in p_game.combat.blocks:
			declared[blocker_id] = p_game.combat.attackers_blocked_by(
				int(blocker_id))
	# The pending map wins where both hold the same blocker: it is what the
	# player is looking at right now.
	for blocker_id in p_block_map:
		var pending: Variant = p_block_map[blocker_id]
		declared[blocker_id] = pending if pending is Array else [pending]
	for blocker_id in declared:
		for attacker_id in declared[blocker_id]:
			_links.append({
				"from": blocker_id, "from_edge": Edge.TOP,
				"to": attacker_id, "to_edge": Edge.BOTTOM,
				"color": BLOCK_COLOR,
			})


## s30 drawStackArrows: one amber arrow per (spell on the stack × target).
func _add_stack_links(p_game: MtgGame) -> void:
	for item in p_game.stack:
		if item.targets.is_empty():
			continue
		var origin: Variant = _cast_origin(item.controller, item.card)
		if origin == null:
			continue
		for ref in item.targets:
			var dest: Variant = _target_anchor(ref)
			if dest == null:
				continue
			_links.append({
				"from": origin, "from_edge": Edge.CENTER,
				"to": dest, "to_edge": Edge.CENTER,
				"color": SPELL_COLOR,
			})


## Our extension: the same amber arrows for the targets picked SO FAR on a
## spell/ability that has not been submitted yet.
func _add_pending_links(p_source: CardInstance, p_refs: Array) -> void:
	if p_source == null or p_refs.is_empty():
		return
	var origin: Variant = _cast_origin(p_source.controller_id, p_source)
	if origin == null:
		return
	for ref in p_refs:
		var dest: Variant = _target_anchor(ref)
		if dest == null:
			continue
		_links.append({
			"from": origin, "from_edge": Edge.CENTER,
			"to": dest, "to_edge": Edge.CENTER,
			"color": SPELL_COLOR,
		})


## Where a cast springs from: the source card's own widget when it is on
## screen (a permanent using an ability, a card visible in the hand
## window), and otherwise that seat's hand panel — s30's own origin.
func _cast_origin(pid: int, card: CardInstance) -> Variant:
	if card != null and _cards.has(card.id):
		return card.id
	if pid >= 0 and pid < hand_anchors.size() and hand_anchors[pid] != null:
		return hand_anchors[pid]
	return _player_anchor(pid)


## s30 targetPosition: a card resolves to its widget, a player to their
## life panel; anything with neither (a graveyard card, a hidden seat) is
## skipped rather than drawn to nowhere.
func _target_anchor(ref: TargetRef) -> Variant:
	if ref.is_player:
		return _player_anchor(ref.player_id)
	if ref.is_ability:
		# An ability picked as a target (Rust, Ayesha Tanaka) has no
		# instance id; its widget is the chain's, found by stack id.
		var w: Variant = _abilities.get(ref.ability_id)
		return w if w != null and is_instance_valid(w) else null
	if _cards.has(ref.instance_id):
		return ref.instance_id
	return null


func _player_anchor(pid: int) -> Variant:
	if pid < 0 or pid >= player_anchors.size():
		return null
	var anchor: Variant = player_anchors[pid]
	if anchor is Control and is_instance_valid(anchor):
		return anchor
	return null


# ------------------------------------------------------------- resolution --

## Every LIVE MiniCard in the tree, by card instance id. Rebuilt from
## scratch on every [method rebuild] — the board is immediate-mode, so a
## widget cached one refresh ago is gone by the next one.
func _scan_cards() -> Dictionary:
	var found := {}
	_abilities = {}
	if board_root != null and is_instance_valid(board_root):
		_collect(board_root, found)
	return found


func _collect(node: Node, found: Dictionary) -> void:
	# A DOOMED widget is still a child until the frame ends: a `queue_free()`
	# that does not `remove_child` first leaves the tree holding both the old
	# card and its replacement, and caching the old one hands `_draw` a freed
	# object a frame later. Every rebuild in the duel now detaches before it
	# frees (`DuelScreen._clear_children`, `CardPile.populate` — which did
	# NOT until the fortieth pass, and is why this guard was written —
	# `GraveyardView`, `CombatWindow._fill`, `MiniCard._rebuild_badges`), so
	# this is defence rather than the fix. It stays: it costs one bool per
	# node and it is the only thing standing between a missed detach
	# anywhere in the board and a crash in `_draw`.
	if node.is_queued_for_deletion():
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
		if node.has_meta("chain_ability_id"):
			_abilities[node.get_meta("chain_ability_id")] = node
	for child in node.get_children():
		_collect(child, found)


## The on-screen rectangle an anchor really occupies, in GLOBAL coordinates
## — empty when the widget has gone away or is clipped out of sight.
static func anchor_rect(node: Control) -> Rect2:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return Rect2()
	var target := node
	# A tapped card is turned 90° inside a plain holder sized to the
	# rotated bounding box; get_global_rect() ignores rotation, so anchor
	# on the holder, which is upright and correctly sized.
	if not is_zero_approx(node.rotation) and node.get_parent() is Control:
		target = node.get_parent()
	var rect := target.get_global_rect()
	# Board halves clip their contents; a card scrolled out of its half
	# must not be given an arrow to a place it is not drawn.
	var parent := target.get_parent()
	while parent is Control:
		var box := parent as Control
		if box.clip_contents:
			rect = rect.intersection(box.get_global_rect())
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				return Rect2()
		parent = box.get_parent()
	return rect


## The point on [param rect] that [param edge] names (s30 anchors a blocker
## at its top-centre and an attacker at its bottom-centre).
static func edge_point(rect: Rect2, edge: int) -> Vector2:
	var center := rect.get_center()
	match edge:
		Edge.TOP:
			return Vector2(center.x, rect.position.y)
		Edge.BOTTOM:
			return Vector2(center.x, rect.end.y)
	return center


func _resolve(anchor: Variant, edge: int) -> Variant:
	if anchor is Vector2:
		return anchor
	var found: Variant = anchor
	if anchor is int:
		if not _cards.has(anchor):
			return null
		found = _cards[anchor]
	# Validity must be tested BEFORE the typed assignment below: assigning a
	# freed object to a `Control` local raises "Trying to assign invalid
	# previously freed instance" on the spot, so a null check afterwards is
	# too late. A dead entry is dropped rather than re-tested every frame.
	if not is_instance_valid(found) or not (found is Control):
		if anchor is int:
			_cards.erase(anchor)
		return null
	var node: Control = found
	var rect := anchor_rect(node)
	if rect.size.x <= 0.0 and rect.size.y <= 0.0:
		return null
	return edge_point(rect, edge)


## The arrows as SCREEN POINTS, in the order they are drawn: one
## [code]{from, to, color}[/code] per arrow whose endpoints both resolve.
## [method _draw] renders exactly this; tests call it to prove the anchor
## cache never outlives the widgets it points at.
func resolved_arrows() -> Array:
	var out: Array = []
	for link in _links:
		var from_pt: Variant = _resolve(link["from"], link["from_edge"])
		var to_pt: Variant = _resolve(link["to"], link["to_edge"])
		if from_pt == null or to_pt == null:
			continue
		out.append({"from": from_pt, "to": to_pt, "color": link["color"]})
	return out


# --------------------------------------------------------------- drawing --

func _draw() -> void:
	var to_local_space := get_global_transform().affine_inverse()
	for arrow in resolved_arrows():
		draw_arrow(to_local_space * (arrow["from"] as Vector2),
			to_local_space * (arrow["to"] as Vector2), arrow["color"])


## s30 drawArrowLine, line for line: the shaft, then two strokes back from
## the destination that form the head.
func draw_arrow(from: Vector2, to: Vector2, arrow_color: Color) -> void:
	draw_line(from, to, arrow_color, LINE_WIDTH)
	for barb in head_points(from, to):
		draw_line(to, barb, arrow_color, LINE_WIDTH)


## The two head strokes' far ends, for a given shaft. Pure geometry, so a
## test can pin the port without a viewport.
static func head_points(from: Vector2, to: Vector2) -> Array[Vector2]:
	var d := from - to
	var length := d.length()
	if is_zero_approx(length):
		return [] as Array[Vector2]
	d /= length
	var perp := Vector2(-d.y, d.x)
	var spread := perp * HEAD_LENGTH * HEAD_SPREAD
	var tip := to + d * HEAD_LENGTH
	return [tip + spread, tip - spread] as Array[Vector2]

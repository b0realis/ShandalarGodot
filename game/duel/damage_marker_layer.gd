class_name DamageMarkerLayer
extends Control
## THE MARKERS ON THE TABLE — one [DamageMarker] per packet waiting in the
## 1997 damage-prevention window, put where the manual says it goes.
##
## Manual p.119: *"a damage marker — a yellow 'card' ON OR NEAR THE TARGET
## of that damage"*. That is a position, not a list, so the markers do not
## live in a row of their own: this layer floats over the whole table and
## anchors each marker to its victim — a creature's own widget, or that
## seat's life register when the damage is aimed at a player (which is the
## same anchor [TargetArrows] resolves a player target to, and the same one
## `Duel.hlp` gives the player to click: *"If you want to target your
## opponent, click on her life register instead."*).
##
## Shaped after [TargetArrows], which solves the same problem: the duel
## screen hands it live state once per [method DuelScreen._refresh], and it
## resolves SCREEN POSITIONS itself, one frame later and every frame after
## — Godot lays containers out AFTER a rebuild returns, so a marker placed
## during the rebuild would be pinned to where its victim was last frame.
## Unlike the arrows this layer holds real, clickable children, so the
## per-frame work is a reposition rather than a redraw, and the anchor
## widgets are captured ONCE per rebuild instead of being hunted every
## frame.
##
## The layer owns no game state and never mutates any: it reports a click
## through [signal marker_clicked] and the duel screen turns that into the
## [method TargetRef.damage] the engine already understands.

## A marker was clicked. The duel screen answers by taking that packet as
## the pending spell's target — the [constant TargetSpec.Kind.DAMAGE] path
## that has existed since §6.8's third slice with nothing to feed it.
signal marker_clicked(packet: DamagePacket)

## Clear air between a marker and the card it belongs to, and between two
## markers sharing one victim. Half [constant DuelScreen.BOARD_INSET]'s
## step: the marker is meant to read as attached to its victim, not as
## another card in the row.
const GAP := 4.0

## The subtree scanned for the widgets to anchor on — the duel screen
## itself, exactly as [member TargetArrows.board_root] is.
var board_root: Node = null

## pid → the Control that stands for that player (the life register).
var player_anchors: Array = [null, null]

## Marker → the Control it hangs off, captured at rebuild time. Parallel
## arrays would drift; a marker that lost its anchor is simply hidden.
var _anchor_of: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The layer itself must never swallow a click meant for the board
	# beneath it. Its CHILDREN are still picked: Godot walks a control's
	# children before it ever consults the control's own filter, so an
	# IGNORE parent is transparent rather than deaf.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Rebuild the markers from [param game]'s waiting packets.
##
## [param aiming] says a [constant TargetSpec.Kind.DAMAGE] slot is actually
## open; [param legal] and [param chosen] are then the packet ids that slot
## may take and has already taken. Without it every marker is simply a
## thing you MAY act on — the manual's yellow — because nothing is being
## pointed at yet, and a table full of refusal stamps would be noise.
##
## Markers exist ONLY while packets do — [member MtgGame.damage_pending] is
## empty except inside an open prevention window, so "clear when the window
## closes" needs no separate teardown.
func rebuild(game: MtgGame, aiming := false, legal: Array = [],
		chosen: Array = []) -> void:
	_clear()
	if game == null or game.damage_pending.is_empty():
		set_process(false)
		return
	var widgets := _scan_cards()
	for packet in game.damage_pending:
		var marker := DamageMarker.new(packet, game)
		if chosen.has(packet.id):
			marker.set_highlight(MiniCard.Highlight.TARGET_CHOSEN)
		elif aiming and not legal.has(packet.id):
			# `Can't target this` — the original's own word for it, drawn
			# as the original's own orange circle-slash.
			marker.set_target_state(MiniCard.State.CANT_TARGET)
		elif aiming:
			marker.set_highlight(MiniCard.Highlight.TARGET_LEGAL)
		marker.pressed.connect(_on_marker_pressed.bind(packet))
		add_child(marker)
		_anchor_of[marker] = _victim_anchor(packet, widgets)
	layout_markers()
	set_process(true)


## The markers currently on the table, in the order their packets wait.
## Tests and the screenshot tour read this.
func markers() -> Array[DamageMarker]:
	var out: Array[DamageMarker] = []
	for child in get_children():
		if child is DamageMarker:
			out.append(child)
	return out


func _on_marker_pressed(packet: DamagePacket) -> void:
	marker_clicked.emit(packet)


## Reposition every frame, so a marker follows its victim as containers
## settle, as the hand window is dragged, and as the Combat window opens
## and takes the attacking creatures out of their territory.
func _process(_delta: float) -> void:
	layout_markers()


## Put each marker ON OR NEAR its victim. Markers sharing one victim are
## laid out as a ROW centred over it, so two packets aimed at the same
## creature never hide each other — which is the case the whole widget
## exists for.
func layout_markers() -> void:
	var groups := {}   # anchor Control (or null) -> [DamageMarker]
	for marker in markers():
		var anchor: Variant = _anchor_of.get(marker)
		if not groups.has(anchor):
			groups[anchor] = []
		groups[anchor].append(marker)
	var to_local_space := get_global_transform().affine_inverse()
	for anchor in groups:
		var row: Array = groups[anchor]
		var rect := Rect2()
		# Validity FIRST: a freed anchor is not a `Control` any more, and
		# asking the typed question of a dead reference is the wrong
		# order even where it happens to answer false (2026-09-02).
		if is_instance_valid(anchor) and anchor is Control:
			rect = TargetArrows.anchor_rect(anchor)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			# A victim that is not on screen (a creature clipped out of its
			# half, a hidden seat) gets no marker rather than a marker
			# floating over nothing — the same rule the arrows follow.
			for marker in row:
				marker.visible = false
			continue
		var span := row.size() * MiniCard.SIZE.x + (row.size() - 1) * GAP
		var left := rect.get_center().x - span * 0.5
		# ABOVE the victim by preference — the manual's *"on or near"*, and
		# above is where a card's own name band already is, so the marker
		# covers the least of what it is about. Below when there is no room.
		var top := rect.position.y - MiniCard.SIZE.y - GAP
		var here := get_global_rect()
		if top < here.position.y:
			top = rect.end.y + GAP
		for i in row.size():
			var marker: DamageMarker = row[i]
			marker.visible = true
			var where := Vector2(left + i * (MiniCard.SIZE.x + GAP), top)
			# Never off the edge of the table: a marker the player cannot
			# reach is a target they cannot choose.
			where.x = clampf(where.x, here.position.x,
				maxf(here.end.x - MiniCard.SIZE.x, here.position.x))
			where.y = clampf(where.y, here.position.y,
				maxf(here.end.y - MiniCard.SIZE.y, here.position.y))
			marker.position = to_local_space * where
			marker.size = MiniCard.SIZE


## Which widget a packet's victim is drawn as: the creature's own MiniCard
## anywhere on screen (its territory, or the Combat window while it is
## fighting), or the seat's life register for damage to a player.
func _victim_anchor(packet: DamagePacket, widgets: Dictionary) -> Variant:
	if packet == null or packet.target == null:
		return null
	if packet.target.is_player:
		var pid: int = packet.target.player_id
		if pid < 0 or pid >= player_anchors.size():
			return null
		var seat: Variant = player_anchors[pid]
		return seat if is_instance_valid(seat) and seat is Control else null   # validity first
	return widgets.get(packet.target.instance_id)


func _clear() -> void:
	_anchor_of.clear()
	for child in get_children():
		# Detach BEFORE freeing: a queue_free()d child is still in the tree
		# until the frame ends, and [method layout_markers] would then be
		# handed a doomed widget (the rule TargetArrows._collect records).
		remove_child(child)
		child.queue_free()


## Every live [MiniCard] under [member board_root], by card instance id.
## The board is immediate-mode, so this is rebuilt from scratch on every
## rebuild and never cached across one.
func _scan_cards() -> Dictionary:
	var found := {}
	if board_root != null and is_instance_valid(board_root):
		_collect(board_root, found)
	return found


func _collect(node: Node, found: Dictionary) -> void:
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
	for child in node.get_children():
		_collect(child, found)

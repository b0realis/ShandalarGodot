class_name StagePane
extends PanelContainer
## A 1997 PAGE IN ONE OF THE WORLD'S MOVABLE ROUNDED PANES (part C, stage
## C2) — the frame the panes around a castle's or a dungeon's duels share:
## the room shown before a duel ([RoomDuelPane]), a wizard beaten in his
## castle ([CastleWinPane]), the dungeon and castle clues ([CluesPane]). The
## meeting's own pane ([EncounterPane]) set the pattern; this is that
## pattern once, so the three look and answer alike:
##  - THE LOOK ([PaneStyle]): the dark glass, a gold title and a dim line
##    under it, the 1997 page on its stage ([EncounterStage]: a ground
##    picture, faces, plaques, cards — read with a right click) in a thin
##    gold frame, the words under it, the choices, a note.
##  - THE SIZE: the page as large as THE WORLD'S FREE AREA allows ([method
##    free_rect]: the window less the panel's band — under the panel, or
##    over it when the panel is at the bottom, its name and its message
##    line too — and kept clear of the small map wherever the pane fits
##    beside or past it, [method obstacles], [method clear_parts]), up to
##    [constant MOST] times 1997's (the owner's ruling P3 for the board's
##    pane, "a rounded pane up to 1.25× the 1997 page"), never under
##    [constant LEAST]; the page shrinks, nothing is clipped — measured,
##    not guessed, so the Big buttons fit too ([method _fit]). A later page
##    may be smaller, never larger: the pane does not swell and shrink from
##    click to click ([member _ceiling]). The pane stands in the middle of
##    the part of the free area it was fitted to; dragged by hand, it stays
##    where it was put.
##  - ANOTHER BODY in the page's place ([method show_body]): the clues'
##    list, the castle's card picks. The words and the choices then wrap to
##    that body's width.
##  - THE KEYS AND THE MOUSE as every pane over the world: a choice's first
##    letter lights it, Enter or Space takes it ([method
##    VisitPane.letter_choice]); with one choice alone Enter or Space takes
##    it; a double click's second press is no choice; Escape is the page's
##    own ([method escape]); a key the page does not answer goes no further
##    (the board under a room's pane hears none); a drag on the glass moves
##    the pane, kept on the screen.
##  - A TUNE of its own on the music bus, looped ([method play_music]), the
##    world's bed stopped under it; stopped as the pane goes.
## Without the 1997 pictures the page is a plain dark field under the same
## words ([EncounterStage]'s plain parts).

## A card right-clicked, to be read full screen ([method WorldScreen.read_card]).
signal card_read(card_name: String)

## The stage's size against 1997's page, at most and at least.
const MOST := 1.25
const LEAST := 0.55
## The side margin a pane leaves the window, in all.
const SIDE_MARGIN := 120.0
## The free area's margin from the window's edges; the gap kept from the
## panel's band and round the small map.
const EDGE := 12.0
const PANEL_GAP := 8.0
const MAP_GAP := 8.0

var player: AdventurePlayer
## The size factor of the choices: 1, or [constant WorldHud.BIG].
var k := 1.0
## The page.
var stage: EncounterStage
var _title: Label
var _subtitle: Label
var _frame: PanelContainer
var _words: Label
var _choices: HFlowContainer
var _note: Label
var _body: Control
var _music: AudioStreamPlayer
var _music_key := ""
var _most := 1.0
var _factor := 1.0
var _ceiling := INF
var _drag := {}
var _relayout_queued := false
## The part of the free area the pane was fitted to ([method _fit]), in its
## parent's units; and whether the player has moved it by hand.
var _region := Rect2()
var _by_hand := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PaneStyle.glass())
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_title = PaneStyle.title("")
	_title.name = "PaneTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_subtitle = PaneStyle.label("", 15, PaneStyle.DIM)
	_subtitle.name = "PaneSubtitle"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)
	_frame = PanelContainer.new()
	_frame.name = "Picture"
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0.02, 0.015, 0.015, 1.0)
	rim.border_color = Color(PaneStyle.GOLD, 0.7)
	rim.set_border_width_all(2)
	rim.set_corner_radius_all(4)
	rim.set_content_margin_all(2)
	_frame.add_theme_stylebox_override("panel", rim)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage = _make_stage()
	stage.card_read.connect(func(card_name: String) -> void: card_read.emit(card_name))
	_frame.add_child(stage)
	column.add_child(_frame)
	_words = PaneStyle.label("", 17, PaneStyle.INK)
	_words.name = "PaneWords"
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.visible = false
	column.add_child(_words)
	_choices = HFlowContainer.new()
	_choices.name = "PaneChoices"
	_choices.alignment = FlowContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("h_separation", int(8 * k))
	_choices.add_theme_constant_override("v_separation", int(6 * k))
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_choices)
	_note = PaneStyle.label("", 14, PaneStyle.DIM)
	_note.name = "PaneNote"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	column.add_child(_note)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = GameAudio.MUSIC_BUS
	_music.finished.connect(func() -> void:
		if _music_key != "" and is_inside_tree():
			_music.play())
	add_child(_music)
	var room := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 800)
	_most = clampf((room.x - SIDE_MARGIN) / EncounterStage.PAGE.x, LEAST, MOST)
	_set_factor(_most)
	minimum_size_changed.connect(_fit)
	resized.connect(_fit)
	# A window made larger or smaller, a device turned: fitted again.
	get_viewport().size_changed.connect(_fit)


## The page's stage: an [EncounterStage], or a pane's own kind of one.
func _make_stage() -> EncounterStage:
	return EncounterStage.new()


# ------------------------------------------------------------- the size --

func _set_factor(value: float) -> void:
	_factor = value
	stage.set_factor(value)
	_wrap_width()


## The words, the choices and the note wrapped to the page's width, or to
## the other body's when one stands in its place.
func _wrap_width() -> void:
	var width := EncounterStage.PAGE.x * _factor
	if _body != null and _body.visible:
		width = _body.get_combined_minimum_size().x
	for part: Control in [_words, _choices, _note]:
		if part != null:
			part.custom_minimum_size.x = width


## The page's size now, times 1997's.
func factor() -> float:
	return _factor


## THE PANE KEPT IN THE FREE AREA, THE PAGE AS LARGE AS THE ROOM LEFT (as
## [method EncounterPane._fit], in the world's free area): of the free
## area and its parts clear of the small map ([method clear_parts]), the
## one where the page can be the largest — the whole area only where the
## pane, there, stays clear of the map; none clear, the whole area. The
## page's size is what that part allows once the rest of the pane — the
## title, the words, the choices, measured — has its room, up to [member
## _most] and what the last page answered took ([member _ceiling]). With
## another body in the page's place the pane keeps its size and goes where
## it fits clear of the map, else into the whole area.
func _fit() -> void:
	if not is_inside_tree() or stage == null:
		return
	var free := free_rect()
	var around := obstacles()
	var need := get_combined_minimum_size()
	if not _frame.visible:
		_region = place_for(need, free, around)
		_queue_relayout()
		return
	var rest := Vector2(maxf(need.x - stage.custom_minimum_size.x, 0.0), need.y - stage.custom_minimum_size.y)
	var best := -1.0
	var where := free
	var parts: Array[Rect2] = [free]
	parts.append_array(clear_parts(free, around))
	for i in parts.size():
		var part := parts[i]
		var room := (part.size - rest) / EncounterStage.PAGE
		var grow := minf(minf(room.x, room.y), minf(_most, _ceiling))
		if grow < LEAST - 0.0001:
			continue
		var pane_size := rest + EncounterStage.PAGE * grow
		if i == 0 and hits(Rect2(part.get_center() - pane_size / 2.0, pane_size), around):
			continue
		if grow > best + 0.0001:
			best = grow
			where = part
	if best < 0.0:
		where = free
		var room := (free.size - rest) / EncounterStage.PAGE
		best = clampf(minf(room.x, room.y), LEAST, minf(_most, _ceiling))
	_region = where
	if absf(best - _factor) * EncounterStage.PAGE.y >= 1.0:
		_set_factor(best)
	_queue_relayout()


## THE WORLD'S FREE AREA, in the pane's parent's units: the window, in
## [constant EDGE] from its edges, less THE PANEL'S BAND — the panel, the
## name under (or over) it and the message line beside the name ([WorldHud]:
## its `Top` and its `Notice`), [constant PANEL_GAP] more — on the side the
## panel stands. Without the world's panel (a test, a screen of its own)
## the window.
func free_rect() -> Rect2:
	var room := _room_size()
	var top := EDGE
	var bottom := room.y - EDGE
	var hud := world_hud()
	if hud != null and hud.is_visible_in_tree():
		var band := hud.find_child("Top", false, false) as Control
		var bar: Control = band.find_child("Bar", false, false) as Control if band != null else null
		var notice := hud.find_child("Notice", false, false) as Control
		if band != null and band.is_visible_in_tree():
			var at := _local(band.get_global_rect())
			var line := notice.get_combined_minimum_size().y + 6.0 if notice != null else 0.0
			var bar_at := _local(bar.get_global_rect()) if bar != null else at
			if hud.bar_at_bottom:
				bottom = minf(bottom, minf(at.position.y, bar_at.position.y - line) - PANEL_GAP)
			else:
				top = maxf(top, maxf(at.end.y, bar_at.end.y + line) + PANEL_GAP)
	return Rect2(EDGE, top, maxf(room.x - EDGE * 2.0, 1.0), maxf(bottom - top, 1.0))


## What the pane keeps clear of where it fits past it, in its parent's
## units: the small map, [constant MAP_GAP] round it, while it shows.
func obstacles() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var hud := world_hud()
	if hud != null and hud.is_visible_in_tree() and hud.minimap != null and hud.minimap.is_visible_in_tree():
		out.append(_local(hud.minimap.get_global_rect()).grow(MAP_GAP))
	return out


## THE PARTS OF [param area] CLEAR OF EVERY RECTANGLE IN [param around]:
## for each one met, the strips of the area to its left, its right, above
## and below it (overlapping each other), cut again by the next.
static func clear_parts(area: Rect2, around: Array[Rect2]) -> Array[Rect2]:
	var parts: Array[Rect2] = [area]
	for block in around:
		var next: Array[Rect2] = []
		for part in parts:
			if not part.intersects(block):
				next.append(part)
				continue
			for piece: Rect2 in [Rect2(part.position.x, part.position.y, block.position.x - part.position.x, part.size.y),
					Rect2(block.end.x, part.position.y, part.end.x - block.end.x, part.size.y),
					Rect2(part.position.x, part.position.y, part.size.x, block.position.y - part.position.y),
					Rect2(part.position.x, block.end.y, part.size.x, part.end.y - block.end.y)]:
				if piece.size.x >= 1.0 and piece.size.y >= 1.0:
					next.append(piece)
		parts = next
	return parts


## Whether [param rect] meets any of [param around].
static func hits(rect: Rect2, around: Array[Rect2]) -> bool:
	for block in around:
		if rect.intersects(block):
			return true
	return false


## WHERE A PANE OF [param need]'s SIZE STANDS in [param free]: the whole
## area when, in its middle, it stays clear of [param around]; else the
## clear part with the most room to spare that holds it; else the whole
## area.
static func place_for(need: Vector2, free: Rect2, around: Array[Rect2]) -> Rect2:
	if not hits(Rect2(free.get_center() - need / 2.0, need), around):
		return free
	var best := free
	var spare := -INF
	for part in clear_parts(free, around):
		var room := part.size - need
		if room.x >= 0.0 and room.y >= 0.0 and minf(room.x, room.y) > spare:
			spare = minf(room.x, room.y)
			best = part
	return best


## The part of the free area the pane was last fitted to.
func region() -> Rect2:
	return _region


## The world's panel ([WorldHud]) up the tree — the world screen's `hud` —
## or null.
func world_hud() -> WorldHud:
	var node := get_parent()
	while node != null:
		var hud: Variant = node.get("hud")
		if hud is WorldHud:
			return hud
		node = node.get_parent()
	return null


## The size of what the pane stands on: its parent control, else the window.
func _room_size() -> Vector2:
	var parent := get_parent_control()
	if parent != null and parent.size.x >= 1.0 and parent.size.y >= 1.0:
		return parent.size
	return get_viewport_rect().size


## [param rect] (the screen's) in the pane's parent's units.
func _local(rect: Rect2) -> Rect2:
	var parent := get_parent_control()
	if parent == null:
		return rect
	return Rect2(rect.position - parent.global_position, rect.size)


## The pane laid out as small as its parts, once a frame at most (a pane
## outside a container only ever grows, [method
## EncounterPane._queue_relayout]).
func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	_relayout.call_deferred()


## In the middle of the part it was fitted to, kept inside it — its head
## first when it cannot be whole there (its foot on the screen when even
## the whole free area is too short); moved by hand, about its own middle
## where it was put, kept on the screen.
func _relayout() -> void:
	_relayout_queued = false
	if not is_inside_tree():
		return
	var middle := position + size / 2.0
	size = get_combined_minimum_size()
	if _by_hand:
		var room := _room_size()
		position = middle - size / 2.0
		position.x = clampf(position.x, 40.0 - size.x, room.x - 40.0)
		position.y = clampf(position.y, 0.0, maxf(room.y - 40.0, 0.0))
		return
	var part := _region if _region.has_area() else free_rect()
	var at := part.get_center() - size / 2.0
	at.x = clampf(at.x, part.position.x, maxf(part.position.x, part.end.x - size.x))
	at.y = clampf(at.y, part.position.y, maxf(part.position.y, part.end.y - size.y))
	if size.y > part.size.y:
		# Taller than the part even at the least page (a window smaller than
		# the panes were made for): its foot kept on the screen.
		var room := _room_size()
		at.y = clampf(room.y - EDGE - size.y, minf(EDGE, part.position.y), part.position.y)
	position = at


## [param body] shown in the page's place (the page hidden), or — null —
## the page again. The body is added to the pane's column the first time.
func show_body(body: Control) -> void:
	if _body != null and _body != body and is_instance_valid(_body):
		_body.visible = false
	_body = body
	if body != null:
		if body.get_parent() == null:
			var column := _frame.get_parent()
			column.add_child(body)
			column.move_child(body, _frame.get_index() + 1)
		body.visible = true
	_frame.visible = body == null
	_wrap_width()
	_queue_relayout()


## THE LARGEST SIZE, from [param most] page points down to [param least],
## at which [param text] stands in [param box] (page units) WITHOUT A LINE
## BROKEN anew — each of its own lines no wider than the box, all of them
## no taller — in the face the page's words wear ([method PaneStyle.label]);
## [param least] when none does. 1997 broke its words itself: they keep
## its breaks ([method EncounterStage.words] only ever shrinks for height,
## and a line too wide would wrap).
static func fit_points(text: String, box: Vector2, most := 16, least := 9) -> int:
	var lines := text.split("\n")
	for points in range(most, least - 1, -1):
		var probe := PaneStyle.label(text, points)
		var face := probe.get_theme_font("font")
		probe.free()
		var widest := 0.0
		for line in lines:
			widest = maxf(widest, face.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x)
		var tall := face.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).y
		# A little room over: the face is drawn at the page's scale, and its
		# hinting does not scale quite in proportion.
		if widest <= (box.x - 2.0) * 0.95 and tall <= box.y * 0.97:
			return points
	return least


## Whether the page shows (no other body in its place).
func page_shown() -> bool:
	return _frame != null and _frame.visible


# ------------------------------------------------------ words, choices --

## The title and the line under it.
func set_title(text: String, under := "") -> void:
	_title.text = text
	_subtitle.text = under
	_subtitle.visible = under != ""


func title_text() -> String:
	return _title.text


func subtitle_text() -> String:
	return _subtitle.text if _subtitle.visible else ""


## The words now: [param lines], a line each (none hides them).
func say(lines: Array) -> void:
	_words.text = "\n".join(PackedStringArray(lines))
	_words.visible = not lines.is_empty()


## THE CHOICES NOW: [param actions], each `[id, words, ready]`, the note
## [param note_text] under them. The page answered so far is the most the
## next may take ([member _ceiling]).
func offer(actions: Array, note_text := "") -> void:
	PaneStyle.drop_children(_choices)
	for action in actions:
		var choice := PaneStyle.button(String(action[1]), "Choice_" + String(action[0]), k)
		choice.disabled = not bool(action[2])
		choice.pressed.connect(func() -> void: WorldSoundscape.play_from(self, "sfx_button"))
		choice.pressed.connect(_pressed.bind(String(action[0])))
		# A DOUBLE CLICK'S SECOND PRESS IS NO CHOICE (the meeting's q2-2
		# guard): the next page's choices stand where these did.
		choice.gui_input.connect(func(input: InputEvent) -> void:
			var press := input as InputEventMouseButton
			if press != null and press.double_click:
				choice.accept_event())
		_choices.add_child(choice)
	set_note(note_text)


## The note under the choices ("" hides it).
func set_note(note_text: String) -> void:
	_note.text = note_text
	_note.visible = note_text != ""


func _pressed(action: String) -> void:
	_ceiling = _factor
	choose(action)


## WHAT A CHOICE DOES — the page's own.
func choose(_action: String) -> void:
	pass


## ESCAPE — the page's own (nothing by default).
func escape() -> void:
	pass


## The words shown, the choices offered (their ids), the note.
func words() -> String:
	return _words.text if _words.visible else ""


func choice_ids() -> Array[String]:
	var out: Array[String] = []
	for child in _choices.get_children():
		if not child.is_queued_for_deletion():
			out.append(String(child.name).trim_prefix("Choice_"))
	return out


## The choice [param id]'s button, null for none.
func choice(id: String) -> Button:
	for child in _choices.get_children():
		if not child.is_queued_for_deletion() and String(child.name) == "Choice_" + id:
			return child as Button
	return null


func note() -> String:
	return _note.text if _note.visible else ""


# ------------------------------------------------------------- the tune --

## [param key] looped on the music bus, the world's bed stopped under it;
## nothing with the music off or without the 1997 skin that holds it.
func play_music(key: String) -> void:
	if key == "" or key == _music_key or not Settings.music_enabled():
		return
	var stream := GameSkin.sound(key)
	if stream == null:
		return
	WorldDuels.world_music_off(self)
	_music_key = key
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music_key = ""
	if _music != null:
		_music.stop()


## The tune playing, "" for none.
func music_key() -> String:
	return _music_key


# ------------------------------------------------------- keys and mouse --

func _unhandled_input(input: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if VisitPane.letter_choice(self, _choices, input):
		get_viewport().set_input_as_handled()
		return
	if input.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		escape()
		return
	# [QoL] Enter or Space with no choice lit takes the only one there is
	# (a page read on, "Duel"): 1997 took any key as "go on" there. With
	# more than one, a letter lights the one meant first.
	var held := get_viewport().gui_get_focus_owner()
	if input.is_action_pressed("ui_accept") and not (held is Button or held is LineEdit or held is TextEdit):
		var ready: Array[String] = []
		for child in _choices.get_children():
			var button := child as Button
			if button != null and not button.disabled and not button.is_queued_for_deletion():
				ready.append(String(button.name).trim_prefix("Choice_"))
		if ready.size() == 1:
			get_viewport().set_input_as_handled()
			_pressed(ready[0])
			return
	# THE PAGE HOLDS THE KEYS: a key it does not answer goes no further —
	# not to the board or the world under it (an arrow would walk the hero
	# under a room's pane, Escape would ask to leave the board).
	var key := input as InputEventKey
	if key != null and key.pressed and VisitPane.on_top(self):
		get_viewport().set_input_as_handled()


## A press of the mouse puts out the choice a letter lit.
func _input(input: InputEvent) -> void:
	VisitPane.drop_letter(_choices, input)


## A drag on the pane's glass moves it, kept on the screen.
func _gui_input(input: InputEvent) -> void:
	var press := input as InputEventMouseButton
	if press != null and press.button_index == MOUSE_BUTTON_LEFT:
		if press.pressed:
			_drag = {"grip": press.global_position - global_position}
		else:
			_drag = {}
		accept_event()
		return
	var motion := input as InputEventMouseMotion
	if motion != null and not _drag.is_empty():
		var room := get_viewport_rect().size
		var to: Vector2 = motion.global_position - Vector2(_drag["grip"])
		to.x = clampf(to.x, 40.0 - size.x, room.x - 40.0)
		to.y = clampf(to.y, 0.0, room.y - 40.0)
		global_position = to
		_by_hand = true
		accept_event()

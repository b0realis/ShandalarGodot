class_name CombatWindow
extends Control
## THE COMBAT WINDOW — the 1997 duel's lineup window, titled `Your attack`.
##
## Manual p.126 / `Duel.hlp` topic **Combat**: *"As soon as you add the
## first creature to the attack, the Combat window opens. Your attackers
## line up on your side, and the space on the other side is reserved for
## (potential) blockers."* · *"All the attacking creatures are shown in the
## Combat window. To make one of your creatures a blocker, click on it.
## Next, click on the attacker you want your blocker to block."* ·
## *"Note that you can minimize the Combat window by clicking in its upper
## right corner. To restore the minimized window, click on the window icon
## in the center area of the Phase Bar."*
##
## Its title comes from `@WINDOWTITLES` (`shandalar-src/Program/
## UIStrings.txt:155`): `Your attack` for the player's own attack, `%s
## Attack` for anyone else's. `@MENU_ATTACK` (`:843`) offers `Minimize` /
## `Help...` and `@MENU_MINIMIZEDATTACK` (`:848`) `Restore` / `Help...`;
## the collapsed state is named `Minimized attack window` in
## `@CUECARD_OTHER` (`:667`).
##
## THE WINDOW IS WHERE THE CREATURES ARE. A creature in combat is NOT also
## in its territory — the Manalink 3 patch
## `shandalar-src/src/patches/patch_not_in_combat_window_if_no_longer_attacking.pl`
## exists precisely to make *"creatures that attacked this turn, but are
## not currently attacking, appear in territory instead of the combat
## window"*, which is only worth patching if the window normally takes them
## out of the territory. `DuelScreen._rebuild_field` honours that, which
## also keeps the blocker arrows unambiguous: every card has exactly one
## widget on screen, and the red arrow runs between the window's two lanes.
##
## THE ART, measured with PIL (tools/import_original.py carries the survey):
##   `Winbk_Attack.pic`       888x316  the ground, a field of SKULLS. Like
##                                     `Winbk_Telluser` it has NO bevel of
##                                     its own — every edge row is plain
##                                     texture — so it is RULED in code by
##                                     `OriginalDialog.ruled_style`, the
##                                     same routine that frames the
##                                     Situation Bar, and its title bar is
##                                     that bar's own stone.
##   `Winbk_Attacksword.pic`   56x132  image+mask -> a 28x132 steel sword:
##                                     the ATTACKERS' lane marker.
##   `Winbk_Attackshield.pic`  44x128  image+mask -> a 22x128 kite shield:
##                                     the BLOCKERS' lane marker.
##   `Winbk_Attackbones.pic`  777x70   image over mask -> a 777x35 strip of
##                                     bones: the window's floor.
##
## The art's own 316 height IS the layout: a title bar over two lanes of
## 140, and 140 is exactly the box a TAPPED mini-card turns inside
## (`MiniCard.SIZE.x + 8`) — which is what an attacker becomes. Cards come
## from `DuelScreen._make_widget` through [member card_builder]; this window
## never draws a card itself.

## The ground's own size — and the window's, wherever the board is wide
## enough to take it.
const ART_SIZE := Vector2(888.0, 316.0)
## One lane: the bounding box of a tapped mini-card (see class docs).
const LANE_H := 140.0
## The ruled frame's own width, from `OriginalDialog._rule` (ink at the
## edge, the highlight two pixels in).
const EDGE := 4.0
## The title bar, in the Situation Bar's stone. Sized so the whole window
## adds up to the ground's own 316 (see [constant HEIGHT]).
const TITLE_H := 28.0
## Total height: frame + title + two lanes + frame.
const HEIGHT := EDGE + TITLE_H + 2.0 * LANE_H + EDGE
## The bone strip's height once its mask is applied (777x70 -> 777x35).
const BONES_H := 35.0
## Width reserved at the left of each lane for its sword/shield marker.
const MARKER_W := 32.0

## The player asked to minimise the window (its upper-right corner).
signal minimize_toggled(is_minimized: bool)

## Builds the widget for one card — `DuelScreen._make_widget`, so every
## table card on screen comes out of the same generator.
var card_builder: Callable = Callable()

## True while the window is collapsed to its Phase Bar icon.
var minimized := false:
	set(value):
		if minimized == value:
			return
		minimized = value
		visible = not minimized

var _panel: Panel
var _title: Label
var _minimize: Button
var _bones: TextureRect
var _top_lane: Lane
var _bottom_lane: Lane
var _top_marker: TextureRect
var _bottom_marker: TextureRect
## Instance ids currently laid out, top lane then bottom (tests read this).
var _top_ids: Array = []
var _bottom_ids: Array = []
## The attack bands as laid out: one Array of member ids per framed group,
## in lane order (tests read this).
var _band_groups: Array = []

## THE BAND FRAME (2026-09-18). A band attacks as one body — blocked as
## one, its blockers' damage divided by its controller (CR 702.22j-k) —
## and the window says so by standing its members SIDE BY SIDE inside one
## ruled frame, the way the lineup already puts a creature "in combat" by
## moving it into the window at all. The ink is the banding badge's own
## blue (docs/card-states.md: *"Blue cross — banding"*), which none of the
## card rings use: yellow is "you may", orange "you must", green "chosen".
## The frame is drawn UNDER the cards, in the 4px of clear holder around
## each of them, so it costs the lane no height (a lane is exactly one
## tapped card tall — see the class docs).
const BAND_INK := Color(0.45, 0.65, 1.0)
const BAND_RULE := 3


func _init() -> void:
	# ABOVE the board: a pile's holders and the board's rows carry z of
	# their own, so a window at the default zero would have the
	# territory's cards painted straight through it — and the board's
	# three rows and its free layer each stand a step higher than the last
	# (`DuelScreen.ROW_Z_STEP`, the whole ladder is documented there), so
	# the window starts above the free layer's tallest card. The arrow
	# layer is lifted above this in turn (duel_screen.gd), because the
	# blocker arrows run between the two lanes.
	z_index = 30
	custom_minimum_size = Vector2(320.0, HEIGHT)
	size = Vector2(ART_SIZE.x, HEIGHT)

	# THE GROUND: the skull field, ruled with the era's own frame. TILED,
	# never stretched — the file is as wide as the window, so exactly one
	# tile is laid and clipped and the skulls keep their 1997 scale.
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel",
		OriginalDialog.ruled_style("attack_panel", 0.0))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.clip_contents = true
	add_child(_panel)

	# The bone strip along the floor, under the cards.
	_bones = TextureRect.new()
	_bones.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bones.offset_left = EDGE
	_bones.offset_right = -EDGE
	_bones.offset_top = -(BONES_H + EDGE)
	_bones.offset_bottom = -EDGE
	_bones.stretch_mode = TextureRect.STRETCH_TILE
	_bones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bones)

	# The two lanes and their markers. Which lane holds the attackers
	# depends on whose attack it is — see [method present].
	_top_marker = _make_marker(EDGE + TITLE_H)
	_bottom_marker = _make_marker(EDGE + TITLE_H + LANE_H)
	add_child(_top_marker)
	add_child(_bottom_marker)
	_top_lane = _make_lane(EDGE + TITLE_H)
	_bottom_lane = _make_lane(EDGE + TITLE_H + LANE_H)
	add_child(_top_lane)
	add_child(_bottom_lane)

	# THE TITLE BAR — the Situation Bar's own stone, so the window and the
	# bar read as one set of furniture, with the minimise gadget at the
	# upper right corner the manual names.
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = EDGE
	bar.offset_right = -EDGE
	bar.offset_top = EDGE
	bar.offset_bottom = EDGE + TITLE_H
	bar.add_theme_stylebox_override("panel", OriginalDialog.bar_style(2.0))
	# THE BAR IS THE DRAG HANDLE, which is the era's own gesture and not an
	# invention: `Duel.hlp`, topic **Hands** — *"To move a hand window,
	# click and drag on the bar at the top of the window"* — and this
	# window has the same bar in the same place. [StackHand] already binds
	# it that way; this is that behaviour, on the window the 2026-09-05
	# playtest asked to move: *"battle window should be movable as it can
	# occlude cards the player wants to designate as attackers or
	# blockers"*. A window that hides the thing it is asking you to click
	# is worse than one you have to move.
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	# THE POINTER SAYS SO, as it already does over the hand's own bar. A
	# window you can drag but whose cursor never changes is a window
	# nobody discovers they can drag (2026-09-05: *"it can be dragged,
	# just the mouse pointer should change also"*).
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bar.gui_input.connect(_on_bar_input)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	_title = OriginalDialog.label("Your attack", 14, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_title)
	# `@MENU_ATTACK` (UIStrings.txt:843) names this exactly `Minimize`.
	_minimize = OriginalDialog.bar_button("▼", Vector2(22.0, 18.0))
	_minimize.tooltip_text = "Minimize"
	_minimize.pressed.connect(_on_minimize_pressed)
	row.add_child(_minimize)


## Where the player last put this window, remembered like the hand's is
## (`Settings "hand_stack_pos"`). Absence means "wherever the screen puts
## it", so a player who has never moved it is not pinned to a position
## chosen on somebody else's resolution.
const POS_SETTING := "combat_window_pos"
## A press moves a pixel or two under the finger; without a threshold
## every click on the bar would read as a drag. [StackHand]'s number.
const DRAG_SLOP := 4.0

var _dragging := false
var _drag_moved := false
var _drag_from := Vector2.ZERO
var _drag_offset := Vector2.ZERO
## fit() runs on every duel refresh, not just on viewport resize. Once
## the player places the window, layout may resize/clamp it but not center it.
var _user_positioned := false


## The pointer is read FROM THE EVENT, not `get_global_mouse_position()`:
## the same number under a mouse, and the only one a finger on the touch
## layer has (game/input/touch_controls.gd — it moves no OS pointer).
func _on_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_moved = false
			_drag_from = event.global_position
			_drag_offset = _drag_from - global_position
		else:
			if _dragging and _drag_moved:
				_user_positioned = true
				Settings.set_value(POS_SETTING, position)
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		if event.global_position.distance_to(_drag_from) > DRAG_SLOP:
			_drag_moved = true
		if _drag_moved:
			_user_positioned = true
			position = event.global_position - _drag_offset
			_clamp_on_screen()


## NEVER OFF THE EDGE. A window dragged past the viewport cannot be
## dragged back, so the bar always stays reachable — the same guard
## [StackHand] keeps for the same reason.
func _clamp_on_screen() -> void:
	var room := get_viewport_rect().size
	if room.x <= 0.0 or room.y <= 0.0:
		return
	position.x = clampf(position.x, -size.x + EDGE + 60.0, room.x - EDGE - 60.0)
	position.y = clampf(position.y, 0.0, room.y - EDGE - TITLE_H)


## Put it back where the player left it, if they ever moved it.
func restore_position() -> void:
	if not Settings.has_value(POS_SETTING):
		return
	var saved: Variant = Settings.get_value(POS_SETTING, Vector2.ZERO)
	if saved is Vector2:
		_user_positioned = true
		position = saved
		_clamp_on_screen()


func _make_lane(top: float) -> Lane:
	var lane := Lane.new()
	lane.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lane.offset_top = top
	lane.offset_bottom = top + LANE_H
	lane.offset_left = EDGE + MARKER_W
	lane.offset_right = -(EDGE + 4.0)
	return lane


## ONE LANE, ONE LINE, HOWEVER MANY CREATURES (the bug campaign c12,
## h4-10). The lanes were [HFlowContainer]s, and the seventh creature of a
## side wrapped to a second line: the lane grew to 216 and 284, wrapped
## blockers sat hidden behind the attackers' lane and the Situation Bar,
## and wrapped attackers fell out of the window onto the board. A lane is
## exactly one tapped card tall (see the class docs), so it does what the
## territory rows do ([SqueezeRow], s30's `duel.go:1424-1434`): an
## under-full lane stands its cards side by side, centred as before, and a
## full one shrinks the pitch — every card but the last slides under its
## neighbour, and the last shows whole.
##
## NOT a [SqueezeRow] itself, on purpose: the duel screen reads a card
## whose parent is one as a TABLE card it may drag and place
## ([method DuelScreen._layout_root]), and a card in this window stands
## for its creature and must not be (hunt of 2026-10-21).
class Lane extends Container:
	## The gap between cards in an under-full lane (the old flow's own 6).
	const SEPARATION := 6.0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			_lay_out()

	## Nothing: the lane is placed by its anchors at the art's own size.
	## Asking for its cards' width or height would grow it past the window
	## — which is what the flow's wrapped lines did.
	func _get_minimum_size() -> Vector2:
		return Vector2.ZERO

	func _cards() -> Array[Control]:
		var out: Array[Control] = []
		for child in get_children():
			if child is Control and child.visible and not child.top_level:
				out.append(child)
		return out

	func _lay_out() -> void:
		var cards := _cards()
		if cards.is_empty():
			return
		var widths: Array[float] = []
		var natural := SEPARATION * (cards.size() - 1)
		for card in cards:
			widths.append(card.get_combined_minimum_size().x)
			natural += widths[-1]
		if natural > size.x and cards.size() > 1:
			var pitch := maxf(size.x - widths[-1], 0.0) / float(cards.size() - 1)
			for i in cards.size():
				_place(cards[i], i * pitch, widths[i])
			return
		var x := floorf((size.x - natural) * 0.5)
		for i in cards.size():
			_place(cards[i], x, widths[i])
			x += widths[i] + SEPARATION

	## Vertically centred in the lane; a card taller than the lane keeps
	## its height and hangs off the bottom, as in [SqueezeRow].
	func _place(card: Control, x: float, width: float) -> void:
		var height: float = card.get_combined_minimum_size().y
		var y: float = maxf((size.y - height) * 0.5, 0.0)
		fit_child_in_rect(card, Rect2(Vector2(x, y), Vector2(width, height)))


func _make_marker(top: float) -> TextureRect:
	var mark := TextureRect.new()
	mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mark.position = Vector2(EDGE, top)
	mark.size = Vector2(MARKER_W, LANE_H)
	return mark


## The window's own title, `@WINDOWTITLES` verbatim: the player's attack is
## `Your attack`, anyone else's is `%s Attack`.
static func title_for(attacking_pid: int, human_pid: int,
		attacker_name: String) -> String:
	if attacking_pid == human_pid:
		return "Your attack"
	return "%s Attack" % attacker_name


## Lay the window out inside [param area] (the board's rectangle): the
## art's own 888 wide wherever there is room, centred on the area and
## straddling its middle — the seam where the two territories meet, which
## is where combat happens. A dragged/restored position takes precedence
## across phase changes, minimize/restore, and subsequent combats.
func fit(area: Rect2) -> void:
	var w := minf(ART_SIZE.x, maxf(custom_minimum_size.x, area.size.x - 8.0))
	size = Vector2(w, HEIGHT)
	if _user_positioned:
		_clamp_on_screen()
	else:
		position = Vector2(area.position.x + (area.size.x - w) * 0.5,
			area.get_center().y - HEIGHT * 0.5)


## Rebuild both lanes. [param attacker_ids] and [param blocker_ids] are
## card instance ids in the order they should line up; the ATTACKER's lane
## sits on the attacking player's own side of the window (manual p.126,
## "Your attackers line up on your side"), so the player's own attack fills
## the BOTTOM lane and the opponent's fills the TOP one.
##
## [param bands] are the attack bands (arrays of attacker ids, declared or
## pencilled in); each one's members are framed together in the attackers'
## lane — see [constant BAND_INK].
func present(game: MtgGame, attacker_ids: Array, blocker_ids: Array,
		attacking_pid: int, human_pid: int, bands: Array = []) -> void:
	_title.text = title_for(attacking_pid, human_pid,
		game.players[attacking_pid].player_name)
	var attackers_on_bottom := attacking_pid == human_pid
	_top_ids = blocker_ids if attackers_on_bottom else attacker_ids
	_bottom_ids = attacker_ids if attackers_on_bottom else blocker_ids
	_band_groups = []
	_fill(_top_lane, game, _top_ids, [] if attackers_on_bottom else bands)
	_fill(_bottom_lane, game, _bottom_ids, bands if attackers_on_bottom else [])
	var sword := MiniCard.masked_sprite("attack_sword")
	var shield := MiniCard.masked_sprite("attack_shield")
	_top_marker.texture = shield if attackers_on_bottom else sword
	_bottom_marker.texture = sword if attackers_on_bottom else shield
	if _bones.texture == null:
		_bones.texture = MiniCard.masked_sprite("attack_bones", true)


func _fill(lane: Lane, game: MtgGame, ids: Array,
		bands: Array = []) -> void:
	for child in lane.get_children():
		lane.remove_child(child)
		child.queue_free()
	if not card_builder.is_valid():
		return
	var laid := {}
	for id in ids:
		if laid.has(id):
			continue
		var band := _band_holding(bands, id)
		if band.size() < 2:
			var inst: CardInstance = game.find_instance(id)
			if inst == null:
				continue
			lane.add_child(card_builder.call(inst) as Control)
			laid[id] = true
			continue
		# A BAND: its members stand together at the first one's place, in
		# lane order, inside one frame.
		var frame := _make_band_frame()
		var row: HBoxContainer = frame.get_child(0)
		var members: Array = []
		for member_id in ids:
			if not band.has(member_id) or laid.has(member_id):
				continue
			var inst: CardInstance = game.find_instance(member_id)
			if inst == null:
				continue
			row.add_child(card_builder.call(inst) as Control)
			laid[member_id] = true
			members.append(member_id)
		# The rule needs clear ground to show on: a turned card's holder
		# has 4px of it on every side and the lane has no height to spare,
		# so the frame hugs the row; a flat card (pencilled in, or
		# attacking with vigilance) has none, so the frame steps out by
		# its own width — it has the room, a flat card being 106 tall.
		var tallest := 0.0
		for child in row.get_children():
			tallest = maxf(tallest, (child as Control).get_combined_minimum_size().y)
		var box: StyleBoxFlat = frame.get_theme_stylebox("panel")
		box.set_content_margin_all(
			BAND_RULE if tallest + 2.0 * BAND_RULE <= LANE_H else 0.0)
		lane.add_child(frame)
		_band_groups.append(members)


## The band in [param bands] that holds [param id], or `[]`.
static func _band_holding(bands: Array, id: int) -> Array:
	for band in bands:
		if (band as Array).has(id):
			return band
	return []


## One band's frame: a ruled box with no ground of its own ([constant
## BAND_INK]) over a row that puts its cards edge to edge — the holders'
## own clear margin is the spacing. Neither takes the pointer, so the
## cards stay as clickable as they are loose in the lane.
func _make_band_frame() -> PanelContainer:
	var frame := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = BAND_INK
	box.set_border_width_all(BAND_RULE)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", box)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(row)
	return frame


## Ids in the top lane, then the bottom — what a test reads to prove the
## lineup landed on the right side of the window.
func lane_ids() -> Array:
	return [_top_ids.duplicate(), _bottom_ids.duplicate()]


## The framed bands, in lane order, each an Array of member ids.
func band_groups() -> Array:
	return _band_groups.duplicate(true)


func _on_minimize_pressed() -> void:
	minimized = true
	minimize_toggled.emit(true)

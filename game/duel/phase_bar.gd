class_name PhaseBar
extends Control
## THE PHASE BAR — *"the central control for the progress of the duel"*
## (manual p.116), the vertical strip between the sidebar and the
## territories. Sixteen icons: the top half is the opponent's turn, the
## lower half yours.
##
## Manual p.116, in order, and every behaviour below is one of these
## sentences:
##
##   * *"First and foremost, the current phase is always highlighted."*
##     — [member _active], the sheet's own washed-out cell, is the ONLY
##     current-phase cue. The red dot is not it (see THE RED DOT below).
##   * *"You can move forward ('run') to any phase by clicking on the icon
##     for that phase."* — [signal slot_pressed].
##   * *"(You can also do this by right-clicking on the phase and selecting
##     Run to from the mini-menu.)"* — [signal slot_context], which the
##     DuelScreen answers with the four `@MENU_PHASEBAR` entries.
##   * *"You can right-click on any phase and select Mark from the
##     mini-menu to put a Stop on that phase."* — [member stops], drawn as
##     the red dots.
##
## THE RED DOT IS THE STOP MARKER, corrected 2026-08-31. It used to ride
## beside the current phase, which duplicated the highlight for no reason;
## `Duel.hlp`, topic **Stop**, is explicit that a Stop *"put[s] a Stop
## **marker** on that phase"*, the manual gives the current phase the
## highlight and nothing else, and the sheet ships no marker sprite of its
## own — so the marker is code-drawn, and there is exactly one thing in the
## 1997 Phase Bar that needs one. There can be several at once, which is
## why this is an array of dots and not the single Label it replaced.
##
## THE ART — `Winbk_Phase.pic`, 82x760: two columns of 41, the NORMAL icons
## at x 0 (black card grounds) and the HIGHLIGHTED variants at x 44 (white
## card grounds) — s30's `phaseDefaultBg` / `phaseActiveImgs`. Eight cells
## per half at a 41px pitch, the opponent's from y=2 and the player's from
## y=431; 329..431 is the bare stone CENTRE BAND that holds the window icon
## (manual p.126).

## The sheet, and the column the bar occupies.
const SHEET_SIZE := Vector2(82.0, 760.0)
const COLUMN_W := 41.0
## One icon cell, and its x inside the column (normal) / in the sheet
## (highlighted).
const CELL := Vector2(35.0, 40.0)
const CELL_X := 2.0
const ACTIVE_X := 44.0
## Row pitch, and the count of icons in one half.
const ROW_PITCH := 41.0
const SLOTS := 8
## y of the first icon of each half, indexed by [enum PhaseStops.Half] —
## the opponent's strip on top, yours below (manual p.116).
const HALF_Y: Array[float] = [2.0, 431.0]

## `@CUECARD_PHASEBAR`, `shandalar-src/Program/UIStrings.txt:706` (the same
## 23 entries at `Program/Text.res:807`) — entries 1-8 are the OPPONENT's
## half, `%s` being their name, and 9-16 are yours. Verbatim, in the
## table's own order, which is the order the icons are drawn in.
## Entries 17-23 are the Combat Bar's and live in [CombatBar].
const CUE_OPPONENT: Array[String] = [
	"%s Untap phase",
	"%s Upkeep phase",
	"%s Draw phase",
	"%s Main phase (precombat)",
	"%s Main phase (combat)",
	"%s Main phase (postcombat)",
	"%s Discard phase",
	"%s Cleanup phase",
]
const CUE_YOURS: Array[String] = [
	"Your Untap phase",
	"Your Upkeep phase",
	"Your Draw phase",
	"Your Main phase (precombat)",
	"Your Main phase (declare combat)",
	"Your Main phase (postcombat)",
	"Your Discard phase",
	"Your Cleanup phase",
]

## A phase icon was left-clicked: *"You can move forward ('run') to any
## phase by clicking on the icon for that phase"* (manual p.116).
signal slot_pressed(half: int, slot: int)

## A phase icon was right-clicked — the DuelScreen opens the
## `@MENU_PHASEBAR` mini-menu at [param at] (screen coordinates).
signal slot_context(half: int, slot: int, at: Vector2)

## The player's Stops. Shared with the DuelScreen and the Combat Bar; the
## bar only READS it, and is told to redraw by [method refresh_stops].
var stops: PhaseStops = null

## The opponent's name, for the `%s` in [constant CUE_OPPONENT].
var opponent_name := "Opponent":
	set(value):
		opponent_name = value
		_apply_cue_cards()

var _ground: TextureRect = null
var _active: TextureRect = null
var _zones: Array[Control] = []
var _dots: Array[Label] = []
var _active_half := PhaseStops.Half.YOURS
var _active_slot := 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ground = TextureRect.new()
	_ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ground.stretch_mode = TextureRect.STRETCH_SCALE
	_ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground)

	_active = TextureRect.new()
	_active.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_active.stretch_mode = TextureRect.STRETCH_SCALE
	_active.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_active)

	# Sixteen hover/click zones, each carrying its 1997 cue card, and
	# sixteen Stop dots riding beside them.
	for half in 2:
		for slot in SLOTS:
			var zone := Control.new()
			zone.mouse_filter = Control.MOUSE_FILTER_STOP
			var h := half
			var s := slot
			zone.gui_input.connect(func(event: InputEvent) -> void:
				_on_zone_input(event, h, s))
			add_child(zone)
			_zones.append(zone)
			var dot := make_stop_dot()
			add_child(dot)
			_dots.append(dot)
	_apply_cue_cards()
	resized.connect(_relayout)


## THE STOP MARKER, shared with the Combat Bar so both bars mark a Stop the
## same way. The sheet carries no marker sprite (checked: `Winbk_Phase.pic`
## is icons and stone), so the original drew it in code, and the owner's
## own word for it is "red dot".
static func make_stop_dot() -> Label:
	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 13)
	dot.add_theme_color_override("font_color", Color(0.85, 0.10, 0.08))
	dot.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	dot.add_theme_constant_override("shadow_offset_x", 1)
	dot.add_theme_constant_override("shadow_offset_y", 1)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.visible = false
	return dot


## The cue card one icon carries. [param half] is a
## [enum PhaseStops.Half].
static func cue_card(half: int, slot: int, other_name: String) -> String:
	var i := clampi(slot, 0, SLOTS - 1)
	if half == PhaseStops.Half.YOURS:
		return CUE_YOURS[i]
	return CUE_OPPONENT[i] % other_name


## Top of one icon cell in the sheet.
static func slot_y(half: int, slot: int) -> float:
	return HALF_Y[clampi(half, 0, 1)] + ROW_PITCH * clampi(slot, 0, SLOTS - 1)


## The sheet rectangle of the HIGHLIGHTED cell for one icon — the
## current-phase cue, and the only one (manual p.116).
static func active_region(half: int, slot: int) -> Rect2:
	return Rect2(ACTIVE_X, slot_y(half, slot), CELL.x, CELL.y)


## Light [param slot] of [param half] as the current phase.
func set_state(half: int, slot: int) -> void:
	_active_half = clampi(half, 0, 1)
	_active_slot = clampi(slot, 0, SLOTS - 1)
	_relayout()


## The icon currently lit, as `[half, slot]`.
func state() -> Array:
	return [_active_half, _active_slot]


## Redraw the red dots from [member stops].
func refresh_stops() -> void:
	for i in _dots.size():
		var half := i / SLOTS
		var slot := i % SLOTS
		_dots[i].visible = stops != null \
			and stops.is_marked(half, PhaseStops.Bar.PHASE, slot)


func _on_zone_input(event: InputEvent, half: int, slot: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		slot_pressed.emit(half, slot)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		slot_context.emit(half, slot, mb.global_position)


func _apply_cue_cards() -> void:
	for i in _zones.size():
		_zones[i].tooltip_text = cue_card(i / SLOTS, i % SLOTS, opponent_name)


func _relayout() -> void:
	var sheet := GameSkin.texture("phase_bar")
	if sheet == null:
		# No 1997 skin: the bar simply is not there (the DuelScreen does not
		# even build it), exactly as the Combat Bar is skipped without one.
		_ground.texture = null
		_active.texture = null
		return
	if _ground.texture == null:
		var column := AtlasTexture.new()
		column.atlas = sheet
		column.region = Rect2(0, 0, COLUMN_W, SHEET_SIZE.y)
		_ground.texture = column
	var lit := AtlasTexture.new()
	lit.atlas = sheet
	lit.region = active_region(_active_half, _active_slot)
	_active.texture = lit

	var sx := size.x / COLUMN_W
	var sy := size.y / SHEET_SIZE.y
	var y := slot_y(_active_half, _active_slot)
	_active.position = Vector2(CELL_X * sx, y * sy)
	_active.size = CELL * Vector2(sx, sy)
	for i in _zones.size():
		var cell_y := slot_y(i / SLOTS, i % SLOTS)
		_zones[i].position = Vector2(CELL_X * sx, cell_y * sy)
		_zones[i].size = CELL * Vector2(sx, sy)
		# The dot rides at the icon's right edge, vertically centred on it —
		# where the single marker used to sit.
		_dots[i].position = Vector2(size.x - 13.0,
			(cell_y + CELL.y * 0.5) * sy - 10.0)

class_name CombatBar
extends Control
## THE COMBAT BAR — the 1997 duel's own name for the strip that REPLACES
## the Phase Bar for the duration of an attack.
##
## `Duel.hlp`, topic **Combat Bar**: *"The Combat Bar is a miniature Phase
## Bar that appears during an attack. It functions in exactly the same way
## as the larger bar; you can even use Stops. This bar has SEVEN icons,
## representing the sub-phases of combat:"* — and it then lists them:
##
##   Declare Attackers · Fast Effects · Declare Blockers · Fast Effects (2)
##   · Damage Dealing, Part 1: First Strike Damage Dealing
##   · Damage Dealing, Part 2: Normal Damage Dealing
##   · Damage Dealing, Part 3: End of Combat
##
## The printed manual (p.117) says FIVE. It is outnumbered three to one and
## is the only source that says so: the shipped help file says seven and
## names them, `@CUECARD_PHASEBAR` carries exactly seven combat tooltips
## (`shandalar-src/Program/UIStrings.txt:706`, entries 17-23), and the art
## draws exactly seven icons. See docs/duel-screen-design.md.
##
## Manual p.125 / `Duel.hlp` topic **Combat**: *"Once you've clicked on the
## combat icon on the Phase Bar, your next step is declaring your attack.
## At this point, the Combat Bar takes the place of the Phase Bar. This
## functions exactly as the Phase Bar does, except that it marks (and
## controls) your progress through the sub-phases that take place during an
## attack."* — and *"Satisfied with the attack line-up? Use the Done option
## on the mini-menu, the Done button on the Situation Bar, or click a
## sub-phase on the Combat Bar."* That last clause is [signal slot_pressed].
##
## THE ART — `Winbk_Phasecombat.pic`, 164x760, measured with PIL:
## it is `Winbk_Phase`'s own 82px [normal | highlighted] pair laid down
## TWICE, side by side — x 0..81 in the opponent's GOLD, x 82..163 in the
## player's BLUE — each column a full 760 tall so the file drops straight
## into the Phase Bar's rectangle and nothing else has to move. That is
## why the seat is chosen by COLUMN here where the Phase Bar chooses it by
## HALF, and why the icons always sit in the top third with the rest of the
## column bare stone.
##
## The seven icons, in sheet order, with their `@CUECARD_PHASEBAR` tooltip:
##
## | row | icon | tooltip |
## |---|---|---|
## | 0 | a sword, hilt up | `Choose attackers phase` |
## | 1 | the sword with red rays | `Attacker fast effects phase` |
## | 2 | a shield | `Assign defenders phase` |
## | 3 | the shield with red rays | `Blocker fast effects phase` |
## | 4 | the shield split, red through the break | `Resolve 1st strike damage` |
## | 5 | a red sword driven through the shield | `Resolve normal damage` |
## | 7 | the Phase Bar's own mirrored crescent | `Main phase (postcombat)` |
##
## Row 6 is bare stone: the gap the original leaves between the six
## in-combat icons and the exit.

## The sheet, and one seat's half of it.
const SHEET_SIZE := Vector2(164.0, 760.0)
## Width of the column the bar occupies — the Phase Bar's own 41px.
const COLUMN_W := 41.0
## x of the player's half within the sheet (the opponent's is 0).
const SEAT_PITCH := 82.0
## x of the HIGHLIGHTED cell inside a half (the normal one is at 3).
const ACTIVE_X := 44.0
## One icon cell, measured on the art (the Phase Bar's own 35x40).
const CELL := Vector2(35.0, 40.0)
## x of a normal cell inside its half — used for the hover zones.
const CELL_X := 3.0

## Pure white is the sheet's key colour inside an icon cell, and what is
## done with it is the CLASSIC MICROPROSE LOOK the owner settled on
## (2026-08-31): *"use the same strip but icons use black behind (recolor
## white to black and when individual phase is active use the white behind
## icon)."*
##
## That is exactly what `Winbk_Phase.pic` — the larger bar this one
## replaces — already does in its own art: its NORMAL cells are drawn on
## black card grounds and its HIGHLIGHTED cells on white ones, so the lit
## phase is a white box in a column of black ones. `Winbk_Phasecombat.pic`
## ships both variants on WHITE, so the ground column is keyed to black
## here and the lit cell is left exactly as the sheet draws it. The two
## bars then read identically, which is the whole point of *"a miniature
## Phase Bar… it functions in exactly the same way as the larger bar."*
const WHITE_KEY := 0.93

## What a keyed-out cell interior is filled with.
## [constant Fill.BLACK] is the strip's own unlit ground (see
## [constant WHITE_KEY]); [constant Fill.STONE] samples the bare row-6 band
## and is kept because it is the right fill for anything that must
## disappear INTO the strip rather than sit on it.
enum Fill { BLACK, STONE }

## The bare-stone gap (row 6) the strip leaves between the six in-combat
## icons and the exit — the only pure background anywhere in the sheet.
## Sampled from the SAME column so the grain lines up.
const STONE_BAND_Y := 248
const STONE_BAND_H := 40
## Top of each icon cell in the sheet. SEVEN entries for seven icons; the
## jump from 207 to 289 skips row 6, the bare stone gap before the exit.
const SLOT_Y: Array[float] = [2.0, 43.0, 84.0, 125.0, 166.0, 207.0, 289.0]

## `@CUECARD_PHASEBAR`, `shandalar-src/Program/UIStrings.txt:706`, entries
## 17-23 — the seven strings that follow the sixteen Phase Bar ones, in
## the table's own order, verbatim. One per icon.
const TOOLTIPS: Array[String] = [
	"Choose attackers phase",
	"Attacker fast effects phase",
	"Assign defenders phase",
	"Blocker fast effects phase",
	"Resolve 1st strike damage",
	"Resolve normal damage",
	"Main phase (postcombat)",
]

## Icon indices, by the name `Duel.hlp` gives each sub-phase.
enum Slot {
	DECLARE_ATTACKERS, ATTACKER_FAST_EFFECTS,
	DECLARE_BLOCKERS, BLOCKER_FAST_EFFECTS,
	FIRST_STRIKE_DAMAGE, NORMAL_DAMAGE, END_OF_COMBAT,
}

## A sub-phase icon was left-clicked. The manual makes this the third way
## to end a declaration (*"or click a sub-phase on the Combat Bar"*); with
## no declaration pending the DuelScreen reads it as the larger bar's
## **Run to**, because *"it functions in exactly the same way."*
signal slot_pressed(slot: int)

## A sub-phase icon was right-clicked — the DuelScreen opens the same
## `@MENU_PHASEBAR` mini-menu it opens on the Phase Bar, at [param at]
## (screen coordinates). `Duel.hlp`, topic **Combat Bar**: *"you can even
## use Stops."*
signal slot_context(slot: int, at: Vector2)

## The player's Stops, shared with the DuelScreen and the Phase Bar. Read
## only; [method refresh_stops] redraws the dots.
var stops: PhaseStops = null

var _ground: TextureRect = null
var _active: TextureRect = null
var _dots: Array[Label] = []
var _zones: Array[Control] = []
var _is_player_seat := false
var _half := PhaseStops.Half.YOURS
var _slot := 0


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

	# One hover/click zone per icon, carrying the original's cue card, and
	# one Stop dot beside each — `Duel.hlp`: "you can even use Stops."
	for i in SLOT_Y.size():
		var zone := Control.new()
		zone.mouse_filter = Control.MOUSE_FILTER_STOP
		zone.tooltip_text = TOOLTIPS[i]
		var index := i
		zone.gui_input.connect(func(event: InputEvent) -> void:
			if not (event is InputEventMouseButton) or not event.pressed:
				return
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				slot_pressed.emit(index)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				slot_context.emit(index, mb.global_position))
		add_child(zone)
		_zones.append(zone)
		# The same red dot the Phase Bar marks a Stop with, built by the
		# same routine so the two bars can never drift apart.
		var dot := PhaseBar.make_stop_dot()
		add_child(dot)
		_dots.append(dot)

	resized.connect(_relayout)


## True while the duel is inside the span the Combat Bar owns: from the
## moment combat begins (the manual's "Once you've clicked on the combat
## icon… the Combat Bar takes the place of the Phase Bar") to the end of
## the combat phase.
static func covers_step(step: int) -> bool:
	return step >= Mtg.Step.COMBAT_BEGIN and step <= Mtg.Step.COMBAT_END


## IS THERE AN ATTACK FOR THIS BAR TO DESCRIBE? The owner's playtest,
## 2026-09-03: *"If no attackers are declared the combat subphases should
## not show."* [method covers_step] is the ENGINE's span; this is the
## SCREEN's, and the two are not the same thing.
##
## `Duel.hlp`, topic **Combat Bar**, is the whole rule and it is one word:
## *"The Combat Bar is a miniature Phase Bar that appears during an
## ATTACK."* Not "during combat" — during an attack. Topic **Combat** says
## when the attack begins to exist: *"Once you've clicked on the combat
## icon on the Phase Bar, your next step is declaring your attack. At this
## point, the Combat Bar takes the place of the Phase Bar"*, and *"As soon
## as you add the first creature to the attack, the Combat window opens."*
##
## So the bar is up while the attack is being DECLARED — the combat-begin
## step and the declaration itself — and after that only while an attack
## actually exists. Declare none and there is no attack, so the Phase Bar
## comes back and the sub-phases the engine is skipping anyway (CR 506.4 /
## 508.1: with no attackers the game proceeds to end of combat —
## `MtgGame._advance_step`, *"Skip blockers/damage when no attackers were
## declared"*) are never paraded.
##
## [param attacker_count] is `game.combat.attackers.size()`.
static func shows_attack(step: int, awaiting_attackers: bool,
		attacker_count: int) -> bool:
	if not covers_step(step):
		return false
	if step == Mtg.Step.COMBAT_BEGIN:
		return true          # "your next step is declaring your attack"
	if step == Mtg.Step.DECLARE_ATTACKERS and awaiting_attackers:
		return true          # it is being declared right now
	return attacker_count > 0


## Which icon a step lights. The two DECLARE steps each carry BOTH a
## declaration and the fast-effects round that follows it, so the engine's
## "is it still waiting on a declaration" flag picks between the pair —
## which is exactly the split the original drew as two icons.
##
## [constant Slot.FIRST_STRIKE_DAMAGE] lights in the engine's own
## `FIRST_STRIKE_DAMAGE` step, which exists only when someone in combat has
## first strike (CR 510.5, docs/duel-todo.md §1.6 — landed 2026-08-31). The
## icon is drawn either way, because the original's bar always shows all
## seven.
static func slot_for_step(step: int, awaiting_attackers: bool,
		awaiting_blockers: bool) -> int:
	match step:
		Mtg.Step.COMBAT_BEGIN:
			return Slot.DECLARE_ATTACKERS
		Mtg.Step.DECLARE_ATTACKERS:
			return Slot.DECLARE_ATTACKERS if awaiting_attackers \
				else Slot.ATTACKER_FAST_EFFECTS
		Mtg.Step.DECLARE_BLOCKERS:
			return Slot.DECLARE_BLOCKERS if awaiting_blockers \
				else Slot.BLOCKER_FAST_EFFECTS
		Mtg.Step.FIRST_STRIKE_DAMAGE:
			return Slot.FIRST_STRIKE_DAMAGE
		Mtg.Step.COMBAT_DAMAGE:
			return Slot.NORMAL_DAMAGE
		Mtg.Step.COMBAT_END:
			return Slot.END_OF_COMBAT
	return Slot.DECLARE_ATTACKERS


## Cache: one keyed texture per (sheet rectangle, fill). The keying walks
## every pixel, so it must not run per frame.
static var _keyed: Dictionary = {}


## [param region] of the sheet with every near-WHITE pixel replaced, per
## [param fill] — see [constant WHITE_KEY] and [enum Fill]. Null without a
## skin.
static func keyed_texture(region: Rect2, fill := Fill.BLACK) -> Texture2D:
	var cache_key := "%s|%d" % [region, fill]
	if _keyed.has(cache_key):
		return _keyed[cache_key]
	var sheet := GameSkin.texture("combat_bar")
	if sheet == null:
		return null
	var src := sheet.get_image()
	var img := src.get_region(Rect2i(region))
	img.convert(Image.FORMAT_RGBA8)
	var band: Image = null
	if fill == Fill.STONE:
		band = src.get_region(Rect2i(int(region.position.x), STONE_BAND_Y,
			int(region.size.x), STONE_BAND_H))
		band.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.r >= WHITE_KEY and c.g >= WHITE_KEY and c.b >= WHITE_KEY:
				if band == null:
					img.set_pixel(x, y, Color.BLACK)
				else:
					img.set_pixel(x, y,
						band.get_pixel(x % band.get_width(),
							y % band.get_height()))
	var tex := ImageTexture.create_from_image(img)
	_keyed[cache_key] = tex
	return tex


## The sheet rectangle of the column that replaces the Phase Bar's own
## background strip: the GOLD half (x 0..81) when the opponent is
## attacking, the BLUE half (x 82..163) when you are.
##
## Settled by the owner (2026-08-31): *"make it blue when im attacking and
## gold when an enemy is attacking."* An earlier pass had inferred, from a
## single 1997 screenshot of "Your attack", that the bar was always blue
## and left the gold half unused; the sheet lays both halves out
## identically for a reason, and this is that reason. It is also the Phase
## Bar's own convention, whose opponent half is gold and player half blue.
static func column_region(is_player_seat: bool) -> Rect2:
	var x := SEAT_PITCH if is_player_seat else 0.0
	return Rect2(x, 0.0, COLUMN_W, SHEET_SIZE.y)


## The sheet rectangle of one seat's HIGHLIGHTED icon for [param slot].
static func active_region(is_player_seat: bool, slot: int) -> Rect2:
	var x := (SEAT_PITCH if is_player_seat else 0.0) + ACTIVE_X
	return Rect2(x, SLOT_Y[clampi(slot, 0, SLOT_Y.size() - 1)], CELL.x, CELL.y)


## Show [param slot] lit, in [param is_player_seat]'s colours (the player's
## blue half of the sheet, or the opponent's gold). [param half] is the
## [enum PhaseStops.Half] whose Stops the bar draws — the attacking seat's,
## because that is whose sub-phases these are.
func set_state(is_player_seat: bool, slot: int,
		half := PhaseStops.Half.YOURS) -> void:
	_is_player_seat = is_player_seat
	_half = clampi(half, 0, 1)
	_slot = clampi(slot, 0, SLOT_Y.size() - 1)
	_relayout()
	refresh_stops()


## The icon currently lit (tests and the screenshot tour ask this).
func slot() -> int:
	return _slot


## Redraw the red dots from [member stops].
func refresh_stops() -> void:
	for i in _dots.size():
		_dots[i].visible = stops != null \
			and stops.is_marked(_half, PhaseStops.Bar.COMBAT, i)


func _relayout() -> void:
	var sheet := GameSkin.texture("combat_bar")
	if sheet == null:
		# No 1997 skin: the bar simply is not there, exactly as the Phase
		# Bar is skipped without it (duel_screen.gd builds neither).
		_ground.texture = null
		_active.texture = null
		return
	# The unlit column goes BLACK behind its icons; the lit cell keeps the
	# sheet's own white box, which IS the highlight (see WHITE_KEY).
	_ground.texture = keyed_texture(column_region(_is_player_seat), Fill.BLACK)
	var lit := AtlasTexture.new()
	lit.atlas = sheet
	lit.region = active_region(_is_player_seat, _slot)
	_active.texture = lit

	var sx := size.x / COLUMN_W
	var sy := size.y / SHEET_SIZE.y
	_active.position = Vector2(CELL_X - 1.0, SLOT_Y[_slot] - 1.0) \
		* Vector2(sx, sy)
	_active.size = CELL * Vector2(sx, sy)
	for i in _zones.size():
		_zones[i].position = Vector2(CELL_X * sx, SLOT_Y[i] * sy)
		_zones[i].size = CELL * Vector2(sx, sy)
		# The Stop dot rides beside its icon, as it does on the Phase Bar.
		_dots[i].position = Vector2(size.x - 13.0,
			(SLOT_Y[i] + CELL.y * 0.5) * sy - 10.0)

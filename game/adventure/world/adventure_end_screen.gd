class_name AdventureEndScreen
extends Control
## THE ADVENTURE LOST (part B, 2026-10-23) — 1997's last screen: `Uth-Arz.pic`
## (`game_over`, Arzakon over a burning castle) on the whole screen, the
## words of `@QUESTFAILED` centred low on it in a shadowed ink, a wait for
## a key — and the program's end (`exit(0)`):
##  - THE SPELL OF DOMINION CAST, a wizard's taps reached ([Sieges];
##    `ResolveWizardTownSiege`, world_lair_monster_slots.c 1225–1262): "Your
##    Righteous Quest has Failed" / "The Evil Planeswalker Arzakon and his
##    Minion the Evil Red Wizardess have attained Dominion over the plane of
##    Shandalar" / "The people will suffer…";
##  - NO CARD LEFT TO STAKE (`ExitIfNoUsableDeckCards`, visitLocation.c
##    2252): "You have no power for even an Ante!" / "Your Righteous Quest has
##    Failed" / "The Evil Planeswalker Arzakon and his Gruesome Minions have
##    worn you down" / "The people will suffer…" ([constant
##    CreatureMeeting.NO_ANTE]).
## Ours ends at the title, not the desktop: "Return to the title", a click
## or a key (after a moment, so the click that brought the end does not
## also end it) — [signal closed], and the world screen leaves WITHOUT A
## SAVE ([method WorldScreen.leave_unsaved]): the lead's default (Q7), as
## played — 1997 saved nothing between the last autosave and the end, so
## its Resume took the adventure up from before the fall, and so does ours.
## Reusable for part C's endings (the words are the caller's).

## The end read: back to the title.
signal closed

## The 1997 page the picture and the words were laid out on.
const PAGE := Vector2(640, 480)
## The 1997 font (16 px on a 640 × 480 screen; retail 20).
const FONT_SIZE := 16
## How long the end ignores a click or a key, in milliseconds.
const GUARD_MS := 500
const RETURN := "Return to the title"
## The words' ink and their shadow (1997 drew palette index 0xEA with a
## shadow under it: a pale stone on the dark ground).
const INK := Color8(232, 222, 236)
const SHADOW := Color8(10, 4, 12)

## The words, a part each (1997's line breaks kept inside a part).
var lines: Array = []
var _shown_at := 0
var _closed := false
var _words: Label
var _art: TextureRect


func _ready() -> void:
	name = "AdventureEndScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shown_at = Time.get_ticks_msec()
	var ground := ColorRect.new()
	ground.name = "Ground"
	ground.color = Color.BLACK
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	_art = TextureRect.new()
	_art.name = "Art"
	_art.texture = GameSkin.texture("game_over")
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_words = Label.new()
	_words.name = "Words"
	_words.text = words()
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.add_theme_color_override("font_color", INK)
	_words.add_theme_color_override("font_shadow_color", SHADOW)
	_words.add_theme_constant_override("shadow_offset_x", 2)
	_words.add_theme_constant_override("shadow_offset_y", 2)
	_words.add_theme_color_override("font_outline_color", SHADOW)
	_words.add_theme_constant_override("outline_size", 4)
	var face := GameSkin.font("font_title")
	if face != null:
		_words.add_theme_font_override("font", face)
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_words)
	var back := PaneStyle.button(RETURN, "ReturnToTitle", 1.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	column.add_child(back)
	var foot := Control.new()
	foot.custom_minimum_size = Vector2(0, 24)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(foot)
	resized.connect(_fit)
	_fit()


## The words as shown: the parts one under another, a blank line between
## (the 1997 strings each ended with one).
func words() -> String:
	var parts := PackedStringArray()
	for part in lines:
		parts.append(String(part))
	return "\n\n".join(parts)


## The words sized as the 1997 page was scaled to the screen.
func _fit() -> void:
	if _words == null:
		return
	var scale_by := minf(size.x / PAGE.x, size.y / PAGE.y) if size.x > 0.0 and size.y > 0.0 else 1.0
	_words.add_theme_font_size_override("font_size", maxi(int(FONT_SIZE * clampf(scale_by, 1.0, 2.0)), FONT_SIZE))


## THE END READ: [signal closed], once.
func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit()


## Whether the end may be read past yet (a moment after it came).
func ready_to_close() -> bool:
	return Time.get_ticks_msec() - _shown_at >= GUARD_MS


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and ready_to_close():
		accept_event()
		close()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if ready_to_close():
		close()

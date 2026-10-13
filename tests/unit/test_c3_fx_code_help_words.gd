extends GutTest
## THE HELP SAYS WHAT THE SCREENS SAY (repository check 2026-10-13,
## findings d1-25, d1-26 and d1-27).
##
## - The targeting cursor's line named Escape whatever key Cancel was bound
##   to; it now names the key bound NOW, as the other pages do, and the
##   Situation Bar's Cancel button when no key is bound.
## - Help called the packs "Pack 6 · Portal", "Pack 8 · The Mirage Block"
##   and "Pack 9 · The Tempest Block"; the Card Packs screen calls them
##   "Pack 6: Portal & Second Age", "Pack 8: The Mirage Block" and
##   "Pack 9: The Tempest Block".
## - The life register's mini help said "choose it again to flip it back";
##   the entry then reads "Flip back to lifepoints".

const CARD_PACKS_SCREEN := "res://game/card_packs_screen.gd"
const PACK_NAMES := ["Pack 6: Portal & Second Age", "Pack 8: The Mirage Block",
	"Pack 9: The Tempest Block"]

var _saved: Variant = null


func before_each() -> void:
	_saved = Settings.get_value(Controls.SETTINGS_KEY, null) \
		if Settings.has_value(Controls.SETTINGS_KEY) else null
	Controls.reset()


func after_each() -> void:
	Controls.reset()
	if _saved != null:
		Settings.set_value(Controls.SETTINGS_KEY, _saved)
		Controls.apply()


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func test_the_targeting_cursor_names_the_key_bound_to_cancel() -> void:
	assert_string_contains(HelpPages.all_text(), "target that player. Escape cancels.",
		"control: the default key")
	assert_true(Controls.bind("duel_cancel", _key(KEY_K)), "control: Cancel moved to K")
	var text := HelpPages.all_text()
	assert_string_contains(text, "target that player. K cancels.", "the key bound now")
	assert_false(text.contains("Escape cancels."), "not the old key")


func test_with_no_key_on_cancel_the_cursor_names_the_bar_button() -> void:
	Controls._set_events("duel_cancel", [] as Array[InputEvent])
	assert_eq(Controls.key_text("duel_cancel"), Controls.UNBOUND, "control: no key")
	assert_string_contains(HelpPages.all_text(),
		"target that player. The Cancel button on the Situation Bar cancels.")


func test_the_packs_are_named_as_the_card_packs_screen_names_them() -> void:
	var screen := FileAccess.get_file_as_string(CARD_PACKS_SCREEN)
	assert_false(screen.is_empty(), "control: the screen's source is readable")
	var text := HelpPages.all_text()
	for pack_name: String in PACK_NAMES:
		assert_string_contains(screen, pack_name, "control: the screen says " + pack_name)
		assert_string_contains(text, pack_name, "Help says " + pack_name)
	for old: String in ["Pack 6 · ", "Pack 8 · ", "Pack 9 · "]:
		assert_false(text.contains(old), "no '%s' left in Help" % old)


func test_the_life_registers_help_names_both_flip_entries() -> void:
	var words: String = HelpPages.mini(HelpPages.MINI_LIFE)["text"]
	assert_string_contains(words, DuelistFace.MENU_LIFE[DuelistFace.FLIP])
	assert_string_contains(words, DuelistFace.MENU_FACE[DuelistFace.FLIP])
	assert_false(words.contains("choose it again"), "the entry changes its name once flipped")

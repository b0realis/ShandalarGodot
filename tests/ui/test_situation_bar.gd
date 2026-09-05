extends GutTest
## THE SITUATION BAR — `docs/duel-todo.md` §3.7 and §3.10.
##
## `Duel.hlp`, topic **Situation Bar**: *"Between the two territories
## (usually) is the Situation Bar. This is a reminder to you of what's
## going on and what you need to do… At the rightmost end of this bar is a
## **Done** button, a **Cancel** button, or both, depending on the
## situation."* Manalink states the same thing as a bit spec — `allow_cancel`
## (`shandalar-src/src/defs.h:2390`), 0 none / 1 Cancel / 2 Done / 3 both —
## so "which buttons apply" is a property of the moment, and these tests
## pin the Done bit. `test_cancel_contract.gd` pins the Cancel bit.
##
## The message the bar CARRIES has three voices and they are pinned here
## too: the running status line, a targeting prompt, and a refused action,
## the last of which is the only one that is not white.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func _give(card_name: String, pid := 0) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(inst)
	return inst


func _put(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	return inst


func _lit() -> bool:
	return screen._pass_button.modulate == DuelScreen.DONE_LIT


# ------------------------------------------------- §3.7 the Done button --

func test_done_is_lit_while_the_human_holds_priority() -> void:
	# THE DEFECT THIS FIXES. Done used to brighten only in the declaration
	# modes, so during an ordinary main phase — the commonest moment in the
	# duel, and one where Done is the ONLY thing to click — the bar gave no
	# cue at all. s30 outlines it whenever `humanHasPriority()`.
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_true(screen._is_human(screen.game.priority_player),
		"the duel opens with the human on priority")
	screen._refresh()
	assert_true(_lit(), "Done is the thing to click, so Done is lit")


func test_done_is_dark_once_the_duel_is_over() -> void:
	screen.game.game_over = true
	screen._refresh()
	assert_false(_lit(), "nothing left to pass")


func test_done_stays_lit_for_the_declarations() -> void:
	# The behaviour that was already right: Done doubles as the
	# declaration Confirm, so it is lit for the whole declaration.
	screen._on_pass_turn()
	if not screen.game.awaiting_attackers:
		pass_test("no attack step reached in this opening — nothing to pin")
		return
	screen._refresh()
	assert_eq(screen.mode, DuelScreen.Mode.ATTACKERS)
	assert_true(_lit(), "Done confirms the attack line-up")


func test_done_is_dark_on_a_fixed_one_target_slot() -> void:
	# Aiming Lightning Bolt, Done has nothing to close: the slot wants
	# exactly one target and shuts itself the moment it gets one. Lighting
	# it would promise an action the button does not have.
	_put(1, "Grizzly Bears")
	screen.game.recalculate()
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	screen._click_hand_card(_give("Lightning Bolt"))
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	screen._refresh()
	assert_false(_lit(), "a fixed slot closes itself; Done is not the way out")


func test_done_lights_on_a_variable_slot_once_its_minimum_is_met() -> void:
	# Sylvan Paradise is "ONE OR MORE target creatures", so the slot stays
	# open and Done is genuinely "that's all my targets" — but only after
	# at least one has been picked.
	var bear := _put(1, "Grizzly Bears")
	_put(1, "Hill Giant")
	screen.game.recalculate()
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.G, 1)
	screen._click_hand_card(_give("Sylvan Paradise"))
	screen._refresh()
	assert_false(_lit(), "no targets yet: the minimum is not met")
	screen._on_card_clicked(bear)
	screen._refresh()
	assert_true(_lit(), "one target in, Done can close the slot")


func test_done_is_dark_on_a_divided_slot() -> void:
	# §6.14: a division is a CLICK LOOP (`@PYROTECHNICS`) and it submits
	# itself when the last point lands, exactly as the combat division
	# does. Done is not the way out of one, so it must not light — this
	# test used to be the one above, with Pyrotechnics as its vehicle.
	var bear := _put(1, "Grizzly Bears")
	_put(1, "Hill Giant")
	screen.game.recalculate()
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.C, 4)
	screen._click_hand_card(_give("Pyrotechnics"))
	screen._refresh()
	assert_false(_lit(), "nothing dialled in")
	screen._on_card_clicked(bear)
	screen._refresh()
	assert_false(_lit(), "and still not: three points are owed")


func test_done_is_dark_while_a_modal_owns_the_keyboard() -> void:
	# The X question answers with its own OK. Done must not offer a second,
	# different way out of a dialog that is holding the cast open.
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.R, 5)
	screen._click_hand_card(_give("Fireball"))
	assert_true(screen._modal_open(), "the X question is up")
	screen._refresh()
	assert_false(_lit())


# ----------------------------------------- §3.10 the bar's three voices --

func test_a_refusal_is_red_and_the_status_line_is_not() -> void:
	# s30 paints `warningMsg` in RGBA{255,100,100} and every other state
	# white (`duel.go:3145-3168`). Ours wrote refusals in the bar's own
	# pale stone, so being refused looked exactly like being told the phase.
	screen._refresh()
	var calm: Color = screen._prompt_label.get_theme_color("font_color")
	assert_eq(calm, OriginalDialog.HIGHLIGHT, "the running line is the bar's own voice")
	screen._report("not enough mana for Lightning Bolt ({R})")
	assert_eq(screen._prompt_label.text, "not enough mana for Lightning Bolt ({R})")
	assert_eq(screen._prompt_label.get_theme_color("font_color"),
		DuelScreen.WARNING, "a refusal is red")


func test_the_refusal_hands_the_bar_back_when_it_expires() -> void:
	# The flash used to be gated only inside _refresh, so with nothing else
	# happening in the duel the red line never went away. It now has a
	# one-shot of its own.
	screen._report("Illegal target.")
	assert_true(screen._flash_until_ms > 0)
	screen._on_flash_expired()
	assert_eq(screen._flash_until_ms, 0)
	assert_eq(screen._prompt_label.get_theme_color("font_color"),
		OriginalDialog.HIGHLIGHT, "the bar is calm again")
	assert_eq(screen._prompt_label.text, screen._status_message(),
		"and back on the status line")


func test_a_successful_action_clears_the_red() -> void:
	screen._report("Illegal target.")
	screen._report("")
	assert_eq(screen._prompt_label.get_theme_color("font_color"),
		OriginalDialog.HIGHLIGHT)


func test_the_targeting_prompt_is_the_originals_own_sentence() -> void:
	# §3.10 asked for s30's `targeting %s (Cancel)` / `Selected %d of %d
	# targets (Cancel)`. The ORIGINAL outranks s30 here and says something
	# else: one sentence per prompt (`promptsX2.txt:24` "Select target
	# creature.") and, when several picks are wanted, @PROMPT_GRABMANA's
	# bracketed count (`UIStrings.txt:1090`, "%s(%d so far)").
	var bear := _put(1, "Grizzly Bears")
	screen.game.recalculate()
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	screen._click_hand_card(_give("Lightning Bolt"))
	assert_eq(screen._prompt_label.text, "Select any target.")
	screen._on_escape()
	screen._on_escape()

	_put(1, "Hill Giant")
	screen.game.recalculate()
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.G, 1)
	screen._click_hand_card(_give("Sylvan Paradise"))
	assert_eq(screen._prompt_label.text, "Select target creature. (0 so far)")
	screen._on_card_clicked(bear)
	assert_eq(screen._prompt_label.text, "Select target creature. (1 so far)")
	screen._on_escape()
	screen._on_escape()

	# A DIVIDED slot has a sentence of its own — `@PYROTECHNICS`
	# (`Program/prompts.txt:698`), one prompt per point of damage. See
	# §6.14: this is the divided-damage dial, and it is a click loop.
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.C, 4)
	screen._click_hand_card(_give("Pyrotechnics"))
	assert_eq(screen._prompt_label.text, "Select (1st of 4) any target.")
	screen._on_card_clicked(bear)
	assert_eq(screen._prompt_label.text, "Select (2nd of 4) any target.")


func test_the_status_line_does_not_paint_over_a_live_prompt() -> void:
	# s30's bar order: warning, then the targeting states, then the status
	# message. Ours is the same order expressed as a guard in _refresh.
	_put(1, "Grizzly Bears")
	screen.game.recalculate()
	screen.game.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	screen._click_hand_card(_give("Lightning Bolt"))
	screen._refresh()
	assert_eq(screen._prompt_label.text, "Select any target.",
		"a cast in progress owns the bar")


# ------------------------------ §6.7 which of the three frames the bar uses --
#
# `@PROMPT_FASTEFFECTS` (`UIStrings.txt:1018`) has three, and
# `src/functions/events.c:396-399` picks between them off the legal-response
# type mask: `Interrupts?...` when only TYPE_INTERRUPT may answer,
# `Fast Effects?...` when TYPE_INSTANT may, `Triggered effects?...` in the
# trigger window. We have no interrupt/instant split, so it reduces to two.
#
# NOTE THE SEPARATOR: a bare `...` with no spaces around it. Ours used to
# read `Fast Effects?  ...  `.

## Put one object on the chain and hand seat 0 priority, without going
## through the turn machine: the frame the bar CHOOSES is what is under
## test, not who may cast when. Fixture surgery, deliberately — the coin
## toss in `_new_game` decides who opens, so a test that assumed a seat
## would fail about one run in two.
func _chain(kind: int, card_name: String) -> void:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.STACK
	var item := StackItem.new()
	item.kind = kind
	item.card = inst
	item.controller = 0
	g.stack.append(item)
	g.priority_player = 0


func test_a_spell_on_the_chain_is_a_fast_effects_window() -> void:
	_chain(Mtg.StackKind.SPELL, "Lightning Bolt")
	assert_eq(screen._status_message(), "Fast Effects?...Cast Lightning Bolt")


func test_an_ability_on_the_chain_is_still_fast_effects() -> void:
	_chain(Mtg.StackKind.ABILITY, "Icy Manipulator")
	assert_eq(screen._status_message(),
		"Fast Effects?...Activate Icy Manipulator")


func test_a_TRIGGER_on_the_chain_changes_the_frame() -> void:
	# THE HALF §6.7 WAS MISSING. A trigger used to be announced as
	# "Fast Effects?...Process X" — the right verb inside the wrong
	# question. The trigger window has its own frame in the string table.
	_chain(Mtg.StackKind.TRIGGER, "Howling Mine")
	assert_eq(screen._status_message(),
		"Triggered effects?...Process Howling Mine")


func test_the_separator_is_a_bare_ellipsis() -> void:
	_chain(Mtg.StackKind.SPELL, "Lightning Bolt")
	var line := screen._status_message()
	assert_false(line.contains("? ..."), "no space before")
	assert_false(line.contains("... "), "and none after")


# ------------------------------------------- THE BAR'S LOOK (2026-09-03) --
#
# The owner, over his own photograph of the 1997 bar: *"In the central
# message I am missing the lighter border, and the correct button, and the
# blue-like text like in the photo."* Three things, and every one of them
# already existed in this project — the fix was assembling them.
#
# The photograph is a phone shot of a CRT and is not a colour reference;
# every number below is measured off the imported art instead
# (`assets/original/button_normal.png`, `message_panel.png`).

func test_the_bar_is_one_ruled_box_with_the_buttons_inside_it() -> void:
	# `Duel.hlp`, topic Situation Bar: "At the RIGHTMOST END OF THIS BAR
	# is a Done button, a Cancel button, or both" — the buttons are at an
	# END OF the bar, i.e. inside it. They used to float to its left, so
	# the border ran round the sentence only and the buttons sat on bare
	# board.
	var row := screen._pass_button.get_parent()
	assert_eq(screen._cancel_button.get_parent(), row,
		"Done and Cancel share one row")
	assert_eq(screen._prompt_label.get_parent(), row,
		"...and the sentence is in that same row")
	var panel := row.get_parent()
	assert_true(panel is PanelContainer,
		"one ruled box holds the whole bar")
	assert_eq(screen._pass_button.get_index(), 0,
		"Done is at the left end, where the sentence cannot push it about")


func test_the_bar_wears_the_1997_message_ground() -> void:
	var panel: Control = screen._pass_button.get_parent().get_parent()
	var box := panel.get_theme_stylebox("panel")
	assert_not_null(box)
	if GameSkin.texture("message_panel") == null:
		# No skin: the fallback must still be a legible ruled box rather
		# than nothing at all.
		assert_true(box is StyleBoxFlat, "a flat box stands in")
		assert_eq((box as StyleBoxFlat).border_color, OriginalDialog.HIGHLIGHT,
			"...still carrying the lighter border")
		return
	assert_true(box is StyleBoxTexture,
		"Winbk_Telluser, ruled — the ONE ground with no bevel of its own")
	var img: Image = (box as StyleBoxTexture).texture.get_image()
	var raw := GameSkin.texture("message_panel").get_image()
	assert_eq(img.get_size(), raw.get_size(), "the bar's own stone")
	assert_eq(img.get_pixel(40, 0), OriginalDialog.HIGHLIGHT,
		"and the lighter border the owner was missing")
	assert_eq(img.get_pixel(300, 17), raw.get_pixel(300, 17),
		"with the stone between the rules untouched")


func test_done_is_the_eras_raised_button() -> void:
	# `Winbk_Startduelbutton{Normal,Depressed,Disabled}` is the only
	# generic button art the 1997 game ships, and `@DIALOGBUTTONS` names
	# exactly three buttons in the whole game — "OK", "Cancel", "Done".
	assert_eq(screen._pass_button.text, "Done")
	assert_eq(screen._cancel_button.text, "Cancel")
	if GameSkin.texture("button_normal") == null:
		pass_test("no original skin imported")
		return
	for btn in [screen._pass_button, screen._cancel_button]:
		var normal: StyleBox = btn.get_theme_stylebox("normal")
		assert_true(normal is StyleBoxTexture, "the era's art, not a theme box")
		assert_eq((normal as StyleBoxTexture).texture,
			GameSkin.texture("button_normal"), "Winbk_Startduelbutton")
		assert_ne(btn.get_theme_stylebox("pressed"), normal,
			"a press must show")
		assert_eq(btn.get_theme_stylebox("hover_pressed"),
			btn.get_theme_stylebox("pressed"),
			"...including while the cursor is still on the button")
		assert_eq(btn.get_theme_color("font_color"), OriginalDialog.INK,
			"dark letters on a light face, as the original letters its own")


func test_the_sentence_is_the_pale_blue_grey_voice() -> void:
	# `OriginalDialog.HIGHLIGHT`, Color8(207, 209, 209), taken off the
	# button art's own top rule — the one pale voice the era uses on its
	# dark grounds. The label used to carry `bold`, which weights every
	# stroke with a hairline outline IN THE SAME COLOUR and reads as flat
	# white at 16px; the colour was already right, the outline hid it.
	screen._set_prompt("Main phase (before combat): cast spells")
	assert_eq(screen._prompt_label.get_theme_color("font_color"),
		OriginalDialog.HIGHLIGHT)
	assert_eq(screen._prompt_label.get_theme_color("font_shadow_color"),
		OriginalDialog.INK, "with the era's hard one-pixel dark shadow")
	assert_eq(screen._prompt_label.get_theme_constant("outline_size"), 0,
		"and nothing thickening it into white")


func test_a_refusal_is_still_the_only_non_pale_line() -> void:
	screen._report("not enough mana for Grizzly Bears ({1}{G})")
	assert_eq(screen._prompt_label.get_theme_color("font_color"),
		DuelScreen.WARNING)
	screen._set_prompt("Main phase (before combat): cast spells")
	assert_eq(screen._prompt_label.get_theme_color("font_color"),
		OriginalDialog.HIGHLIGHT, "and the bar takes its own voice back")

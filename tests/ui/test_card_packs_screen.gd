extends GutTest
## Pack management away from the title-screen shortcut: compatibility details,
## deck dependencies, readable failures, and name-based reprint selection.

const DECK_PATH := "user://pack_1_requirement_test.deck"

## EVERY enabled pack, not only Pack 1: a test here may reach for an
## expansion, and one that fails halfway must not hand the next script a
## different card pool.
var _was_enabled: Array[String] = []


func before_each() -> void:
	_was_enabled = Settings.enabled_card_packs()
	CardPacks.set_enabled(CardPacks.ID, false)
	CardPacks.set_current_deck_names([])


func after_each() -> void:
	CardPacks.set_current_deck_names([])
	Settings.set_enabled_card_packs(_was_enabled)
	CardPacks._configure_registry()
	CardRegistry.ensure_loaded()
	if FileAccess.file_exists(DECK_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DECK_PATH))


func _screen(path: String) -> Control:
	var screen: Control = load(path).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


func _button(root: Node, name: String) -> Button:
	return root.find_child(name, true, false) as Button


func test_options_has_a_card_packs_page_entry() -> void:
	var options := await _screen("res://game/options_screen.tscn")
	var button := _button(options, "CardPacks")
	assert_not_null(button)
	assert_eq(button.text, "Card Packs...")


func test_page_shows_folder_controls_state_version_and_compatibility() -> void:
	var page := await _screen("res://game/card_packs_screen.tscn")
	assert_not_null(_button(page, "OpenFolder"))
	assert_not_null(_button(page, "Rescan"))
	assert_false(_button(page, "EnablePack1").disabled)
	assert_true(_button(page, "DisablePack1").disabled)
	var status := page.find_child("Pack1Status", true, false) as Label
	assert_string_contains(status.text, "Status: Disabled")
	assert_string_contains(status.text, "Version: 1.0.0")
	assert_string_contains(status.text, "Minimum game version: 0.20.0")
	assert_string_contains(status.text, "1,270 set entries · 901 unique cards")
	var local_only := page.find_child("LocalOnly", true, false) as Label
	assert_string_contains(local_only.text, "not distributed with the game")
	assert_string_contains(local_only.text, "tools/pack_1_dotp_complete.py")


func test_page_prints_a_readable_rejection_reason() -> void:
	var saved_available := CardPacks._available.duplicate(true)
	var saved_rejections := CardPacks._rejections.duplicate(true)
	CardPacks._available.clear()
	CardPacks._rejections = [{"path": "/bad/Pack-1-DotP-complete.zip",
		"why": "its metadata checksum does not match"}]
	var page := await _screen("res://game/card_packs_screen.tscn")
	var status := page.find_child("Pack1Status", true, false) as Label
	assert_string_contains(status.text, "Status: Not available")
	assert_string_contains(status.text, "Reason: its metadata checksum does not match")
	CardPacks._available = saved_available
	CardPacks._rejections = saved_rejections


func test_saved_deck_declares_pack_but_keeps_plain_card_names() -> void:
	CardPacks.set_enabled(CardPacks.ID, true)
	var model := DeckModel.new()
	model.deck_name = "Orbital"
	assert_eq(model.add("Chaos Orb"), "")
	assert_eq(model.add("Disenchant"), "")
	var text := model.to_text()
	assert_string_contains(text, "# requires-pack: pack-1")
	assert_string_contains(text, "1 Chaos Orb")
	assert_string_contains(text, "1 Disenchant")
	assert_false(text.contains("Chaos Orb ["), "no printing is pinned")
	assert_eq(text.count("# requires-pack:"), 1)
	var parsed := DeckList.new()
	parsed.parse(text, "fallback", true)
	assert_eq(parsed.required_packs, [CardPacks.ID])


func test_loading_a_disabled_pack_deck_offers_enable_then_reloads_it() -> void:
	var file := FileAccess.open(DECK_PATH, FileAccess.WRITE)
	file.store_string("# requires-pack: pack-1\nname: Orbital\n1 Chaos Orb\n")
	file.close()
	var builder := await _screen(
		"res://game/deck_builder/deck_builder_screen.tscn") as DeckBuilderScreen
	builder._load_deck(DECK_PATH)
	await get_tree().process_frame
	assert_true(is_instance_valid(builder._pack_requirement_notice))
	assert_false(CardPacks.is_enabled(CardPacks.ID))
	_button(builder._pack_requirement_notice, "EnablePack1").pressed.emit()
	await get_tree().process_frame
	assert_true(CardPacks.is_enabled(CardPacks.ID))
	assert_eq(builder.deck.deck_name, "Orbital")
	assert_eq(builder.deck.count_of("Chaos Orb"), 1)
	assert_false(builder.deck.has_proxies())


## A drafted deck routinely spans two expansions. Enabling the first one
## must hand the second requirement its own question instead of closing
## the door on a deck that was never loaded.
func test_a_deck_needing_two_packs_asks_for_each_in_turn() -> void:
	for id in [IceAgePack.ID, AlliancesPack.ID]:
		CardPacks.set_enabled(id, false)
	var file := FileAccess.open(DECK_PATH, FileAccess.WRITE)
	file.store_string("# requires-pack: pack-3\n# requires-pack: pack-5\n"
		+ "name: Two Packs\n1 Ashen Ghoul\n1 Force of Will\n")
	file.close()
	var builder := await _screen(
		"res://game/deck_builder/deck_builder_screen.tscn") as DeckBuilderScreen
	builder._load_deck(DECK_PATH)
	await get_tree().process_frame
	assert_true(is_instance_valid(builder._pack_requirement_notice))
	_button(builder._pack_requirement_notice, "EnablePack3").pressed.emit()
	await get_tree().process_frame
	assert_true(CardPacks.is_enabled(IceAgePack.ID))
	assert_true(is_instance_valid(builder._pack_requirement_notice),
		"the second missing pack must get its own question")
	assert_ne(builder.deck.deck_name, "Two Packs",
		"the deck is not loaded while a requirement is still disabled")
	_button(builder._pack_requirement_notice, "EnablePack5").pressed.emit()
	await get_tree().process_frame
	assert_true(CardPacks.is_enabled(AlliancesPack.ID))
	assert_eq(builder.deck.deck_name, "Two Packs")
	assert_eq(builder.deck.count_of("Ashen Ghoul"), 1)
	assert_eq(builder.deck.count_of("Force of Will"), 1)
	assert_false(builder.deck.has_proxies())


## The requirement popup is a modal veil, not an OriginalDialog, so the
## builder's own key handler used to run under it: Enter added the
## Inventory's first card to the very deck the question was about, and
## the focused button never fired.
func test_the_requirement_popup_keeps_the_builders_keys_out() -> void:
	var file := FileAccess.open(DECK_PATH, FileAccess.WRITE)
	file.store_string("# requires-pack: pack-1\nname: Orbital\n1 Chaos Orb\n")
	file.close()
	var builder := await _screen(
		"res://game/deck_builder/deck_builder_screen.tscn") as DeckBuilderScreen
	builder._load_deck(DECK_PATH)
	await get_tree().process_frame
	assert_true(is_instance_valid(builder._pack_requirement_notice))
	var before := builder.deck.total()
	for code in [KEY_ENTER, KEY_RIGHT, KEY_BACKSPACE]:
		var key := InputEventKey.new()
		key.keycode = code
		key.pressed = true
		builder._input(key)
		await get_tree().process_frame
	assert_eq(builder.deck.total(), before,
		"no builder key may reach the board under the requirement modal")
	assert_true(is_instance_valid(builder._pack_requirement_notice))


func test_disabling_warns_when_the_current_deck_needs_pack_one() -> void:
	CardPacks.set_enabled(CardPacks.ID, true)
	CardPacks.set_current_deck_names(["Chaos Orb"])
	var page := await _screen("res://game/card_packs_screen.tscn")
	_button(page, "DisablePack1").pressed.emit()
	await get_tree().process_frame
	assert_true(is_instance_valid(page._warning))
	assert_true(CardPacks.is_enabled(CardPacks.ID), "the first click only warns")
	var labels := ""
	for label in page._warning.find_children("*", "Label", true, false):
		labels += (label as Label).text + "\n"
	assert_string_contains(labels, "Chaos Orb")
	_button(page._warning, "DisableAnyway").pressed.emit()
	await get_tree().process_frame
	assert_false(CardPacks.is_enabled(CardPacks.ID))


func test_selected_set_chooses_reprint_art_without_changing_identity() -> void:
	CardPacks.set_enabled(CardPacks.ID, true)
	var data := CardRegistry.get_card("Disenchant")
	var filter := DeckFilter.new()
	assert_eq(filter.preferred_printing(data), data.set_code)
	for code in CardRegistry.SET_ORDER:
		if code != "4ed":
			filter.toggle_set(code)
	assert_eq(filter.preferred_printing(data), "4ed")
	assert_eq(CardRegistry.all_names().count("Disenchant"), 1)


## THE CATALOGUE LOCK REACHES EVERY PACK (bug pass 2026-10-03). While an
## SGManalink session holds the catalogue, `_refresh` greys every pack
## button and says why on its tooltip — but its list stopped at Pack 6,
## so Pack 7's two stayed live under the lock. The tooltip is the tell
## that works on any machine: only the lock loop writes the refusal there,
## whether or not the pack itself was found.
func test_the_catalogue_lock_greys_every_packs_buttons() -> void:
	var holder := RefCounted.new()
	CardPacks.lock_catalogue(holder)
	var refusal := CardPacks.change_refusal()
	assert_ne(refusal, "", "a held catalogue says why")
	var page := await _screen("res://game/card_packs_screen.tscn")
	for n in range(1, 8):
		for verb in ["Enable", "Disable"]:
			var button := _button(page, "%sPack%d" % [verb, n])
			assert_not_null(button, "%sPack%d" % [verb, n])
			if button == null:
				continue
			assert_true(button.disabled, "%s is greyed under the lock" % button.name)
			assert_eq(button.tooltip_text, refusal, "%s says why" % button.name)
	CardPacks.unlock_catalogue(holder)


# ================================ bug pass 2026-10-03: shared reprints ==
#
# Pyroclasm is Ice Age's card and Portal carries it too. A deck saved with
# Ice Age on declared `# requires-pack: pack-3`, the declaration was
# carried for ever, and the gates checked DECLARED ids — so the deck was
# refused once Ice Age went off although the enabled Portal pack provides
# the card (`_shared_provider`'s own rule: any one enabled provider), and
# every re-save under another provider declared one pack more.

func _only_enabled(ids: Array) -> void:
	for id in CardPacks.known_ids():
		CardPacks.set_enabled(id, ids.has(id))


func test_a_shared_reprint_needs_any_one_enabled_provider() -> void:
	_only_enabled([IceAgePack.ID, PortalPack.ID])
	var names: Array[String] = ["Pyroclasm", "Mountain"]
	var declared: Array[String] = [IceAgePack.ID]
	assert_eq(CardPacks.effective_requirements(declared, names), [] as Array[String],
		"Portal provides Pyroclasm as well")
	_only_enabled([PortalPack.ID])
	assert_eq(CardPacks.missing_requirements(
		CardPacks.effective_requirements(declared, names)), [] as Array[String],
		"Ice Age off, Portal on: nothing is missing")
	_only_enabled([])
	assert_eq(CardPacks.effective_requirements(declared, names), declared,
		"no other provider on: the declaration stands")
	_only_enabled([PortalPack.ID])
	var with_new: Array[String] = ["Pyroclasm", "Arctic Foxes"]
	assert_eq(CardPacks.effective_requirements(declared, with_new), declared,
		"an Ice Age card only Ice Age provides keeps it")
	var unexplained: Array[String] = ["Mountain"]
	assert_eq(CardPacks.effective_requirements(declared, unexplained), declared,
		"a declaration no card explains is kept as written")
	var pack_one: Array[String] = [CardPacks.ID]
	assert_eq(CardPacks.effective_requirements(pack_one, names), pack_one,
		"Pack 1's own ids (printings) are kept")


func test_a_deck_saved_under_one_provider_loads_and_saves_under_another() -> void:
	_only_enabled([PortalPack.ID])
	var file := FileAccess.open(DECK_PATH, FileAccess.WRITE)
	file.store_string("# requires-pack: pack-3\nname: Burn\n4 Pyroclasm\n36 Mountain\n")
	file.close()
	var builder := await _screen(
		"res://game/deck_builder/deck_builder_screen.tscn") as DeckBuilderScreen
	builder._load_deck(DECK_PATH)
	await get_tree().process_frame
	assert_false(is_instance_valid(builder._pack_requirement_notice),
		"no pack to ask for: Portal provides the card")
	assert_eq(builder.deck.deck_name, "Burn")
	assert_eq(builder.deck.count_of("Pyroclasm"), 4)
	var text := builder.deck.to_text()
	assert_string_contains(text, "# requires-pack: pack-6")
	assert_false(text.contains("# requires-pack: pack-3"),
		"the re-save names the provider in play, not one more pack")

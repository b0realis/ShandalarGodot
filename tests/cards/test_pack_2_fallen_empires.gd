extends GameTest
## Needs the imported 1997 skin (assets/original) — run_tests.sh leaves this
## script out, by name, where there is none.
## Pack 2's separate pool and the first shared Fallen Empires mechanics.

func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	CardPacks.set_enabled(CardPacks.ID, false)
	# The Extras switches are remembered across screens (2026-09-17); a
	# test that moved them must not hand them to the next one.
	Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)

func test_fallen_empires_is_complete_and_independent_of_pack_one() -> void:
	assert_eq(CardRegistry.size(), 999)
	assert_eq(CardRegistry.names_in_set("fem").size(), 102)
	assert_false(CardRegistry.optional_pack_enabled())
	for name in FallenEmpiresPack.names():
		assert_true(CardRegistry.has_card(name), name)
		var data := CardRegistry.get_card(name)
		assert_eq(data.set_code, "fem")
		assert_false(data.oracle_text.contains("TODO"), name)
	CardPacks.set_enabled(CardPacks.ID, true)
	assert_eq(CardRegistry.size(), 1003)
	assert_eq(CardRegistry.named_set_entry_count(), 1372)
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_eq(CardRegistry.size(), 901)
	assert_false(CardRegistry.has_card("Thallid"))

func test_pack_two_names_are_saved_as_a_separate_requirement() -> void:
	assert_eq(CardPacks.packs_required_by(["Forest", "Thallid"]), ["pack-2"])
	assert_eq(CardPacks.packs_required_by(["Chaos Orb", "Hymn to Tourach"]), ["pack-1", "pack-2"])

func test_each_extra_can_be_hidden_without_disabling_packs_or_editing_the_deck() -> void:
	CardPacks.set_enabled(CardPacks.ID, true)
	var enabled_before: Array = Settings.get_value("enabled_card_packs", []).duplicate()
	var screen: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_ok(screen.deck.add("Chaos Orb"))
	assert_ok(screen.deck.add("Thallid"))
	var deck_before := screen.deck.counts.duplicate()
	var sets_before := screen.filter.sets.duplicate()
	screen._open_extra_sets()
	var buttons := {}
	for id in ["Original", "Pack1", "Pack2"]:
		for state in ["On", "Off"]:
			var key: String = id + state
			buttons[key] = screen.find_child("Extra" + key, true, false) as Button
			assert_not_null(buttons[key], key)
			if buttons[key] == null:
				return
	assert_null(screen.find_child("Onlyextras", true, false))
	assert_null(screen.find_child("Allsets", true, false))
	assert_null(screen.find_child("Original1997", true, false))
	assert_eq(screen._inventory.entry_count(), 1003)
	# Explicit On/Off is idempotent; it never flips an already chosen state.
	for step in [["Pack1Off", 999], ["Pack1Off", 999], ["Pack2Off", 897],
			["Pack1On", 901], ["Pack2On", 1003], ["Pack2On", 1003],
			["OriginalOff", -1], ["Pack1Off", 102], ["Pack2Off", 0],
			["OriginalOn", 897]]:
		buttons[step[0]].pressed.emit()
		if step[1] >= 0:
			assert_eq(screen._inventory.entry_count(), step[1], step[0])
		for id in ["Original", "Pack1", "Pack2"]:
			assert_ne(buttons[id + "On"].button_pressed, buttons[id + "Off"].button_pressed)
	assert_true(buttons.OriginalOn.button_pressed)
	assert_true(buttons.Pack1Off.button_pressed)
	assert_true(buttons.Pack2Off.button_pressed)
	for code in CardRegistry.SET_ORDER:
		assert_eq(screen.filter.set_on(code), sets_before[code], "source switches preserve the set strip")
	assert_eq(screen._pool.size(), 1003, "filtering does not unload cards")
	assert_eq(CardRegistry.size(), 1003)
	assert_eq(Settings.get_value("enabled_card_packs", []), enabled_before)
	assert_eq(screen.deck.counts, deck_before)
	# Reopening the panel retains the selections; Close does not reset filters.
	var dialog := screen.find_child("ExtraSetsDialog", true, false) as OriginalDialog
	dialog._buttons.get_child(0).pressed.emit()
	await get_tree().process_frame
	screen._open_extra_sets()
	assert_true((screen.find_child("ExtraPack1Off", true, false) as Button).button_pressed)
	assert_eq(screen._inventory.entry_count(), 897)

func test_pack_only_view_includes_added_reprints_and_uses_their_artwork() -> void:
	CardPacks.set_enabled(CardPacks.ID, true)
	var filter := DeckFilter.new()
	filter.original_cards_on = false
	filter.toggle_set("fem")
	assert_true(filter.active())
	var expected := {}
	for record in CardPacks.entry_records(CardPacks.ID):
		expected[String(record["name"])] = true
	var pool: Array[CardData] = []
	for name in CardRegistry.all_names():
		pool.append(CardRegistry.get_card(name))
	var visible := filter.apply(pool)
	assert_gt(visible.size(), 4, "Pack 1 includes reprints, not just new rules identities")
	assert_eq(visible.size(), expected.size())
	for data in visible:
		assert_true(expected.has(data.card_name), data.card_name)
		var printing := filter.preferred_printing(data)
		var belongs := false
		for record in CardPacks.entry_records(CardPacks.ID):
			if record["name"] == data.card_name and record["set"] == printing:
				belongs = true
				break
		assert_true(belongs, "%s uses an added Pack 1 printing" % data.card_name)
	filter.completion_pack_on = false
	assert_eq(filter.apply(pool).size(), 0)
	filter.select_all()
	assert_true(filter.original_cards_on)
	assert_eq(filter.apply(pool).size(), 1003)
	filter.original_cards_on = false
	filter.reset()
	assert_true(filter.original_cards_on)
	assert_false(filter.active())

func test_unavailable_pack_has_a_consistent_off_row_without_enabling_it() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	var screen: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._open_extra_sets()
	for id in ["Pack1", "Pack2"]:
		var on := screen.find_child("Extra" + id + "On", true, false) as Button
		var off := screen.find_child("Extra" + id + "Off", true, false) as Button
		assert_not_null(on)
		assert_not_null(off)
		if on == null or off == null:
			return
		assert_true(on.disabled)
		assert_true(off.button_pressed)
		assert_true(on.tooltip_text.contains("Options > Card Packs"))
		on.pressed.emit()
	assert_eq(CardRegistry.size(), 897)
	(screen.find_child("ExtraOriginalOff", true, false) as Button).pressed.emit()
	assert_eq(screen._inventory.entry_count(), 0)
	(screen.find_child("ExtraOriginalOn", true, false) as Button).pressed.emit()
	assert_eq(screen._inventory.entry_count(), 897)

func test_hiding_completion_also_restores_original_set_membership_and_artwork() -> void:
	CardPacks.set_enabled(CardPacks.ID, true)
	var filter := DeckFilter.new()
	var pool: Array[CardData] = []
	for name in CardRegistry.all_names():
		pool.append(CardRegistry.get_card(name))
	for code in CardRegistry.active_set_order():
		filter.sets[code] = code == "4ed"
	assert_eq(filter.apply(pool).size(), 368, "378 printings include repeated basic-land names")
	filter.completion_pack_on = false
	var original_fourth := 0
	for data in pool:
		if data.set_code == "4ed" and not CardRegistry.is_completion_card(data.card_name):
			original_fourth += 1
	assert_eq(filter.apply(pool).size(), original_fourth)
	assert_lt(original_fourth, 368)
	var bolt := CardRegistry.get_card("Lightning Bolt")
	filter.select_all()
	filter.original_1997()
	assert_eq(filter.preferred_printing(bolt), bolt.set_code)
	assert_false(filter.matches_set(CardRegistry.get_card("Chaos Orb")))

func test_hymn_discards_two_random_cards() -> void:
	for name in ["Forest", "Island", "Mountain"]:
		give_hand(1, name)
	var hymn := give_hand(0, "Hymn to Tourach")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, hymn, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1)
	assert_eq(g.players[1].graveyard.size(), 2)

func test_thallid_spends_three_counters_as_a_cost() -> void:
	var thallid := put_battlefield(0, "Thallid")
	g.add_counters(thallid, "spore", 3)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, thallid, 0, []))
	assert_eq(int(thallid.counters.get("spore", 0)), 0)
	assert_ne(g.activate_ability(0, thallid, 0, []), "")
	resolve_stack()
	var tokens := 0
	for inst in g.players[0].battlefield:
		if inst.is_token and inst.data.card_name == "Saproling":
			tokens += 1
			assert_eq(inst.cur_power, 1)
			assert_eq(inst.cur_toughness, 1)
	assert_eq(tokens, 1)

func test_aeolipile_is_sacrificed_before_its_damage_resolves() -> void:
	var bomb := put_battlefield(0, "Aeolipile")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, bomb, 0, [TargetRef.player(1)]))
	assert_eq(bomb.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].life, 18)

func test_javelineers_enter_with_one_ammunition_counter() -> void:
	var soldier := put_battlefield(0, "Icatian Javelineers")
	assert_eq(int(soldier.counters.get("javelin", 0)), 1)

func test_armor_thrull_counter_is_permanent_not_an_end_of_turn_pump() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.add_counters(bear, "+1/+2", 1)
	assert_eq(bear.cur_power, 3)
	assert_eq(bear.cur_toughness, 4)

func test_all_new_cards_are_reachable_through_the_live_extra_filter() -> void:
	var screen: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq(screen._inventory.entry_count(), 999)
	assert_eq(screen._filter_bar.group_buttons("Set Filters").size(), 8)
	screen._open_extra_sets()
	var on := screen.find_child("ExtraPack2On", true, false) as Button
	var off := screen.find_child("ExtraPack2Off", true, false) as Button
	assert_not_null(on)
	assert_not_null(off)
	if on == null or off == null:
		return
	assert_eq(on.text, "", "the tile carries the crown, not lettering over it")
	assert_eq(off.text, "")
	assert_eq(on.get_parent().get_node("Caption").text, "On")
	assert_eq(off.get_parent().get_node("Caption").text, "Off")
	var on_face := on.get_theme_stylebox("pressed") as StyleBoxTexture
	var off_face := on.get_theme_stylebox("normal") as StyleBoxTexture
	assert_not_null(on_face)
	assert_not_null(off_face)
	if on_face != null and off_face != null:
		assert_eq(on_face.texture, GameSkin.our_art("filter_fem_on"))
		assert_eq(off_face.texture, GameSkin.our_art("filter_fem_off"))
	off.pressed.emit()
	assert_eq(screen._inventory.entry_count(), 897)
	on.pressed.emit()
	assert_eq(screen._inventory.entry_count(), 999)
	(screen.find_child("ExtraOriginalOff", true, false) as Button).pressed.emit()
	assert_eq(screen._inventory.entry_count(), 102)
	for entry in screen._inventory._visible_entries():
		assert_true(FallenEmpiresPack.names().has(entry[0].card_name))

func test_fallen_empires_card_preview_wears_the_common_white_crown() -> void:
	var preview := CardPreview.new()
	preview.docked = true
	add_child_autofree(preview)
	preview.size = CardPreview.SIZE
	preview.show_card(CardInstance.new(CardRegistry.get_card("Thallid"), 7, 0))
	await get_tree().process_frame
	assert_eq(preview._set_icon.texture, GameSkin.set_icon("fem", "common"))
	assert_true(preview._set_icon.visible)
	assert_false(preview._set_text.visible, "no FEM text fallback remains")

func test_extras_button_groups_are_centered_on_the_stone_panel() -> void:
	var screen: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._open_extra_sets()
	var rows: Array[HBoxContainer] = []
	for id in ["Original", "Pack1", "Pack2"]:
		var row := screen.find_child("ExtraSourceRow_" + id, true, false) as HBoxContainer
		assert_not_null(row)
		if row == null:
			return
		rows.append(row)
	var dialog := screen.find_child("ExtraSetsDialog", true, false) as OriginalDialog
	assert_not_null(dialog)
	if dialog == null:
		return
	assert_eq(dialog._buttons.get_child_count(), 1)
	assert_eq(dialog._buttons.get_child(0).text, "Close")
	for id in ["Original", "Pack1", "Pack2"]:
		var key: String = {"Original": "source", "Pack1": "pack1", "Pack2": "fem"}[id]
		for state in ["On", "Off"]:
			var tile := screen.find_child("Extra" + id + state, true, false) as Button
			assert_eq(tile.custom_minimum_size, Vector2(48, 48), "square like the set strip")
			assert_eq(tile.text, "97" if id == "Original" else "")
			assert_eq(tile.get_parent().get_node("Caption").text, state)
			assert_eq((tile.get_theme_stylebox("pressed") as StyleBoxTexture).texture,
				GameSkin.our_art("filter_" + key + "_on"))
	for width in [390.0, 480.0]:
		dialog.size.x = width
		for _frame in 3:
			await get_tree().process_frame
		for group in rows + [dialog._buttons]:
			# A visible scrollbar occupies one edge; center each group in
			# its actual content column, and Close in the full footer.
			var middle: float = group.get_global_rect().get_center().x
			var first := group.get_child(0) as Control
			var last := group.get_child(group.get_child_count() - 1) as Control
			var group_middle := (first.get_global_rect().position.x + last.get_global_rect().end.x) * 0.5
			assert_almost_eq(group_middle, middle, 1.0, "%s centered at width %s" % [group.name, width])
			assert_true(dialog.get_global_rect().encloses(group.get_global_rect()), "no panel overflow")
		for column in 3:
			for row in rows:
				assert_almost_eq(row.get_child(column).global_position.x,
					rows[0].get_child(column).global_position.x, 1.0, "matching columns")

func test_warrens_requires_two_goblins_and_pays_before_resolving() -> void:
	var warrens := put_battlefield(0, "Goblin Warrens")
	var first := put_battlefield(0, "Mons's Goblin Raiders")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ne(g.activate_ability(0, warrens, 0), "")
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD)
	var second := put_battlefield(0, "Goblin Balloon Brigade")
	assert_ok(g.activate_ability(0, warrens, 0))
	assert_eq(first.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), 4)

func test_night_soil_cannot_mix_graveyards_but_can_use_opponents() -> void:
	var soil := put_battlefield(0, "Night Soil")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	g.destroy(mine)
	g.destroy(theirs)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ne(g.activate_ability(0, soil, 0), "")
	var second := put_battlefield(1, "Llanowar Elves")
	g.destroy(second)
	assert_ok(g.activate_ability(0, soil, 0))
	assert_eq(theirs.zone, Mtg.Zone.EXILE)
	assert_eq(second.zone, Mtg.Zone.EXILE)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), 2)

func test_hand_of_justice_needs_three_other_white_creatures() -> void:
	var hand := put_battlefield(0, "Hand of Justice")
	var one := put_battlefield(0, "Savannah Lions", true)
	var two := put_battlefield(0, "Savannah Lions", true)
	var victim := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ne(g.activate_ability(0, hand, 0, [TargetRef.card(victim)]), "")
	assert_false(hand.tapped)
	var three := put_battlefield(0, "Savannah Lions", true)
	assert_ok(g.activate_ability(0, hand, 0, [TargetRef.card(victim)]))
	assert_true(hand.tapped and one.tapped and two.tapped and three.tapped)
	resolve_stack()
	assert_eq(victim.zone, Mtg.Zone.GRAVEYARD)

func test_derelor_adds_black_not_generic_and_only_to_own_black_spells() -> void:
	put_battlefield(0, "Derelor")
	var hymn := give_hand(0, "Hymn to Tourach")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ne(g.cast_spell(0, hymn, [TargetRef.player(1)]), "")
	assert_eq(hymn.zone, Mtg.Zone.HAND)
	assert_eq(g.spell_cost_for(1, hymn.data).mana_value(), 2)
	assert_eq(g.spell_cost_for(0, CardRegistry.get_card("Grizzly Bears")).mana_value(), 2)
	add_mana(0, Mtg.ManaColor.B, 1)
	assert_ok(g.cast_spell(0, hymn, [TargetRef.player(1)]))
	resolve_stack()

func test_menace_rejects_a_single_blocker_accepts_two_and_ai_repairs_one() -> void:
	put_battlefield(0, "Goblin War Drums")
	var attacker := put_battlefield(0, "Grizzly Bears")
	var one := put_battlefield(1, "Grizzly Bears")
	var two := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ne(g.declare_blockers(1, {one.id: [attacker.id]}), "")
	var ai := AiPlayer.new(1, AiProfile.wizard())
	var free: Array[CardInstance] = [one, two]
	var repaired := ai._minimum_blockers(g, {one.id: [attacker.id]}, free)
	assert_eq(repaired.size(), 2)
	assert_ok(g.declare_blockers(1, repaired))

func test_menace_does_not_force_an_impossible_lure_block() -> void:
	put_battlefield(0, "Goblin War Drums")
	var attacker := put_battlefield(0, "Grizzly Bears")
	var lure := give_hand(0, "Lure")
	g.attach_aura_from_anywhere(lure, attacker, 0)
	var lone := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var ai := AiPlayer.new(1, AiProfile.wizard())
	var free: Array[CardInstance] = [lone]
	assert_eq(ai._minimum_blockers(g, {lone.id: [attacker.id]}, free), {})
	assert_ok(g.declare_blockers(1, {}))

func test_merseine_charges_host_cost_and_allows_only_hosts_controller() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := give_hand(0, "Merseine")
	g.attach_aura_from_anywhere(aura, bear, 0)
	g.tap_permanent(bear)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(int(aura.counters.get("net", 0)), 3)
	assert_true(bear.cur_skips_untap)
	assert_ne(g.activate_ability(0, aura, 0), "")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(1, aura, 0))
	resolve_stack()
	assert_eq(int(aura.counters.get("net", 0)), 2)
	g.remove_counters(aura, "net", 2)
	assert_false(bear.cur_skips_untap)

func test_soul_exchange_exiles_cost_and_returns_a_thrull_enhanced_creature() -> void:
	var dead := put_battlefield(0, "Grizzly Bears")
	g.destroy(dead)
	var thrull := put_battlefield(0, "Basal Thrull")
	var spell := give_hand(0, "Soul Exchange")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(dead)]))
	assert_eq(thrull.zone, Mtg.Zone.EXILE)
	resolve_stack()
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(dead.cur_power, 4)
	assert_eq(dead.cur_toughness, 4)

func test_war_machine_remembers_tapped_crew_even_if_ability_is_countered() -> void:
	var machine := put_battlefield(0, "Vodalian War Machine")
	var crew := put_battlefield(0, "Merfolk of the Pearl Trident", true)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, machine, 0))
	assert_true(crew.tapped)
	# Destroy it before its permission effect resolves: cost bookkeeping
	# already happened and survives in the dies event's memory snapshot.
	g.destroy(machine)
	resolve_stack()
	assert_eq(crew.zone, Mtg.Zone.GRAVEYARD)

func test_war_machine_can_attack_without_losing_defender() -> void:
	var machine := put_battlefield(0, "Vodalian War Machine")
	put_battlefield(0, "Merfolk of the Pearl Trident", true)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ne(CombatState.attack_illegality(g, machine, 1), "")
	assert_ok(g.activate_ability(0, machine, 0))
	resolve_stack()
	assert_true(machine.has_keyword(Mtg.Keyword.DEFENDER))
	assert_eq(CombatState.attack_illegality(g, machine, 1), "")

func test_war_machine_does_not_destroy_a_returned_crew_member() -> void:
	var machine := put_battlefield(0, "Vodalian War Machine")
	var crew := put_battlefield(0, "Merfolk of the Pearl Trident")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, machine, 0))
	resolve_stack()
	g.return_to_hand(crew)
	g._put_on_battlefield(crew, 0)
	g.destroy(machine)
	resolve_stack()
	assert_eq(crew.zone, Mtg.Zone.BATTLEFIELD)

func test_war_machine_cost_bookkeeping_is_reversible_for_ai_probes() -> void:
	var machine := put_battlefield(0, "Vodalian War Machine")
	var crew := put_battlefield(0, "Merfolk of the Pearl Trident")
	advance_to_step(Mtg.Step.MAIN1)
	var before := machine.memory.duplicate(true)
	var mark := g.make_mark()
	assert_ok(g.activate_ability(0, machine, 1))
	g.unmake_to(mark)
	g.end_search()
	assert_eq(machine.memory, before)
	assert_false(crew.tapped)
	assert_eq(machine.cur_power, 0)

func test_tourachs_gate_taps_only_enchanted_land_and_pumps_current_attackers() -> void:
	var land := put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var bear := put_battlefield(0, "Grizzly Bears")
	var gate := give_hand(0, "Tourach's Gate")
	g.attach_aura_from_anywhere(gate, land, 0)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_ok(g.activate_ability(0, gate, 1))
	assert_true(land.tapped)
	assert_ne(g.activate_ability(0, gate, 1), "")
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	assert_eq(bear.cur_toughness, 1)

func test_thelonite_monk_changes_land_indefinitely() -> void:
	var monk := put_battlefield(0, "Thelonite Monk")
	put_battlefield(0, "Llanowar Elves")
	var island := put_battlefield(1, "Island")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, monk, 0, [TargetRef.card(island)]))
	resolve_stack()
	assert_true(island.cur_subtypes.has("forest"))
	assert_false(island.cur_subtypes.has("island"))
	g.destroy(monk)
	advance_to_next_turn()
	assert_true(island.cur_subtypes.has("forest"))

func test_delifs_cube_prevents_assignment_not_damage_and_gains_a_counter() -> void:
	var cube := put_battlefield(0, "Delif's Cube")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, cube, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	resolve_stack()
	assert_eq(int(cube.counters.get("cube", 0)), 1)
	assert_true(bear.cur_assigns_no_combat_damage)
	assert_false(bear.cur_prevent_combat_damage_dealt)
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[1].life, 20)

func test_farrels_zealot_targets_at_trigger_time_and_replaces_combat_damage() -> void:
	var zealot := put_battlefield(0, "Farrel's Zealot")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [zealot.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_eq(g.stack[-1].targets[0].instance_id, bear.id)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[1].life, 20)

func test_raiding_party_is_not_targetable_by_white_but_not_full_protection() -> void:
	var raid := put_battlefield(0, "Raiding Party")
	var disenchant := give_hand(1, "Disenchant")
	var boomerang := give_hand(1, "Boomerang")
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT)
	assert_false(spec.is_legal(g, TargetRef.card(raid), disenchant))
	assert_true(spec.is_legal(g, TargetRef.card(raid), boomerang))
	assert_eq(raid.cur_protection, 0)

func test_fallen_empires_common_effects_are_visible_to_ai() -> void:
	var thallid := CardRegistry.get_card("Thallid")
	var tokens := EffectIntent.read(thallid.activated_abilities[0].effects, thallid.card_name)
	assert_false(tokens.unknown)
	assert_eq(int(tokens.makes_token.power), 1)
	var hymn := CardRegistry.get_card("Hymn to Tourach")
	assert_eq(EffectIntent.read(hymn.spell_effects, hymn.card_name).discards, 2)
	var ai := AiPlayer.new(0, AiProfile.wizard())
	var soil := put_battlefield(0, "Night Soil")
	assert_false(ai._ability_available(g, soil, 0, true))
	for name in ["Grizzly Bears", "Llanowar Elves"]:
		g.destroy(put_battlefield(1, name))
	assert_true(ai._ability_available(g, soil, 0, true))

func test_tide_reset_is_one_responseable_state_trigger_even_outside_upkeep() -> void:
	var homarid := put_battlefield(0, "Homarid")
	advance_to_step(Mtg.Step.MAIN1)
	g.add_counters(homarid, "tide", 3)
	assert_eq(int(homarid.counters.get("tide", 0)), 4)
	assert_eq(g.stack.size(), 1)
	g.check_state_based_actions()
	assert_eq(g.stack.size(), 1, "a pending state trigger does not duplicate")
	resolve_stack()
	assert_eq(int(homarid.counters.get("tide", 0)), 0)
	assert_eq(homarid.cur_power, 2)

func test_storage_land_banks_counters_and_mana_planner_can_spend_them() -> void:
	var vault := put_battlefield(0, "Bottomless Vault")
	assert_true(vault.tapped)
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ManaPlanner.sources(g, 0).is_empty())
	g.add_counters(vault, "storage", 3)
	g.untap_permanent(vault)
	var cost := ManaCost.parse("{B}{B}{1}")
	var plan := ManaPlanner.plan_from(ManaPlanner.sources(g, 0), cost, 0)
	assert_eq(plan.size(), 1)
	assert_ok(g.tap_for_mana(0, vault))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 3)
	assert_eq(int(vault.counters.get("storage", 0)), 0)

func test_high_tide_bonus_expires_at_cleanup() -> void:
	var island := put_battlefield(0, "Island")
	var tide := give_hand(0, "High Tide")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, tide))
	resolve_stack()
	assert_ok(g.tap_for_mana(0, island))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 2)
	advance_to_next_turn()
	assert_true(g.delayed_triggers.is_empty())

func test_spawning_bed_uses_mana_value_before_sacrifice() -> void:
	var bed := put_battlefield(0, "Homarid Spawning Bed")
	var soldier := put_battlefield(0, "Vodalian Soldiers")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.activate_ability(0, bed, 0))
	assert_eq(soldier.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), 3)

func test_conch_horn_draws_then_returns_one_card_to_library() -> void:
	var horn := put_battlefield(0, "Conch Horn")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	var count := g.players[0].library.size()
	assert_ok(g.activate_ability(0, horn, 0))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1)
	assert_eq(g.players[0].library.size(), count - 1)

func test_flotilla_unpaid_combat_fee_grants_first_strike_to_the_other_creature() -> void:
	var flotilla := put_battlefield(0, "Goblin Flotilla")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [flotilla.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: [flotilla.id]}))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(g.delayed_triggers.is_empty())

func test_mindstab_thrull_sacrifices_to_make_defender_choose_three_discards() -> void:
	var thrull := put_battlefield(0, "Mindstab Thrull")
	for name in ["Island", "Swamp", "Forest"]:
		give_hand(1, name)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [thrull.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	resolve_stack()
	assert_eq(thrull.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[1].hand.is_empty())

func test_thelons_chant_offers_a_counter_instead_of_damage() -> void:
	put_battlefield(0, "Thelon's Chant")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Swamp")
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(int(bear.counters.get("-1/-1", 0)), 1)

func test_orcish_spy_reads_top_to_bottom_without_public_logging() -> void:
	var spy := put_battlefield(0, "Orcish Spy")
	var top := give_hand(1, "Black Lotus")
	g.put_from_hand_on_top_of_library(top)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, spy, 0, [TargetRef.player(1)]))
	resolve_stack()
	var question: PlayerChoice = g.choice_log[-1]
	assert_eq(question.pid, 0)
	assert_string_contains(question.prompt, "top to bottom: Black Lotus, Forest, Forest")
	assert_eq(g.players[1].library[-1], top)

func test_bound_forest_effect_does_not_follow_a_bounced_land_back() -> void:
	var monk := put_battlefield(0, "Thelonite Monk")
	put_battlefield(0, "Llanowar Elves")
	var island := put_battlefield(1, "Island")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, monk, 0, [TargetRef.card(island)]))
	resolve_stack()
	g.return_to_hand(island)
	g._put_on_battlefield(island, 1)
	assert_true(island.cur_subtypes.has("island"))
	assert_false(island.cur_subtypes.has("forest"))

func test_tidal_influence_refuses_a_second_copy_instead_of_erroring() -> void:
	# "Cast this spell only if no permanents named Tidal Influence are on
	# the battlefield." The rider is a cast_condition, which the engine
	# calls as func(game, pid) — a third parameter made every announcement
	# of the card raise a script error and skip the restriction.
	put_battlefield(1, "Tidal Influence")
	var second := give_hand(0, "Tidal Influence")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_refused(g.cast_spell(0, second), "already on the battlefield")
	assert_eq(second.zone, Mtg.Zone.HAND)

func test_tidal_influence_casts_when_no_other_copy_is_out() -> void:
	var first := give_hand(0, "Tidal Influence")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, first))
	resolve_stack()
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(first.counters.get("tide", 0)), 1)

func test_orgg_stays_home_against_a_creature_a_pump_just_made_big() -> void:
	# "Can't attack if the defending player controls an untapped creature
	# with power 3 or greater" is a question ABOUT a power, so every layer
	# that writes one has to be finished before it is asked (CR 613.8,
	# StaticAbility.reading_pt). Until 2026-09-17 the static ran in the
	# anthem pass, a pass ahead of the floating pumps: a Giant-Growthed 2/2
	# was invisible and the Orgg attacked into it.
	var orgg := put_battlefield(0, "Orgg")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.continuous.add_until_eot_pump(bear.id, 1, 1)   # an untapped 3/3
	g.recalculate()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [orgg.id]), "can't attack")

func test_orgg_attacks_past_a_creature_that_stayed_small() -> void:
	var orgg := put_battlefield(0, "Orgg")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [orgg.id]))

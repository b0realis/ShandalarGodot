extends GutTest
## THE HUMAN'S DOUBLE-CLICK AUTO-CAST THROUGH THE SHARED PLANNER (whole-game
## campaign, 2026-10-07 — `DuelScreen._auto_tap_for_pending` runs the plan
## against the cast's own bill). Under a Mana Flare a Hill Giant tapped four
## Mountains, made eight red and left four floating to burn (w1-1); a
## Grizzly Bears tapped the Forest wearing the opponent's Psychic Venom while
## two plain Forests stood untapped (w1-2); a one-drop took the Sol Ring
## beside an untapped Mountain (w6-1).

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func _stage(card_name: String, mine: Array, preset: String) -> CardInstance:
	var g: MtgGame = screen.game
	g.rules.set_preset(preset)
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	g.players[0].hand.clear()
	g.players[0].mana_pool.clear()
	g.players[0].battlefield.clear()
	g.players[1].battlefield.clear()
	screen.mode = DuelScreen.Mode.NORMAL
	var inst := CardInstance.new(CardRegistry.get_card(card_name), 94001, 0)
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[0].hand.append(inst)
	var next := 94010
	for permanent_name in mine:
		var c := CardInstance.new(CardRegistry.get_card(permanent_name), next, 0)
		next += 1
		g._instances[c.id] = c
		g._put_on_battlefield(c, 0)
	g.recalculate()
	screen._refresh()
	return inst


func _tapped(card_name: String) -> int:
	var n := 0
	for p in screen.game.players[0].battlefield:
		if p.data.card_name == card_name and p.tapped:
			n += 1
	return n


func _double_click(inst: CardInstance) -> void:
	screen._on_card_clicked(inst)
	screen._auto_cast(inst)
	await get_tree().process_frame


func _flare_case(preset: String) -> void:
	var giant := _stage("Hill Giant", ["Mana Flare", "Mountain", "Mountain",
		"Mountain", "Mountain"], preset)
	await _double_click(giant)
	assert_ne(giant.zone, Mtg.Zone.HAND, "%s: the Giant was cast" % preset)
	assert_eq(screen.game.players[0].mana_pool.total(), 0, "%s: nothing floats" % preset)
	assert_eq(_tapped("Mountain"), 2, "%s: two Mountains make four red under the Flare" % preset)


func test_double_click_under_mana_flare_taps_only_what_the_spell_needs() -> void:
	await _flare_case("modern_mana_burn")


func test_double_click_under_mana_flare_in_fifth_edition_rules() -> void:
	await _flare_case("fifth")


func test_double_click_spares_the_psychic_venomed_forest() -> void:
	var bears := _stage("Grizzly Bears", ["Forest", "Forest", "Forest"], "modern_mana_burn")
	var g: MtgGame = screen.game
	var cursed: CardInstance = g.players[0].battlefield[0]
	var venom := CardInstance.new(CardRegistry.get_card("Psychic Venom"), 94050, 1)
	g._instances[venom.id] = venom
	g.attach_aura_from_anywhere(venom, cursed, 1)
	screen._refresh()
	await _double_click(bears)
	assert_ne(bears.zone, Mtg.Zone.HAND, "the Bears were cast")
	assert_false(cursed.tapped, "the Venomed Forest is left alone")
	assert_eq(g.players[0].life, 20)


func test_double_click_pays_a_one_drop_with_the_mountain_not_the_sol_ring() -> void:
	var vise := _stage("Black Vise", ["Sol Ring", "Mountain"], "modern_mana_burn")
	await _double_click(vise)
	assert_ne(vise.zone, Mtg.Zone.HAND, "the Vise was cast")
	assert_eq(_tapped("Mountain"), 1)
	assert_eq(_tapped("Sol Ring"), 0)
	assert_eq(screen.game.players[0].mana_pool.total(), 0)

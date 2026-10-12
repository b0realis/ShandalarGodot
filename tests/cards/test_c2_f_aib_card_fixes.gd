extends GameTest
## SMALL CARD FIXES (bug-hunt campaign 2026-10-12, b4-5 / b4-6 / b4-7 / b4-9).
##  * b4-5 The five Ice Age Talismans: the trigger's target is ranked —
##    our own tapped permanents first, the most valuable first — so the
##    heuristic and AI seats no longer aim it at the untapped Talisman.
##  * b4-6 Clairvoyance and Portent borrow Glasses of Urza's and Natural
##    Selection's effects: the look and its log line now name the card
##    that made them.
##  * b4-7 Urza's Bauble shows the card it saw to its activator alone
##    (reveal_information); the public log says only that it looked.
##  * b4-9 The ability menu names every cost: Tornado's life payment at
##    its current velocity, Earthlore's "Tap enchanted land".

class Recorder extends RefCounted:
	var rows: Array = []
	func on_reveal(viewer: int, title: String, names: Array) -> void:
		rows.append({"viewer": viewer, "title": title, "names": names})


func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	CardPacks.set_enabled(AlliancesPack.ID, true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)
	CardPacks.set_enabled(AlliancesPack.ID, false)


# ------------------------------------------------------------ b4-5 Talismans --

func _talisman_trigger(seat_agent: DecisionAgent) -> StackItem:
	if seat_agent != null:
		g.set_agent(0, seat_agent)
	put_battlefield(0, "Hematite Talisman")
	var land := put_battlefield(0, "Mountain")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, land))
	add_mana(0, Mtg.ManaColor.C, 3)
	var bolt := give_hand(0, "Lightning Bolt")
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	var trigger: StackItem = g.stack.back()
	assert_eq(trigger.card.data.card_name, "Hematite Talisman")
	return trigger


func test_talisman_untaps_our_own_tapped_permanent_for_the_ai() -> void:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	var trigger := _talisman_trigger(AiPlayer.new(0, p))
	var aimed := g.find_instance(trigger.targets[0].instance_id)
	assert_true(aimed.tapped and aimed.controller_id == 0,
		"aimed at %s; untapping an untapped permanent is a wasted trigger" % aimed.data.card_name)


func test_talisman_untaps_our_own_tapped_permanent_for_the_heuristic_seat() -> void:
	var trigger := _talisman_trigger(null)
	var aimed := g.find_instance(trigger.targets[0].instance_id)
	assert_true(aimed.tapped and aimed.controller_id == 0, aimed.data.card_name)


func test_talisman_ranks_the_dearer_tapped_permanent_first() -> void:
	put_battlefield(0, "Malachite Talisman")
	var land := put_battlefield(0, "Forest")
	var wurm := put_battlefield(0, "Craw Wurm")
	g.tap_permanent(land)
	g.tap_permanent(wurm)
	var data := CardRegistry.get_card("Malachite Talisman")
	var trigger: TriggeredAbility = data.triggered_abilities[0]
	assert_true(trigger.target_order.is_valid(), "the trigger ranks its targets")
	var source := g.find_on_battlefield(0, "Malachite Talisman")
	var refs: Array = [TargetRef.card(source), TargetRef.card(land), TargetRef.card(wurm)]
	refs.sort_custom(func(a: TargetRef, b: TargetRef) -> bool: return trigger.target_order.call(g, source, a, b))
	assert_eq(refs[0].instance_id, wurm.id, "the tapped Craw Wurm first")
	assert_eq(refs[1].instance_id, land.id, "then the tapped Forest")


# ---------------------------------------------------- b4-6 the borrowed looks --

func test_clairvoyance_names_itself() -> void:
	var rec := Recorder.new()
	g.information_revealed.connect(rec.on_reveal)
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(1, "Hill Giant")
	var c := give_hand(0, "Clairvoyance")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, c, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(rec.rows.size(), 1)
	assert_string_contains(String(rec.rows[0]["title"]), "Clairvoyance")
	assert_eq(int(rec.rows[0]["viewer"]), 0, "shown to its caster")
	for line in g.log_lines:
		assert_false(line.contains("Glasses of Urza"), line)


func test_glasses_of_urza_still_names_itself() -> void:
	var rec := Recorder.new()
	g.information_revealed.connect(rec.on_reveal)
	var glasses := put_battlefield(0, "Glasses of Urza")
	give_hand(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, glasses, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(rec.rows.size(), 1)
	assert_string_contains(String(rec.rows[0]["title"]), "Glasses of Urza")
	assert_true(rec.rows[0]["names"].has("Hill Giant"))


func test_a_look_at_our_own_hand_keeps_it_out_of_the_public_log() -> void:
	var glasses := put_battlefield(0, "Glasses of Urza")
	give_hand(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, glasses, 0, [TargetRef.player(0)]))
	resolve_stack()
	for i in g.log_meta.size():
		var meta: Dictionary = g.log_meta[i]
		var public := String(meta.get("public", g.log_lines[i]))
		assert_false(public.contains("Shivan Dragon"), "the opponent reads: " + public)


func test_portent_names_itself() -> void:
	var rec := Recorder.new()
	g.information_revealed.connect(rec.on_reveal)
	advance_to_step(Mtg.Step.MAIN1)
	var p := give_hand(0, "Portent")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, p, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(rec.rows.size(), 1)
	assert_string_contains(String(rec.rows[0]["title"]), "Portent")
	for line in g.log_lines:
		assert_false(line.contains("Natural Selection"), line)


func test_natural_selection_still_names_itself() -> void:
	var rec := Recorder.new()
	g.information_revealed.connect(rec.on_reveal)
	advance_to_step(Mtg.Step.MAIN1)
	var spell := give_hand(0, "Natural Selection")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(rec.rows.size(), 1)
	assert_string_contains(String(rec.rows[0]["title"]), "Natural Selection")


# ------------------------------------------------------- b4-7 Urza's Bauble --

func _bauble_look(preset: String) -> Recorder:
	g.rules.set_preset(preset)
	var rec := Recorder.new()
	g.information_revealed.connect(rec.on_reveal)
	var bauble := put_battlefield(0, "Urza's Bauble")
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(1, "Hill Giant")
	assert_ok(g.activate_ability(0, bauble, 0, [TargetRef.player(1)]))
	resolve_stack()
	return rec


func test_urzas_bauble_shows_its_activator_alone() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		before_each()
		var rec := _bauble_look(preset)
		for line in g.log_lines:
			assert_false(line.contains("Hill Giant"), "%s public log: %s" % [preset, line])
		assert_eq(rec.rows.size(), 1, "%s: the look is shown" % preset)
		assert_eq(int(rec.rows[0]["viewer"]), 0, "%s: to the activator alone" % preset)
		assert_eq(rec.rows[0]["names"], ["Hill Giant"])
		assert_string_contains(String(rec.rows[0]["title"]), "Urza's Bauble")
		var said := false
		for line in g.log_lines:
			said = said or (line.contains("Urza's Bauble") and line.contains("looks at"))
		assert_true(said, "%s: the public log says a look happened" % preset)
		after_each()


func test_urzas_bauble_at_an_empty_hand_shows_nothing() -> void:
	var rec := Recorder.new()
	g.information_revealed.connect(rec.on_reveal)
	var bauble := put_battlefield(0, "Urza's Bauble")
	advance_to_step(Mtg.Step.MAIN1)
	g.players[1].hand.clear()
	assert_ok(g.activate_ability(0, bauble, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(rec.rows.size(), 0)


# ---------------------------------------------------- b4-9 the costs, named --

func test_tornado_menu_text_names_its_life_payment() -> void:
	var tornado := put_battlefield(0, "Tornado")
	g.recalculate()
	var a: ActivatedAbility = tornado.cur_activated_abilities[0]
	assert_eq(a.life_cost, 0)
	assert_false(a.text.contains("life"), "no counters, no life: " + a.text)
	assert_string_contains(a.text, "Activate only once each turn.")
	g.add_counters(tornado, "velocity", 2)
	g.recalculate()
	a = tornado.cur_activated_abilities[0]
	assert_eq(a.life_cost, 6)
	assert_string_contains(a.text, "Pay 6 life")
	assert_true(a.text.begins_with("{2}{G}, Pay 6 life: "), a.text)
	assert_string_contains(a.text, "Activate only once each turn.")


func test_earthlore_menu_text_names_its_tap_cost() -> void:
	var land := put_battlefield(0, "Forest")
	var lore := give_hand(0, "Earthlore")
	g.attach_aura_from_anywhere(lore, land, 0)
	var a: ActivatedAbility = lore.cur_activated_abilities[0]
	assert_true(a.text.begins_with("Tap enchanted land: "), a.text)
	assert_string_contains(a.text.to_lower(), "blocking creature")

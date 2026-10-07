extends GameTest
## Campaign fix-engine — the 1997 "tapped artifacts stop working" rule
## (manual p.124, RulesOptions.tapped_artifacts_stop) and the statics that
## are ABOUT being tapped (StaticAbility.working_while_tapped).
##
## w4-1: a tapped Basalt Monolith / Mana Vault / Time Vault had its own
##   "doesn't untap during your untap step" suspended with its other
##   statics, so all three untapped for free (Time Vault: an extra turn
##   every turn; Mana Vault never burned).
## w2-1: the "for as long as this artifact remains tapped" bonus of Zelyon
##   Sword, Spirit Shield, Tawnos's Weaponry (and Ashnod's Battle Gear) was
##   switched off by the very tap that starts it.
## w4-4 / w4-7: activating a {T} ability tapped its source without
##   recalculating — Castle's +0/+2 outlived the tap (a damaged creature
##   survived the state-based check) and the 1997 mark stayed stale.

const PACKS := ["pack-2", "pack-3", "pack-4", "pack-5"]


func before_each() -> void:
	for p in PACKS: CardPacks.set_enabled(p, true)
	super()


func after_each() -> void:
	g = null
	for p in PACKS: CardPacks.set_enabled(p, false)


# ------------------------------------------------------------ untap locks --

func test_basalt_monolith_stays_tapped_under_both_presets() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		advance_to_step(Mtg.Step.MAIN1)
		var mono := put_battlefield(0, "Basalt Monolith")
		assert_ok(g.tap_for_mana(0, mono))
		assert_true(mono.cur_skips_untap, "the lock holds while tapped under " + preset)
		advance_to_next_turn()
		advance_to_next_turn()
		assert_eq(g.active_player, 0)
		assert_true(mono.tapped, "Basalt Monolith doesn't untap during its untap step under " + preset)


func test_time_vault_does_not_untap_for_an_endless_chain_under_fifth() -> void:
	g.rules.set_preset("fifth")
	advance_to_step(Mtg.Step.MAIN1)
	var vault := put_battlefield(0, "Time Vault")
	vault.tapped = false
	g.recalculate()
	assert_ok(g.activate_ability(0, vault, 0))
	resolve_stack()
	assert_true(vault.tapped)
	advance_to_next_turn()   # the extra turn
	assert_eq(g.active_player, 0, "precondition: the extra turn is P0's")
	assert_true(vault.tapped, "Time Vault must not untap in the extra turn's untap step")
	assert_refused(g.activate_ability(0, vault, 0), "tapped")


func test_mana_vault_stays_tapped_and_burns_under_fifth() -> void:
	g.rules.set_preset("fifth")
	advance_to_step(Mtg.Step.MAIN1)
	var vault := put_battlefield(0, "Mana Vault")
	vault.tapped = true   # tapped earlier (no floating mana to burn under fifth)
	g.recalculate()
	advance_to_next_turn()
	# P0's next turn: the {4} upkeep offer is declined by the plain agent
	# (it cannot pay anyway), and the draw step's burn lands.
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_true(vault.tapped, "Mana Vault doesn't untap during its untap step (1997 preset too)")
	assert_eq(g.players[0].life, 19, "and so it deals 1 damage at the draw step")


## Every noncreature artifact whose Oracle bans its OWN untap keeps the ban
## while tapped under the 1997 rule — a census, so a card added later with
## the same line and no flag fails here by name.
func test_every_self_untap_lock_survives_the_1997_tap_rule() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	var checked: Array[String] = []
	var broken: Array[String] = []
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		if data == null or not data.is_type(Mtg.CardType.ARTIFACT) \
				or data.is_type(Mtg.CardType.CREATURE):
			continue
		var text := data.oracle_text.to_lower()
		var own_lock := "this artifact doesn't untap during your untap step." in text \
			or ("%s doesn't untap during your untap step." % card_name.to_lower()) in text
		if not own_lock:
			continue
		g = MtgGame.new()
		var filler: Array = []
		for i in 30: filler.append("Forest")
		g.setup(filler, filler, "P0", "P1", 20, 20, 424242)
		g.start(0)
		g.rules.set_preset("fifth")
		var inst := put_battlefield(0, card_name)
		inst.tapped = true
		g.recalculate()
		checked.append(card_name)
		if not inst.cur_skips_untap:
			broken.append(card_name)
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	gut.p("self untap locks checked: %s" % ", ".join(checked))
	assert_true(checked.size() >= 3, "the census found the base pool's three (Basalt Monolith, Mana Vault, Time Vault)")
	assert_eq(broken, [] as Array[String],
		"a tapped artifact's own untap lock must not cease under the 1997 rule")


# ------------------------------------------------- "remains tapped" bonuses --

func _held_bonus(card_name: String, cost: int, preset: String) -> CardInstance:
	before_each()
	g.rules.set_preset(preset)
	advance_to_step(Mtg.Step.MAIN1)
	var artifact := put_battlefield(0, card_name)
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, cost)
	assert_ok(g.activate_ability(0, artifact, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.recalculate()
	assert_true(artifact.tapped, card_name + " is tapped by its own cost")
	return bear


func test_zelyon_sword_and_spirit_shield_work_while_tapped() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		var bear := _held_bonus("Zelyon Sword", 3, preset)
		assert_eq(bear.cur_power, 4, "Zelyon Sword +2/+0 under " + preset)
		bear = _held_bonus("Spirit Shield", 2, preset)
		assert_eq(bear.cur_toughness, 4, "Spirit Shield +0/+2 under " + preset)


func test_tawnos_weaponry_and_battle_gear_work_while_tapped() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		var bear := _held_bonus("Tawnos's Weaponry", 2, preset)
		assert_eq([bear.cur_power, bear.cur_toughness], [3, 3],
			"Tawnos's Weaponry +1/+1 under " + preset)
		bear = _held_bonus("Ashnod's Battle Gear", 2, preset)
		assert_eq(bear.zone, Mtg.Zone.GRAVEYARD,
			"Ashnod's Battle Gear's +2/-2 kills the 2/2 under " + preset)


## The flag is per ABILITY: an artifact with a flagged and an unflagged
## static keeps the first and loses the second while tapped (1997 preset);
## both work under the modern one.
func test_the_flag_exempts_only_the_static_that_carries_it() -> void:
	var data := CardData.new("Two-Faced Relic", "{2}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_relic_lock, "This artifact doesn't untap.") \
			.working_while_tapped()) \
		.static_ability(StaticAbility.new(_relic_anthem, "Creatures you control get +1/+1."))
	for preset in ["modern_mana_burn", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		var relic := put_synthetic(0, data)
		var bear := put_battlefield(0, "Grizzly Bears")
		relic.tapped = true
		g.recalculate()
		assert_true(relic.cur_skips_untap, "the flagged lock works while tapped under " + preset)
		assert_eq(bear.cur_power, 3 if preset != "fifth" else 2,
			"the unflagged anthem ceases only under the 1997 rule (" + preset + ")")
		relic.tapped = false
		g.recalculate()
		assert_eq(bear.cur_power, 3, "untapped, every static works (" + preset + ")")


static func _relic_lock(_game: MtgGame, source: CardInstance) -> void:
	source.cur_skips_untap = true


static func _relic_anthem(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_creature():
			inst.cur_power += 1
			inst.cur_toughness += 1


# ------------------------------------------- a {T} activation recalculates --

func test_a_tap_ability_cost_recalculates_at_once() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Castle")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	g.recalculate()
	assert_eq(sorcerer.cur_toughness, 3, "precondition: Castle makes it 1/3")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(bear)]))
	assert_true(sorcerer.tapped)
	assert_eq(sorcerer.cur_toughness, 1, "tapped, it no longer gets Castle's +0/+2")


func test_a_damaged_creature_tapped_by_its_cost_dies_before_priority() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Castle")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	g.recalculate()
	sorcerer.damage = 2
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(bear)]))
	assert_eq(sorcerer.zone, Mtg.Zone.GRAVEYARD,
		"a 1/1 with 2 damage goes before its controller keeps priority (CR 704.3)")
	assert_eq(g.stack.size(), 1, "its ability is still on the stack")


## w4-7: a {T} activation marks a 1997 artifact suspended at once — no
## stale flag until some later recalculation (Icy Manipulator tapping
## itself turns its own continuous effects off).
func test_a_tap_activation_marks_the_artifact_suspended_at_once() -> void:
	g.rules.set_preset("fifth")
	advance_to_step(Mtg.Step.MAIN1)
	var icy := put_battlefield(0, "Icy Manipulator")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, icy, 0, [TargetRef.card(bear)]))
	assert_true(icy.tapped)
	assert_true(icy.cur_statics_suspended, "manual p.124 applies the moment the cost taps it")

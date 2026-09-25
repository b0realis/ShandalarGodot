extends GameTest
## Portal Second Age joins Pack 6, without replacing the original Portal.

func before_each() -> void:
	CardPacks.set_enabled("pack-6", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func test_second_age_complete_and_original_portal_preserved() -> void:
	assert_eq(CardRegistry.names_in_set("p02").size(), 155)
	assert_eq(CardRegistry.names_in_set("por").size(), 200)
	assert_true(CardRegistry.has_card("Piracy"))
	assert_true(CardRegistry.has_card("Relentless Assault"))
	assert_true(CardRegistry.has_card("Cunning Giant"))
	assert_true(CardRegistry.has_card("Deathcoil Wurm"))
	assert_eq(CardRegistry.size(), 1193)

func test_shared_printings_keep_one_rules_identity() -> void:
	assert_true(CardRegistry.card_in_set("Archangel", "por"))
	assert_true(CardRegistry.card_in_set("Archangel", "p02"))
	assert_eq(CardPrintings.choices("Forest").filter(func(row: Dictionary) -> bool: return row.set == "p02").size(), 3)

func cast(name: String, targets: Array = [], pid := 0, x := 0) -> CardInstance:
	var c := give_hand(pid, name)
	for color in Mtg.WUBRG: add_mana(pid, color, 20)
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.cast_spell(pid, c, targets, x))
	resolve_stack()
	return c

func test_enter_life_draw_discard_and_sacrifice_families() -> void:
	cast("Temple Acolyte")
	cast("Angel of Mercy")
	assert_eq(g.players[0].life, 26)
	cast("Vampiric Spirit")
	assert_eq(g.players[0].life, 22)
	var land := put_battlefield(0, "Swamp")
	cast("Foul Spirit")
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	var food := give_hand(0, "Bear Cub")
	var horror := cast("Hidden Horror")
	assert_eq(food.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(horror.zone, Mtg.Zone.BATTLEFIELD)
	var hand := g.players[0].hand.size()
	cast("Screeching Drake")
	assert_eq(g.players[0].hand.size(), hand)
	var enemy := give_hand(1, "Goblin Piker")
	cast("Ravenous Rats")
	assert_eq(enemy.zone, Mtg.Zone.GRAVEYARD)

func test_exact_two_targets_and_partial_fizzle() -> void:
	var a := put_battlefield(1, "Hill Giant")
	var b := put_battlefield(1, "Grizzly Bears")
	var jagged := give_hand(0, "Jagged Lightning")
	add_mana(0, Mtg.ManaColor.R, 10)
	assert_refused(g.cast_spell(0, jagged, [TargetRef.card(a)]))
	assert_refused(g.cast_spell(0, jagged, [TargetRef.card(a), TargetRef.card(a)]))
	assert_ok(g.cast_spell(0, jagged, [TargetRef.card(a), TargetRef.card(b)]))
	g.return_to_hand(b)
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.HAND)

func test_sea_drake_needs_two_lands_not_one_and_keeps_trigger_targets() -> void:
	var land := put_battlefield(0, "Island")
	cast("Sea Drake")
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "No legal two-target trigger with one land")
	var other := put_battlefield(0, "Island")
	cast("Sea Drake")
	assert_eq(land.zone, Mtg.Zone.HAND)
	assert_eq(other.zone, Mtg.Zone.HAND)

func test_edict_sacrifice_ignores_shroud_and_regeneration() -> void:
	var body := put_battlefield(1, "Will-o'-the-Wisp")
	RegenerateEffect.new().resolve(g, body, 1, null)
	cast("Cruel Edict", [TargetRef.player(1)])
	assert_eq(body.zone, Mtg.Zone.GRAVEYARD)

func test_righteous_fury_counts_only_actually_destroyed_creatures() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Will-o'-the-Wisp")
	var standing := put_battlefield(1, "Hill Giant")
	g.tap_permanent(a)
	g.tap_permanent(b)
	RegenerateEffect.new().resolve(g, b, 1, null)
	cast("Righteous Fury")
	assert_eq(g.players[0].life, 22)
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(standing.zone, Mtg.Zone.BATTLEFIELD)

func test_rain_of_daggers_only_destroys_opponents_and_counts_regeneration() -> void:
	var own := put_battlefield(0, "Bear Cub")
	var enemy := put_battlefield(1, "Grizzly Bears")
	var wisp := put_battlefield(1, "Will-o'-the-Wisp")
	RegenerateEffect.new().resolve(g, wisp, 1, null)
	cast("Rain of Daggers", [TargetRef.player(1)])
	assert_eq(g.players[0].life, 18)
	assert_eq(own.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(enemy.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wisp.zone, Mtg.Zone.BATTLEFIELD)

func test_public_dynamic_power_recalculates_with_pumps() -> void:
	var sorceress := put_battlefield(0, "Dakmor Sorceress")
	put_battlefield(0, "Badlands")
	put_battlefield(0, "Swamp")
	assert_eq(sorceress.cur_power, 2)
	cast("Giant Growth", [TargetRef.card(sorceress)])
	assert_eq(sorceress.cur_power, 5)
	var rats := put_battlefield(0, "Swarm of Rats")
	put_battlefield(0, "Ravenous Rats")
	assert_eq(rats.cur_power, 2)
	var engine := put_battlefield(0, "Nightstalker Engine")
	g.destroy(rats)
	resolve_stack()
	assert_eq(engine.cur_power, 1)
	var yeti := put_battlefield(0, "Sylvan Yeti")
	give_hand(0, "Forest")
	g.recalculate()
	assert_eq(yeti.cur_power, g.players[0].hand.size())

func test_return_nightstalkers_then_destroy_swamps() -> void:
	var stalker := put_battlefield(0, "Lurking Nightstalker")
	var other := put_battlefield(0, "Bear Cub")
	g.destroy(stalker)
	g.destroy(other)
	var dual := put_battlefield(0, "Badlands")
	var enemy := put_battlefield(1, "Swamp")
	cast("Return of the Nightstalkers")
	assert_eq(stalker.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(other.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(dual.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(enemy.zone, Mtg.Zone.BATTLEFIELD)

func test_salvage_and_renewing_touch_use_library_not_hand() -> void:
	var a := put_battlefield(0, "Bear Cub")
	var b := put_battlefield(0, "Norwood Ranger")
	g.destroy(a)
	g.destroy(b)
	cast("Renewing Touch", [TargetRef.card(a), TargetRef.card(b)])
	assert_eq(a.zone, Mtg.Zone.LIBRARY)
	assert_eq(b.zone, Mtg.Zone.LIBRARY)
	var land := put_battlefield(0, "Forest")
	g.destroy(land)
	cast("Salvage", [TargetRef.card(land)])
	assert_eq(g.players[0].library.back(), land)

func test_wildfire_sacrifices_four_or_as_many_as_possible_before_damage() -> void:
	for n in 5: put_battlefield(0, "Mountain")
	for n in 2: put_battlefield(1, "Forest")
	var small := put_battlefield(1, "Hill Giant")
	var large := put_battlefield(0, "Force of Nature")
	cast("Wildfire")
	assert_eq(g.players[0].battlefield.filter(func(i: CardInstance) -> bool: return i.is_land()).size(), 1)
	assert_eq(g.players[1].battlefield.size(), 0)
	assert_eq(small.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(large.damage, 4)

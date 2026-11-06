extends GameTest
## Pack 10 (the Urza block), batch B9: Urza's Legacy's five creature lands
## (cards/sets/ulg/_lands_mana.gd) — Faerie Conclave, Forbidding Watchtower,
## Ghitu Encampment, Spawning Pool, Treetop Village. Each enters tapped,
## taps for its colour, and for {1}+its colour becomes a coloured creature
## of its type until end of turn, still a land; Spawning Pool's Skeleton
## gains "{B}: Regenerate this creature" for that turn only.

## [name, colour, power, toughness, subtype, keywords]
const LANDS := [
	["Faerie Conclave", Mtg.ManaColor.U, 2, 1, "faerie", [Mtg.Keyword.FLYING]],
	["Forbidding Watchtower", Mtg.ManaColor.W, 1, 5, "soldier", []],
	["Ghitu Encampment", Mtg.ManaColor.R, 2, 1, "warrior", [Mtg.Keyword.FIRST_STRIKE]],
	["Spawning Pool", Mtg.ManaColor.B, 1, 1, "skeleton", []],
	["Treetop Village", Mtg.ManaColor.G, 3, 3, "ape", [Mtg.Keyword.TRAMPLE]],
]


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

## [param card_name] on [param pid]'s battlefield, untapped and not sick
## (put_battlefield honours "enters tapped").
func ready_land(pid: int, card_name: String) -> CardInstance:
	var land := put_battlefield(pid, card_name)
	land.tapped = false
	return land


func test_claimed_cards_are_no_longer_pending() -> void:
	for row in LANDS:
		var c := CardRegistry.get_card(String(row[0]))
		assert_not_null(c, row[0])
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", row[0])


func test_each_enters_tapped_and_taps_for_its_color() -> void:
	for row in LANDS:
		before_each()
		var land := give_hand(0, String(row[0]))
		assert_ok(g.play_land(0, land))
		assert_true(land.tapped, "%s enters tapped" % row[0])
		land.tapped = false
		assert_ok(g.tap_for_mana(0, land))
		assert_eq(g.players[0].mana_pool.amount_of(int(row[1])), 1, row[0])
		assert_false(land.is_creature(), row[0])

func test_each_becomes_its_creature_until_end_of_turn() -> void:
	for row in LANDS:
		before_each()
		var land := ready_land(0, String(row[0]))
		add_mana(0, int(row[1]))
		add_mana(0, Mtg.ManaColor.C)
		assert_ok(g.activate_ability(0, land, 0))
		resolve_stack()
		var name := String(row[0])
		assert_true(land.is_creature(), name)
		assert_true(land.is_land(), "%s: it's still a land" % name)
		assert_eq([land.cur_power, land.cur_toughness], [int(row[2]), int(row[3])], name)
		assert_eq(land.cur_colors, int(row[1]), "%s: its colour" % name)
		assert_true(land.has_subtype(String(row[4])), name)
		for keyword in row[5]:
			assert_true(land.has_keyword(int(keyword)), name)
		assert_ok(g.tap_for_mana(0, land))   # a creature not sick: it may tap for mana
		assert_eq(g.players[0].mana_pool.amount_of(int(row[1])), 1, name)
		advance_to_next_turn()
		assert_false(land.is_creature(), "%s: until end of turn" % name)
		assert_eq(land.cur_colors, 0, "%s: colorless again" % name)
		for keyword in row[5]:
			assert_false(land.has_keyword(int(keyword)), name)

func test_an_animation_needs_its_colored_mana() -> void:
	var village := ready_land(0, "Treetop Village")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, village, 0))

func test_a_land_played_this_turn_animates_but_cannot_attack() -> void:
	var village := give_hand(0, "Treetop Village")
	assert_ok(g.play_land(0, village))
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, village, 0))
	resolve_stack()
	village.tapped = false
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [village.id]))

func test_treetop_village_attacks_with_trample() -> void:
	var village := ready_land(0, "Treetop Village")
	var bears := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, village, 0))
	resolve_stack()
	run_combat([village.id], {bears.id: village.id})
	assert_eq(g.players[1].life, 19, "one tramples over the 2/2")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)

func test_spawning_pool_skeleton_regenerates_only_while_animated() -> void:
	var pool := ready_land(0, "Spawning Pool")
	var abilities_before := pool.cur_activated_abilities.size()
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, pool, 0))
	resolve_stack()
	assert_eq(pool.cur_activated_abilities.size(), abilities_before + 1, "\"{B}: Regenerate this creature\"")
	var regen := abilities_before
	assert_ok(g.activate_ability(0, pool, regen))
	resolve_stack()
	assert_eq(pool.regeneration_shields, 1)
	g.destroy(pool)
	assert_eq(pool.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	advance_to_next_turn()
	assert_eq(pool.cur_activated_abilities.size(), abilities_before, "the grant ended with the turn")
	assert_false(pool.is_creature())

func test_forbidding_watchtower_blocks_as_a_one_five() -> void:
	var tower := ready_land(1, "Forbidding Watchtower")
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, tower, 0))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {tower.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(tower.zone, Mtg.Zone.BATTLEFIELD, "3 damage to a 1/5")
	assert_eq(tower.damage, 3)

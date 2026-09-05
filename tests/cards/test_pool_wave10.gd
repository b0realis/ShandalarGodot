extends GameTest
## Wave-10 tests: walls & their killers (Wall of Fire/Water/Brambles,
## Living Wall, Tunnel, Dwarven Demolition Team), the regenerator suite
## (Will-o'-the-Wisp, Sedge Troll), targeted removal (Ice Storm, Northern
## Paladin), forestwalk (Shanodin Dryads) and reanimation to the
## battlefield (Resurrection).


# ---------------------------------------------------------------- Ice Storm --

func test_ice_storm_destroys_a_land() -> void:
	var swamp := put_battlefield(1, "Swamp")
	var storm := give_hand(0, "Ice Storm")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, storm, [TargetRef.card(swamp)]))
	resolve_stack()
	assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD)


func test_ice_storm_refuses_creatures() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var storm := give_hand(0, "Ice Storm")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, storm, [TargetRef.card(bear)]), "Illegal target")


# ------------------------------------------------------------------- Tunnel --

func test_tunnel_kills_walls_through_regeneration() -> void:
	var wall := put_battlefield(1, "Wall of Brambles")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, wall, 0, []))
	resolve_stack()
	assert_eq(wall.regeneration_shields, 1)
	var tunnel := give_hand(0, "Tunnel")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, tunnel, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "can't be regenerated")


func test_tunnel_refuses_non_walls() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var tunnel := give_hand(0, "Tunnel")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, tunnel, [TargetRef.card(bear)]), "Illegal target")


# ------------------------------------------------- Dwarven Demolition Team --

func test_demolition_team_wrecks_a_wall() -> void:
	var dwarves := put_battlefield(0, "Dwarven Demolition Team")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, dwarves, 0, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)
	assert_true(dwarves.tapped)


func test_demolition_team_refuses_non_walls() -> void:
	var dwarves := put_battlefield(0, "Dwarven Demolition Team")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, dwarves, 0, [TargetRef.card(bear)]),
		"Illegal target")


# --------------------------------------------------------- Northern Paladin --

func test_northern_paladin_smites_black_permanents() -> void:
	var paladin := put_battlefield(0, "Northern Paladin")
	var zombies := put_battlefield(1, "Scathe Zombies")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.activate_ability(0, paladin, 0, [TargetRef.card(zombies)]))
	resolve_stack()
	assert_eq(zombies.zone, Mtg.Zone.GRAVEYARD)


func test_northern_paladin_refuses_nonblack() -> void:
	var paladin := put_battlefield(0, "Northern Paladin")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_refused(g.activate_ability(0, paladin, 0, [TargetRef.card(bear)]),
		"Illegal target")


# --------------------------------------------------------- pumpable walls --

func test_wall_of_fire_breathes() -> void:
	var wall := put_battlefield(0, "Wall of Fire")
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, wall, 0, []))
	assert_ok(g.activate_ability(0, wall, 0, []))
	resolve_stack()
	assert_eq(wall.cur_power, 2, "0 + two pumps")
	assert_eq(wall.cur_toughness, 5)


func test_wall_of_water_breathes() -> void:
	var wall := put_battlefield(0, "Wall of Water")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, wall, 0, []))
	resolve_stack()
	assert_eq(wall.cur_power, 1)


# ------------------------------------------------------------- regenerators --

func test_living_wall_regenerates_for_generic() -> void:
	var wall := put_battlefield(0, "Living Wall")
	assert_true(wall.is_type(Mtg.CardType.ARTIFACT), "artifact creature")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)   # generic {1} payable with any color
	assert_ok(g.activate_ability(0, wall, 0, []))
	resolve_stack()
	g.destroy(wall, true)
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(wall.tapped)


func test_will_o_the_wisp_regenerates() -> void:
	var wisp := put_battlefield(0, "Will-o'-the-Wisp")
	assert_true(wisp.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(wisp.cur_toughness, 1)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, wisp, 0, []))
	resolve_stack()
	g.destroy(wisp, true)
	assert_eq(wisp.zone, Mtg.Zone.BATTLEFIELD)


# -------------------------------------------------------------- Sedge Troll --

func test_sedge_troll_grows_with_a_swamp() -> void:
	var troll := put_battlefield(0, "Sedge Troll")
	assert_eq(troll.cur_power, 2, "no swamp yet")
	put_battlefield(1, "Swamp")
	assert_eq(troll.cur_power, 2, "the OPPONENT's swamp doesn't count")
	var mine := put_battlefield(0, "Swamp")
	assert_eq(troll.cur_power, 3, "+1/+1 while you control a Swamp")
	assert_eq(troll.cur_toughness, 3)
	g.destroy(mine, false)
	assert_eq(troll.cur_power, 2, "bonus leaves with the swamp")


func test_sedge_troll_regenerates_for_black() -> void:
	var troll := put_battlefield(0, "Sedge Troll")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, troll, 0, []))
	resolve_stack()
	g.destroy(troll, true)
	assert_eq(troll.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------- Shanodin Dryads --

func test_shanodin_dryads_forestwalk() -> void:
	var dryads := put_battlefield(0, "Shanodin Dryads")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [dryads.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: dryads.id}), "walk")


# ------------------------------------------------------------- Resurrection --

func test_resurrection_raises_your_own_dead() -> void:
	var angel := put_battlefield(0, "Serra Angel")
	g.destroy(angel, false)
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)
	var res := give_hand(0, "Resurrection")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, res, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(angel.controller_id, 0)
	assert_true(angel.summoning_sick, "entered the battlefield this turn")


func test_resurrection_cannot_reach_the_enemy_graveyard() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(bear, false)
	var res := give_hand(0, "Resurrection")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, res, [TargetRef.card(bear)]), "Illegal target")

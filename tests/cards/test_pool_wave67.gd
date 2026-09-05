extends GameTest
## Wave-67 tests: the one-off cards that each taught the engine a small
## shared piece — countering an ACTIVATED ABILITY (Rust, Ayesha Tanaka), an
## exile-from-graveyard COST (Necropolis), a player-target predicate (Fire
## and Brimstone), unpreventable damage (Whippoorwill), a discard trigger
## from HAND (Psychic Purge), and ATTACK COSTS (Brainwash). Giant Slug rides
## on card-local memory and the existing landwalk grant.


## Refuses every yes/no (declines Ayesha Tanaka's ransom).
class Skinflint extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return false


## Picks an OPTION by its label.
class Chooser extends DecisionAgent:
	var says := ""

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			options: Array[String], hint: int) -> int:
		var i := options.find(says)
		return i if i >= 0 else hint


func test_registry_loaded_wave67() -> void:
	for name in ["Rust", "Ayesha Tanaka", "Necropolis", "Fire and Brimstone",
			"Whippoorwill", "Psychic Purge", "Brainwash", "Giant Slug"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ---------------------------------------------------------------- Rust --

func _icy_freeze() -> Array:
	# An Icy Manipulator activation waiting on the stack, and the bear it
	# is aimed at.
	var icy := put_battlefield(0, "Icy Manipulator")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, icy, 0, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))   # p1 now holds priority over the ability
	return [icy, bear]


func test_rust_counters_an_artifact_ability() -> void:
	var pair := _icy_freeze()
	var bear: CardInstance = pair[1]
	var rust := give_hand(1, "Rust")
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, rust, [TargetRef.ability(g.stack[0])]))
	resolve_stack()
	assert_false(bear.tapped, "the freeze never resolved")


func test_rust_cannot_target_a_creatures_ability() -> void:
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	var rust := give_hand(1, "Rust")
	add_mana(1, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(1, rust, [TargetRef.ability(g.stack[0])]),
		"Illegal target")


func test_rust_fizzles_if_the_ability_already_resolved() -> void:
	var pair := _icy_freeze()
	var bear: CardInstance = pair[1]
	var target := TargetRef.ability(g.stack[0])
	var rust := give_hand(1, "Rust")
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, rust, [target]))
	# Rust is on top, so it resolves first — but pull the ability out from
	# under it to prove the fizzle path.
	g.counter_ability(target.ability_id)
	resolve_stack()
	assert_false(bear.tapped)
	assert_eq(rust.zone, Mtg.Zone.GRAVEYARD)


# -------------------------------------------------------- Ayesha Tanaka --

func test_ayesha_counters_unless_the_ransom_is_paid() -> void:
	g.set_agent(0, Skinflint.new())    # the Icy's controller won't pay
	var pair := _icy_freeze()
	var bear: CardInstance = pair[1]
	var ayesha := put_battlefield(1, "Ayesha Tanaka")
	assert_ok(g.activate_ability(1, ayesha, 0, [TargetRef.ability(g.stack[0])]))
	resolve_stack()
	assert_false(bear.tapped, "the ransom was declined")


func test_ayesha_lets_the_ability_through_when_paid() -> void:
	var pair := _icy_freeze()
	var bear: CardInstance = pair[1]
	put_battlefield(0, "Plains")        # something to pay the {W} with
	var ayesha := put_battlefield(1, "Ayesha Tanaka")
	assert_ok(g.activate_ability(1, ayesha, 0, [TargetRef.ability(g.stack[0])]))
	resolve_stack()
	assert_true(bear.tapped, "the {W} was paid, so the freeze resolved")


func test_ayesha_has_banding() -> void:
	var ayesha := put_battlefield(0, "Ayesha Tanaka")
	assert_true(ayesha.has_keyword(Mtg.Keyword.BANDING))


# ----------------------------------------------------------- Necropolis --

func _bury(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.players[pid].hand.erase(inst)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


func test_necropolis_grows_by_the_exiled_cards_mana_value() -> void:
	var wall := put_battlefield(0, "Necropolis")
	var angel := _bury(0, "Serra Angel")   # {3}{W}{W} = 5
	assert_ok(g.activate_ability(0, wall, 0))
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.EXILE, "the corpse is exiled as a COST")
	assert_eq(wall.cur_toughness, 6, "0/1 plus five +0/+1 counters")
	assert_eq(wall.cur_power, 0)


func test_necropolis_is_refused_with_no_creature_card() -> void:
	var wall := put_battlefield(0, "Necropolis")
	_bury(0, "Lightning Bolt")
	assert_refused(g.activate_ability(0, wall, 0), "graveyard")


func test_necropolis_cannot_eat_the_same_corpse_twice() -> void:
	var wall := put_battlefield(0, "Necropolis")
	_bury(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, wall, 0))
	assert_refused(g.activate_ability(0, wall, 0), "graveyard")
	resolve_stack()
	assert_eq(wall.cur_toughness, 3, "one bear, mana value 2")


func test_necropolis_has_defender() -> void:
	var wall := put_battlefield(0, "Necropolis")
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))


# ---------------------------------------------------- Fire and Brimstone --

func test_fire_and_brimstone_needs_a_player_who_attacked() -> void:
	var bolt := give_hand(0, "Fire and Brimstone")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]), "Illegal target")


func test_fire_and_brimstone_burns_the_attacker_and_you() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()                    # p1's turn
	run_combat([bear.id])
	assert_true(g.players[1].attacked_this_turn)
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.pass_priority(1))   # p0 takes priority in p1's main phase
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	var bolt := give_hand(0, "Fire and Brimstone")
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20 - 4)
	assert_eq(g.players[0].life, 20 - 2 - 4, "the bear got in, then 4 to you")


# --------------------------------------------------------- Whippoorwill --

func test_whippoorwill_stops_regeneration_and_exiles_the_body() -> void:
	var bird := put_battlefield(0, "Whippoorwill")
	var troll := put_battlefield(1, "Uthden Troll")
	troll.regeneration_shields = 1
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, bird, 0, [TargetRef.card(troll)]))
	resolve_stack()
	assert_true(troll.regeneration_banned_this_turn)
	g.destroy(troll)
	assert_eq(troll.zone, Mtg.Zone.EXILE, "no regeneration, and exiled")


func test_whippoorwill_makes_damage_unpreventable() -> void:
	var bird := put_battlefield(0, "Whippoorwill")
	var bear := put_battlefield(1, "Grizzly Bears")
	bear.prevention = 5                       # a Samite Healer's shield
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, bird, 0, [TargetRef.card(bear)]))
	resolve_stack()
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE, "3 damage got through, and it was exiled")


# -------------------------------------------------------- Psychic Purge --

func test_psychic_purge_burns_the_discarder() -> void:
	var purge := give_hand(1, "Psychic Purge")
	var scepter := put_battlefield(0, "Disrupting Scepter")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, scepter, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(purge.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 15, "the discarder loses 5 life")


func test_psychic_purge_is_free_when_you_discard_it_yourself() -> void:
	give_hand(0, "Psychic Purge")
	var tome := put_battlefield(0, "Jalum Tome")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tome, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "your own ability costs you nothing")


func test_psychic_purge_still_deals_its_damage() -> void:
	var purge := give_hand(0, "Psychic Purge")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, purge, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)


# ------------------------------------------------------------ Brainwash --

func test_brainwash_taxes_the_attack() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := give_hand(0, "Brainwash")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_next_turn()                    # p1's turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, [bear.id]), "pays {3}")


func test_brainwash_lets_a_paid_attack_through() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := give_hand(0, "Brainwash")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	for _i in 3:
		put_battlefield(1, "Forest")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id]))
	assert_true(g.combat.attackers.has(bear.id))


# ---------------------------------------------------------- Giant Slug --

func test_giant_slug_gains_landwalk_at_your_next_upkeep() -> void:
	var agent := Chooser.new()
	agent.says = "Island"
	g.set_agent(0, agent)
	var slug := put_battlefield(0, "Giant Slug")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, slug, 0))
	resolve_stack()
	assert_eq(slug.cur_landwalk.size(), 0, "nothing happens this turn")
	advance_to_next_turn()
	advance_to_next_turn()                    # p0's next upkeep has passed
	assert_true(slug.cur_landwalk.has("island"))


func test_giant_slug_landwalk_lasts_only_that_turn() -> void:
	var slug := put_battlefield(0, "Giant Slug")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, slug, 0))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(slug.cur_landwalk.size(), 1)
	advance_to_next_turn()
	assert_eq(slug.cur_landwalk.size(), 0, "until the end of THAT turn")

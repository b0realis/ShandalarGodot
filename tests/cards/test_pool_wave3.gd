extends GameTest
## Behavior tests for wave 3: multi-block, banding, tribal lords with live
## landwalk grants, untap locks, attack restrictions, upkeep punishers,
## milling, and full graveyard recursion.


# -------------------------------------------------------------- multi-block --

func test_two_blockers_gang_a_big_attacker() -> void:
	# Craw Wurm (6/4, ground — a flyer would refuse the bears, as the
	# engine reminded this test's first draft) double-blocked by two
	# Grizzly Bears: the wurm assigns lethal-first 2+2 (both bears die,
	# 2 wasted — no trample); the bears' combined 4 kills the 6/4.
	var wurm := put_battlefield(0, "Craw Wurm")
	var bear1 := put_battlefield(1, "Grizzly Bears")
	var bear2 := put_battlefield(1, "Grizzly Bears")
	run_combat([wurm.id], {bear1.id: wurm.id, bear2.id: wurm.id})
	assert_eq(bear1.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear2.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "2+2 combined kills the 6/4")
	assert_eq(g.players[1].life, 20, "no trample: the extra 2 is wasted")


func test_lethal_first_split_leaves_no_overkill() -> void:
	# Mammoth (3/3) gang-blocked by two Savannah Lions (2/1 each): lethal-
	# first assigns 1+1 (not 3+0), killing both, wasting the third point
	# (no trample on... wait, War Mammoth HAS trample: excess 1 tramples).
	var mammoth := put_battlefield(0, "War Mammoth")
	var lions1 := put_battlefield(1, "Savannah Lions")
	var lions2 := put_battlefield(1, "Savannah Lions")
	run_combat([mammoth.id], {lions1.id: mammoth.id, lions2.id: mammoth.id})
	assert_eq(lions1.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(lions2.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 19, "1+1 lethal, 1 tramples through")
	assert_eq(mammoth.zone, Mtg.Zone.GRAVEYARD, "2+2 lions' power kills the 3/3")


# ------------------------------------------------------------------ banding --

func test_band_is_blocked_as_a_group() -> void:
	# Benalish Hero bands with Grizzly Bears; Serra (4/4) blocks the BEAR.
	# The whole band fights her: 1+2 power vs her 4 toughness (she lives),
	# her 4 damage spreads lethal-first across the band in band order —
	# hero (1) dies, bears take the rest and die too (2 toughness, 3 left).
	var hero := put_battlefield(0, "Benalish Hero")
	var bears := put_battlefield(0, "Grizzly Bears")
	var serra := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hero.id, bears.id], [[hero.id, bears.id]]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {serra.id: bears.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(hero.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(serra.damage, 3, "the whole band's power hit the blocker")
	assert_eq(g.players[1].life, 20, "blocked band deals no player damage")


func test_band_needs_banding_members() -> void:
	# Two non-banding creatures can't form a band (CR 702.22c).
	var bears := put_battlefield(0, "Grizzly Bears")
	var lions := put_battlefield(0, "Savannah Lions")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(
		g.declare_attackers(0, [bears.id, lions.id], [[bears.id, lions.id]]),
		"banding")


func test_unblocked_band_all_connect() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var pegasus := put_battlefield(0, "Mesa Pegasus")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hero.id, pegasus.id], [[hero.id, pegasus.id]]))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18, "1 + 1 unblocked band damage")


# ------------------------------------------------------------ tribal lords --

func test_lord_of_atlantis_pumps_others_not_itself() -> void:
	var lord := put_battlefield(0, "Lord of Atlantis")
	var merfolk := put_battlefield(0, "Merfolk of the Pearl Trident")
	assert_eq(merfolk.cur_power, 2, "1/1 + lord")
	assert_eq(lord.cur_power, 2, "the lord doesn't pump itself")
	assert_true(merfolk.cur_landwalk.has("island"), "granted islandwalk")


func test_granted_islandwalk_works_in_combat() -> void:
	put_battlefield(0, "Lord of Atlantis")
	var merfolk := put_battlefield(0, "Merfolk of the Pearl Trident")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Island")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [merfolk.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: merfolk.id}), "islandwalk")


func test_goblin_kings_pump_each_other() -> void:
	var king1 := put_battlefield(0, "Goblin King")
	var king2 := put_battlefield(0, "Goblin King")
	assert_eq(king1.cur_power, 3, "each king is an 'other Goblin' to the other")
	assert_eq(king2.cur_power, 3)


# ------------------------------------------------- Meekstone & Sea Serpent --

func test_meekstone_locks_big_attackers_tapped() -> void:
	put_battlefield(1, "Meekstone")
	var serra := put_battlefield(0, "Serra Angel")     # vigilance — never taps
	var mammoth := put_battlefield(0, "War Mammoth")   # 3 power — locks
	run_combat([serra.id, mammoth.id])
	assert_true(mammoth.tapped)
	advance_to_next_turn()
	advance_to_next_turn()   # back to P0 — their untap step has passed
	assert_true(mammoth.tapped, "Meekstone holds the 3-power creature tapped")
	assert_false(serra.tapped, "vigilance never tapped to begin with")


func test_sea_serpent_needs_the_defender_islandbound() -> void:
	# Its own "when you control no Islands, sacrifice this" fires as a
	# state-based action the moment anyone would get priority, so the
	# Serpent's controller needs one of their own to keep it alive.
	put_battlefield(0, "Island")
	var serpent := put_battlefield(0, "Sea Serpent")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [serpent.id]), "Island")
	put_battlefield(1, "Island")
	assert_ok(g.declare_attackers(0, [serpent.id]))


# --------------------------------------------------------- upkeep punishers --

func test_karma_burns_swamp_controllers() -> void:
	put_battlefield(0, "Karma")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	advance_to_next_turn()   # into P1's turn — upkeep trigger fires en route
	resolve_stack()
	assert_eq(g.players[1].life, 18, "2 swamps = 2 damage at their upkeep")


func test_black_vise_and_ivory_tower_read_hand_size() -> void:
	put_battlefield(0, "Black Vise")
	put_battlefield(1, "Ivory Tower")
	for _i in 6:
		give_hand(1, "Forest")
	advance_to_next_turn()   # P1's upkeep: Vise (6-4=2 dmg), Tower (+2 life)
	resolve_stack()
	assert_eq(g.players[1].life, 20, "Vise's 2 damage and Tower's 2 gain cancel out")


func test_the_rack_squeezes_an_empty_hand() -> void:
	put_battlefield(0, "The Rack")
	advance_to_next_turn()   # P1 upkeep with 0 cards (draws after upkeep)
	resolve_stack()
	assert_eq(g.players[1].life, 17, "3 - 0 cards = 3 damage")


# ----------------------------------------------------- mill & recursion --

func test_millstone_grinds_and_drawing_out_loses() -> void:
	var stone := put_battlefield(0, "Millstone")
	g.players[1].library.resize(3)   # test surgery: tiny library
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, stone, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].library.size(), 1)
	assert_eq(g.players[1].graveyard.size(), 2)
	assert_false(g.game_over, "milling out is not a loss by itself")
	advance_to_next_turn()   # P1 draws their last card — fine...
	advance_to_next_turn()
	advance_to_next_turn()   # ...next draw is from an empty library
	assert_true(g.game_over)
	assert_eq(g.winner, 0)


func test_regrowth_recovers_any_card_type() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	var regrowth := give_hand(0, "Regrowth")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, regrowth, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.HAND, "an instant came back — any card type works")


# ------------------------------------------------------- assorted wave 3 --

func test_kird_ape_sizes_with_forests() -> void:
	var ape := put_battlefield(0, "Kird Ape")
	assert_eq(ape.cur_power, 1)
	put_battlefield(0, "Taiga")   # forest subtype
	assert_eq(ape.cur_power, 2)
	assert_eq(ape.cur_toughness, 3, "+1/+2 with a forest — Taiga counts")


func test_city_of_brass_taxes_its_tap() -> void:
	var city := put_battlefield(0, "City of Brass")
	assert_ok(g.tap_for_mana(0, city, 2))   # index 2 = black
	resolve_stack()   # the self-burn trigger
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1)
	assert_eq(g.players[0].life, 19, "1 damage per tap, as printed")


func test_burrowing_grants_live_mountainwalk() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var burrowing := give_hand(0, "Burrowing")
	put_battlefield(1, "Mountain")
	var blocker := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, burrowing, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {blocker.id: bear.id}), "mountainwalk")


func test_firebreathing_pumps_the_host() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Firebreathing")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, aura, 0, []))
	assert_ok(g.activate_ability(0, aura, 0, []))
	resolve_stack()
	assert_eq(bear.cur_power, 4, "2/2 + two breaths through the aura")


func test_wall_of_bone_regenerates_behind_defender() -> void:
	var wall := put_battlefield(0, "Wall of Bone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [wall.id]), "defender")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.declare_attackers(0, []))
	assert_ok(g.activate_ability(0, wall, 0, []))
	resolve_stack()
	assert_eq(wall.regeneration_shields, 1)

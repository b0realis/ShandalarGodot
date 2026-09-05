extends GameTest
## Per-card behavior tests for the Limited (Alpha) starter pool.
## One test (at least) per non-vanilla card — the card file's doc comment
## says what the card does; the test here proves it. Add a test whenever
## you add a card: docs/adding-cards.md, step 4.


func test_registry_loaded_the_pool() -> void:
	# 821 hand-written (incl. waves 1-74) + 76 auto-generated
	# (see tests/cards/test_pool_wave1.gd). Grows as stubs graduate from
	# cards/todo/ — keep this exact so a broken card file (which fails to
	# register) is caught immediately.
	assert_eq(CardRegistry.size(), 897, "pool through wave 74 — 896 stubs plus Nalathni Dragon, the card the pool DEFINITION missed")
	assert_not_null(CardRegistry.get_card("Lightning Bolt"))


# ------------------------------------------------------------ Lightning Bolt --

func test_bolt_kills_a_bear() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)


func test_bolt_burns_a_player() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)


func test_bolt_fizzles_when_target_dies_first() -> void:
	# Two bolts on the same 2/2: the second to resolve finds no target and
	# fizzles (CR 608.2b) — no damage is redirected anywhere.
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt1 := give_hand(0, "Lightning Bolt")
	var bolt2 := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, bolt1, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, bolt2, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20, "fizzled bolt dealt nothing")


# ----------------------------------------------------------------- Terror --

func test_terror_destroys_a_white_creature() -> void:
	var serra := put_battlefield(1, "Serra Angel")
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(serra)]))
	resolve_stack()
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD)


func test_terror_cannot_target_black_creature() -> void:
	var zombies := put_battlefield(1, "Scathe Zombies")
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, terror, [TargetRef.card(zombies)]), "Illegal target")


# ------------------------------------------------------- Ancestral Recall --

func test_ancestral_draws_three() -> void:
	var recall := give_hand(0, "Ancestral Recall")
	var hand_before := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, recall, [TargetRef.player(0)]))
	resolve_stack()
	# -1 for the cast Recall leaving hand, +3 drawn.
	assert_eq(g.players[0].hand.size(), hand_before - 1 + 3)


func test_ancestral_can_target_opponent() -> void:
	var recall := give_hand(0, "Ancestral Recall")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, recall, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 3)


# ---------------------------------------------------------------- Sol Ring --

func test_sol_ring_taps_the_turn_it_arrives() -> void:
	# Artifacts have no summoning sickness (CR 302.6 is creature-only).
	var ring := give_hand(0, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, ring, []))
	resolve_stack()
	assert_ok(g.tap_for_mana(0, ring))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 2)


# ------------------------------------------------------ Prodigal Sorcerer --

func test_prodigal_sick_on_arrival() -> void:
	var tim := put_battlefield(0, "Prodigal Sorcerer", true)   # sick
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, tim, 0, [TargetRef.player(1)]),
		"summoning sickness")


func test_prodigal_pings_for_one() -> void:
	var tim := put_battlefield(0, "Prodigal Sorcerer")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, tim, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_true(tim.tapped)
	assert_refused(g.activate_ability(0, tim, 0, [TargetRef.player(1)]),
		"already tapped")


# ------------------------------------------------------- Ankh of Mishra --

func test_ankh_punishes_every_land_drop() -> void:
	put_battlefield(1, "Ankh of Mishra")
	var land := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.play_land(0, land))
	resolve_stack()   # the trigger
	assert_eq(g.players[0].life, 18, "the land's controller takes 2")
	assert_eq(g.players[1].life, 20)


func test_ankh_hits_its_own_controller_too() -> void:
	put_battlefield(1, "Ankh of Mishra")
	var land := give_hand(1, "Swamp")
	advance_to_next_turn()   # P1's turn
	assert_ok(g.play_land(1, land))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "Ankh is symmetrical, as printed")


# -------------------------------------------------------- Holy Strength --

func test_holy_strength_pumps_enchanted_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(aura.attached_to, bear.id)
	assert_eq(bear.cur_power, 3)
	assert_eq(bear.cur_toughness, 4)


func test_holy_strength_saves_bear_from_bolt() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Holy Strength")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "3 damage vs 4 toughness")
	assert_eq(bear.damage, 3)


func test_aura_falls_off_when_host_dies() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Holy Strength")
	var terror := give_hand(1, "Terror")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, terror, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD, "orphaned aura swept by SBA")


# ---------------------------------------------------------- basic lands --

func test_forest_taps_for_green() -> void:
	var forest := put_battlefield(0, "Forest")
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)
	assert_true(forest.tapped)
	assert_refused(g.tap_for_mana(0, forest), "already tapped")


func test_full_manual_turn_land_into_bears() -> void:
	# The complete honest path: draw phase passes, play a land... two turns
	# of it, then cast Grizzly Bears with real land mana.
	var land1 := give_hand(0, "Forest")
	var land2 := give_hand(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.play_land(0, land1))
	advance_to_next_turn()          # P1's turn passes
	advance_to_next_turn()          # back to P0, main 1
	assert_ok(g.play_land(0, land2))
	assert_ok(g.tap_for_mana(0, land1))
	assert_ok(g.tap_for_mana(0, land2))
	assert_ok(g.cast_spell(0, bears, []))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)

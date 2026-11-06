extends GameTest
## Pack 10 (the Urza block), the fair AI's SYMMETRIC SPELLS (stage 4,
## casting; engine/ai/urza_spells.gd, [member AiProfile.forecasts_tactics]).
##
## Sunder, Hibernation, Rebuild, Harmonic Convergence, Catastrophe, Curfew,
## Planar Birth, Exhume, Disorder, Acidic Soil and Meltdown act on BOTH
## sides of the table. The card modules declare each one's shape
## ([member EffectBase.ai_role]); with no reader the pilot saw an untargeted
## card worth its cost and cast Sunder into its own land lead. Each is now
## priced by what the opponent loses against what we lose, from the public
## board and both graveyards, and cast only past a sweeper's bar. With the
## gate off the pilot casts as it did before Pack 10.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-10", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _lands(pid: int, land: String, n: int) -> void:
	for _i in n:
		put_battlefield(pid, land)


func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


func _cast_now(ai: AiPlayer, card: CardInstance) -> bool:
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 3:
		if card.zone != Mtg.Zone.HAND:
			break
		ai.act(g)
	return card.zone != Mtg.Zone.HAND


# ---------------------------------------------------------------------- Sunder --

func test_sunder_erases_their_land_lead() -> void:
	var ai := _ai()
	_lands(0, "Island", 5)
	put_battlefield(0, "Sol Ring")
	_lands(1, "Forest", 10)
	var sunder := give_hand(0, "Sunder")
	assert_true(_cast_now(ai, sunder))
	resolve_stack()
	assert_eq(g.players[1].battlefield.filter(func(c): return c.is_land()).size(), 0)


func test_sunder_is_kept_from_our_own_land_lead() -> void:
	var ai := _ai()
	_lands(0, "Island", 8)
	_lands(1, "Forest", 4)
	var sunder := give_hand(0, "Sunder")
	assert_false(_cast_now(ai, sunder), "eight lands of ours for their four")


func test_the_null_arm_casts_sunder_for_its_card() -> void:
	var ai := _ai(false)
	_lands(0, "Island", 8)
	_lands(1, "Forest", 4)
	var sunder := give_hand(0, "Sunder")
	assert_true(_cast_now(ai, sunder), "gate off: an untargeted card worth its cost, as before Pack 10")


# ----------------------------------------------------------------- Hibernation --

func test_hibernation_sends_their_green_army_home() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	put_battlefield(1, "Craw Wurm")
	put_battlefield(1, "Craw Wurm")
	var hibernation := give_hand(0, "Hibernation")
	assert_true(_cast_now(ai, hibernation))
	resolve_stack()
	assert_eq(g.players[1].creatures().size(), 0)


func test_hibernation_never_bounces_our_own_green() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	put_battlefield(0, "Craw Wurm")
	put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Grizzly Bears")
	var hibernation := give_hand(0, "Hibernation")
	assert_false(_cast_now(ai, hibernation))


# --------------------------------------------------------------------- Rebuild --

func test_rebuild_against_their_artifacts_only() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	put_battlefield(1, "Sol Ring")
	put_battlefield(1, "Jayemdae Tome")
	put_battlefield(1, "Icy Manipulator")
	var rebuild := give_hand(0, "Rebuild")
	assert_true(_cast_now(ai, rebuild))


func test_rebuild_is_kept_from_our_own_artifacts() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(0, "Icy Manipulator")
	var rebuild := give_hand(0, "Rebuild")
	assert_false(_cast_now(ai, rebuild))


# -------------------------------------------------------- Harmonic Convergence --

func test_harmonic_convergence_never_tops_our_own_enchantments() -> void:
	var ai := _ai()
	_lands(0, "Forest", 3)
	put_battlefield(0, "Crusade")
	put_battlefield(0, "Bad Moon")
	put_battlefield(0, "Castle")
	var convergence := give_hand(0, "Harmonic Convergence")
	assert_false(_cast_now(ai, convergence))


func test_harmonic_convergence_tops_theirs() -> void:
	var ai := _ai()
	_lands(0, "Forest", 3)
	put_battlefield(1, "Crusade")
	put_battlefield(1, "Bad Moon")
	put_battlefield(1, "Castle")
	var convergence := give_hand(0, "Harmonic Convergence")
	assert_true(_cast_now(ai, convergence))
	resolve_stack()
	assert_eq(g.players[1].battlefield.size(), 0)


# ------------------------------------------------------------------ Catastrophe --

func test_catastrophe_takes_their_creatures() -> void:
	var ai := _ai()
	_lands(0, "Plains", 6)
	_lands(1, "Forest", 6)
	for _i in 3: put_battlefield(1, "Craw Wurm")
	var catastrophe := give_hand(0, "Catastrophe")
	assert_true(_cast_now(ai, catastrophe))
	resolve_stack()
	assert_eq(g.players[1].creatures().size(), 0)
	assert_eq(g.players[0].battlefield.size(), 6, "our lands stand")


func test_catastrophe_is_kept_when_both_choices_cost_us() -> void:
	var ai := _ai()
	_lands(0, "Plains", 6)
	_lands(1, "Forest", 6)
	for _i in 3: put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	var catastrophe := give_hand(0, "Catastrophe")
	assert_false(_cast_now(ai, catastrophe))


# ----------------------------------------------------------------------- Curfew --

func test_curfew_bounces_their_only_creature() -> void:
	var ai := _ai()
	_lands(0, "Island", 1)
	var dragon := put_battlefield(1, "Shivan Dragon")
	var curfew := give_hand(0, "Curfew")
	assert_true(_cast_now(ai, curfew))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.HAND)


func test_curfew_is_kept_when_we_lose_more() -> void:
	var ai := _ai()
	_lands(0, "Island", 1)
	put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	var curfew := give_hand(0, "Curfew")
	assert_false(_cast_now(ai, curfew))


# ----------------------------------------------------------------- Planar Birth --

func test_planar_birth_when_our_graveyard_holds_the_lands() -> void:
	var ai := _ai()
	_lands(0, "Plains", 2)
	for _i in 4: _in_graveyard(0, "Plains")
	var birth := give_hand(0, "Planar Birth")
	assert_true(_cast_now(ai, birth))
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), 6)


func test_planar_birth_is_kept_when_theirs_does() -> void:
	var ai := _ai()
	_lands(0, "Plains", 2)
	for _i in 4: _in_graveyard(1, "Forest")
	var birth := give_hand(0, "Planar Birth")
	assert_false(_cast_now(ai, birth))


# ----------------------------------------------------------------------- Exhume --

func test_exhume_when_our_graveyard_is_the_better_one() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 2)
	_in_graveyard(0, "Shivan Dragon")
	_in_graveyard(1, "Grizzly Bears")
	var exhume := give_hand(0, "Exhume")
	assert_true(_cast_now(ai, exhume))
	resolve_stack()
	assert_eq(g.players[0].creatures().size(), 1)


func test_exhume_is_kept_when_theirs_is() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 2)
	_in_graveyard(0, "Grizzly Bears")
	_in_graveyard(1, "Shivan Dragon")
	var exhume := give_hand(0, "Exhume")
	assert_false(_cast_now(ai, exhume))


# ----------------------------------------------------------------------- Disorder --

func test_disorder_burns_their_white_creatures_and_them() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	put_battlefield(1, "Savannah Lions")
	put_battlefield(1, "Savannah Lions")
	var disorder := give_hand(0, "Disorder")
	assert_true(_cast_now(ai, disorder))
	resolve_stack()
	assert_eq(g.players[1].creatures().size(), 0)
	assert_eq(g.players[1].life, 18)


func test_disorder_is_kept_from_our_white_creatures() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	put_battlefield(0, "White Knight")
	put_battlefield(0, "White Knight")
	var disorder := give_hand(0, "Disorder")
	assert_false(_cast_now(ai, disorder))


# ------------------------------------------------------------------- Acidic Soil --

func test_acidic_soil_finishes_their_land_rich_board() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 3)
	_lands(1, "Forest", 8)
	g.players[1].life = 6
	var soil := give_hand(0, "Acidic Soil")
	assert_true(_cast_now(ai, soil))
	resolve_stack()
	assert_true(g.game_over)
	assert_eq(g.winner, 0)


func test_acidic_soil_never_into_our_own_death() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	_lands(1, "Forest", 8)
	g.players[0].life = 4
	var soil := give_hand(0, "Acidic Soil")
	assert_false(_cast_now(ai, soil))


# ---------------------------------------------------------------------- Meltdown --

func test_meltdown_sizes_x_to_their_artifacts() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 6)
	var ring := put_battlefield(1, "Sol Ring")
	var tome := put_battlefield(1, "Jayemdae Tome")
	var meltdown := give_hand(0, "Meltdown")
	assert_true(_cast_now(ai, meltdown))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(tome.zone, Mtg.Zone.GRAVEYARD)


func test_meltdown_spares_our_own_artifacts() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 6)
	put_battlefield(0, "Sol Ring")
	put_battlefield(0, "Jayemdae Tome")
	var meltdown := give_hand(0, "Meltdown")
	assert_false(_cast_now(ai, meltdown))


# ------------------------------------------------------------------- Opalescence --

func test_opalescence_animates_our_enchantments() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	put_battlefield(0, "Crusade")
	put_battlefield(0, "Bad Moon")
	put_battlefield(0, "Castle")
	var opalescence := give_hand(0, "Opalescence")
	assert_true(_cast_now(ai, opalescence))
	resolve_stack()
	assert_eq(g.players[0].creatures().size(), 3)


func test_opalescence_never_animates_only_theirs() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	put_battlefield(1, "Crusade")
	put_battlefield(1, "Bad Moon")
	put_battlefield(1, "Castle")
	var opalescence := give_hand(0, "Opalescence")
	assert_false(_cast_now(ai, opalescence), "three bodies for them, none for us")


func test_the_null_arm_casts_opalescence_for_its_card() -> void:
	var ai := _ai(false)
	_lands(0, "Plains", 4)
	put_battlefield(1, "Crusade")
	put_battlefield(1, "Bad Moon")
	put_battlefield(1, "Castle")
	var opalescence := give_hand(0, "Opalescence")
	assert_true(_cast_now(ai, opalescence))


# ----------------------------------------------------------------- hidden state --

## Every reading above is the public board and both graveyards: their hand
## and both libraries changed leave the answer where it was.
func test_the_symmetric_readings_ignore_hidden_zones() -> void:
	var outcomes: Array = []
	for hand in [["Counterspell", "Shivan Dragon"], ["Forest", "Swamp"]]:
		g = null
		before_each()
		var ai := _ai()
		_lands(0, "Island", 5)
		put_battlefield(0, "Sol Ring")
		_lands(1, "Forest", 10)
		for card_name in hand: give_hand(1, card_name)
		if hand[0] == "Forest":
			g.players[0].library.reverse()
			g.players[1].library.reverse()
		var sunder := give_hand(0, "Sunder")
		outcomes.append(_cast_now(ai, sunder))
	assert_eq(outcomes, [true, true])

extends GameTest
## Pack 9 (the Tempest block), the fair AI's SYMMETRIC SPELLS (stage 4,
## casting; engine/ai/tempest_spells.gd, [member AiProfile.forecasts_tactics]).
##
## Apocalypse, Cataclysm, Fade Away, Evacuation, Price of Progress, Living
## Death, Limited Resources and Mogg Infestation act on BOTH sides of the
## table (or hand the victim tokens back). The reader saw a card-local
## effect it could not price and cast each for its printed worth — an
## Apocalypse exiled our own board and our hand with it. Each is now
## priced by what the opponent loses against what we lose, from the public
## board and our own hand, and cast only past a sweeper's bar. Reins of
## Power is cast only for the lethal attack it makes. With the gate off the
## pilot casts as it did before Pack 9.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
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
	ai.act(g)
	return card.zone != Mtg.Zone.HAND


# ------------------------------------------------------------------ Apocalypse --

func test_apocalypse_never_exiles_our_better_board() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 5)
	put_battlefield(0, "Shivan Dragon")
	put_battlefield(1, "Grizzly Bears")
	var apocalypse := give_hand(0, "Apocalypse")
	assert_false(_cast_now(ai, apocalypse))


func test_apocalypse_resets_a_lost_board() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 5)
	for _i in 2: put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Shivan Dragon")
	var apocalypse := give_hand(0, "Apocalypse")
	assert_true(_cast_now(ai, apocalypse))


func test_the_null_arm_casts_apocalypse_for_its_card() -> void:
	var ai := _ai(false)
	_lands(0, "Mountain", 5)
	put_battlefield(0, "Shivan Dragon")
	put_battlefield(1, "Grizzly Bears")
	var apocalypse := give_hand(0, "Apocalypse")
	assert_true(_cast_now(ai, apocalypse), "gate off: the printed worth, as before Pack 9")


# ------------------------------------------------------------------- Cataclysm --

func test_cataclysm_only_when_they_lose_more() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	for _i in 3: put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	var cataclysm := give_hand(0, "Cataclysm")
	assert_false(_cast_now(ai, cataclysm), "two Bears of ours for none of theirs")


func test_cataclysm_cuts_their_wide_board() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	for _i in 3: put_battlefield(1, "Craw Wurm")
	_lands(1, "Forest", 6)
	var cataclysm := give_hand(0, "Cataclysm")
	assert_true(_cast_now(ai, cataclysm))
	resolve_stack()
	assert_eq(g.players[1].creatures().size(), 1)


# ------------------------------------------------------------------- Fade Away --

func test_fade_away_against_a_tapped_out_wide_board() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	for _i in 4: put_battlefield(1, "Grizzly Bears")
	var fade := give_hand(0, "Fade Away")
	assert_true(_cast_now(ai, fade), "four creatures, no open mana: four permanents")


func test_fade_away_is_kept_when_we_pay_more() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	for _i in 3: put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	_lands(1, "Forest", 3)
	var fade := give_hand(0, "Fade Away")
	assert_false(_cast_now(ai, fade))


# ------------------------------------------------------------------ Evacuation --

func test_evacuation_is_kept_from_our_own_board() -> void:
	var ai := _ai()
	_lands(0, "Island", 5)
	for _i in 2: put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	var evacuation := give_hand(0, "Evacuation")
	assert_false(_cast_now(ai, evacuation))


# ----------------------------------------------------------- Price of Progress --

func test_price_of_progress_never_burns_us_harder() -> void:
	var ai := _ai()
	_lands(0, "City of Brass", 4)
	_lands(1, "Mountain", 4)
	var price := give_hand(0, "Price of Progress")
	assert_false(_cast_now(ai, price), "eight to us, none to them")


func test_price_of_progress_finishes_them() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	_lands(1, "City of Brass", 3)
	g.players[1].life = 6
	var price := give_hand(0, "Price of Progress")
	assert_true(_cast_now(ai, price))
	resolve_stack()
	assert_true(g.game_over)
	assert_eq(g.winner, 0)


# ---------------------------------------------------------------- Living Death --

func test_living_death_when_our_graveyard_is_the_better_army() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 5)
	for _i in 2: _in_graveyard(0, "Shivan Dragon")
	put_battlefield(1, "Serra Angel")
	var death := give_hand(0, "Living Death")
	assert_true(_cast_now(ai, death))
	resolve_stack()
	assert_eq(g.players[0].creatures().size(), 2)
	assert_eq(g.players[1].creatures().size(), 0)


func test_living_death_is_kept_when_theirs_is() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 5)
	put_battlefield(0, "Serra Angel")
	for _i in 2: _in_graveyard(1, "Shivan Dragon")
	var death := give_hand(0, "Living Death")
	assert_false(_cast_now(ai, death))


# ---------------------------------------------------------- Limited Resources --

func test_limited_resources_against_their_land_lead() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	_lands(1, "Forest", 9)
	var limited := give_hand(0, "Limited Resources")
	assert_true(_cast_now(ai, limited))


func test_limited_resources_never_cuts_our_own_lands() -> void:
	var ai := _ai()
	_lands(0, "Plains", 9)
	_lands(1, "Forest", 4)
	var limited := give_hand(0, "Limited Resources")
	assert_false(_cast_now(ai, limited))


# ------------------------------------------------------------ Mogg Infestation --

func test_mogg_infestation_on_a_board_of_value() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 5)
	put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Craw Wurm")
	var infestation := give_hand(0, "Mogg Infestation")
	assert_true(_cast_now(ai, infestation))
	resolve_stack()
	assert_eq(g.players[1].creatures().size(), 4, "four Goblins for an Angel and a Wurm")


func test_mogg_infestation_never_hands_them_goblins_for_elves() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 5)
	for _i in 3: put_battlefield(1, "Llanowar Elves")
	var infestation := give_hand(0, "Mogg Infestation")
	assert_false(_cast_now(ai, infestation), "six 1/1s for three 1/1s")


# -------------------------------------------------------------- Reins of Power --

func test_reins_of_power_steals_the_lethal_attack() -> void:
	var ai := _ai()
	_lands(0, "Island", 4)
	for _i in 2: put_battlefield(1, "Craw Wurm")
	g.players[1].life = 10
	var reins := give_hand(0, "Reins of Power")
	assert_true(_cast_now(ai, reins))


func test_reins_of_power_is_kept_short_of_lethal() -> void:
	var ai := _ai()
	_lands(0, "Island", 4)
	put_battlefield(1, "Craw Wurm")
	put_battlefield(0, "Grizzly Bears")
	var reins := give_hand(0, "Reins of Power")
	assert_false(_cast_now(ai, reins))

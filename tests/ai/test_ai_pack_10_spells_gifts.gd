extends GameTest
## Pack 10 (the Urza block), the fair AI's GIFTS AND EXCHANGES (stage 4,
## casting; engine/ai/urza_spells.gd, [member AiProfile.forecasts_tactics]).
##
## Sleeper Agent hands itself to the opponent as it enters and then pings
## its controller each upkeep; read as a plain 3/3 for {B} it was cast
## into an empty board of ours and beat us down (the B5 batch's note).
## Gilded Drake swaps itself for their best creature — or is sacrificed
## with nothing to take. Donate gives away our liability, Brand takes back
## what we own, Flicker brings a stolen permanent home, Wild Dogs goes to
## the player with the most life. Each is priced off the public board.
## With the gate off the pilot casts as before Pack 10.


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


func _cast_now(ai: AiPlayer, card: CardInstance) -> bool:
	advance_to_step(Mtg.Step.MAIN1)
	g.players[0].lands_played_this_turn = 99
	for _i in 3:
		if card.zone != Mtg.Zone.HAND:
			break
		ai.act(g)
	return card.zone != Mtg.Zone.HAND


# ---------------------------------------------------------------- Sleeper Agent --

func test_sleeper_agent_is_no_plain_three_three() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 1)
	var agent := give_hand(0, "Sleeper Agent")
	assert_false(_cast_now(ai, agent), "their 3/3 into our empty board, 2 a turn at 20 life")


func test_sleeper_agent_finishes_them_at_low_life() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 1)
	put_battlefield(0, "Wall of Stone")
	g.players[1].life = 4
	var agent := give_hand(0, "Sleeper Agent")
	assert_true(_cast_now(ai, agent))
	resolve_stack()
	assert_eq(agent.controller_id, 1, "theirs now, and its upkeep is theirs")


func test_the_null_arm_casts_the_agent_as_a_creature() -> void:
	var ai := _ai(false)
	_lands(0, "Swamp", 1)
	var agent := give_hand(0, "Sleeper Agent")
	assert_true(_cast_now(ai, agent), "gate off: a 3/3 for one, as before Pack 10")


# ----------------------------------------------------------------- Gilded Drake --

func test_gilded_drake_takes_their_dragon() -> void:
	var ai := _ai()
	_lands(0, "Island", 2)
	var dragon := put_battlefield(1, "Shivan Dragon")
	var drake := give_hand(0, "Gilded Drake")
	assert_true(_cast_now(ai, drake))
	resolve_stack()
	assert_eq(dragon.controller_id, 0)
	assert_eq(drake.controller_id, 1)


func test_gilded_drake_with_nothing_to_take_is_kept() -> void:
	var ai := _ai()
	_lands(0, "Island", 2)
	var drake := give_hand(0, "Gilded Drake")
	assert_false(_cast_now(ai, drake), "no creature of theirs: a two-mana self-sacrifice")


func test_gilded_drake_is_kept_from_a_worse_creature() -> void:
	var ai := _ai()
	_lands(0, "Island", 2)
	put_battlefield(1, "Llanowar Elves")
	var drake := give_hand(0, "Gilded Drake")
	assert_false(_cast_now(ai, drake), "our 3/3 flier for their 1/1")


# ----------------------------------------------------------------------- Donate --

func test_donate_hands_over_the_agent_that_is_killing_us() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	var agent := put_battlefield(0, "Sleeper Agent")
	advance_to_step(Mtg.Step.MAIN1)
	g.change_control(agent, 0)   # its arrival handed it over; it is back with us
	assert_eq(agent.controller_id, 0)
	g.players[0].life = 5
	var donate := give_hand(0, "Donate")
	assert_true(_cast_now(ai, donate))
	resolve_stack()
	assert_eq(agent.controller_id, 1)


func test_donate_never_gives_away_a_creature_we_keep() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	put_battlefield(0, "Grizzly Bears")
	var donate := give_hand(0, "Donate")
	assert_false(_cast_now(ai, donate))


# ------------------------------------------------------------------------ Brand --

func test_brand_takes_back_what_we_own() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 1)
	var dragon := put_battlefield(0, "Shivan Dragon")
	g.change_control(dragon, 1)
	var brand := give_hand(0, "Brand")
	assert_true(_cast_now(ai, brand))
	resolve_stack()
	assert_eq(dragon.controller_id, 0)


func test_brand_with_nothing_of_ours_away_is_kept() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 1)
	put_battlefield(1, "Shivan Dragon")
	var brand := give_hand(0, "Brand")
	assert_false(_cast_now(ai, brand))


# ---------------------------------------------------------------------- Flicker --

func test_flicker_brings_our_stolen_creature_home() -> void:
	var ai := _ai()
	_lands(0, "Plains", 2)
	var angel := put_battlefield(0, "Serra Angel")
	g.change_control(angel, 1)
	var flicker := give_hand(0, "Flicker")
	assert_true(_cast_now(ai, flicker))
	resolve_stack()
	assert_eq(angel.controller_id, 0)


func test_flicker_with_nothing_to_gain_is_kept() -> void:
	var ai := _ai()
	_lands(0, "Plains", 2)
	put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Shivan Dragon")
	var flicker := give_hand(0, "Flicker")
	assert_false(_cast_now(ai, flicker))


# -------------------------------------------------------------------- Wild Dogs --

func test_wild_dogs_wait_while_they_lead_on_life() -> void:
	var ai := _ai()
	_lands(0, "Forest", 1)
	g.players[1].life = 25
	var dogs := give_hand(0, "Wild Dogs")
	assert_false(_cast_now(ai, dogs), "their upkeep would hand them over")


func test_wild_dogs_are_cast_when_we_lead() -> void:
	var ai := _ai()
	_lands(0, "Forest", 1)
	g.players[1].life = 15
	var dogs := give_hand(0, "Wild Dogs")
	assert_true(_cast_now(ai, dogs))

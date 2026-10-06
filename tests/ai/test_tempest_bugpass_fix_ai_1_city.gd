extends GameTest
## Pack 9 bug pass (h6-2): the land drop that sacrifices our own City of
## Traitors ([member AiProfile.forecasts_tactics]).
##
## "When you play another land, sacrifice this land." Nothing in the land
## choice read a LAND_PLAYED trigger on a permanent ALREADY on the table, so
## the Wizard played a Mountain beside its City and two Mountains, lost the
## City, and with it the Hill Giant the four mana were for. The drop is now
## priced ([method AiPlayer._drop_costs_mana]): made when the land makes as
## much as what it sacrifices, when the swap unlocks a cast now (the colour
## the City cannot make), or when the lands in hand make more than the City;
## otherwise the land waits. Gate off: the drop, as before. Their hidden
## hand never moves it.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(develops_late := false, on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = develops_late
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


## Seat 0's main phase played out by the AI (seat 1 only passes).
func _play_main(ai: AiPlayer) -> void:
	var turn := g.turn_number
	for k in 30:
		if g.game_over or g.turn_number != turn or g.current_step() != Mtg.Step.MAIN1: break
		if g.priority_player == 0:
			var had_stack := not g.stack.is_empty()
			var did := ai.act(g)
			if (did == "" or did == "pass") and not had_stack: break
		else:
			g.pass_priority(g.priority_player)


func _scenario(develops_late: bool, on := true, their_hand: Array = []) -> Array:
	var ai := _ai(develops_late, on)
	var city := put_battlefield(0, "City of Traitors")
	for k in 2: put_battlefield(0, "Mountain")
	var mountain := give_hand(0, "Mountain")
	var giant := give_hand(0, "Hill Giant")
	for card_name in their_hand: give_hand(1, card_name)
	_play_main(ai)
	resolve_stack()
	return [city, giant, mountain]


func test_the_city_stays_and_the_giant_is_cast() -> void:
	var out := _scenario(false)
	assert_eq((out[0] as CardInstance).zone, Mtg.Zone.BATTLEFIELD, "the City stays")
	assert_eq((out[1] as CardInstance).zone, Mtg.Zone.BATTLEFIELD, "City + two Mountains: the Giant")
	assert_eq((out[2] as CardInstance).zone, Mtg.Zone.HAND, "the Mountain waits")


func test_the_default_wizard_keeps_its_city() -> void:
	var out := _scenario(AiProfile.wizard().develops_late)
	assert_eq((out[0] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)


func test_gate_off_plays_the_mountain_as_before() -> void:
	var out := _scenario(false, false)
	assert_eq((out[2] as CardInstance).zone, Mtg.Zone.BATTLEFIELD, "gate off: the drop")
	assert_eq((out[0] as CardInstance).zone, Mtg.Zone.GRAVEYARD, "and the City it costs")


func test_the_city_ignores_their_hidden_hand() -> void:
	var zones: Array = []
	for hand in [["Counterspell", "Stone Rain"], ["Mountain"], []]:
		g = null
		before_each()
		zones.append((_scenario(false, true, hand)[0] as CardInstance).zone)
	assert_eq(zones, [Mtg.Zone.BATTLEFIELD, Mtg.Zone.BATTLEFIELD, Mtg.Zone.BATTLEFIELD])


## The colour the City cannot make: Grizzly Bears wants {G}, and only the
## Forest that costs the City gives it — the swap is worth it.
func test_a_forest_for_the_green_the_city_cannot_make() -> void:
	var ai := _ai()
	var city := put_battlefield(0, "City of Traitors")
	put_battlefield(0, "Mountain")
	var forest := give_hand(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	_play_main(ai)
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(city.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


## A hand of lands that make more than the City between them: the switch
## pays back within the hand, so the drop is made.
func test_three_lands_in_hand_replace_the_city() -> void:
	var ai := _ai()
	var city := put_battlefield(0, "City of Traitors")
	put_battlefield(0, "Mountain")
	give_hand(0, "Mountain")
	give_hand(0, "Mountain")
	give_hand(0, "Mountain")
	_play_main(ai)
	resolve_stack()
	assert_eq(city.zone, Mtg.Zone.GRAVEYARD)
	var played := 0
	for inst in g.players[0].battlefield:
		if inst.data.card_name == "Mountain": played += 1
	assert_eq(played, 2, "one Mountain played")


## A land drop that sacrifices nothing is the drop it always was.
func test_no_city_no_change() -> void:
	var ai := _ai()
	for k in 2: put_battlefield(0, "Mountain")
	var mountain := give_hand(0, "Mountain")
	_play_main(ai)
	assert_eq(mountain.zone, Mtg.Zone.BATTLEFIELD)


func test_the_line_reader() -> void:
	assert_true(EffectIntent.sacrifices_its_source("When you play another land, sacrifice this land."))
	assert_false(EffectIntent.sacrifices_its_source("Whenever a land enters, you gain 1 life."))
